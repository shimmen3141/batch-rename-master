// VER-006: 更新日時ずらし(REQ-014 / REQ-015 / REQ-016)。
//
// 契約の例 13〜16 に対応する。
//   13: OFF(既定)なら更新日時は設定されない
//   14: ON で3件成功すると、表示順に一定間隔ずつ増加する更新日時が設定される
//   15: ON でも更新日時の設定に失敗したら、改名は成功のまま実行は止まらない
//   16: 更新日時を設定できないプラットフォームでは設定を提示しない
//
// 「表示順」は実行計画の順ではない。planExecution は衝突を避けるために順序を
// 変えるので、両者が食い違う入力でこの区別を検査する。
import 'package:batch_rename_master/core/rename_engine.dart';
import 'package:batch_rename_master/data/rename_exec/rename_executor.dart';
import 'package:batch_rename_master/ui/file_list/file_list_controller.dart';
import 'package:batch_rename_master/ui/file_list/file_list_view.dart';
import 'package:batch_rename_master/ui/rename_exec/rename_execution_controller.dart';
import 'package:batch_rename_master/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

FileEntry _file(String name) => FileEntry(
  name: name,
  createdAt: DateTime(2026, 1, 2, 3, 4),
  modifiedAt: DateTime(2026, 1, 2, 3, 4),
  size: 1,
  sourceHandle: '/files/$name',
);

/// 更新日時を書ける fake。書き込みを記録し、任意の handle で失敗させられる。
class _WritableExecutor extends FakeRenameExecutor implements ModifiedAtWriter {
  _WritableExecutor({required super.files, this.failOn = const {}});

  /// setModifiedAt が失敗する handle(改名後のもの)。
  final Set<String> failOn;

  /// 書き込んだ順の (handle, 値)。
  final List<(String, DateTime)> written = [];

  @override
  Future<RenameError?> setModifiedAt(String handle, DateTime value) async {
    if (failOn.contains(handle)) {
      return const RenameError(RenameErrorKind.io, '更新日時を設定できません');
    }
    written.add((handle, value));
    return null;
  }
}

RenameExecutionController _controller(
  FileListController files,
  RenameExecutor executor, {
  DateTime Function()? clock,
}) => RenameExecutionController(
  files: files,
  executor: executor,
  clock: clock ?? () => DateTime(2026, 5, 6, 7, 8),
);

