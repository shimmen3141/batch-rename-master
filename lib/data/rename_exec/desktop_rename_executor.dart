import 'dart:io';

import 'package:path/path.dart' as p;

import 'native_exclusive_rename.dart';
import 'rename_executor.dart';

typedef DesktopRenameOperation =
    Future<NativeRenameResult> Function(String source, String destination);

/// 更新日時の書き込み(test で差し替えるために外へ出す)。
typedef DesktopSetModifiedAt =
    Future<void> Function(String path, DateTime value);

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
  }) : _rename = rename ?? _exclusiveRename,
       _setModifiedAt = setModifiedAt ?? _setLastModified;

  final DesktopRenameOperation _rename;
  final DesktopSetModifiedAt _setModifiedAt;

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

      // REQ-025: 目標名が実在しないことを確認してから改名する。**原子的
      // no-replace があっても省かない。** 確認と改名の間(TOCTOU)は native の
      // 排他 rename が塞ぐが、それが実際に効かない環境ではこの確認だけが残る。
      final destinationType = await FileSystemEntity.type(
        destination,
        followLinks: false,
      );
      // 「実体があるか」ではなく「**別の実体**があるか」で判定する(REQ-025)。
      //
      // 大文字小文字を区別しないfilesystem(Windows、macOSのAPFS既定)や
      // 正規化を区別しないfilesystem(APFS)では、`Photo.jpg -> photo.jpg` の
      // ような改名で目標名が「実在する」ことになる。**それは自分自身である。**
      //
      // **case感度も正規化感度もアプリ側で推測しない。** `FileSystemEntity.identical`
      // がfilesystemに問い合わせて同一実体かを返す。名前の文字列比較で代用しようと
      // して3回失敗した(`013:T11`のreview attempt 1〜3)。
      var sameEntity = false;
      if (destinationType != FileSystemEntityType.notFound) {
        try {
          sameEntity = await FileSystemEntity.identical(handle, destination);
        } on FileSystemException {
          // 判定できないときは「別の実体」として扱う。**安全側へ倒す** —
          // 誤って同一とみなすと、次の行で既存を上書きする。
          sameEntity = false;
        }
        if (!sameEntity) {
          return RenameFailed(
            RenameError(
              RenameErrorKind.nameConflict,
              '同名のファイルが既に存在します: $destination',
            ),
          );
        }
      }

      if (sameEntity) {
        // 目標名は自分自身を指している(大文字小文字や正規化だけの違い)。
        // **排他renameは使えない** — macOSの`renamex_np(RENAME_EXCL)`は
        // この場合も`EEXIST`を返す。同一実体だと確認済みなので、通常のrenameで
        // 上書きされる相手は存在しない(INV-002を破らない)。
        await File(handle).rename(destination);
        return Renamed(File(destination).absolute.path, name: newName);
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
