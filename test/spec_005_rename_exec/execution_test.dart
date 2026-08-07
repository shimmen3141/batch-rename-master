// VER-003: 実行オーケストレーション(OP-002 / REQ-001 / REQ-002 / REQ-003 /
// REQ-005 / INV-001 / INV-003 / INV-005)。
//
// 観点: 計画の順に1件ずつ行いハンドルを更新すること、失敗した時点で停止し
// 成功済みを巻き戻さないこと、成功・失敗・未実行の3者が区別できること、停止で
// 残った一時名の扱い、実行結果と実体が食い違わないこと。
//
// 巻き戻し(undo)は T6 の範囲で、このファイルでは扱わない(ID を書くと
// 被覆照合の文字列一致を素通りさせてしまうため、ここでは挙げない)。
import 'package:batch_rename_master/data/rename_exec/rename_execution.dart';
import 'package:batch_rename_master/data/rename_exec/rename_executor.dart';
import 'package:batch_rename_master/data/rename_exec/rename_plan.dart';
import 'package:flutter_test/flutter_test.dart';

const _dir = '/photos';

List<RenameRequest> _requests(Map<String, String> renames) => [
  for (final e in renames.entries)
    RenameRequest(
      handle: '$_dir/${e.key}',
      originalName: e.key,
      targetName: e.value,
    ),
];

FakeRenameExecutor _folder(
  Iterable<String> names, {
  RenameFailureInjector? failWhen,
}) => FakeRenameExecutor(
  files: {for (final n in names) '$_dir/$n': n},
  failWhen: failWhen,
);

