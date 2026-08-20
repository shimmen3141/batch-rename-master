// 占有名(005 REQ-026 / REQ-027 / REQ-028)を扱う test の共通部品。
//
// 占有名そのものを主題にしない検証でも、`planExecution` / `executePlan` は
// **全域な占有名**を要求する(OP-001 / OP-002 の事前条件、OQ-003)。key が無い
// ことを「占有名が空」と読ませないための要求なので、`{}` では代用できない。
// ここでは「対象 folder は分かっていて、占有している名前は無い」を明示する。
import 'package:batch_rename_master/data/file_source/file_source.dart';
import 'package:batch_rename_master/data/rename_exec/rename_execution.dart';
import 'package:batch_rename_master/data/rename_exec/rename_executor.dart';
import 'package:batch_rename_master/ui/rename_exec/rename_execution_controller.dart';

/// [folder] について「占有している名前は無い」ことを表す全域な占有名。
OccupiedNames noOccupiedIn(String? folder) => OccupiedNames.emptyFor([folder]);

/// [executor] が持つ実体の現在名を、[folder] の実在名として返す lister。
///
/// **本物と同じ観測**を与える — 実行前にその folder に何があるかは executor が持つ
/// 状態そのものなので、別に並べるとテストの前提が実体とずれる。
///
/// 他の folder を尋ねられたら [NameListFailed] を返す。テストが意図しない folder を
/// 見に行ったことを、空の列挙結果で見逃さないため。
FolderNameLister listNamesOf(
  FakeRenameExecutor executor, {
  required String folder,
}) {
  return (String requested) async => requested == folder
      ? NamesListed(executor.names.toSet())
      : const NameListFailed(
          PickError(PickErrorKind.io, 'このテストが用意していないフォルダです'),
        );
}

/// [folder] の実在名を [names] として返す lister(executor と切り離したい場合)。
FolderNameLister listNamesFixed(String folder, Set<String> names) {
  return (String requested) async => requested == folder
      ? NamesListed(names)
      : const NameListFailed(
          PickError(PickErrorKind.io, 'このテストが用意していないフォルダです'),
        );
}

/// [folder] の実在名の取得に失敗する lister(REQ-027 の検証用)。
FolderNameLister listNamesFailing(PickError error) {
  return (String requested) async => NameListFailed(error);
}

/// 通常の実行経路: 要求時に占有名を取り直してから実行する(REQ-028)。
///
/// UI の実行ボタンが辿るのと同じ順序である。取り直しに失敗したら実行しない
/// (REQ-027)ので、その場合はここで例外を投げて test を止める — 黙って
/// `null` を返すと「実行したが何も起きなかった」と区別できない。
Future<RenameOutcome?> prepareAndExecute(
  RenameExecutionController execution, {
  required bool force,
}) async {
  final prepared = await execution.prepare();
  if (prepared is! OccupiedNamesReady) {
    throw StateError('実在名を取得できませんでした: $prepared');
  }
  return execution.execute(force: force, occupiedNames: prepared.names);
}
