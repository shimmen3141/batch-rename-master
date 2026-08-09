import 'dart:io';

import 'package:path/path.dart' as p;

import 'rename_executor.dart';

/// Windows / Linux / macOS の実ファイル用リネーム adapter。
///
/// `File.rename` は OS によって既存ファイルを置換しうるため、呼び出す前に目標パスを
/// 検査し、既存ファイルを上書きしない(INV-002)。成功時は絶対パスを新しいハンドル
/// として返す(REQ-001)。
class DesktopRenameExecutor implements RenameExecutor {
  const DesktopRenameExecutor();

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

      // 大文字小文字だけの変更は同じ実体を指す可能性があるため除外する。
      if (!p.equals(handle, destination)) {
        final destinationType = await FileSystemEntity.type(
          destination,
          followLinks: false,
        );
        if (destinationType != FileSystemEntityType.notFound) {
          return RenameFailed(
            RenameError(
              RenameErrorKind.nameConflict,
              '同名のファイルが既に存在します: $destination',
            ),
          );
        }
      }

      final renamed = await File(handle).rename(destination);
      return Renamed(renamed.absolute.path, name: newName);
    } catch (error) {
      return RenameFailed(errorOf(error));
    }
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
