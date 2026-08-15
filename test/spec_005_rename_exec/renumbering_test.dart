// VER-008: 実行時の再採番(REQ-023)、結果の提示(REQ-024)、常に実在確認
// (REQ-025)、占有名を常に含める(REQ-026)、実在名を取得できない場合(REQ-027)。
//
// 観点: 事前検出をすり抜けた衝突を`nameConflict`で捕まえ、生存名に対する次の
// 候補名で再試行すること。**再採番するのは改名要求を確認した目標名へ進める改名
// だけ**で、一時名への改名・停止時の復旧改名・巻き戻しでは再採番しないこと。
// 再採番された項目が「確認した名前と異なる」と分かる形で結果に現れること。
//
// 「再採番する側」と「しない側」は逆向きなので、両方を固定する。片方だけでは
// 「常に再採番する実装」と「一度も再採番しない実装」のどちらかが通ってしまう。
import 'package:batch_rename_master/core/rename_engine.dart';
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

/// 目標名 [name] への最初の1回だけ`nameConflict`を注入する。
///
/// 事前検出(REQ-026)を通ったのに実行時に衝突する状況 — 他processがちょうど
/// その名前を作った — を再現する。2回目以降は通すので、再採番が1段進めば成功する。
RenameFailureInjector _conflictOnce(String name) {
  var fired = false;
  return (handle, newName) {
    if (newName != name || fired) return null;
    fired = true;
    return const RenameError(RenameErrorKind.nameConflict, '注入');
  };
}

