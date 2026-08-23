import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'native_exclusive_rename.dart';
import 'plain_rename.dart';
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
    PlainRenameOperation? plainRename,
    DesktopPathProbe? probe,
  }) : _rename = rename ?? _exclusiveRename,
       _plainRename = plainRename ?? plainRenameFile,
       _setModifiedAt = setModifiedAt ?? _setLastModified,
       _probe = probe ?? const _RealPathProbe();

  final DesktopRenameOperation _rename;
  final PlainRenameOperation _plainRename;
  final DesktopSetModifiedAt _setModifiedAt;
  final DesktopPathProbe _probe;

  static Future<NativeRenameResult> _exclusiveRename(
    String source,
    String destination,
  ) async => renameFileWithoutOverwrite(source, destination);

  /// 改名を1回行う。**すべての改名はここを通る。**
  ///
  /// nativeが[NativeRenameResult.fallbackRequired]を返したら、通常renameへ落とす
  /// (013 REQ-005)。**「Androidかどうか」はここでは判定しない** — 落としてよいか
  /// どうかはOSを知っている C が結果として渡してくる(ADR-003)。
  ///
  /// 落としてよい理由は、[_renameTo]と[_renameThroughTemporary]が**この呼び出しの
  /// 直前に目標名の不在を確認している**ことである(REQ-025)。確認と改名の間は
  /// 原子的ではなくなるので、005 INV-002の成立範囲はその窓の分だけ狭まる
  /// (005 contract revision 4 が受容した)。
  Future<NativeRenameResult> _renameOnce(
    String source,
    String destination,
  ) async {
    final result = await _rename(source, destination);
    if (result != NativeRenameResult.fallbackRequired) return result;
    return _plainRename(source, destination);
  }

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
      // **判定をやめ、一時名を経由して確かめる。** 退避すると元の名前が空くので、
      // 目標名の実体が自分自身だったならもう存在しない。**まだ存在するなら
      // 別の実体である。** 観測するだけで、同一性を推測しない。
      // **一度も上書きrenameを使わない**(どのrenameも排他rename)。
      if (await _probe.exists(destination)) {
        // **`await` を落とさない。** `try { return future; }` はfutureをtryの
        // 外で待つので、この先で投げられた例外がcatchへ入らず呼び出し側へ抜ける
        // (REQ-017違反)。review attempt 6で指摘された。
        return await _renameViaTemporary(handle, destination, newName);
      }

      final nativeResult = await _renameOnce(handle, destination);
      if (nativeResult == NativeRenameResult.success) {
        return Renamed(File(destination).absolute.path, name: newName);
      }
      return RenameFailed(_nativeError(nativeResult, handle, destination));
    } catch (error) {
      return RenameFailed(errorOf(error));
    }
  }

  /// 一時名を経由して [destination] へ改名する。
  ///
  /// **目標名に実体があるときの経路であり、case-only改名専用ではない。**
  /// ありふれた重複名もここを通る。再採番(REQ-023)が繰り返されると、
  /// **1件の改名要求につき最大`renumberLimit + 1`回この経路を通る**。
  ///
  /// 1. 排他renameで **一意な一時名** へ退避する。**退避先も実在確認する。**
  /// 2. **目標名をもう一度観測する。** 退避で元の名前が空いたので、目標名の実体が
  ///    自分自身だったならもう存在しない。**まだ存在するなら別の実体**なので、
  ///    3を実行せず4へ進む。
  /// 3. 排他renameで一時名から目標名へ進める。成功なら改名は完了。
  /// 4. 失敗したら、排他renameで元の名前へ巻き戻して`nameConflict`を返す。
  ///    **巻き戻し先も実在確認する。**
  ///
  /// **退避したあと異常終了すると、一時名のfileが残る。** 元の名前は空くので
  /// 次回の実行を妨げない(preflightの残骸と違い、恒久的な阻害にならない)。
  /// 名前で正体が分かり、利用者が直せる。窓はsyscall 2回の間だけで、しかも
  /// 目標名が実在するときにしか通らない。
  ///
  /// **4の巻き戻しにも失敗した場合、実体は一時名にあるまま`RenameFailed`を返す。**
  /// これは`OP-004`の事後条件「失敗時、実体は変化しない」の例外である
  /// (契約の`open_questions` OQ-007へ登録済み)。理由に現在の名前を含めるので、
  /// 結果の提示(REQ-013)が利用者へ届ける。
  Future<RenameResult> _renameViaTemporary(
    String handle,
    String destination,
    String newName,
  ) async {
    final directory = p.dirname(handle);
    final base = _temporaryBase(p.basename(handle));

    String? temporary;
    for (var n = 0; n < 32; n++) {
      final candidate = p.join(directory, '$base.renaming-swap-$n');
      // **退避先にも実在確認を省かない**(REQ-025)。フラグを黙って無視する
      // 環境では排他renameが成功してしまい、**前回の異常終了で残った実体を
      // 上書きする**。実装自身がその残骸を「利用者が直せる」として受容範囲に
      // 置いている以上、想定外の状態ではない。
      if (await _probe.exists(candidate)) continue;
      // ここで例外が出ても外側の`try`が受ける(`return await`)。**内側に
      // catchを置かない** — 冗長でtestが固定できず、「検査済み」と誤認させる。
      final result = await _renameOnce(handle, candidate);
      if (result == NativeRenameResult.success) {
        temporary = candidate;
        break;
      }
      if (result != NativeRenameResult.nameConflict) {
        // **観測済みの衝突を捨てない。** この関数へ入った時点で、目標名に
        // 実体があることをprobeで肯定的に観測している。退避が別の理由で
        // 失敗したからといって`io`等を返すと、呼び出し側の再採番
        // (REQ-023)は`nameConflict`しか拾わないので**再採番されず実行全体が
        // 止まる**。内部の失敗理由は本文へ併記する。
        return RenameFailed(
          _conflictWithDetail(destination, result, handle, candidate),
        );
      }
    }
    if (temporary == null) {
      // 同上。衝突は観測済みなので`nameConflict`として返し、再採番へ繋ぐ。
      return RenameFailed(
        RenameError(
          RenameErrorKind.nameConflict,
          '同名のファイルが既に存在します: $destination(一時名を確保できませんでした)',
        ),
      );
    }

    // **1段目を通った。ここから先は必ず巻き戻し経路を通る。**
    //
    // 個別のawaitをcatchで囲むのではなく、**1段目成功以降をまとめて囲む**。
    // 事例ごとに囲む形は、awaitを1つ足すたびに漏れる(review attempt 11で、
    // attempt 9が新設したprobeが2箇所とも漏れていた)。
    try {
      // **目標名をもう一度観測する。**
      //
      // 退避で元の名前が空いたので、目標名の実体が「自分自身」だったなら
      // **もう存在しない**。まだ存在するなら、それは**別の実体**である。
      // **判定ではなく観測**であり、case感度も正規化感度も推測しない。
      //
      // ここを省くと、no-replaceフラグを黙って無視する環境で2段目が成功し、
      // **実在を確認済みの別の実体を上書きする**(REQ-025の存在理由そのもの)。
      if (await _probe.exists(destination)) {
        return await _rollbackAfter(
          temporary,
          handle,
          RenameError(
            RenameErrorKind.nameConflict,
            '同名のファイルが既に存在します: $destination',
          ),
        );
      }

      final forward = await _renameOnce(temporary, destination);
      if (forward == NativeRenameResult.success) {
        return Renamed(File(destination).absolute.path, name: newName);
      }
      return await _rollbackAfter(
        temporary,
        handle,
        _nativeError(forward, handle, destination),
      );
    } catch (error) {
      return await _rollbackAfter(temporary, handle, errorOf(error));
    }
  }

  /// 一時名 [temporary] を [handle] へ戻し、[reason] を失敗として返す。
  ///
  /// **戻せなかった場合は、現在の名前(一時名)を理由に含める。** このとき実体は
  /// 一時名にあるので、`OP-004`の事後条件「失敗時、実体は変化しない」の例外に
  /// なる(契約の`open_questions` OQ-007)。理由に名前を出さないと、利用者は
  /// どのfileがどうなったかを知る手立てを失う。
  Future<RenameResult> _rollbackAfter(
    String temporary,
    String handle,
    RenameError reason,
  ) async {
    // **巻き戻し先にも実在確認を省かない**(REQ-025)。退避と巻き戻しの間に
    // 他processが元の名前を作っていると、フラグを黙って無視する環境では
    // **その実体を上書きする**。戻せないなら戻さず、現在の名前を理由へ出す。
    // **probeもrenameもまとめて囲む。** どちらが投げても「戻せなかった」として
    // 現在の名前を理由へ出す。ここで例外を漏らすと、実体が一時名にあるのに
    // 名前がどこにも出ない。
    NativeRenameResult rollback;
    try {
      rollback = await _probe.exists(handle)
          ? NativeRenameResult.nameConflict
          : await _renameOnce(temporary, handle);
    } catch (_) {
      rollback = NativeRenameResult.io;
    }
    if (rollback == NativeRenameResult.success) return RenameFailed(reason);
    return RenameFailed(
      RenameError(
        RenameErrorKind.io,
        '${reason.message ?? reason.kind.name} '
        '元の名前へも戻せませんでした。現在の名前: ${p.basename(temporary)}',
      ),
    );
  }

  /// 観測済みの衝突を`nameConflict`として返しつつ、内部の失敗理由を併記する。
  static RenameError _conflictWithDetail(
    String destination,
    NativeRenameResult result,
    String source,
    String candidate,
  ) {
    final detail = _nativeError(result, source, candidate);
    return RenameError(
      RenameErrorKind.nameConflict,
      '同名のファイルが既に存在します: $destination'
      '(一時名への退避に失敗: ${detail.message ?? detail.kind.name})',
    );
  }

  /// 一時名のbase。`.renaming-swap-N` を足しても `NAME_MAX`(255 byte)を
  /// 超えないよう、**byte長で**切り詰める。
  ///
  /// 超えると排他renameが`ENAMETOOLONG`で失敗し、`io`として返る。呼び出し側の
  /// 再採番(REQ-023)は`nameConflict`しか拾わないので、**長い名前のときだけ
  /// 再採番が働かず実行全体が止まる**(review attempt 9で実FS再現)。
  static String _temporaryBase(String name) {
    const suffix = '.renaming-swap-00'; // 最長の接尾辞
    const limit = 255;
    final bytes = utf8.encode(name);
    final room = limit - suffix.length;
    if (bytes.length <= room) return name;
    // **切り詰めると元の名前が読めなくなる。** 同じ前置を持つ別fileの残骸と
    // 区別できるよう、元名から求めた短いhashを付ける。
    final digest = name.hashCode
        .toUnsigned(32)
        .toRadixString(16)
        .padLeft(8, '0');
    var cut = room - digest.length - 1;
    // UTF-8のcode point境界で切る。境界の途中(continuation byte)なら戻る。
    while (cut > 0 && (bytes[cut] & 0xC0) == 0x80) {
      cut -= 1;
    }
    return '${utf8.decode(bytes.sublist(0, cut))}-$digest';
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
      // [_renameOnce]が通常renameへ落とすので、ここへは届かない。
      // 届いたときは劣化が行われなかったということなので、握りつぶさず失敗にする。
      NativeRenameResult.fallbackRequired => RenameError(
        RenameErrorKind.io,
        '通常renameへの切り替えが行われませんでした: $source',
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