void main() {
  group('REQ-014: 既定OFF、ONなら表示順に一定間隔でずらす', () {
    test('例13: OFF(既定)では更新日時を設定しない', () async {
      final files = FileListController(
        files: [_file('a.txt'), _file('b.txt')],
        rule: const RenameRule([OriginalNameToken(), LiteralToken('_x')]),
      );
      final executor = _WritableExecutor(
        files: {'/files/a.txt': 'a.txt', '/files/b.txt': 'b.txt'},
      );
      final execution = _controller(files, executor);

      expect(execution.shiftModifiedAt, isFalse); // 既定OFF
      final outcome = await execution.execute(force: false);

      expect(outcome!.successes, hasLength(2)); // 改名自体は成功する
      expect(executor.written, isEmpty); // 更新日時には触れない
      expect(execution.modifiedAtFailures, isEmpty);
      // 一覧の更新日時も元のまま。
      expect(
        files.items.every((i) => i.modifiedAt == DateTime(2026, 1, 2, 3, 4)),
        isTrue,
      );
    });

    test('例14: ONなら成功分へ表示順で一定間隔ずつ増える更新日時を設定する', () async {
      // a→b, b→c の入れ替えを含むので、planExecution は衝突を避けるために
      // 表示順(a, b, c)とは違う順序で実行する。ここで「表示順」を検査する。
      final files = FileListController(
        files: [_file('a.txt'), _file('b.txt'), _file('c.txt')],
        rule: const RenameRule([OriginalNameToken(), LiteralToken('_1')]),
      );
      final executor = _WritableExecutor(
        files: {
          '/files/a.txt': 'a.txt',
          '/files/b.txt': 'b.txt',
          '/files/c.txt': 'c.txt',
        },
      );
      final base = DateTime(2026, 5, 6, 7, 8);
      final execution = _controller(files, executor, clock: () => base);
      execution.setShiftModifiedAt(true);

      final outcome = await execution.execute(force: false);
      expect(outcome!.successes, hasLength(3));

      // 表示順(a, b, c)に対応する新しい handle へ、interval ずつ増えて書かれる。
      final interval = execution.modifiedAtInterval;
      expect(executor.written, [
        ('/files/a_1.txt', base),
        ('/files/b_1.txt', base.add(interval)),
        ('/files/c_1.txt', base.add(interval * 2)),
      ]);
      // 単調増加であること(間隔が丸められても順序が保たれる性質の検査)。
      final times = executor.written.map((w) => w.$2).toList();
      for (var i = 1; i < times.length; i++) {
        expect(times[i].isAfter(times[i - 1]), isTrue);
      }
      // 一覧の更新日時も書き込んだ値に揃う。
      expect(files.items.map((i) => i.modifiedAt), [
        base,
        base.add(interval),
        base.add(interval * 2),
      ]);
    });

    test('表示順を並べ替えると、ずらす順序もそれに追随する', () async {
      final files = FileListController(
        files: [_file('a.txt'), _file('b.txt')],
        rule: const RenameRule([OriginalNameToken(), LiteralToken('_1')]),
      );
      files.reorder(0, 1); // a を末尾へ = 表示順は b, a
      final executor = _WritableExecutor(
        files: {'/files/a.txt': 'a.txt', '/files/b.txt': 'b.txt'},
      );
      final base = DateTime(2026, 5, 6, 7, 8);
      final execution = _controller(files, executor, clock: () => base);
      execution.setShiftModifiedAt(true);

      await execution.execute(force: false);

      expect(executor.written.map((w) => w.$1), [
        '/files/b_1.txt',
        '/files/a_1.txt',
      ]);
    });
  });

  group('REQ-016: 更新日時の設定に失敗しても改名は成功のまま', () {
    test('例15: 失敗しても実行は止まらず、残りのファイルも処理される', () async {
      final files = FileListController(
        files: [_file('a.txt'), _file('b.txt'), _file('c.txt')],
        rule: const RenameRule([OriginalNameToken(), LiteralToken('_1')]),
      );
      final executor = _WritableExecutor(
        files: {
          '/files/a.txt': 'a.txt',
          '/files/b.txt': 'b.txt',
          '/files/c.txt': 'c.txt',
        },
        failOn: {'/files/b_1.txt'},
      );
      final base = DateTime(2026, 5, 6, 7, 8);
      final execution = _controller(files, executor, clock: () => base);
      execution.setShiftModifiedAt(true);

      final outcome = await execution.execute(force: false);

      // 改名は3件とも成功し、失敗として記録されない。
      expect(outcome!.successes, hasLength(3));
      expect(outcome.failure, isNull);
      expect(outcome.notExecuted, isEmpty);
      expect(files.items.map((i) => i.name), ['a_1.txt', 'b_1.txt', 'c_1.txt']);

      // 止まらないので、失敗の後ろにある c も書かれる。
      expect(executor.written.map((w) => w.$1), [
        '/files/a_1.txt',
        '/files/c_1.txt',
      ]);
      // 失敗は改名の失敗と区別して提示できる形で残る。
      expect(execution.modifiedAtFailures.map((f) => f.name), ['b_1.txt']);
      // 失敗した分の更新日時は元のまま。
      expect(files.items[1].modifiedAt, DateTime(2026, 1, 2, 3, 4));
    });

    test('次の実行を始めると前回の失敗記録は消える', () async {
      final files = FileListController(
        files: [_file('a.txt')],
        rule: const RenameRule([OriginalNameToken(), LiteralToken('_1')]),
      );
      final executor = _WritableExecutor(
        files: {'/files/a.txt': 'a.txt'},
        failOn: {'/files/a_1.txt'},
      );
      final execution = _controller(files, executor);
      execution.setShiftModifiedAt(true);

      await execution.execute(force: false);
      expect(execution.modifiedAtFailures, hasLength(1));

      files.setRule(
        const RenameRule([OriginalNameToken(), LiteralToken('_2')]),
      );
      await execution.execute(force: false);
      expect(execution.modifiedAtFailures, isEmpty);
    });
  });

  group('REQ-015: 設定できないプラットフォームでは提示しない', () {
    test('更新日時を書けない実装では ON にできない', () async {
      final files = FileListController(
        files: [_file('a.txt')],
        rule: const RenameRule([OriginalNameToken(), LiteralToken('_1')]),
      );
      // 素の FakeRenameExecutor は ModifiedAtWriter ではない(= Android SAF 相当)。
      final executor = FakeRenameExecutor(files: {'/files/a.txt': 'a.txt'});
      final execution = _controller(files, executor);

      expect(execution.canShiftModifiedAt, isFalse);
      execution.setShiftModifiedAt(true);
      expect(execution.shiftModifiedAt, isFalse); // 立たない

      final outcome = await execution.execute(force: false);
      expect(outcome!.successes, hasLength(1)); // 改名自体は通常どおり
      expect(execution.modifiedAtFailures, isEmpty);
    });

    testWidgets('例16: 書けない実装では設定そのものを画面に出さない', (tester) async {
      final files = FileListController(
        files: [_file('a.txt')],
        rule: const RenameRule([OriginalNameToken(), LiteralToken('_1')]),
      );
      final execution = _controller(
        files,
        FakeRenameExecutor(files: {'/files/a.txt': 'a.txt'}),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: appDarkTheme(),
          home: Scaffold(
            body: FileListView(controller: files, renameExecution: execution),
          ),
        ),
      );

      expect(find.byKey(shiftModifiedAtKey), findsNothing);
    });

    testWidgets('書ける実装では設定が出て、切り替えると状態が変わる', (tester) async {
      final files = FileListController(
        files: [_file('a.txt')],
        rule: const RenameRule([OriginalNameToken(), LiteralToken('_1')]),
      );
      final execution = _controller(
        files,
        _WritableExecutor(files: {'/files/a.txt': 'a.txt'}),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: appDarkTheme(),
          home: Scaffold(
            body: FileListView(controller: files, renameExecution: execution),
          ),
        ),
      );

      expect(find.byKey(shiftModifiedAtKey), findsOneWidget);
      expect(execution.shiftModifiedAt, isFalse);

      await tester.tap(find.byKey(shiftModifiedAtKey));
      await tester.pumpAndSettle();

      expect(execution.shiftModifiedAt, isTrue);
    });
  });
}
