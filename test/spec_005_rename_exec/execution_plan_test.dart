// VER-002: 実行計画(OP-001 / REQ-004 / REQ-005 / INV-002)。
//
// 観点: 各改名を行う「時点で」目標名が衝突しない順序になっていること、順序では
// 解けない循環だけを一時名で解くこと、最後まで進めば一時名が残らないこと。
// 「上書きしない」は fake 側でも守られている(同名があれば nameConflict を返す)
// ため、計画が誤っていれば実行が失敗して検出される。
import 'dart:math';

import 'package:batch_rename_master/data/rename_exec/rename_execution.dart';
import 'package:batch_rename_master/data/rename_exec/rename_executor.dart';
import 'package:batch_rename_master/data/rename_exec/rename_plan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'occupied_support.dart';

const _dir = '/photos';

/// この folder で「占有している名前は無い」ことを表す全域な占有名。
///
/// これらの test の executor は選択 file だけを持つので、実在名から改名される
/// 現在名を除いた占有名は実際に空である(005 用語「占有名」)。
final _noOccupied = noOccupiedIn(_dir);

List<RenameRequest> _requests(Map<String, String> renames) => [
  for (final e in renames.entries)
    RenameRequest(
      handle: '$_dir/${e.key}',
      originalName: e.key,
      targetName: e.value,
      folder: _dir,
    ),
];

FakeRenameExecutor _folder(Iterable<String> names) =>
    FakeRenameExecutor(files: {for (final n in names) '$_dir/$n': n});

/// 実体の「同一性 → 現在の名前」。id は最初のハンドルで、改名しても変わらない。
Map<String, String> _namesById(FakeRenameExecutor executor) => {
  for (final file in executor.files.values) file.id: file.name,
};