void main() {
  test('成功のたびに改名要求のハンドルが更新される(REQ-001)', () async {
    final requests = _requests({'a.jpg': 'x.jpg', 'b.jpg': 'y.jpg'});
    final executor = _folder(['a.jpg', 'b.jpg']);

    final outcome = await executePlan(planExecution(requests), executor);

    expect(outcome.failure, isNull);
    expect(requests[0].handle, '$_dir/x.jpg');
    expect(requests[1].handle, '$_dir/y.jpg');
    expect(
      outcome.successes.map((s) => s.handle),
      unorderedEquals(['$_dir/x.jpg', '$_dir/y.jpg']),
    );
  });

  test('更新後のハンドルで続けて実行できる(REQ-001)', () async {
    final first = _requests({'a.jpg': 'x.jpg'});
    final executor = _folder(['a.jpg']);

    await executePlan(planExecution(first), executor);

    // 2回目は1回目で更新されたハンドルから始める(古い値なら notFound になる)。
    final second = [
      RenameRequest(
        handle: first.single.handle,
        originalName: 'x.jpg',
        targetName: 'z.jpg',
      ),
    ];
    final outcome = await executePlan(planExecution(second), executor);

    expect(outcome.failure, isNull);
    expect(executor.names, ['z.jpg']);
    expect(second.single.handle, '$_dir/z.jpg');
  });

  test('一時名への改名でもハンドルは現在の識別子に保たれる(INV-005)', () async {
    final requests = _requests({'a.jpg': 'b.jpg', 'b.jpg': 'a.jpg'});
    final executor = _folder(['a.jpg', 'b.jpg']);

    final outcome = await executePlan(planExecution(requests), executor);

    expect(outcome.failure, isNull);
    // 一時名を経由した要求も、最後は目標名のハンドルを指している。
    for (final request in requests) {
      expect(executor.files[request.handle]?.name, request.targetName);
    }
  });

  test('1件失敗したらその時点で停止し、成功済みは元に戻さない(REQ-002)', () async {
    final requests = _requests({
      'a.jpg': 'x.jpg',
      'b.jpg': 'y.jpg',
      'c.jpg': 'z.jpg',
    });
    final executor = _folder(
      ['a.jpg', 'b.jpg', 'c.jpg'],
      failWhen: (handle, newName) => newName == 'y.jpg'
          ? const RenameError(RenameErrorKind.io, '書き込みに失敗しました')
          : null,
    );

    final outcome = await executePlan(planExecution(requests), executor);

    expect(outcome.stopped, isTrue);
    expect(outcome.failure!.error.kind, RenameErrorKind.io);
    // 1件目は成功のまま残る(巻き戻さない)。
    expect(executor.files['$_dir/x.jpg']?.name, 'x.jpg');
    // 3件目には手を付けていない。
    expect(executor.calls, ['$_dir/a.jpg -> x.jpg', '$_dir/b.jpg -> y.jpg']);
    expect(executor.files['$_dir/c.jpg']?.name, 'c.jpg');
  });

  test('成功・失敗・未実行の3者が区別できる(REQ-003)', () async {
    final requests = _requests({
      'a.jpg': 'x.jpg',
      'b.jpg': 'y.jpg',
      'c.jpg': 'z.jpg',
    });
    final executor = _folder(
      ['a.jpg', 'b.jpg', 'c.jpg'],
      failWhen: (handle, newName) => newName == 'y.jpg'
          ? const RenameError(RenameErrorKind.permissionDenied, '権限がありません')
          : null,
    );

    final outcome = await executePlan(planExecution(requests), executor);

    expect(outcome.successes.map((s) => s.originalName), ['a.jpg']);
    expect(outcome.failure!.request.originalName, 'b.jpg');
    expect(outcome.failure!.error.message, '権限がありません');
    expect(outcome.failure!.temporary, isFalse);
    expect(outcome.notExecuted.map((r) => r.originalName), ['c.jpg']);
  });

  test('成功として記録した改名は実体と一致する(INV-003)', () async {
    final requests = _requests({
      'a.jpg': 'b.jpg',
      'b.jpg': 'a.jpg',
      'c.jpg': 'z.jpg',
    });
    final executor = _folder(['a.jpg', 'b.jpg', 'c.jpg']);

    final outcome = await executePlan(planExecution(requests), executor);

    expect(outcome.successes, hasLength(3));
    for (final success in outcome.successes) {
      expect(executor.files[success.handle]?.name, success.newName);
      expect(success.newName, success.request.targetName);
    }
    // 一時名への改名は「成功した改名」に含まれない(REQ-005)。
    expect(
      outcome.successes.any((s) => s.newName.contains('renaming-')),
      isFalse,
    );
  });

  test('実行はファイルの個数・内容・所在を変えない(INV-001)', () async {
    final requests = _requests({'a.jpg': 'b.jpg', 'b.jpg': 'a.jpg'});
    final executor = _folder(['a.jpg', 'b.jpg']);
    final before = executor.files.values.toList();

    await executePlan(planExecution(requests), executor);

    final after = executor.files.values.toList();
    expect(after, hasLength(before.length));
    expect(after.map((f) => f.id), unorderedEquals(before.map((f) => f.id)));
    expect(
      {for (final f in after) f.id: f.content},
      {for (final f in before) f.id: f.content},
    );
    // 所在(フォルダ)も変わらない。
    expect(executor.files.keys.every((h) => h.startsWith('$_dir/')), isTrue);
  });

  test('停止で残った一時名は元の名前へ戻す(REQ-005)', () async {
    final requests = _requests({'a.jpg': 'b.jpg', 'b.jpg': 'a.jpg'});
    // 一時名を付けた直後のステップ(b.jpg のハンドルに対する改名)だけ失敗させる。
    final executor = _folder(
      ['a.jpg', 'b.jpg'],
      failWhen: (handle, newName) => handle == '$_dir/b.jpg'
          ? const RenameError(RenameErrorKind.io, '書き込みに失敗しました')
          : null,
    );

    final outcome = await executePlan(planExecution(requests), executor);

    expect(outcome.stopped, isTrue);
    expect(outcome.failure!.request.originalName, 'b.jpg');
    expect(outcome.successes, isEmpty);
    // 一時名のファイルは元の名前へ戻っており、報告すべき残留は無い。
    expect(outcome.stranded, isEmpty);
    expect(executor.names, unorderedEquals(['a.jpg', 'b.jpg']));
    expect(
      outcome.notExecuted.map((r) => r.originalName),
      unorderedEquals(['a.jpg']),
    );
  });

  test('元の名前へ戻せなかった一時名は現在の名前を報告する(REQ-005)', () async {
    final requests = _requests({'a.jpg': 'b.jpg', 'b.jpg': 'a.jpg'});
    // a.jpg への改名(b.jpg の目標名 と 一時名からの戻し)を両方失敗させる。
    final executor = _folder(
      ['a.jpg', 'b.jpg'],
      failWhen: (handle, newName) => newName == 'a.jpg'
          ? const RenameError(RenameErrorKind.io, '書き込みに失敗しました')
          : null,
    );

    final outcome = await executePlan(planExecution(requests), executor);

    expect(outcome.stopped, isTrue);
    final stranded = outcome.stranded.single;
    expect(stranded.request.originalName, 'a.jpg');
    expect(stranded.currentName, contains('renaming-'));
    expect(stranded.error.kind, RenameErrorKind.io);
    // 実体も一時名のまま残っている(実行結果と実体が食い違わない)。
    expect(executor.names, contains(stranded.currentName));
  });

  test('一時名への改名で失敗した場合も理由が記録される(REQ-002)', () async {
    final requests = _requests({'a.jpg': 'b.jpg', 'b.jpg': 'a.jpg'});
    final executor = _folder(
      ['a.jpg', 'b.jpg'],
      failWhen: (handle, newName) => newName.contains('renaming-')
          ? const RenameError(RenameErrorKind.permissionDenied, '権限がありません')
          : null,
    );

    final outcome = await executePlan(planExecution(requests), executor);

    expect(outcome.failure!.temporary, isTrue);
    expect(outcome.failure!.attemptedName, contains('renaming-'));
    expect(outcome.successes, isEmpty);
    expect(outcome.stranded, isEmpty);
    // 実体は1件も変わっていない。
    expect(executor.names, unorderedEquals(['a.jpg', 'b.jpg']));
  });
}
