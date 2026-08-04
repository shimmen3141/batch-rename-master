import 'package:saf_util/saf_util.dart';
import 'package:saf_util/saf_util_platform_interface.dart';

import '../../core/rename_engine.dart';
import 'file_source.dart';

/// Android の Storage Access Framework(SAF)を用いる [FileSource] 実装(T4)。
///
/// フォルダは `OPEN_DOCUMENT_TREE` 相当(`pickDirectory`)で**永続化可能な**
/// URI 権限を取り、ファイルは `OPEN_DOCUMENT` 相当(`pickFiles`)で複数選択する。
/// `MANAGE_EXTERNAL_STORAGE` は要求しない(PRD §5)。
///
/// 各エントリの [FileEntry.sourceHandle] は **SAF の document URI** で、005 の
/// リネーム(`renameDocument`)先を一意に指す。作成日時は SAF の列に存在しないため
/// **常に不明**(`null`)とする — 更新日時などで代替しない(004 REQ-003 / 001 INV-006)。
class SafFileSource implements FileSource {
  SafFileSource({SafUtil? safUtil}) : _saf = safUtil ?? SafUtil();

  final SafUtil _saf;

  @override
  Future<PickResult> pickFolder() async {
    try {
      // 書き込み権限も同時に取る(005 のリネームで必要)。永続化を要求して
      // 次回起動時にも同じフォルダへアクセスできるようにする。
      final dir = await _saf.pickDirectory(
        writePermission: true,
        persistablePermission: true,
      );
      // ピッカーを閉じただけ = 未選択(REQ-001)。
      if (dir == null) return const Cancelled();
      final children = await _saf.list(dir.uri);
      return Picked([
        for (final child in children)
          if (!child.isDir) entryOf(child, location: dir.name),
      ]);
    } catch (error) {
      return Failed(errorOf(error));
    }
  }

  @override
  Future<PickResult> pickFiles() async {
    try {
      final files = await _saf.pickFiles(multiple: true);
      // null / 空はどちらも「選ばずに閉じた」を意味する(REQ-001)。
      if (files == null || files.isEmpty) return const Cancelled();
      return Picked([
        for (final file in files)
          if (!file.isDir) entryOf(file, location: null),
      ]);
    } catch (error) {
      return Failed(errorOf(error));
    }
  }

  /// SAF のドキュメントを [FileEntry] へ写す(実 IO 無しで検証できるよう公開)。
  ///
  /// [location] はフォルダ読み込み時の表示用フォルダ名(REQ-009)。個別選択では
  /// 親フォルダが分からないため `null`(行は日時のみを副題に出す)。
  static FileEntry entryOf(SafDocumentFile file, {required String? location}) {
    return FileEntry(
      name: file.name,
      // SAF には作成日時の列が無い。取得できないので不明のままにする(REQ-003)。
      createdAt: null,
      modifiedAt: DateTime.fromMillisecondsSinceEpoch(file.lastModified),
      size: file.length < 0 ? 0 : file.length,
      sourceHandle: file.uri,
      sourceLocation: location,
    );
  }

  /// プラットフォーム例外を [PickError] へ分類する(REQ-008。実 IO 無しで検証できるよう公開)。
  ///
  /// 権限拒否はメッセージに `permission` / `denied` を含むことが多いが、文言は
  /// 端末・OS バージョンで変わる。判別できないものは、SAF 経路での失敗はほぼ
  /// 読み取り・列挙の失敗であることから [PickErrorKind.io] に倒す(仕様は分類の
  /// 内部基準を実装に委ねている)。いずれの場合も理由の文字列は保持する。
  static PickError errorOf(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('permission') || text.contains('denied')) {
      return PickError(PickErrorKind.permissionDenied, error.toString());
    }
    return PickError(PickErrorKind.io, error.toString());
  }
}