void main() {
  test('入力の改名要求はすべて計画に現れる(OP-001)', () {
    final requests = _requests({
      'a.jpg': 'x.jpg',
      'b.jpg': 'y.jpg',
      'c.jpg': 'z.jpg',
    });

    final plan = planExecution(requests, occupiedNames: _noOccupied);

    expect(plan.requests, hasLength(3));
    expect(plan.requests, containsAll(requests));
    for (final request in requests) {
      expect(
        plan.steps.any(
          (s) =>
              identical(s.request, request) && s.newName == request.targetName,
        ),
        isTrue,
        reason: '${request.targetName} への改名が計画に無い',
      );
    }
  });

  test('衝突しない改名は一時名を使わない(OP-001)', () {
    final plan = planExecution(
      _requests({'a.jpg': 'x.jpg', 'b.jpg': 'y.jpg'}),
      occupiedNames: _noOccupied,
    );

    expect(plan.usesTemporaryNames, isFalse);
    expect(plan.steps, hasLength(2));
    expect(plan.steps.every((s) => s.kind == RenameStepKind.target), isTrue);
  });

  test('目標名が現在の名前と等しい要求はポートを呼ばない(OP-001)', () async {
    final requests = _requests({'a.jpg': 'a.jpg'});
    final executor = _folder(['a.jpg']);

    final outcome = await executePlan(
      planExecution(requests, occupiedNames: _noOccupied),
      executor,
      occupiedNames: _noOccupied,
    );

    expect(executor.calls, isEmpty);
    expect(outcome.failure, isNull);
    expect(outcome.successes.single.newName, 'a.jpg');
  });

  test('入れ替え a→b, b→c は b→c を先に行う順序になる(REQ-004)', () async {
    final requests = _requests({'a.jpg': 'b.jpg', 'b.jpg': 'c.jpg'});

    final plan = planExecution(requests, occupiedNames: _noOccupied);

    expect(plan.usesTemporaryNames, isFalse);
    expect(plan.steps.map((s) => s.newName), ['c.jpg', 'b.jpg']);

    final executor = _folder(['a.jpg', 'b.jpg']);
    final outcome = await executePlan(
      plan,
      executor,
      occupiedNames: _noOccupied,
    );

    // 既存の b.jpg を上書きしていない: 2件とも残り、id ごとの名前が目標名になる。
    expect(outcome.failure, isNull);
    expect(executor.files, hasLength(2));
    expect(_namesById(executor), {
      '$_dir/a.jpg': 'b.jpg',
      '$_dir/b.jpg': 'c.jpg',
    });
  });

  test('循環 a→b, b→a は一時名を1つ挟んで解く(REQ-004)', () async {
    final requests = _requests({'a.jpg': 'b.jpg', 'b.jpg': 'a.jpg'});

    final plan = planExecution(requests, occupiedNames: _noOccupied);

    final temporary = plan.steps
        .where((s) => s.kind == RenameStepKind.temporary)
        .toList();
    expect(temporary, hasLength(1));
    // 一時名は判別できる形にする(OP-001 の nondeterminism)。
    expect(temporary.single.newName, contains('renaming-'));

    final executor = _folder(['a.jpg', 'b.jpg']);
    final outcome = await executePlan(
      plan,
      executor,
      occupiedNames: _noOccupied,
    );

    expect(outcome.failure, isNull);
    expect(executor.files, hasLength(2));
    expect(_namesById(executor), {
      '$_dir/a.jpg': 'b.jpg',
      '$_dir/b.jpg': 'a.jpg',
    });
  });

  test('3件の循環 a→b, b→c, c→a も既存を上書きしない(INV-002)', () async {
    final requests = _requests({
      'a.jpg': 'b.jpg',
      'b.jpg': 'c.jpg',
      'c.jpg': 'a.jpg',
    });
    final executor = _folder(['a.jpg', 'b.jpg', 'c.jpg']);

    final outcome = await executePlan(
      planExecution(requests, occupiedNames: _noOccupied),
      executor,
      occupiedNames: _noOccupied,
    );

    expect(outcome.failure, isNull);
    expect(executor.files, hasLength(3));
    expect(_namesById(executor), {
      '$_dir/a.jpg': 'b.jpg',
      '$_dir/b.jpg': 'c.jpg',
      '$_dir/c.jpg': 'a.jpg',
    });
  });

  test('最後まで進めば一時名を持つファイルは残らない(REQ-005)', () async {
    final requests = _requests({'a.jpg': 'b.jpg', 'b.jpg': 'a.jpg'});
    final executor = _folder(['a.jpg', 'b.jpg']);

    await executePlan(
      planExecution(requests, occupiedNames: _noOccupied),
      executor,
      occupiedNames: _noOccupied,
    );

    expect(executor.names.any((n) => n.contains('renaming-')), isFalse);
  });

  test('一時名は元の名前・目標名のどれとも衝突しない(REQ-005)', () {
    // 一時名の候補と同じ名前が実在する状況を作る。
    final requests = _requests({
      'a.renaming-0.jpg': 'a.jpg',
      'a.jpg': 'a.renaming-0.jpg',
    });

    final plan = planExecution(requests, occupiedNames: _noOccupied);

    final temporary = plan.steps
        .where((s) => s.kind == RenameStepKind.temporary)
        .single;
    expect(temporary.newName, isNot('a.renaming-0.jpg'));
    expect(
      requests.every(
        (r) =>
            r.originalName != temporary.newName &&
            r.targetName != temporary.newName,
      ),
      isTrue,
    );
  });

  test('無作為な並べ替え 200 通りで既存を上書きしない(INV-002)', () async {
    final random = Random(20260807);

    for (var trial = 0; trial < 200; trial++) {
      final count = 2 + random.nextInt(6);
      final names = [for (var i = 0; i < count; i++) 'f$i.jpg'];
      final targets = List<String>.of(names)..shuffle(random);
      final requests = [
        for (var i = 0; i < count; i++)
          RenameRequest(
            handle: '$_dir/${names[i]}',
            originalName: names[i],
            targetName: targets[i],
            folder: _dir,
          ),
      ];
      final executor = _folder(names);

      final outcome = await executePlan(
        planExecution(requests, occupiedNames: _noOccupied),
        executor,
        occupiedNames: _noOccupied,
      );

      final trace = executor.calls.join(' / ');
      expect(outcome.failure?.error, isNull, reason: '$targets: $trace');
      // ファイルは1件も失われず、各実体が目標名に到達している(INV-002)。
      expect(executor.files, hasLength(count), reason: trace);
      expect(_namesById(executor), {
        for (var i = 0; i < count; i++) '$_dir/${names[i]}': targets[i],
      }, reason: trace);
      expect(
        executor.names.any((n) => n.contains('renaming-')),
        isFalse,
        reason: trace,
      );
    }
  });
}
