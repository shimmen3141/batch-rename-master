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

/// 実ファイルの読み込み入口の抽象ポート(FEAT-004)。
///
/// プラットフォーム権限・URI の保持は実装の内側に隠す(実装は T4:
/// Android SAF / Windows ピッカー)。いずれの操作も例外を投げず、結果は
/// [PickResult] で返す(REQ-001)。
abstract interface class FileSource {
  /// ユーザーにフォルダを選ばせ、そのフォルダ内のファイルを読み込む(REQ-001)。
  Future<PickResult> pickFolder();

  /// ユーザーにファイルを個別選択させる(複数可。REQ-001)。
  Future<PickResult> pickFiles();
}

/// あらかじめ与えた結果を返す [FileSource] 実装(サンドボックス検証用の fake)。
///
/// [folderResults] / [fileResults] を順に返し、尽きたら [exhausted] を返す
/// (既定は [Cancelled] = 何も追加されない)。実 IO を伴わないため
/// unit/widget test で結線を検証できる。
class FakeFileSource implements FileSource {
  FakeFileSource({
    List<PickResult> folderResults = const [],
    List<PickResult> fileResults = const [],
    this.exhausted = const Cancelled(),
  }) : _folderResults = List<PickResult>.of(folderResults),
       _fileResults = List<PickResult>.of(fileResults);

  /// 与えた結果が尽きた後に返す結果。
  final PickResult exhausted;

  final List<PickResult> _folderResults;
  final List<PickResult> _fileResults;

  /// [pickFolder] が呼ばれた回数。
  int folderCallCount = 0;

  /// [pickFiles] が呼ばれた回数。
  int fileCallCount = 0;

  @override
  Future<PickResult> pickFolder() async {
    folderCallCount++;
    return _folderResults.isEmpty ? exhausted : _folderResults.removeAt(0);
  }

  @override
  Future<PickResult> pickFiles() async {
    fileCallCount++;
    return _fileResults.isEmpty ? exhausted : _fileResults.removeAt(0);
  }
}
