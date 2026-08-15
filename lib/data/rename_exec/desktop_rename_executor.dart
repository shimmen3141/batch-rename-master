import 'dart:io';

import 'package:path/path.dart' as p;

import 'native_exclusive_rename.dart';
import 'rename_executor.dart';

typedef DesktopRenameOperation =
    Future<NativeRenameResult> Function(String source, String destination);

/// 更新日時の書き込み(test で差し替えるために外へ出す)。
typedef DesktopSetModifiedAt =
    Future<void> Function(String path, DateTime value);

/// 改名の前に「目標名に実体があるか」をfilesystemへ問い合わせる述語(REQ-025)。
///
/// **testで差し替えるために外へ出す。** 大文字小文字や正規化を区別しない
/// filesystemは、`Photo.jpg`がある状態で`photo.jpg`を「実在する」と答える。
/// その条件はLinuxのcontainerでは作れないので、条件そのものを注入する。
abstract interface class DesktopPathProbe {
  /// [path] に実体があるか(symlinkを辿らない)。
  Future<bool> exists(String path);
}

/// Windows / Linux / macOS の実ファイル用リネーム adapter。
///
/// 通常の`File.rename`はOSによって既存fileを置換しうるため、排他的なnative rename
/// を使って既存fileを原子的に上書きしない(INV-002)。成功時は絶対pathを新しい
/// handleとして返す(REQ-001)。
///
/// **目標名の実在確認は、原子的no-replaceがあっても省かない**(REQ-025)。
/// フラグを受け付けながら黙って無視する環境をアプリは区別できないため、
/// 省くとその環境で事前検出まで失われる。
class DesktopRenameExecutor implements RenameExecutor, ModifiedAtWriter {
  DesktopRenameExecutor({
    DesktopRenameOperation? rename,
    DesktopSetModifiedAt? setModifiedAt,
    DesktopPathProbe? probe,
  }) : _rename = rename ?? _exclusiveRename,
       _setModifiedAt = setModifiedAt ?? _setLastModified,
       _probe = probe ?? const _RealPathProbe();

  final DesktopRenameOperation _rename;
  final DesktopSetModifiedAt _setModifiedAt;
  final DesktopPathProbe _probe;

  static Future<NativeRenameResult> _exclusiveRename(
    String source,
    String destination,
  ) async => renameFileWithoutOverwrite(source, destination);

  static Future<void> _setLastModified(String path, DateTime value) =>
      File(path).setLastModified(value);

  /// 更新日時ずらし(005 REQ-014)。改名の副次処理なので、失敗しても理由を
  /// 返すだけで実体の名前には触れない(REQ-016 は呼び出し側で保証する)。
  @override
  Future<RenameError?> setModifiedAt(String handle, DateTime value) async {
    try {
      await _setModifiedAt(handle, value);
      return null;
    } catch (error) {
      // 分類は rename と同じ [errorOf] に任せる。errorCode の数値は OS で意味が
      // 違う(POSIX の 5 は EIO、Win32 の 5 は ACCESS_DENIED)ので独自に読まない。
      // ここで捕らえるのは FileSystemException だけではない — この port は
      // 「例外を投げない」と約束しており(REQ-017)、想定外の例外を通すと
      // REQ-016(更新日時の失敗で実行を止めない)が破れる。
      final classified = errorOf(error);
      return RenameError(
        classified.kind,
        '更新日時を設定できません: ${classified.message ?? error}',
      );
    }
  }

  @override
  Future<RenameResult> rename(String handle, String newName) async {
    if (p.isAbsolute(newName) ||
        p.basename(newName) != newName ||
        newName == '.' ||
        newName == '..') {
      return RenameFailed(
        RenameError(RenameErrorKind.io, 'ファイル名にパスを含めることはできません: $newName'),
      );
    }
    final destination = p.join(p.dirname(handle), newName);
    try {
      final sourceType = await FileSystemEntity.type(
        handle,
        followLinks: false,
      );
      if (sourceType == FileSystemEntityType.notFound) {
        return RenameFailed(
          RenameError(RenameErrorKind.notFound, '対象が見つかりません: $handle'),
        );
      }

      // REQ-025: 目標名の実在を**常に**確認する。原子的no-replaceがあっても
      // 省かない — フラグを受け付けながら黙って無視する環境を区別できないため。
      //
      // 実体があるなら、そのまま改名しない。
      //
      // **ただし「その実体は自分自身ではないか」を判定しない。** 大文字小文字や
      // 正規化を区別しないfilesystemでは、`Photo.jpg -> photo.jpg` のような改名
      // (case-only改名)で目標名が「実在する」ことになるが、それは自分自身である。
      //
      // 判定で言い当てようとして5回失敗した(`013:T11`のreview attempt 1〜5)。
      // 文字列比較、`p.equals`、小文字化、`identical`(inode)、親directoryの
      // byte一致 — **毎回、増やした条件の外側に反例があった**。
      //
      // **判定をやめ、一時名を経由して確かめる。** 自分自身なら1段目で目標名が
      // 空くので2段目が通り、本物の衝突なら2段目が`EEXIST`で止まる。
      // **一度も上書きrenameを使わない**(どちらの段も排他rename)。
      if (await _probe.exists(destination)) {
        // **`await` を落とさない。** `try { return future; }` はfutureをtryの
        // 外で待つので、この先で投げられた例外がcatchへ入らず呼び出し側へ抜ける
        // (REQ-017違反)。review attempt 6で指摘された。
        return await _renameViaTemporary(handle, destination, newName);
      }

      final nativeResult = await _rename(handle, destination);
      if (nativeResult == NativeRenameResult.success) {
        return Renamed(File(destination).absolute.path, name: newName);
      }
      return RenameFailed(_nativeError(nativeResult, handle, destination));
    } catch (error) {
      return RenameFailed(errorOf(error));
    }
  }

