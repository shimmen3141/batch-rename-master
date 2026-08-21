// REQ-001 / REQ-018: 実行結果の新しい handle と目標名を作業一覧へ投影する。
import 'package:batch_rename_master/core/rename_engine.dart';
import 'package:batch_rename_master/data/rename_exec/rename_executor.dart';
import 'package:batch_rename_master/ui/file_list/file_list_controller.dart';
import 'package:batch_rename_master/ui/rename_exec/rename_execution_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'occupied_support.dart';

FileEntry _file(String name) => FileEntry(
  name: name,
  modifiedAt: DateTime(2026, 8, 9),
  size: 1,
  sourceHandle: '/files/$name',
  sourceLocation: 'files',
  sourceFolder: '/files',
);

void main() {
  test('実体handleがないUI sampleはadapterへ渡さない', () async {
    final sample = FileEntry(
      name: 'IMG_0009.jpg',
      modifiedAt: DateTime(2026, 8, 9),
      size: 1,
    );
    final files = FileListController(
      files: [sample],
      rule: const RenameRule([LiteralToken('renamed')]),
    );
    final executor = FakeRenameExecutor(
      files: {'IMG_0009.jpg': 'IMG_0009.jpg'},
    );
    final controller = RenameExecutionController(
      files: files,
      executor: executor,
      listNames: listNamesOf(executor, folder: '/files'),
    );

    final outcome = await prepareAndExecute(controller, force: false);

    expect(outcome!.successes, isEmpty);
    expect(outcome.failure, isNull);
    expect(executor.calls, isEmpty);
    expect(files.items.single.name, 'IMG_0009.jpg');
    expect(files.items.single.sourceHandle, isNull);
  });

  test('成功後は目標名と新ハンドルを一覧へ反映し、次回実行で使用する', () async {
    final original = _file('a.txt');
    final files = FileListController(
      files: [original],
      rule: const RenameRule([LiteralToken('first')]),
    );
    final executor = FakeRenameExecutor(files: {'/files/a.txt': 'a.txt'});
    final controller = RenameExecutionController(
      files: files,
      executor: executor,
      listNames: listNamesOf(executor, folder: '/files'),
    );

    await prepareAndExecute(controller, force: false);

    final first = files.items.single;
    expect(first.name, 'first.txt');
    expect(first.sourceHandle, '/files/first.txt');
    expect(first.sourceLocation, 'files');
    expect(files.selectedOf(first), isTrue);
    expect(files.selectedOf(original), isFalse);

    files.setRule(const RenameRule([LiteralToken('second')]));
    await prepareAndExecute(controller, force: false);

    expect(executor.calls, [
      '/files/a.txt -> first.txt',
      '/files/first.txt -> second.txt',
    ]);
    expect(files.items.single.name, 'second.txt');
    expect(files.items.single.sourceHandle, '/files/second.txt');
  });

  test('途中停止では成功済みだけを更新し、失敗・未実行は元のまま保つ', () async {
    final files = FileListController(
      files: [_file('a.txt'), _file('b.txt'), _file('c.txt')],
      rule: const RenameRule([
        LiteralToken('renamed-'),
        SequenceToken(start: 1),
      ]),
    );
    final executor = FakeRenameExecutor(
      files: {
        '/files/a.txt': 'a.txt',
        '/files/b.txt': 'b.txt',
        '/files/c.txt': 'c.txt',
      },
      failWhen: (handle, _) => handle == '/files/b.txt'
          ? const RenameError(RenameErrorKind.io, 'injected')
          : null,
    );
    final controller = RenameExecutionController(
      files: files,
      executor: executor,
      listNames: listNamesOf(executor, folder: '/files'),
    );

    final outcome = await prepareAndExecute(controller, force: false);

    expect(outcome!.successes, hasLength(1));
    expect(outcome.failure, isNotNull);
    expect(outcome.notExecuted, hasLength(1));
    expect(files.items.map((file) => file.name), [
      'renamed-1.txt',
      'b.txt',
      'c.txt',
    ]);
    expect(files.items.map((file) => file.sourceHandle), [
      '/files/renamed-1.txt',
      '/files/b.txt',
      '/files/c.txt',
    ]);
  });
}
