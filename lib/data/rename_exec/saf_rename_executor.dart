import 'package:saf_util/saf_util.dart';
import 'package:saf_util/saf_util_platform_interface.dart';

import 'rename_executor.dart';

/// `saf_util.rename` と同じ形の注入点。Android 実機を使わず契約を検証するために使う。
typedef SafRenameOperation =
    Future<SafDocumentFile> Function(String uri, bool isDir, String newName);

/// Android Storage Access Framework 用の実リネーム adapter。
///
/// SAF の document URI は改名によって変わりうるため、プラグインが返した URI を
/// そのまま新しいハンドルとして返す(REQ-001)。戻り値の名前は空になりうるので、
/// 表示名の正本には用いない(REQ-018)。
class SafRenameExecutor implements RenameExecutor {
  SafRenameExecutor({SafRenameOperation? rename})
    : _rename = rename ?? SafUtil().rename;

  final SafRenameOperation _rename;

  @override
  Future<RenameResult> rename(String handle, String newName) async {
    try {
      final document = await _rename(handle, false, newName);
      return Renamed(document.uri, name: document.name);
    } catch (error) {
      return RenameFailed(errorOf(error));
    }
  }

  /// プラットフォーム例外をポートの失敗理由へ分類する(REQ-017)。
  static RenameError errorOf(Object error) {
    final message = error.toString();
    final text = message.toLowerCase();
    if (text.contains('permission') ||
        text.contains('denied') ||
        text.contains('security')) {
      return RenameError(RenameErrorKind.permissionDenied, message);
    }
    if (text.contains('not found') ||
        text.contains('notfound') ||
        text.contains('stale')) {
      return RenameError(RenameErrorKind.notFound, message);
    }
    if (text.contains('already exists') ||
        text.contains('conflict') ||
        text.contains('duplicate')) {
      return RenameError(RenameErrorKind.nameConflict, message);
    }
    return RenameError(RenameErrorKind.io, message);
  }
}
