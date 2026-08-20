import 'package:saf_util/saf_util.dart';
import 'package:saf_util/saf_util_platform_interface.dart';

import '../../core/rename_engine.dart';
import 'file_source.dart';

/// Android の Storage Access Framework(SAF)を用いる [FileSource] 実装(T4)。
///
/// `OPEN_DOCUMENT` 相当(`pickFiles`)で、フォルダを辿ってファイルを複数選択させる。
/// `MANAGE_EXTERNAL_STORAGE` は要求しない(PRD §5)。フォルダ単位のツリー権限は
/// 使わない — 一括選択はシステム画面の「すべて選択」で成立する(T8 で実機確認)。
///
/// 各エントリの [FileEntry.sourceHandle] は **SAF の document URI** で、005 の
/// リネーム(`renameDocument`)先を一意に指す。作成日時は SAF の列に存在しないため
/// **常に不明**(`null`)とする — 更新日時などで代替しない(004 REQ-003 / 001 INV-006)。
class SafFileSource implements FileSource {
  SafFileSource({SafUtil? safUtil}) : _saf = safUtil ?? SafUtil();

  final SafUtil _saf;

  @override
  Future<PickResult> pickFiles({List<String> mimeTypes = const []}) async {
    try {
      final files = await _saf.pickFiles(
        multiple: true,
        mimeTypes: mimeTypes.isEmpty ? null : mimeTypes,
      );
      // null / 空はどちらも「選ばずに閉じた」を意味する(REQ-001)。
      if (files == null || files.isEmpty) return const Cancelled();
      return Picked([
        for (final file in files)
          if (!file.isDir)
            entryOf(
              file,
              location: locationOfDocumentUri(file.uri),
              folder: folderHandleOfDocumentUri(file.uri),
            ),
      ]);
    } catch (error) {
      return Failed(errorOf(error));
    }
  }

  /// SAF の document URI から**親フォルダ名**を取り出す(REQ-009 / REQ-012)。
  ///
  /// URI の最後のセグメントが document ID で、`primary:Download/photos/a.jpg`
  /// のように URL エンコードされた「ボリューム:パス」を含む。ここから親ディレクトリの
  /// 名前(`photos`)を導出する。取り出せない場合(ルート直下・想定外の形)は `null`。
  ///
  /// これが無いと Android では場所の副題(REQ-009)と親フォルダ跨ぎの警告
  /// (REQ-012)が常に発火しない。
  static String? locationOfDocumentUri(String uri) {
    final lastSlash = uri.lastIndexOf('/');
    if (lastSlash < 0) return null;
    final docId = Uri.decodeComponent(uri.substring(lastSlash + 1));
    // "primary:Download/photos/a.jpg" → "Download/photos/a.jpg"
    final colon = docId.indexOf(':');
    final path = colon < 0 ? docId : docId.substring(colon + 1);
    final parts = path.split('/').where((p) => p.isNotEmpty).toList();
    // 末尾はファイル名。その手前が親フォルダ。
    return parts.length >= 2 ? parts[parts.length - 2] : null;
  }

  /// SAF の document URI から**所属 folder ハンドル**を作る(004 REQ-013)。
  ///
  /// document ID の親ディレクトリ部分を URI へ戻した文字列。同じフォルダの
  /// ファイルは同じ値になる。**path として解釈するための値ではない** — 005 も 001 も
  /// 等値だけで使う(005 用語 `folder`)。導出できない形なら URI 全体を返す
  /// (1ファイル1 folder として扱われるだけで、既存を上書きすることはない)。
  static String folderHandleOfDocumentUri(String uri) {
    final lastSlash = uri.lastIndexOf('/');
    if (lastSlash < 0) return uri;
    final prefix = uri.substring(0, lastSlash + 1);
    final docId = Uri.decodeComponent(uri.substring(lastSlash + 1));
    final colon = docId.indexOf(':');
    final volume = colon < 0 ? '' : docId.substring(0, colon + 1);
    final path = colon < 0 ? docId : docId.substring(colon + 1);
    final parts = path.split('/').where((p) => p.isNotEmpty).toList();
    // 末尾はファイル名。その手前までが親フォルダ(無ければボリューム直下)。
    final parent = parts.sublist(0, parts.length - 1).join('/');
    return '$prefix${Uri.encodeComponent('$volume$parent')}';
  }

  /// **Android SAF では実在名を列挙できない**(004 REQ-014)。
  ///
  /// `pickFiles` が取るのは1ファイルずつの読み取り権限で、**親フォルダを列挙する
  /// 権限は含まれない**。ツリー権限は使わないと決めてある(004 の T8 実機確認)。
  ///
  /// したがって理由付きの [NameListFailed] を返す。**空の [NamesListed] にしない** —
  /// 005 はそれを「衝突が無い」と読み、読み込んでいないファイルを上書きしうる
  /// 名前で確認なしに実行へ入ってしまう(005 REQ-027)。**Android の実 rename は
  /// revision 2 以来「安全な未対応」なので、ここで実行が止まることは新しい制限を
  /// 作らない。** app 内 file browser(`013:T07`)が入ったときに、その browser が
  /// 持つ列挙権限で実装し直す。
  @override
  Future<NameListResult> listNames(String folder) async => const NameListFailed(
    PickError(
      PickErrorKind.permissionDenied,
      'SAF ではフォルダ内のファイル名を一覧できません(フォルダの権限がありません)',
    ),
  );

  /// SAF のドキュメントを [FileEntry] へ写す(実 IO 無しで検証できるよう公開)。
  ///
  /// [location] は表示用のフォルダ名(REQ-009)。導出できない場合は `null`
  /// (行は日時のみを副題に出す)。[folder] は所属 folder ハンドル(REQ-013)。
  static FileEntry entryOf(
    SafDocumentFile file, {
    required String? location,
    String? folder,
  }) {
    return FileEntry(
      name: file.name,
      // SAF には作成日時の列が無い。取得できないので不明のままにする(REQ-003)。
      createdAt: null,
      modifiedAt: DateTime.fromMillisecondsSinceEpoch(file.lastModified),
      size: file.length < 0 ? 0 : file.length,
      sourceHandle: file.uri,
      sourceLocation: location,
      sourceFolder: folder ?? folderHandleOfDocumentUri(file.uri),
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