void main() {
  group('REQ-023 再採番', () {
    test('目標名への改名が`nameConflict`なら、次の候補名で再試行する', () async {
      final requests = _requests({'a.jpg': 'x.jpg'});
      final executor = _folder(['a.jpg'], failWhen: _conflictOnce('x.jpg'));

      final outcome = await executePlan(planExecution(requests), executor);

      expect(outcome.failure, isNull, reason: '再採番できたので失敗にはならない');
      expect(outcome.successes.single.newName, 'x (1).jpg');
      expect(executor.names, contains('x (1).jpg'));
    });

    test('衝突が続いても ` (n)` の n が進む(接尾辞を入れ子にしない)', () async {
      // 直前の試行名をbaseに次候補を求めると `x (1) (1).jpg` になる。候補は
      // 毎回**確認した目標名**から数え直さなければならない。
      final requests = _requests({'a.jpg': 'x.jpg'});
      var remaining = 2;
      final executor = _folder(
        ['a.jpg'],
        failWhen: (handle, newName) {
          if (remaining == 0) return null;
          remaining -= 1;
          return const RenameError(RenameErrorKind.nameConflict, '注入');
        },
      );

      final outcome = await executePlan(planExecution(requests), executor);

      expect(outcome.failure, isNull);
      expect(outcome.successes.single.newName, 'x (2).jpg');
      expect(executor.calls, [
        '/photos/a.jpg -> x.jpg',
        '/photos/a.jpg -> x (1).jpg',
        '/photos/a.jpg -> x (2).jpg',
      ]);
    });

    test('`nameConflict`以外の失敗では再採番せず、その時点で停止する', () async {
      final requests = _requests({'a.jpg': 'x.jpg'});
      final executor = _folder(
        ['a.jpg'],
        failWhen: (handle, newName) =>
            const RenameError(RenameErrorKind.io, '注入'),
      );

      final outcome = await executePlan(planExecution(requests), executor);

      expect(outcome.failure?.error.kind, RenameErrorKind.io);
      expect(outcome.failure?.attemptedName, 'x.jpg', reason: '名前を変えて試し直さない');
      expect(outcome.successes, isEmpty);
    });

    test('試行上限に達したら失敗として記録し、無限に試さない', () async {
      final requests = _requests({'a.jpg': 'x.jpg'});
      // 何を試しても衝突し続ける環境。
      final executor = _folder(
        ['a.jpg'],
        failWhen: (handle, newName) =>
            const RenameError(RenameErrorKind.nameConflict, '注入'),
      );

      final outcome = await executePlan(
        planExecution(requests),
        executor,
        renumberLimit: 3,
      );

      expect(outcome.failure?.error.kind, RenameErrorKind.nameConflict);
      expect(outcome.successes, isEmpty);
      // 最初の1回 + 上限3回 = 4回でやめる。
      expect(executor.calls.length, 4);
    });

    test('次の候補名を求められなければ失敗として記録する', () async {
      final requests = _requests({'a.jpg': 'x.jpg'});
      final executor = _folder(['a.jpg'], failWhen: _conflictOnce('x.jpg'));

      final outcome = await executePlan(
        planExecution(requests),
        executor,
        renumber: (request, liveNames) => null,
      );

      expect(outcome.failure?.error.kind, RenameErrorKind.nameConflict);
      expect(outcome.successes, isEmpty);
    });

    test('portが`nameConflict`を返せば、その原因を問わず再採番する', () async {
      // **自己衝突の判定はportの責務である**(REQ-025)。大文字小文字や正規化
      // だけが違う改名で目標名が「実在する」ことになるかはfilesystem依存で、
      // 実行orchestrationは判定できない。ここへ届く`nameConflict`は本物の衝突。
      final requests = _requests({'Photo.jpg': 'photo.jpg'});
      final executor = _folder([
        'Photo.jpg',
      ], failWhen: _conflictOnce('photo.jpg'));

      final outcome = await executePlan(planExecution(requests), executor);

      expect(outcome.failure, isNull);
      expect(outcome.successes.single.newName, 'photo (1).jpg');
    });

    test('一時名への改名では再採番しない(利用者が確認していない名前を内部ステップで作らない)', () async {
      // 循環。planExecution が一時名を挿入する。
      final requests = _requests({'a.jpg': 'b.jpg', 'b.jpg': 'a.jpg'});
      final plan = planExecution(requests);
      expect(plan.usesTemporaryNames, isTrue);

      final temporaryName = plan.steps
          .firstWhere((s) => s.kind == RenameStepKind.temporary)
          .newName;
      final executor = _folder([
        'a.jpg',
        'b.jpg',
      ], failWhen: _conflictOnce(temporaryName));

      final outcome = await executePlan(plan, executor);

      expect(outcome.failure, isNotNull, reason: '再採番せずに失敗する');
      expect(outcome.failure!.temporary, isTrue);
      expect(outcome.failure!.attemptedName, temporaryName);
      // 一時名の ' (n)' 版が作られていないこと。
      expect(
        executor.calls.where((c) => c.contains('$temporaryName (')),
        isEmpty,
      );
    });

    // 次の2件は**構造ガード**である。復旧改名と巻き戻しは再採番ループの外の
    // 別codeなので、`renumberable` を真に改変しても落ちない。再採番機構が
    // これらの経路へ広がったときに落ちることを狙っている。REQ-023の除外条項を
    // 能動的に検証しているのは、直前の「一時名への改名では再採番しない」だけ。
    test('停止時の復旧改名では再採番しない(構造ガード)', () async {
      final requests = _requests({'a.jpg': 'b.jpg', 'b.jpg': 'a.jpg'});
      final plan = planExecution(requests);
      final temporaryName = plan.steps
          .firstWhere((s) => s.kind == RenameStepKind.temporary)
          .newName;

      // 一時名への改名は通し、そのあとの目標名への改名と復旧改名を衝突させる。
      final executor = _folder(
        ['a.jpg', 'b.jpg'],
        failWhen: (handle, newName) => newName == temporaryName
            ? null
            : const RenameError(RenameErrorKind.nameConflict, '注入'),
      );

      final outcome = await executePlan(plan, executor, renumberLimit: 1);

      expect(outcome.stranded, isNotEmpty, reason: '復旧できず一時名のまま残る');
      // 復旧改名の宛先は元の名前そのもので、' (n)' を付けた名前ではない。
      final recovery = executor.calls.last;
      expect(
        recovery.contains(' ('),
        isFalse,
        reason: '復旧で再採番していない: $recovery',
      );
    });

    test('巻き戻しでは再採番しない(構造ガード)', () async {
      final requests = _requests({'a.jpg': 'x.jpg'});
      final executor = _folder(['a.jpg']);
      final outcome = await executePlan(planExecution(requests), executor);

      // 元の名前が埋まった状態にする。
      await executor.rename('$_dir/other.jpg', 'a.jpg');
      final blocked = FakeRenameExecutor(
        files: {'$_dir/x.jpg': 'x.jpg', '$_dir/a.jpg': 'a.jpg'},
      );

      final undo = await undoSuccessfulRenames(outcome.successes, blocked);

      expect(undo.failure?.error.kind, RenameErrorKind.nameConflict);
      expect(
        blocked.calls.where((c) => c.contains(' (')),
        isEmpty,
        reason: '巻き戻しで別名を作らない',
      );
    });
  });

  group('REQ-024 結果の提示', () {
    test('再採番された改名は、確認した名前と異なることが結果から分かる', () async {
      final requests = _requests({'a.jpg': 'x.jpg', 'b.jpg': 'y.jpg'});
      final executor = _folder([
        'a.jpg',
        'b.jpg',
      ], failWhen: _conflictOnce('x.jpg'));

      final outcome = await executePlan(planExecution(requests), executor);

      final renamed = outcome.successes.firstWhere(
        (s) => s.originalName == 'a.jpg',
      );
      expect(renamed.renumbered, isTrue);
      expect(renamed.confirmedName, 'x.jpg', reason: '利用者が確認した名前');
      expect(renamed.newName, 'x (1).jpg', reason: '実際になった名前');

      final untouched = outcome.successes.firstWhere(
        (s) => s.originalName == 'b.jpg',
      );
      expect(untouched.renumbered, isFalse);
      expect(untouched.confirmedName, untouched.newName);
    });

    test('再採番後の名前が実行結果の目標名として記録される(INV-003)', () async {
      final requests = _requests({'a.jpg': 'x.jpg'});
      final executor = _folder(['a.jpg'], failWhen: _conflictOnce('x.jpg'));

      final outcome = await executePlan(planExecution(requests), executor);

      // 記録した名前と実体の名前が食い違わない。
      expect(outcome.successes.single.newName, 'x (1).jpg');
      expect(
        executor.files[outcome.successes.single.handle]!.name,
        'x (1).jpg',
      );
    });
  });

  group('生存名(OQ-005 / `T04` review attempt 2 の P1-2)', () {
    test('再採番の照合集合に、計画がこれから使う一時名が含まれる', () async {
      // 循環がある計画。一時名は「その時点で存在する」ものだけでなく、
      // **これから使う予定**のものも避けないと、後続の一時名への改名が衝突して
      // 停止する(一時名は再採番の対象外なので回復できない)。
      final requests = _requests({'a.jpg': 'b.jpg', 'b.jpg': 'a.jpg'});
      final plan = planExecution(requests);
      final temporaryNames = {
        for (final s in plan.steps)
          if (s.kind == RenameStepKind.temporary) s.newName,
      };
      expect(temporaryNames, isNotEmpty);

      // 最初の目標名への改名を1回だけ衝突させ、そこで生存名を覗く。
      final firstTarget = plan.steps
          .firstWhere((s) => s.kind == RenameStepKind.target)
          .newName;
      final executor = _folder([
        'a.jpg',
        'b.jpg',
      ], failWhen: _conflictOnce(firstTarget));

      Set<String>? live;
      await executePlan(
        plan,
        executor,
        renumber: (request, liveNames) {
          live ??= liveNames;
          return nextCandidateName(request.targetName, liveNames);
        },
      );

      expect(live, isNotNull, reason: '再採番が呼ばれること');
      expect(live, containsAll(temporaryNames));
    });

    test('生存名に、この実行ですでに確定した結果名が含まれる', () async {
      // **先行要求自身を再採番させて、確定名 ≠ targetName にする。** そうしないと
      // 確定名は「未実行の目標名」としても集合へ入るので、(5)を消しても落ちない
      // (`T04` review attempt 2のP1-2、`T11` attempt 6のP1-4)。
      final requests = _requests({'a.jpg': 'x.jpg', 'b.jpg': 'y.jpg'});
      final conflicts = <String>{'x.jpg', 'y.jpg'};
      final executor = _folder(
        ['a.jpg', 'b.jpg'],
        failWhen: (handle, newName) {
          if (!conflicts.remove(newName)) return null;
          return const RenameError(RenameErrorKind.nameConflict, '注入');
        },
      );

      final live = <Set<String>>[];
      final outcome = await executePlan(
        planExecution(requests),
        executor,
        renumber: (request, liveNames) {
          live.add(liveNames);
          return nextCandidateName(request.targetName, liveNames);
        },
      );

      // a は x (1).jpg で確定する(targetName は x.jpg のまま)。
      final settled = outcome.successes.firstWhere(
        (s) => s.originalName == 'a.jpg',
      );
      expect(settled.newName, 'x (1).jpg');
      expect(settled.confirmedName, 'x.jpg');

      // b の再採番時、照合集合に**確定名**が入っていること。
      expect(live.length, 2);
      expect(live.last, contains('x (1).jpg'), reason: 'すでに確定した結果名(生存名の第5要素)');
    });

    test('生存名に、未実行の改名要求の確認した目標名が含まれる(第2要素)', () async {
      // 先行fileが後続fileの**確認済み目標名を横取り**すると、後続に
      // `x (1) (1).jpg` という入れ子接尾辞が確定する。attempt 1のP1-1で
      // 直した症状そのものなので、(2)を守るtestが要る。
      final requests = _requests({'a.jpg': 'x.jpg', 'b.jpg': 'x (1).jpg'});
      final executor = _folder([
        'a.jpg',
        'b.jpg',
      ], failWhen: _conflictOnce('x.jpg'));

      final outcome = await executePlan(planExecution(requests), executor);

      expect(outcome.failure, isNull);
      final a = outcome.successes.firstWhere((s) => s.originalName == 'a.jpg');
      final b = outcome.successes.firstWhere((s) => s.originalName == 'b.jpg');
      expect(a.newName, 'x (2).jpg', reason: '未実行の b の目標名 x (1).jpg を横取りしない');
      expect(b.newName, 'x (1).jpg');
    });

    test('生存名に、未実行の選択fileの現在名が含まれる(第3要素)', () async {
      // 現在名を数えないと、まだ改名していないfileの名前を候補に選び、
      // portが`nameConflict`を返して試行上限を無駄に消費する。
      final requests = _requests({'a.jpg': 'x.jpg', 'x (1).jpg': 'z.jpg'});
      final executor = _folder([
        'a.jpg',
        'x (1).jpg',
      ], failWhen: _conflictOnce('x.jpg'));

      final calls = <String>[];
      await executePlan(
        planExecution(requests),
        executor,
        renumber: (request, liveNames) {
          calls.add(liveNames.contains('x (1).jpg') ? 'counted' : 'missed');
          return nextCandidateName(request.targetName, liveNames);
        },
      );

      expect(calls, ['counted'], reason: '未実行fileの現在名を数える');
    });

    test('占有名(folderごと)が生存名に含まれ、別folderの名前は混ざらない', () async {
      final requests = _requests({'a.jpg': 'x.jpg'});
      final executor = _folder(['a.jpg'], failWhen: _conflictOnce('x.jpg'));

      Set<String>? live;
      await executePlan(
        planExecution(requests),
        executor,
        occupiedNames: {
          _dir: {'keep.jpg'},
          '/other': {'elsewhere.jpg'},
        },
        renumber: (request, liveNames) {
          live ??= liveNames;
          return nextCandidateName(request.targetName, liveNames);
        },
      );

      expect(live, contains('keep.jpg'));
      expect(live, isNot(contains('elsewhere.jpg')), reason: 'folderを跨いで混ぜない');
    });

    test('別folderの改名要求は生存名に混ざらない', () async {
      // 占有名だけでなく、**他の改名要求**もfolderで絞る。
      final requests = [
        RenameRequest(
          handle: '$_dir/a.jpg',
          originalName: 'a.jpg',
          targetName: 'x.jpg',
        ),
        RenameRequest(
          handle: '/other/b.jpg',
          originalName: 'b.jpg',
          targetName: 'elsewhere.jpg',
        ),
      ];
      final executor = FakeRenameExecutor(
        files: {'$_dir/a.jpg': 'a.jpg', '/other/b.jpg': 'b.jpg'},
        failWhen: _conflictOnce('x.jpg'),
      );

      Set<String>? live;
      await executePlan(
        planExecution(requests),
        executor,
        renumber: (request, liveNames) {
          live ??= liveNames;
          return nextCandidateName(request.targetName, liveNames);
        },
      );

      expect(live, isNotNull);
      expect(live, isNot(contains('elsewhere.jpg')));
      expect(live, isNot(contains('b.jpg')));
    });

    test('別folderの一時名は生存名に混ざらない', () async {
      // 循環がある`/photos`と、衝突する`/other`。`/other`の再採番の照合集合に
      // `/photos`の一時名が入ってはならない。
      final requests = [
        RenameRequest(
          handle: '$_dir/a.jpg',
          originalName: 'a.jpg',
          targetName: 'b.jpg',
        ),
        RenameRequest(
          handle: '$_dir/b.jpg',
          originalName: 'b.jpg',
          targetName: 'a.jpg',
        ),
        RenameRequest(
          handle: '/other/c.jpg',
          originalName: 'c.jpg',
          targetName: 'z.jpg',
        ),
      ];
      final plan = planExecution(requests);
      final temporaryNames = {
        for (final s in plan.steps)
          if (s.kind == RenameStepKind.temporary) s.newName,
      };
      expect(temporaryNames, isNotEmpty);

      final executor = FakeRenameExecutor(
        files: {
          '$_dir/a.jpg': 'a.jpg',
          '$_dir/b.jpg': 'b.jpg',
          '/other/c.jpg': 'c.jpg',
        },
        failWhen: _conflictOnce('z.jpg'),
      );

      Set<String>? live;
      await executePlan(
        plan,
        executor,
        renumber: (request, liveNames) {
          live ??= liveNames;
          return nextCandidateName(request.targetName, liveNames);
        },
      );

      expect(live, isNotNull);
      for (final name in temporaryNames) {
        expect(live, isNot(contains(name)), reason: '別folderの一時名: $name');
      }
    });
  });

  group('nextCandidateName(001 の自動解決規則)', () {
    test('拡張子を保ったまま ` (n)` を付け、衝突しない最小の n を選ぶ', () {
      expect(nextCandidateName('x.jpg', {}), 'x (1).jpg');
      expect(nextCandidateName('x.jpg', {'x (1).jpg'}), 'x (2).jpg');
      expect(
        nextCandidateName('x.jpg', {'x (1).jpg', 'x (2).jpg'}),
        'x (3).jpg',
      );
    });

    test('拡張子が無い名前、先頭ドットの名前でも壊れない', () {
      expect(nextCandidateName('noext', {}), 'noext (1)');
      expect(nextCandidateName('.gitignore', {}), '.gitignore (1)');
      expect(nextCandidateName('archive.tar.gz', {}), 'archive.tar (1).gz');
    });

    test('上限内に空きが無ければ null を返す(無限に探さない)', () {
      final taken = {for (var n = 1; n <= 5; n++) 'x ($n).jpg'};
      expect(nextCandidateName('x.jpg', taken, limit: 5), isNull);
      expect(nextCandidateName('x.jpg', taken, limit: 6), 'x (6).jpg');
    });

    test('衝突していなくても、必ず別の名前を返す', () {
      // 同じ名前を返すと、呼び出し側は同じ失敗を繰り返すだけになる。
      expect(nextCandidateName('x.jpg', {}), isNot('x.jpg'));
    });
  });
}
