import '../../core/rename_engine.dart';
import 'file_source.dart';

/// 選択結果でリネーム対象のリストを置き換える受け口。
///
/// 002 の `FileListController.setFiles` がこの形に一致するため、UI 層はそれを
/// そのまま渡せる。data 層から ui 層へ依存させないための境界。
typedef SetFiles = void Function(List<FileEntry> entries);

/// [pick] の結果でリストを置き換える(004 REQ-007 / REQ-008)。
///
/// - [Picked]: [setFiles] へ渡してリストを置き換える(同一ハンドルの集約と
///   全件選択はリスト側で行う)。
/// - [Cancelled]: 何もしない(リスト無変化・通知なし。前回の選択が保たれる)。
/// - [Failed]: リストを変えず、理由を返り値で通知する(UI が提示する)。
///
/// 返り値は失敗の理由。成功・キャンセルでは `null`。
Future<PickError?> applyPick(
  Future<PickResult> Function() pick,
  SetFiles setFiles,
) async {
  final result = await pick();
  switch (result) {
    case Picked(:final entries):
      setFiles(entries);
      return null;
    case Cancelled():
      return null;
    case Failed(:final error):
      return error;
  }
}

/// ファイルを選ばせ、確定した集合でリストを置き換える(REQ-007 / REQ-008)。
///
/// [mimeTypes] は種類「文書」の絞り込みに使う(空なら絞り込まない。REQ-011)。
Future<PickError?> loadFilesInto(
  FileSource source,
  SetFiles setFiles, {
  List<String> mimeTypes = const [],
}) => applyPick(() => source.pickFiles(mimeTypes: mimeTypes), setFiles);
