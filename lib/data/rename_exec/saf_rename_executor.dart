import 'rename_executor.dart';

/// Android Storage Access Framework用の安全な未対応adapter。
///
/// `DocumentsContract.renameDocument`はproviderが別名を選べ、原子的な
/// no-replaceを保証しない。INV-002とOP-004の失敗時不変を守るため、production
/// 経路ではprovider APIを呼ばず、常に理由付き失敗を返す。
class SafRenameExecutor implements RenameExecutor {
  const SafRenameExecutor();

  static const _error = RenameError(
    RenameErrorKind.unsupportedPlatform,
    'Android SAFでは既存ファイルを置換しない安全な改名を保証できないため、現在は改名に対応していません',
  );

  @override
  Future<RenameResult> rename(String handle, String newName) async =>
      const RenameFailed(_error);
}
