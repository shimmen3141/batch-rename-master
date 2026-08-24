// VER-005 / VER-008: 占有名(REQ-026)、実在名を取得できない folder(REQ-027)、
// 取得のタイミング(REQ-028)、OP-005(collectOccupiedNames)、および
// OP-001 / OP-002 の全域性(OQ-003)。
//
// 観点: 読み込んでいない file との衝突を**実行前に**捕まえること。ただし
// **入れ替えや循環では捕まえないこと** — 選択 file 自身の現在名を占有名へ入れると、
// `IMG_0001..0100` を1つずらす改名がほぼ全件 ` (n)` になる(005:T04 review
// attempt 1 の P0)。両方向を固定しないと、この P0 の再発を検出できない。
//
// もう一つの逆向きは「取得できなかった」と「衝突が無い」である。空の列挙結果へ
// 落とすと、権限が無い folder で確認なしに実行へ入る(REQ-027)。
import 'package:batch_rename_master/core/rename_engine.dart';
import 'package:batch_rename_master/data/file_source/file_source.dart';
import 'package:batch_rename_master/data/rename_exec/rename_execution.dart';
import 'package:batch_rename_master/data/rename_exec/rename_executor.dart';
import 'package:batch_rename_master/data/rename_exec/rename_plan.dart';
import 'package:batch_rename_master/ui/file_list/file_list_controller.dart';
import 'package:batch_rename_master/ui/file_list/file_list_view.dart';
import 'package:batch_rename_master/ui/rename_exec/rename_execution_controller.dart';
import 'package:batch_rename_master/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:batch_rename_master/data/permission/storage_permission.dart';
import 'package:flutter_test/flutter_test.dart';

import 'occupied_support.dart';

const _a = '/A';
const _b = '/B';

final DateTime _now = DateTime(2026, 8, 20, 9, 0, 0);

FileEntry _file(
  String name, {
  bool selected = true,
  String folder = _a,
  bool withHandle = true,
}) => FileEntry(
  name: name,
  modifiedAt: _now,
  size: 1,
  selected: selected,
  sourceHandle: withHandle ? '$folder/$name' : null,
  sourceFolder: withHandle ? folder : null,
);

/// folder → 実在名 を返す lister。載っていない folder は失敗にする。
FolderNameLister _lister(Map<String, Set<String>> folders) =>
    (String folder) async {
      final names = folders[folder];
      return names == null
          ? const NameListFailed(PickError(PickErrorKind.io, '用意していないフォルダ'))
          : NamesListed(names);
    };

Future<OccupiedNamesResult> _collect(
  List<FileEntry> entries,
  RenameRule rule,
  FolderNameLister listNames,
) => collectOccupiedNames(
  entries: entries,
  rule: rule,
  now: _now,
  listNames: listNames,
);

// ---------------------------------------------------------------- UI helpers

/// 一覧・実行境界・fake 実体を1組で用意する。
({
  FileListController files,
  RenameExecutionController execution,
  FakeRenameExecutor executor,
})
_wire({
  required List<FileEntry> entries,
  required RenameRule rule,
  required FolderNameLister listNames,
}) {
  final files = FileListController(files: entries, rule: rule);
  final executor = FakeRenameExecutor(
    files: {
      for (final entry in entries)
        if (entry.sourceHandle != null) entry.sourceHandle!: entry.name,
    },
  );
  return (
    files: files,
    executor: executor,
    execution: RenameExecutionController(
      permission: const UnrestrictedStoragePermission(),
      files: files,
      executor: executor,
      listNames: listNames,
      clock: () => _now,
    ),
  );
}

Future<void> _pump(
  WidgetTester tester,
  FileListController files,
  RenameExecutionController execution,
) => tester.pumpWidget(
  MaterialApp(
    theme: appDarkTheme(),
    home: Scaffold(
      body: FileListView(controller: files, renameExecution: execution),
    ),
  ),
);

Future<void> _tapExecute(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('rename-action')));
  await tester.pumpAndSettle();
}

