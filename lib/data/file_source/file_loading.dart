import '../../core/rename_engine.dart';
import 'file_source.dart';

/// 読み込んだファイルを作業セットへ足す受け口。
///
/// 002 の `FileListController.addFiles` がこの形に一致するため、UI 層はそれを
/// そのまま渡せる。data 層から ui 層へ依存させないための境界。
typedef AddFiles = void Function(List<FileEntry> entries);

/// [pick] の結果を作業セットへ反映する(004 REQ-007 / REQ-008)。
///
/// - [Picked]: [addFiles] へ渡して末尾へ追加する(重複排除・既定選択は作業セット側)。
/// - [Cancelled]: 何もしない(作業セット無変化・通知なし)。
/// - [Failed]: 作業セットを変えず、理由を返り値で通知する(UI が提示する)。
///
/// 返り値は失敗の理由。成功・キャンセルでは `null`。
Future<PickError?> applyPick(
  Future<PickResult> Function() pick,
  AddFiles addFiles,
) async {
  final result = await pick();
  switch (result) {
    case Picked(:final entries):
      addFiles(entries);
      return null;
    case Cancelled():
      return null;
    case Failed(:final error):
      return error;
  }
}

/// フォルダを選ばせ、その中身を作業セットへ追加する(REQ-007 / REQ-008)。
Future<PickError?> loadFolderInto(FileSource source, AddFiles addFiles) =>
    applyPick(source.pickFolder, addFiles);

/// ファイルを個別選択させ、作業セットへ追加する(REQ-007 / REQ-008)。
Future<PickError?> loadFilesInto(FileSource source, AddFiles addFiles) =>
    applyPick(source.pickFiles, addFiles);