  /// 一時名を経由して [destination] へ改名する(case-only改名の経路)。
  ///
  /// 1. 排他renameで **一意な一時名** へ退避する。一意なので衝突しない。
  /// 2. 排他renameで一時名から目標名へ進める。
  ///    - 成功: 目標名の実体は自分自身だった(case-only改名)。改名は完了。
  ///    - `nameConflict`: 目標名には**別の実体**がある。3へ。
  /// 3. 排他renameで元の名前へ巻き戻し、`nameConflict`を返す。
  ///
  /// **1と2の間で異常終了すると、一時名のfileが残る。** 元の名前は空くので
  /// 次回の実行を妨げない(preflightの残骸と違い、恒久的な阻害にならない)。
  /// 名前で正体が分かり、利用者が直せる。窓はsyscall 2回の間だけで、しかも
  /// 目標名が実在するときにしか通らない。
  ///
  /// **3にも失敗した場合、実体は一時名にあるまま`RenameFailed`を返す。**
  /// これは`OP-004`の事後条件「失敗時、実体は変化しない」の例外である
  /// (契約の`open_questions` OQ-007へ登録済み)。理由に現在の名前を含めるので、
  /// 結果の提示(REQ-013)が利用者へ届ける。
  Future<RenameResult> _renameViaTemporary(
    String handle,
    String destination,
    String newName,
  ) async {
    final directory = p.dirname(handle);
    final base = p.basename(handle);

    String? temporary;
    for (var n = 0; n < 32; n++) {
      final candidate = p.join(directory, '$base.renaming-swap-$n');
      final result = await _rename(handle, candidate);
      if (result == NativeRenameResult.success) {
        temporary = candidate;
        break;
      }
      if (result != NativeRenameResult.nameConflict) {
        return RenameFailed(_nativeError(result, handle, candidate));
      }
    }
    if (temporary == null) {
      return RenameFailed(
        RenameError(RenameErrorKind.io, '一時名を確保できません: $handle'),
      );
    }

    final forward = await _rename(temporary, destination);
    if (forward == NativeRenameResult.success) {
      return Renamed(File(destination).absolute.path, name: newName);
    }

    // 目標名には別の実体がある。**元の名前へ戻す。**
    final rollback = await _rename(temporary, handle);
    if (rollback != NativeRenameResult.success) {
      return RenameFailed(
        RenameError(
          RenameErrorKind.io,
          '改名に失敗し、元の名前へも戻せませんでした。'
          '現在の名前: ${p.basename(temporary)}',
        ),
      );
    }
    // 巻き戻せたので実体は元の名前にある。**理由に一時名を出さない** —
    // 既に存在しない名前を利用者へ見せることになる。
    return RenameFailed(_nativeError(forward, handle, destination));
  }

  static RenameError _nativeError(
    NativeRenameResult result,
    String source,
    String destination,
  ) {
    return switch (result) {
      NativeRenameResult.success => RenameError(
        RenameErrorKind.unknown,
        '成功結果を失敗として処理しました',
      ),
      NativeRenameResult.nameConflict => RenameError(
        RenameErrorKind.nameConflict,
        '同名のファイルが既に存在します: $destination',
      ),
      NativeRenameResult.notFound => RenameError(
        RenameErrorKind.notFound,
        '対象が見つかりません: $source',
      ),
      NativeRenameResult.permissionDenied => RenameError(
        RenameErrorKind.permissionDenied,
        '名前を変更する権限がありません: $source',
      ),
      NativeRenameResult.unsupported => RenameError(
        RenameErrorKind.io,
        'このplatformまたはfilesystemは排他的renameに対応していません: $source',
      ),
      NativeRenameResult.io => RenameError(
        RenameErrorKind.io,
        '排他的renameに失敗しました: $source',
      ),
    };
  }

  /// `dart:io` の例外をポートの失敗理由へ分類する(REQ-017)。
  static RenameError errorOf(Object error) {
    if (error is PathNotFoundException) {
      return RenameError(RenameErrorKind.notFound, error.message);
    }
    if (error is PathAccessException) {
      return RenameError(RenameErrorKind.permissionDenied, error.message);
    }
    if (error is FileSystemException) {
      final text = error.message.toLowerCase();
      if (text.contains('exist') || text.contains('already')) {
        return RenameError(RenameErrorKind.nameConflict, error.message);
      }
      return RenameError(RenameErrorKind.io, error.message);
    }
    return RenameError(RenameErrorKind.unknown, error.toString());
  }
}

/// 実filesystemを見る [DesktopPathProbe]。
class _RealPathProbe implements DesktopPathProbe {
  const _RealPathProbe();

  @override
  Future<bool> exists(String path) async =>
      await FileSystemEntity.type(path, followLinks: false) !=
      FileSystemEntityType.notFound;
}
