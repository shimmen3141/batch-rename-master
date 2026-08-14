import 'dart:io';

import 'package:path/path.dart' as p;

import 'native_exclusive_rename.dart';
import 'rename_executor.dart';

typedef DesktopRenameOperation =
    Future<NativeRenameResult> Function(String source, String destination);

/// 更新日時の書き込み(test で差し替えるために外へ出す)。
typedef DesktopSetModifiedAt =
    Future<void> Function(String path, DateTime value);

/// 改名の前にfilesystemへ問い合わせる3つの述語(REQ-025)。
///
/// **testで差し替えるために外へ出す。** 自己衝突の分岐は
/// 「目標名が実在し、かつ同じ実体で、かつ別のentryではない」ときにだけ通る。
/// この条件はcase-insensitive / 正規化を区別しないfilesystemでしか起きず、
/// **Linuxのcontainerでは実FSから作れない**。差し替えられないと、この機能の
/// 中心にある分岐を一度も検査できないまま出すことになる。
abstract interface class DesktopPathProbe {
  /// [path] に実体があるか(symlinkを辿らない)。
  Future<bool> exists(String path);

  /// [a] と [b] が**同じ実体**(dev+inode)か。
  Future<bool> isSameEntity(String a, String b);

  /// [path] の basename が、親directoryの実際のentry名として**byte一致で**
  /// 存在するか。**hard linkはここで真になる。**
  Future<bool> hasExactEntry(String path);
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

      // REQ-025: 目標名が実在しないことを確認してから改名する。**原子的
      // no-replace があっても省かない。** 確認と改名の間(TOCTOU)は native の
      // 排他 rename が塞ぐが、それが実際に効かない環境ではこの確認だけが残る。
      final destinationExists = await _probe.exists(destination);
      // 「実体があるか」ではなく「**別の directory entry があるか**」で
      // 判定する(REQ-025)。
      //
      // 大文字小文字を区別しないfilesystem(Windows、macOSのAPFS既定)や
      // 正規化を区別しないfilesystem(APFS)では、`Photo.jpg -> photo.jpg` の
      // ような改名で目標名が「実在する」ことになる。**それは自分自身である。**
      //
      // **case感度も正規化感度もアプリ側で推測しない。** 判定は2段で行う。
      //
      // 1. `FileSystemEntity.identical` — 同じ実体(dev+inode)か。
      // 2. **親directoryの実際のentry名にbyte一致で存在するか。**
      //
      // 1だけでは足りない。**hard linkは「別の名前が同じ inode を指す」ので
      // `identical` が`true`を返す**が、それは自分自身ではなく別のentryである。
      // 見逃すと、POSIXの`rename()`が「同じfileの別entry」に対して**何もせず
      // 成功を返す**ため、実体が動いていないのに改名済みとして記録する
      // (INV-003違反)。`013:T11`のreview attempt 4で実測された。
      //
      // 2はfilesystemが**保存している名前**を見るので、case/正規化の別名は
      // byte一致せず自己衝突側へ、hard linkはbyte一致して衝突側へ落ちる。
      if (destinationExists) {
        final sameEntity = await _probe.isSameEntity(handle, destination);
        final separateEntry =
            !sameEntity || await _probe.hasExactEntry(destination);
        if (separateEntry) {
          return RenameFailed(
            RenameError(
              RenameErrorKind.nameConflict,
              '同名のファイルが既に存在します: $destination',
            ),
          );
        }

        // 目標名は自分自身の別名(大文字小文字や正規化だけの違い)である。
        // **排他renameは使えない** — macOSの`renamex_np(RENAME_EXCL)`は
        // この場合も`EEXIST`を返す(**macOS実機では未検証**)。
        //
        // **ここにはTOCTOUの窓がある。** 確認と改名は別のstepなので、その間に
        // 他processがdestinationをunlinkして別fileを作れば、no-replaceでない
        // renameがそれを置換する。**INV-002が受容しているTOCTOUは「原子的
        // no-replaceが効かない環境」の話であり、ここは効く環境で自分から
        // no-replaceを捨てている。** 窓は狭いが、無いとは書かない。
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

/// 実filesystemを見る [DesktopPathProbe]。
class _RealPathProbe implements DesktopPathProbe {
  const _RealPathProbe();

  @override
  Future<bool> exists(String path) async =>
      await FileSystemEntity.type(path, followLinks: false) !=
      FileSystemEntityType.notFound;

  @override
  Future<bool> isSameEntity(String a, String b) async {
    try {
      return await FileSystemEntity.identical(a, b);
    } on FileSystemException {
      // 判定できないときは「別の実体」として扱う。**安全側へ倒す** —
      // 誤って同一とみなすと既存を上書きする。
      return false;
    }
  }

  @override
  Future<bool> hasExactEntry(String path) async {
    final name = p.basename(path);
    try {
      await for (final entity in Directory(
        p.dirname(path),
      ).list(followLinks: false)) {
        if (p.basename(entity.path) == name) return true;
      }
    } on FileSystemException {
      // 列挙できないときは「存在する」として扱う。**安全側へ倒す** —
      // 存在しないと決めつけると、通常のrenameで別entryを消しうる。
      return true;
    }
    return false;
  }
}
