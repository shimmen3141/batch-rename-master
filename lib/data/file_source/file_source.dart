import '../../core/rename_engine.dart';

/// 読み込み失敗の理由(004 spec: `Failed(error)` の `error`)。
enum PickErrorKind {
  /// 権限が拒否された(SAF のフォルダ権限ダイアログで拒否等)。
  permissionDenied,

  /// 読み取り・列挙時の IO 失敗。
  io,

  /// 上記に分類できない失敗。
  unknown,
}

/// 読み込み失敗の理由と任意のメッセージ(004 REQ-008 の通知内容)。
class PickError {
  const PickError(this.kind, [this.message]);

  /// 失敗の分類。
  final PickErrorKind kind;

  /// 補足メッセージ(実装が提供できる場合)。
  final String? message;
}

/// [FileSource] の選択結果(004 spec: `PickResult`)。
///
/// 「決定した(件数0もありうる)」「決定していない」「失敗した」を型で区別し、
/// 空リストで3者を混同できないようにする(004 REQ-001)。
sealed class PickResult {
  const PickResult();
}

/// 選択が確定した。[entries] は0件以上(空フォルダは空の [Picked])。
class Picked extends PickResult {
  const Picked(this.entries);

  /// 読み込まれたファイル(各要素は元場所ハンドルを持つ。REQ-002)。
  final List<FileEntry> entries;
}

/// ユーザーがピッカーを閉じ、何も選ばなかった(決定していない。REQ-008)。
class Cancelled extends PickResult {
  const Cancelled();
}

/// 選択後のアクセス・列挙に失敗した(REQ-008: 無変化のまま理由を通知する)。
class Failed extends PickResult {
  const Failed(this.error);

  /// 失敗の理由。
  final PickError error;
}

/// [FileSource.listNames] の結果(004 REQ-014)。
///
/// **「列挙できなかった」と「entry が無い」を型で区別する。** 空リストで両者を
/// 表すと、権限が無い folder を「衝突が無い」と読んでしまう(005 REQ-027)。
sealed class NameListResult {
  const NameListResult();
}

/// 列挙できた。[names] は 0 件以上(空フォルダは空の [NamesListed])。
class NamesListed extends NameListResult {
  NamesListed(Set<String> names) : names = Set.unmodifiable(names);

  /// その folder に**実際に存在する** entry の名前。
  ///
  /// ファイル・サブフォルダを問わない。**アプリへ読み込まれたファイルに限らない** —
  /// 読み込んでいないファイルの名前も含む(004 REQ-014)。隠しファイルもフィルタ
  /// しない(決定 D-2) — 名前を占めていることに変わりはないため。
  final Set<String> names;
}

/// 権限・IO・フォルダ消失などで列挙できなかった(004 REQ-014)。
class NameListFailed extends NameListResult {
  const NameListFailed(this.error);

  /// 失敗の理由。
  final PickError error;
}

/// 実ファイルの読み込み入口の抽象ポート(FEAT-004)。
///
/// プラットフォーム権限・URI の保持は実装の内側に隠す(実装は T4:
/// Android SAF / Windows ピッカー)。いずれの操作も例外を投げず、結果は
/// [PickResult] で返す(REQ-001)。
abstract interface class FileSource {
  /// ユーザーに**フォルダを辿ってファイルを複数選択**させる(REQ-001)。
  ///
  /// システムのファイル選択画面を開き、確定した集合を返す。フォルダ単位で
  /// 一括読み込みする経路(ツリー権限)は持たない — 一括選択はシステム画面の
  /// 「すべて選択」で成立することを実機で確認したため(2026-08-05 / T8)。
  ///
  /// [mimeTypes] を渡すとその種類で絞り込む(種類「文書」用。REQ-011)。
  /// 空なら絞り込まない(種類「すべて」)。絞り込みの効き方はプラットフォーム
  /// 依存で、効かない環境があっても契約違反ではない。
  Future<PickResult> pickFiles({List<String> mimeTypes = const []});

  /// [folder] にある**実在 entry 名**を返す(REQ-014)。
  ///
  /// [folder] は [FileEntry.sourceFolder] が持つ所属 folder ハンドル(REQ-013)。
  /// 005 はこれを材料に**占有名**を作り、読み込んでいないファイルとの衝突を実行前に
  /// 検出する(005 REQ-026)。
  ///
  /// **例外を投げない**(REQ-001 と同じ約束)。列挙できなければ [NameListFailed] を
  /// 返す。**空の [NamesListed] で代用しない** — 005 は「取得できなかった」folder を
  /// 含む実行を行わないと定めており(REQ-027)、区別できないとその判断ができない。
  Future<NameListResult> listNames(String folder);
}

/// あらかじめ与えた結果を返す [FileSource] 実装(サンドボックス検証用の fake)。
///
/// [fileResults] を順に返し、尽きたら [exhausted] を返す
/// (既定は [Cancelled] = 何も追加されない)。実 IO を伴わないため
/// unit/widget test で結線を検証できる。
class FakeFileSource implements FileSource {
  FakeFileSource({
    List<PickResult> fileResults = const [],
    this.exhausted = const Cancelled(),
  }) : _fileResults = List<PickResult>.of(fileResults);

  /// 与えた結果が尽きた後に返す結果。
  final PickResult exhausted;

  final List<PickResult> _fileResults;

  /// [pickFiles] が呼ばれた回数。
  int fileCallCount = 0;

  /// 直近の [pickFiles] に渡された MIME フィルタ(検証用)。
  List<String> lastMimeTypes = const [];

  @override
  Future<PickResult> pickFiles({List<String> mimeTypes = const []}) async {
    fileCallCount++;
    lastMimeTypes = mimeTypes;
    return _fileResults.isEmpty ? exhausted : _fileResults.removeAt(0);
  }

  /// folder ハンドル → その folder の実在 entry 名。
  ///
  /// [nameFailures] に載っている folder は [NameListFailed] を返す(REQ-014)。
  /// どちらにも無い folder は**空の [NamesListed]** を返す。
  final Map<String, Set<String>> folderNames = {};

  /// 列挙に失敗する folder ハンドル → その理由。
  final Map<String, PickError> nameFailures = {};

  /// [listNames] が呼ばれた folder(呼ばれた順)。
  final List<String> listedFolders = [];

  @override
  Future<NameListResult> listNames(String folder) async {
    listedFolders.add(folder);
    final failure = nameFailures[folder];
    if (failure != null) return NameListFailed(failure);
    return NamesListed(folderNames[folder] ?? const {});
  }
}