/// 巻き戻しの提示期限(5 秒)を進め、保留中の Timer を消化する(REQ-007)。
Future<void> _passUndoWindow(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

void main() {
  group('OP-005: 占有名の組み立て', () {
    test('占有名 = 実在名 − この実行で改名される選択 file の現在名', () async {
      const rule = RenameRule([OriginalNameToken(), LiteralToken('-v2')]);
      final entries = [_file('a.txt'), _file('b.txt')];

      final result = await _collect(
        entries,
        rule,
        _lister({
          _a: {'a.txt', 'b.txt', 'keep.txt'},
        }),
      );

      final names = (result as OccupiedNamesReady).names;
      expect(names.of(_a), {'keep.txt'}, reason: '改名される2件の現在名は空くので占有名に含めない');
    });

    test('未選択 file の現在名は占有名に残る', () async {
      const rule = RenameRule([OriginalNameToken(), LiteralToken('-v2')]);
      final entries = [_file('a.txt'), _file('keep.txt', selected: false)];

      final result = await _collect(
        entries,
        rule,
        _lister({
          _a: {'a.txt', 'keep.txt'},
        }),
      );

      expect((result as OccupiedNamesReady).names.of(_a), {'keep.txt'});
    });

    test('REQ-022 で除外される file の現在名は占有名に残る(例25c)', () async {
      // 生成後ベース名が空になる file は改名されないので、その名前は空かない。
      // 作成日時トークンだけのルールでは、作成日時が不明な file だけが空名になる。
      const rule = RenameRule([
        DateTimeToken(source: DateTimeSource.created, format: 'YYYYMMDD'),
      ]);
      final entries = [
        // 作成日時が不明 → 生成後名は `.txt` → REQ-022 で除外される。
        _file('keep.txt'),
        // 作成日時がある → 改名される。
        FileEntry(
          name: 'other.txt',
          createdAt: _now,
          modifiedAt: _now,
          size: 1,
          sourceHandle: '$_a/other.txt',
          sourceFolder: _a,
        ),
      ];

      final result = await _collect(
        entries,
        rule,
        _lister({
          _a: {'keep.txt', 'other.txt'},
        }),
      );

      expect(
        (result as OccupiedNamesReady).names.of(_a),
        {'keep.txt'},
        reason:
            '除外された keep.txt は改名されないので占有名に残り、'
            '改名される other.txt は空くので除かれる',
      );
    });

    test('全件が REQ-022 で除外されても、その folder は問い合わせる', () async {
      // **除外は「占有名から引く集合」だけを狭め、対象 folder は狭めない**
      // (OP-005 の事後条件)。強制実行の自動解決は除外を解く方向へ働きうるので、
      // 狭めると execute が prepare の覆う範囲の外へ出る(下の回帰 test)。
      const rule = RenameRule([
        DateTimeToken(source: DateTimeSource.created, format: 'YYYYMMDD'),
      ]);
      final entries = [_file('keep.txt')]; // 作成日時が不明 → 全件除外
      final asked = <String>[];

      final result = await _collect(entries, rule, (folder) async {
        asked.add(folder);
        return NamesListed(const {'keep.txt'});
      });

      expect(asked, [_a]);
      final names = (result as OccupiedNamesReady).names;
      expect(names.covers(_a), isTrue);
      expect(names.of(_a), {
        'keep.txt',
      }, reason: '除外された file は改名されないので現在名は占有名に残る');
    });

    test('folder ごとに持ち、跨いで混ぜない(例25d)', () async {
      const rule = RenameRule([OriginalNameToken(), LiteralToken('-v2')]);
      final entries = [_file('a.txt'), _file('c.txt', folder: _b)];

      final result = await _collect(
        entries,
        rule,
        _lister({
          _a: {'a.txt', 'keepA.txt'},
          _b: {'c.txt', 'keepB.txt'},
        }),
      );

      final names = (result as OccupiedNamesReady).names;
      expect(names.of(_a), {'keepA.txt'});
      expect(names.of(_b), {'keepB.txt'});
    });

    test('対象は選択 file の folder だけ(未選択だけの folder は問い合わせない)', () async {
      const rule = RenameRule([OriginalNameToken(), LiteralToken('-v2')]);
      final entries = [
        _file('a.txt'),
        _file('c.txt', folder: _b, selected: false),
      ];
      final asked = <String>[];

      final result = await _collect(entries, rule, (folder) async {
        asked.add(folder);
        return NamesListed({'a.txt'});
      });

      expect(asked, [_a]);
      expect((result as OccupiedNamesReady).names.covers(_b), isFalse);
    });

    test('実体ハンドルを持たない file は対象にしない', () async {
      // 起動時の UI サンプル。改名の対象にならないので folder も問い合わせない。
      const rule = RenameRule([LiteralToken('x')]);
      final entries = [_file('sample.jpg', withHandle: false)];
      final asked = <String>[];

      final result = await _collect(entries, rule, (folder) async {
        asked.add(folder);
        return NamesListed(const {});
      });

      expect(asked, isEmpty);
      expect(result, isA<OccupiedNamesReady>());
    });

    test('返る占有名は対象 folder について全域である(OQ-003)', () async {
      const rule = RenameRule([OriginalNameToken(), LiteralToken('-v2')]);
      final entries = [_file('a.txt'), _file('c.txt', folder: _b)];

      final result = await _collect(
        entries,
        rule,
        _lister({_a: <String>{}, _b: <String>{}}),
      );

      final names = (result as OccupiedNamesReady).names;
      expect(names.covers(_a), isTrue);
      expect(names.covers(_b), isTrue);
    });
  });

  group('REQ-027: 実在名を取得できない folder', () {
    test('1つでも取得できなければ Unavailable を返し、理由を含む(例25e)', () async {
      const rule = RenameRule([OriginalNameToken(), LiteralToken('-v2')]);
      final entries = [_file('a.txt'), _file('c.txt', folder: _b)];

      final result = await _collect(
        entries,
        rule,
        (folder) async => folder == _a
            ? NamesListed(const {'a.txt'})
            : const NameListFailed(
                PickError(PickErrorKind.permissionDenied, '権限がありません'),
              ),
      );

      expect(result, isA<OccupiedNamesUnavailable>());
      final reasons = (result as OccupiedNamesUnavailable).reasons;
      expect(reasons.keys, [_b]);
      expect(reasons[_b]!.kind, PickErrorKind.permissionDenied);
      expect(reasons[_b]!.message, '権限がありません');
    });

    test('実体ハンドルはあるが所属 folder が無い file は Unavailable にする', () async {
      // 問い合わせる先が無いので「取得できなかった」として扱う。**空として通さない。**
      // production の adapter は必ず folder を埋める(desktop / SAF とも)ので、
      // ここは到達しない防御である。**到達しないことを理由に検査を省かない** —
      // 将来 adapter が増えたとき、空として通す実装は静かに REQ-027 を破る。
      const rule = RenameRule([LiteralToken('x')]);
      final entries = [
        FileEntry(
          name: 'a.txt',
          modifiedAt: _now,
          size: 1,
          sourceHandle: '/A/a.txt',
          // sourceFolder は与えない。
        ),
      ];
      final asked = <String>[];

      final result = await _collect(entries, rule, (folder) async {
        asked.add(folder);
        return NamesListed(const {});
      });

      expect(asked, isEmpty, reason: '問い合わせる先が無い');
      expect(result, isA<OccupiedNamesUnavailable>());
      expect((result as OccupiedNamesUnavailable).reasons.keys, [null]);
    });

    test('空の列挙結果は失敗ではない(区別する)', () async {
      const rule = RenameRule([OriginalNameToken(), LiteralToken('-v2')]);
      final entries = [_file('a.txt')];

      final result = await _collect(entries, rule, _lister({_a: <String>{}}));

      expect(result, isA<OccupiedNamesReady>());
      expect((result as OccupiedNamesReady).names.of(_a), isEmpty);
    });
  });

  group('OQ-003: occupiedNames の全域性', () {
    List<RenameRequest> requests() => [
      RenameRequest(
        handle: '$_a/a.txt',
        originalName: 'a.txt',
        targetName: 'x.txt',
        folder: _a,
      ),
    ];

    test('key が無い folder を引くと投げる(空として通さない)', () {
      expect(() => noOccupiedIn(_b).of(_a), throwsArgumentError);
    });

    test('planExecution は key 欠損を事前条件違反として弾く', () {
      expect(
        () => planExecution(requests(), occupiedNames: noOccupiedIn(_b)),
        throwsArgumentError,
      );
    });

    test('executePlan は key 欠損を事前条件違反として弾く', () async {
      // **衝突が起きたときだけ落ちる形にしない。** 生存名は再採番のときにしか
      // 組み立てないので、そこまで遅らせると通常の実行では素通りする。
      final rs = requests();
      final plan = planExecution(rs, occupiedNames: noOccupiedIn(_a));
      final executor = FakeRenameExecutor(files: {'$_a/a.txt': 'a.txt'});

      await expectLater(
        executePlan(plan, executor, occupiedNames: noOccupiedIn(_b)),
        throwsArgumentError,
      );
      expect(executor.calls, isEmpty, reason: '実ファイルへ触る前に弾く(実体は変化しない)');
    });
  });

  group('回帰: prepare が覆う folder は execute の改名要求を覆う', () {
    // **強制実行の自動解決は REQ-022 の除外を解く方向へ働く。** 同じ folder に
    // 生成後ベース名が空になる選択 file が2件あると、2件目は ` (1)` が付いて
    // ベース名が空でなくなり、除外されずに改名要求になる。対象 folder を
    // 「この実行で改名される file」に狭めていると、その folder の占有名が無いまま
    // 実行へ渡り、全域性(OQ-003)が破れて `ArgumentError` が UI へ抜ける。
    // 独立review 1回目の P1-1。

    test('空ベース名が同一 folder に2件 + 強制実行でも例外を投げない', () async {
      final wired = _wire(
        entries: [_file('a.txt'), _file('b.txt')],
        rule: const RenameRule([LiteralToken('')]),
        listNames: _lister({
          _a: {'a.txt', 'b.txt'},
        }),
      );

      final prepared = await wired.execution.prepare();
      expect(
        (prepared as OccupiedNamesReady).names.covers(_a),
        isTrue,
        reason: '全件除外でも対象 folder は覆う',
      );

      final outcome = await wired.execution.execute(
        force: true,
        occupiedNames: prepared.names,
      );

      expect(outcome, isNotNull);
    });

    testWidgets('同じ入力を UI から実行しても黙って終わらない', (tester) async {
      // 実行ボタンは fire-and-forget なので、例外が抜けると snackbar も dialog も
      // 出ずに**何も起きない**。結果の提示(REQ-013)が届くことで、例外が抜けて
      // いないことが観測できる。
      final wired = _wire(
        entries: [_file('a.txt'), _file('b.txt')],
        rule: const RenameRule([LiteralToken('')]),
        listNames: _lister({
          _a: {'a.txt', 'b.txt'},
        }),
      );
      await _pump(tester, wired.files, wired.execution);

      await _tapExecute(tester);
      // 空名の警告が出るので確認を経る(REQ-011 / REQ-021)。
      expect(
        find.byKey(const Key('rename-confirmation-dialog')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('rename-force')));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('件を改名しました'),
        findsOneWidget,
        reason: '例外が抜けると結果の提示(REQ-013)に到達しない',
      );
      await _passUndoWindow(tester);
    });
  });

  group('OP-001: 占有名は実行計画にも効く(REQ-004)', () {
    test('目標名が占有名に含まれる入力は事前条件違反として弾く', () {
      final requests = [
        RenameRequest(
          handle: '$_a/a.txt',
          originalName: 'a.txt',
          targetName: 'keep.txt',
          folder: _a,
        ),
      ];

      expect(
        () => planExecution(
          requests,
          occupiedNames: OccupiedNames({
            _a: {'keep.txt'},
          }),
        ),
        throwsArgumentError,
        reason: 'REQ-026 の自動解決を経ていない入力',
      );
    });

    test('挿入する一時名は占有名を避ける(REQ-004)', () {
      // 循環を一時名で解くとき、その一時名が実在すると改名が nameConflict で
      // 止まる。一時名は再採番の対象外(REQ-023)なので、実行全体が停止する。
      final requests = [
        RenameRequest(
          handle: '$_a/a.txt',
          originalName: 'a.txt',
          targetName: 'b.txt',
          folder: _a,
        ),
        RenameRequest(
          handle: '$_a/b.txt',
          originalName: 'b.txt',
          targetName: 'a.txt',
          folder: _a,
        ),
      ];
      // 素直に作ると `a.renaming-0.txt` になるので、それを占有名で塞ぐ。
      final plan = planExecution(
        requests,
        occupiedNames: OccupiedNames({
          _a: {'a.renaming-0.txt', 'b.renaming-0.txt'},
        }),
      );

      final temporaries = [
        for (final step in plan.steps)
          if (step.kind == RenameStepKind.temporary) step.newName,
      ];
      expect(temporaries, isNotEmpty);
      expect(
        temporaries,
        isNot(contains('a.renaming-0.txt')),
        reason: '占有名と同じ一時名を使ってはならない',
      );
      expect(temporaries, isNot(contains('b.renaming-0.txt')));
    });
  });

  group('REQ-026: 占有名との衝突は実行前に確認を経る', () {
    testWidgets('読み込んでいない file と同名になる改名は確認を経る(例25)', (tester) async {
      final wired = _wire(
        entries: [_file('a.txt')],
        rule: const RenameRule([LiteralToken('keep')]),
        listNames: _lister({
          _a: {'a.txt', 'keep.txt'},
        }),
      );
      await _pump(tester, wired.files, wired.execution);

      await _tapExecute(tester);

      expect(
        find.byKey(const Key('rename-confirmation-dialog')),
        findsOneWidget,
        reason: '他に警告が無くても、占有名との衝突だけで確認を経る',
      );
      await tester.tap(find.byKey(const Key('rename-cancel')));
      await tester.pumpAndSettle();
      expect(wired.executor.calls, isEmpty);
    });

    testWidgets('占有名が無ければ確認を経ずに実行する(REQ-010 の直行経路)', (tester) async {
      // 逆向き。これが無いと「常に確認する実装」が通ってしまう。
      final wired = _wire(
        entries: [_file('a.txt')],
        rule: const RenameRule([LiteralToken('keep')]),
        listNames: _lister({
          _a: {'a.txt'},
        }),
      );
      await _pump(tester, wired.files, wired.execution);

      await _tapExecute(tester);

      expect(find.byKey(const Key('rename-confirmation-dialog')), findsNothing);
      expect(wired.executor.names, ['keep.txt']);
      await _passUndoWindow(tester);
    });

    testWidgets('強制実行すると占有名を避けた名前になる(REQ-026 の自動解決)', (tester) async {
      final wired = _wire(
        entries: [_file('a.txt')],
        rule: const RenameRule([LiteralToken('keep')]),
        listNames: _lister({
          _a: {'a.txt', 'keep.txt'},
        }),
      );
      await _pump(tester, wired.files, wired.execution);

      await _tapExecute(tester);
      await tester.tap(find.byKey(const Key('rename-force')));
      await tester.pumpAndSettle();

      expect(wired.executor.names, [
        'keep (1).txt',
      ], reason: '判定だけ占有名で行い解決を占有名抜きで行うと keep.txt になる');
      await _passUndoWindow(tester);
    });

    testWidgets('連番を1つずらす改名では確認を経ない(例25b)', (tester) async {
      // **目標名が他の選択 file の現在名と一致する**入力である。
      // `IMG_0001..0010` を1つずらすと、各目標名は隣の file の現在名になる。
      // 選択 file 自身の現在名を占有名へ入れてしまうと、ここでほぼ全件に
      // 重複警告が出て ` (n)` が付く(005:T04 review attempt 1 の P0)。
      //
      // 占有名は**実在名から導出**させる — 手で空集合を渡すと恒真になり、
      // 導出の誤りを検出できない。
      final names = [
        for (var i = 1; i <= 10; i++) 'IMG_${i.toString().padLeft(4, '0')}.jpg',
      ];
      final wired = _wire(
        entries: [for (final name in names) _file(name)],
        rule: const RenameRule([
          LiteralToken('IMG_'),
          SequenceToken(start: 2, digits: 4),
        ]),
        listNames: _lister({_a: names.toSet()}),
      );
      await _pump(tester, wired.files, wired.execution);

      // 一覧の警告も0件でなければならない(REQ-026 は判定そのものに効く)。
      await wired.execution.prepare();
      expect(
        wired.files.warnings.whereType<DuplicateWarning>(),
        isEmpty,
        reason: '選択 file 自身の現在名は占有名に含まれない',
      );

      await _tapExecute(tester);

      expect(find.byKey(const Key('rename-confirmation-dialog')), findsNothing);
      expect(
        wired.executor.names,
        unorderedEquals([
          for (var i = 2; i <= 11; i++)
            'IMG_${i.toString().padLeft(4, '0')}.jpg',
        ]),
        reason: '` (n)` が1件も付いていない',
      );
      await _passUndoWindow(tester);
    });

    testWidgets('別 folder の同名とは衝突しない(例25d)', (tester) async {
      final wired = _wire(
        entries: [_file('a.txt')],
        rule: const RenameRule([LiteralToken('keep')]),
        listNames: _lister({
          _a: {'a.txt'},
          _b: {'keep.txt'},
        }),
      );
      await _pump(tester, wired.files, wired.execution);

      await _tapExecute(tester);

      expect(find.byKey(const Key('rename-confirmation-dialog')), findsNothing);
      expect(wired.executor.names, ['keep.txt']);
      await _passUndoWindow(tester);
    });
  });

  group('REQ-027: 取得できない folder を含む実行は行わない', () {
    testWidgets('実行せず、どの folder がなぜ駄目かを提示する(例25e)', (tester) async {
      final wired = _wire(
        entries: [_file('a.txt')],
        rule: const RenameRule([LiteralToken('keep')]),
        listNames: listNamesFailing(
          const PickError(PickErrorKind.permissionDenied, '権限がありません'),
        ),
      );
      await _pump(tester, wired.files, wired.execution);

      await _tapExecute(tester);

      expect(wired.executor.calls, isEmpty, reason: '実ファイルを1件も変更しない');
      expect(find.byKey(const Key('rename-confirmation-dialog')), findsNothing);
      final snack = find.byKey(const Key('rename-occupied-names-unavailable'));
      expect(snack, findsOneWidget);
      expect(find.textContaining(_a), findsOneWidget);
      expect(find.textContaining('権限がありません'), findsOneWidget);
      expect(wired.execution.unavailableFolders.keys, [_a]);
    });

    test('取得できないことを「衝突が無い」と読まない', () async {
      final wired = _wire(
        entries: [_file('a.txt')],
        rule: const RenameRule([LiteralToken('keep')]),
        listNames: listNamesFailing(const PickError(PickErrorKind.io, '読めません')),
      );

      final prepared = await wired.execution.prepare();

      expect(prepared, isA<OccupiedNamesUnavailable>());
      expect(wired.files.occupiedNames, isEmpty, reason: '失敗した取得結果を占有名として採らない');
    });
  });

  group('REQ-028: 占有名は実行を要求した時点で取り直す', () {
    testWidgets('読み込み後に他 process が作った名前でも確認を経る(例25g)', (tester) async {
      // 読み込み時点の観測では衝突が無い。実行を要求した時点では衝突する。
      var existing = <String>{'a.txt'};
      final wired = _wire(
        entries: [_file('a.txt')],
        rule: const RenameRule([LiteralToken('keep')]),
        listNames: (folder) async => folder == _a
            ? NamesListed(existing)
            : const NameListFailed(PickError(PickErrorKind.io, '用意していないフォルダ')),
      );
      // 読み込み時点の観測を一覧へ入れておく(この時点では警告0件)。
      wired.files.setOccupiedNames(const {_a: <String>{}});
      await _pump(tester, wired.files, wired.execution);
      expect(wired.files.warnings, isEmpty, reason: '一覧には警告が出ていない状態から始める');

      // 他 process が `keep.txt` を作った。
      existing = {'a.txt', 'keep.txt'};

      await _tapExecute(tester);

      expect(
        find.byKey(const Key('rename-confirmation-dialog')),
        findsOneWidget,
        reason: '一覧に警告が無かったことを理由に確認を飛ばさない',
      );
    });

    testWidgets('取り直した占有名は一覧の警告表示にも反映される(REQ-026)', (tester) async {
      final wired = _wire(
        entries: [_file('a.txt')],
        rule: const RenameRule([LiteralToken('keep')]),
        listNames: _lister({
          _a: {'a.txt', 'keep.txt'},
        }),
      );
      await _pump(tester, wired.files, wired.execution);
      expect(wired.files.warnings, isEmpty);

      await wired.execution.prepare();

      expect(wired.files.warnings.whereType<DuplicateWarning>(), hasLength(1));
    });
  });
}
