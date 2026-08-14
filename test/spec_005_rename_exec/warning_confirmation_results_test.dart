// VER-004 / VER-005: 警告確認、直接実行、二重開始防止、空名除外と結果提示。
import 'dart:async';

import 'package:batch_rename_master/core/rename_engine.dart';
import 'package:batch_rename_master/data/rename_exec/rename_executor.dart';
import 'package:batch_rename_master/data/rename_exec/saf_rename_executor.dart';
import 'package:batch_rename_master/ui/file_list/file_list_controller.dart';
import 'package:batch_rename_master/ui/file_list/file_list_view.dart';
import 'package:batch_rename_master/ui/rename_exec/rename_execution_controller.dart';
import 'package:batch_rename_master/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

FileEntry _file(String name) => FileEntry(
  name: name,
  modifiedAt: DateTime(2026, 8, 9),
  size: 1,
  sourceHandle: '/files/$name',
);

Future<void> _pump(
  WidgetTester tester,
  FileListController files,
  RenameExecutionController execution,
) {
  return tester.pumpWidget(
    MaterialApp(
      theme: appDarkTheme(),
      home: Scaffold(
        body: FileListView(controller: files, renameExecution: execution),
      ),
    ),
  );
}

void main() {
  test('強制実行は autoResolve 後に空名を除外する(REQ-022)', () async {
    final files = FileListController(
      files: [_file('empty.txt')],
      rule: const RenameRule([LiteralToken('')]),
    );
    final executor = FakeRenameExecutor(
      files: {'/files/empty.txt': 'empty.txt'},
    );
    final execution = RenameExecutionController(
      files: files,
      executor: executor,
    );

    final outcome = await execution.execute(force: true);

    expect(outcome!.successes, isEmpty);
    expect(execution.excludedEmptyNames.map((file) => file.name), [
      'empty.txt',
    ]);
    expect(executor.calls, isEmpty);
  });

  testWidgets('警告時は全件を確認してから、キャンセルでは改名しない(REQ-011)', (tester) async {
    final files = FileListController(
      files: [_file('a.txt'), _file('b.txt')],
      rule: const RenameRule([LiteralToken('same')]),
    );
    final executor = FakeRenameExecutor(
      files: {'/files/a.txt': 'a.txt', '/files/b.txt': 'b.txt'},
    );
    final execution = RenameExecutionController(
      files: files,
      executor: executor,
    );
    await _pump(tester, files, execution);

    await tester.tap(find.byKey(const Key('rename-action')));
    await tester.pumpAndSettle();
    final dialog = find.byKey(const Key('rename-confirmation-dialog'));
    expect(dialog, findsOneWidget);
    expect(
      find.descendant(of: dialog, matching: find.textContaining('a.txt')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.textContaining('b.txt')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('rename-cancel')));
    await tester.pumpAndSettle();
    expect(executor.calls, isEmpty);
  });

  testWidgets('警告なしは直ちに実行し、成功件数を提示する(REQ-013)', (tester) async {
    final files = FileListController(
      files: [_file('a.txt')],
      rule: const RenameRule([LiteralToken('renamed')]),
    );
    final executor = FakeRenameExecutor(files: {'/files/a.txt': 'a.txt'});
    final execution = RenameExecutionController(
      files: files,
      executor: executor,
    );
    await _pump(tester, files, execution);

    await tester.tap(find.byKey(const Key('rename-action')));
    await tester.pumpAndSettle();
    expect(executor.calls, ['/files/a.txt -> renamed.txt']);
    expect(find.textContaining('1 件を改名しました'), findsOneWidget);
    // このtestがcontrollerの所有者。5秒timerをbindingのinvariant検査前に破棄する。
    execution.dispose();
  });

  testWidgets('再採番が起きたら、確認した名前と結果名の違いを提示する(REQ-024)', (tester) async {
    // 事前検出をすり抜けた衝突(他processがちょうどその名前を作った)を注入する。
    // **黙って別の名前にしない** — 利用者は自分が確認した名前と違う結果になった
    // ことに気づけなければならない。
    final files = FileListController(
      files: [_file('a.txt')],
      rule: const RenameRule([LiteralToken('renamed')]),
    );
    var fired = false;
    final executor = FakeRenameExecutor(
      files: {'/files/a.txt': 'a.txt'},
      failWhen: (handle, newName) {
        if (newName != 'renamed.txt' || fired) return null;
        fired = true;
        return const RenameError(RenameErrorKind.nameConflict, '注入');
      },
    );
    final execution = RenameExecutionController(
      files: files,
      executor: executor,
    );
    await _pump(tester, files, execution);

    await tester.tap(find.byKey(const Key('rename-action')));
    await tester.pumpAndSettle();

    expect(find.textContaining('1 件を改名しました'), findsOneWidget);
    expect(find.textContaining('1 件の名前が変わりました'), findsOneWidget);
    expect(
      find.textContaining('renamed.txt → renamed (1).txt'),
      findsOneWidget,
      reason: 'どの項目がどの名前になったかを示す',
    );
    execution.dispose();
  });

  testWidgets('再採番が起きていなければ、名前が変わった旨は出さない(REQ-024)', (tester) async {
    final files = FileListController(
      files: [_file('a.txt')],
      rule: const RenameRule([LiteralToken('renamed')]),
    );
    final executor = FakeRenameExecutor(files: {'/files/a.txt': 'a.txt'});
    final execution = RenameExecutionController(
      files: files,
      executor: executor,
    );
    await _pump(tester, files, execution);

    await tester.tap(find.byKey(const Key('rename-action')));
    await tester.pumpAndSettle();

    expect(find.textContaining('名前が変わりました'), findsNothing);
    execution.dispose();
  });

  testWidgets('失敗時は成功件数と理由を提示する(REQ-013)', (tester) async {
    final files = FileListController(
      files: [_file('a.txt')],
      rule: const RenameRule([LiteralToken('renamed')]),
    );
    final executor = FakeRenameExecutor(
      files: {'/files/a.txt': 'a.txt'},
      failWhen: (_, _) =>
          const RenameError(RenameErrorKind.permissionDenied, '権限がありません'),
    );
    final execution = RenameExecutionController(
      files: files,
      executor: executor,
    );
    await _pump(tester, files, execution);

    await tester.tap(find.byKey(const Key('rename-action')));
    await tester.pumpAndSettle();

    expect(find.textContaining('0 件を改名しました'), findsOneWidget);
    expect(find.textContaining('権限がありません'), findsOneWidget);
  });

  testWidgets('Android SAFの安全な未対応理由を表示する(REQ-017)', (tester) async {
    final files = FileListController(
      files: [_file('a.txt')],
      rule: const RenameRule([LiteralToken('renamed')]),
    );
    final execution = RenameExecutionController(
      files: files,
      executor: const SafRenameExecutor(),
    );
    await _pump(tester, files, execution);

    await tester.tap(find.byKey(const Key('rename-action')));
    await tester.pumpAndSettle();

    expect(find.textContaining('0 件を改名しました'), findsOneWidget);
    expect(find.textContaining('安全な改名を保証できない'), findsOneWidget);
    expect(files.items.single.name, 'a.txt');
    expect(files.items.single.sourceHandle, '/files/a.txt');
  });

  testWidgets('期限内は成功したrenameを元に戻せる(REQ-006 / REQ-007)', (tester) async {
    final files = FileListController(
      files: [_file('a.txt')],
      rule: const RenameRule([LiteralToken('renamed')]),
    );
    final executor = FakeRenameExecutor(files: {'/files/a.txt': 'a.txt'});
    final execution = RenameExecutionController(
      files: files,
      executor: executor,
    );
    await _pump(tester, files, execution);

    await tester.tap(find.byKey(const Key('rename-action')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rename-undo')), findsOneWidget);

    await tester.tap(find.byKey(const Key('rename-undo')));
    await tester.pumpAndSettle();

    expect(find.textContaining('1 件を元に戻しました'), findsOneWidget);
    expect(files.items.single.name, 'a.txt');
    expect(files.items.single.sourceHandle, '/files/a.txt');
    expect(executor.calls, [
      '/files/a.txt -> renamed.txt',
      '/files/renamed.txt -> a.txt',
    ]);
    expect(find.byKey(const Key('rename-undo')), findsNothing);
  });

  testWidgets('5秒後はundoを提示せず実体を変更しない(REQ-007)', (tester) async {
    final files = FileListController(
      files: [_file('a.txt')],
      rule: const RenameRule([LiteralToken('renamed')]),
    );
    final executor = FakeRenameExecutor(files: {'/files/a.txt': 'a.txt'});
    final execution = RenameExecutionController(
      files: files,
      executor: executor,
    );
    await _pump(tester, files, execution);

    await tester.tap(find.byKey(const Key('rename-action')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rename-undo')), findsOneWidget);

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle(); // undo を載せたトーストが閉じきるまで進める。

    expect(find.byKey(const Key('rename-undo')), findsNothing);
    expect(await execution.undo(), isNull);
    expect(files.items.single.name, 'renamed.txt');
    expect(executor.calls, ['/files/a.txt -> renamed.txt']);
  });

  test('実行中は二重に開始しない(REQ-012)', () async {
    final gate = Completer<RenameResult>();
    final files = FileListController(
      files: [_file('a.txt')],
      rule: const RenameRule([LiteralToken('renamed')]),
    );
    final execution = RenameExecutionController(
      files: files,
      executor: _DelayedExecutor(gate.future),
    );

    final first = execution.execute(force: false);
    final second = await execution.execute(force: false);
    expect(second, isNull);
    gate.complete(const Renamed('/files/renamed.txt'));
    await first;
  });
}

class _DelayedExecutor implements RenameExecutor {
  _DelayedExecutor(this.result);
  final Future<RenameResult> result;

  @override
  Future<RenameResult> rename(String handle, String newName) => result;
}
