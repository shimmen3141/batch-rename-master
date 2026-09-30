// VER-002(008:T02): 手動並び替えはルールに関わらず提示する(002 REQ-019)と、
// 並び順を1か所で示すcontrol(REQ-020)。REQ-014(連番があるときだけ提示)は
// 2026-09-30 `008:T01` で廃止した。
import 'package:batch_rename_master/core/rename_engine.dart';
import 'package:batch_rename_master/ui/common/selection_checkbox.dart';
import 'package:batch_rename_master/ui/file_list/file_list_controller.dart';
import 'package:batch_rename_master/ui/file_list/file_list_view.dart';
import 'package:batch_rename_master/ui/file_list/file_sort.dart';
import 'package:batch_rename_master/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

FileEntry _f(String name, {int size = 0}) =>
    FileEntry(name: name, modifiedAt: DateTime(2026, 1, 1), size: size);

const _withSequence = RenameRule([
  LiteralToken('IMG_'),
  SequenceToken(start: 1, digits: 2, increment: 1),
]);
const _withoutSequence = RenameRule([OriginalNameToken(), LiteralToken('_v2')]);

Future<void> _pump(WidgetTester tester, FileListController c) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: appDarkTheme(),
      home: Scaffold(body: FileListView(controller: c)),
    ),
  );
}

List<String> _names(FileListController c) =>
    c.items.map((e) => e.name).toList();

/// 並び順の表示の文言(帯へ移してから「並び順:」は付けない。読み上げが持つ)。
Finder _sortLabel(String text) =>
    find.descendant(of: find.byKey(sortControlKey), matching: find.text(text));

Future<void> _openSortMenu(WidgetTester tester) async {
  await tester.tap(find.byKey(sortControlKey));
  await tester.pumpAndSettle();
}

/// メニュー項目の選択の印が付いているか。
bool _checked(WidgetTester tester, FileSortMode mode, SortDirection dir) =>
    tester
        .widget<SelectionCheckbox>(
          find.descendant(
            of: find.byKey(sortOptionKeyOf(mode, dir)),
            matching: find.byType(SelectionCheckbox),
          ),
        )
        .value;

void main() {
  group('REQ-019: 手動並び替えはルールに関わらず提示する', () {
    testWidgets('例16: 連番が無いルールでもつまみが出て、並べると「カスタム」になる', (tester) async {
      final c = FileListController(
        files: [_f('a.txt'), _f('b.txt'), _f('c.txt')],
        rule: _withoutSequence,
      );
      await _pump(tester, c);

      expect(find.byIcon(Icons.drag_handle), findsNWidgets(3));
      expect(_sortLabel('名前 A→Z'), findsOneWidget);

      // 先頭の a のつまみを掴んで下へ動かす(REQ-003)。
      final handle = find.byIcon(Icons.drag_handle).first;
      final gesture = await tester.startGesture(tester.getCenter(handle));
      await tester.pump(const Duration(milliseconds: 250));
      await gesture.moveBy(const Offset(0, 60));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 60));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(_names(c).first, isNot('a.txt'));
      expect(c.sortMode, FileSortMode.custom);
      expect(_sortLabel('カスタム'), findsOneWidget);
    });

    testWidgets('連番があるルールでもつまみが出る', (tester) async {
      await _pump(
        tester,
        FileListController(files: [_f('a.txt')], rule: _withSequence),
      );
      expect(find.byIcon(Icons.drag_handle), findsOneWidget);
    });

    testWidgets('ルールから連番を外してもつまみは消えない', (tester) async {
      final c = FileListController(files: [_f('a.txt')], rule: _withSequence);
      await _pump(tester, c);
      c.setRule(_withoutSequence);
      await tester.pump();
      expect(find.byIcon(Icons.drag_handle), findsOneWidget);
    });
  });

  group('REQ-020: 並び順を1か所で示し、すべてのキーと向きを選べる', () {
    testWidgets('並び順はケバブの左にあり、並び順だけの帯は無い(2026-09-30 の開発者の指定)', (tester) async {
      final c = FileListController(
        files: [_f('a.txt'), _f('b.txt')],
        rule: _withSequence,
      );
      await _pump(tester, c);

      final sort = tester.getRect(find.byKey(sortControlKey));
      final menu = tester.getRect(find.byKey(listMenuKey));
      final count = tester.getRect(find.byKey(fileCountKey));
      // 件数・並び順・ケバブが同じ帯の1行に並ぶ。
      expect(sort.right, lessThanOrEqualTo(menu.left));
      expect(sort.center.dy, closeTo(menu.center.dy, 1));
      expect(count.center.dy, closeTo(menu.center.dy, 1));
      // 状態のメッセージ(準備完了)は帯ではなく、その下のバナーにある。
      expect(
        find.descendant(
          of: find.byKey(messageBannerKey),
          matching: find.text('正常にリネームできます'),
        ),
        findsOneWidget,
      );
      expect(
        tester.getRect(find.text('正常にリネームできます')).top,
        greaterThanOrEqualTo(menu.bottom),
      );
    });

    testWidgets('メニューに8項目があり、カスタムは無い', (tester) async {
      await _pump(tester, FileListController(files: [_f('a.txt')]));
      await _openSortMenu(tester);

      for (final (mode, dir, label) in [
        (FileSortMode.name, SortDirection.ascending, 'A→Z'),
        (FileSortMode.name, SortDirection.descending, 'Z→A'),
        (FileSortMode.createdAt, SortDirection.ascending, '古い順'),
        (FileSortMode.createdAt, SortDirection.descending, '新しい順'),
        (FileSortMode.modifiedAt, SortDirection.ascending, '古い順'),
        (FileSortMode.modifiedAt, SortDirection.descending, '新しい順'),
        (FileSortMode.size, SortDirection.ascending, '小さい順'),
        (FileSortMode.size, SortDirection.descending, '大きい順'),
      ]) {
        final option = find.byKey(sortOptionKeyOf(mode, dir));
        expect(option, findsOneWidget, reason: '$mode $dir');
        expect(
          find.descendant(of: option, matching: find.textContaining(label)),
          findsOneWidget,
          reason: '$mode $dir',
        );
      }
      expect(
        find.byType(PopupMenuItem<(FileSortMode, SortDirection)>),
        findsNWidgets(8),
      );
      expect(find.textContaining('カスタム'), findsNothing);
    });

    testWidgets('選んでいる項目にだけ選択の印が付く', (tester) async {
      await _pump(tester, FileListController(files: [_f('a.txt')]));
      await _openSortMenu(tester);

      expect(
        _checked(tester, FileSortMode.name, SortDirection.ascending),
        isTrue,
      );
      for (final mode in [
        FileSortMode.name,
        FileSortMode.createdAt,
        FileSortMode.modifiedAt,
        FileSortMode.size,
      ]) {
        for (final dir in SortDirection.values) {
          if (mode == FileSortMode.name && dir == SortDirection.ascending) {
            continue;
          }
          expect(_checked(tester, mode, dir), isFalse, reason: '$mode $dir');
        }
      }
    });

    testWidgets('項目を選ぶと状態と表示に反映される(キーと向き)', (tester) async {
      final c = FileListController(
        files: [_f('a', size: 1), _f('b', size: 3), _f('c', size: 2)],
      );
      await _pump(tester, c);

      await _openSortMenu(tester);
      await tester.tap(
        find.byKey(
          sortOptionKeyOf(FileSortMode.size, SortDirection.descending),
        ),
      );
      await tester.pumpAndSettle();
      expect(c.sortMode, FileSortMode.size);
      expect(c.sortDirection, SortDirection.descending);
      expect(_names(c), ['b', 'c', 'a']);
      expect(_sortLabel('サイズ 大きい順'), findsOneWidget);

      await _openSortMenu(tester);
      expect(
        _checked(tester, FileSortMode.size, SortDirection.descending),
        isTrue,
      );
      await tester.tap(
        find.byKey(
          sortOptionKeyOf(FileSortMode.name, SortDirection.descending),
        ),
      );
      await tester.pumpAndSettle();
      expect(c.sortMode, FileSortMode.name);
      expect(c.sortDirection, SortDirection.descending);
      expect(_names(c), ['c', 'b', 'a']);
      expect(_sortLabel('名前 Z→A'), findsOneWidget);
    });

    testWidgets('カスタムのときはどの項目にも印が付かない', (tester) async {
      final c = FileListController(files: [_f('a'), _f('b')]);
      c.reorder(1, 0);
      await _pump(tester, c);
      expect(_sortLabel('カスタム'), findsOneWidget);

      await _openSortMenu(tester);
      for (final mode in [
        FileSortMode.name,
        FileSortMode.createdAt,
        FileSortMode.modifiedAt,
        FileSortMode.size,
      ]) {
        for (final dir in SortDirection.values) {
          expect(_checked(tester, mode, dir), isFalse, reason: '$mode $dir');
        }
      }
    });

    testWidgets('N-8a: 文字を最大(2.0)にしても、すべての項目へ到達できる', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final c = FileListController(files: [_f('a.txt')]);
      await tester.pumpWidget(
        MaterialApp(
          theme: appDarkTheme(),
          // メニューの route にも効くよう、Navigator の外側で文字を拡大する。
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(body: FileListView(controller: c)),
        ),
      );
      expect(tester.takeException(), isNull);

      await _openSortMenu(tester);
      expect(tester.takeException(), isNull);
      // 最後の項目までスクロールして選べる(はみ出して隠れない)。
      final last = find.byKey(
        sortOptionKeyOf(FileSortMode.size, SortDirection.descending),
      );
      await tester.scrollUntilVisible(
        last,
        50,
        scrollable: find
            .ancestor(
              of: find.byKey(
                sortOptionKeyOf(FileSortMode.name, SortDirection.ascending),
              ),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(last);
      await tester.pumpAndSettle();
      expect(c.sortMode, FileSortMode.size);
      expect(c.sortDirection, SortDirection.descending);
      expect(_sortLabel('サイズ 大きい順'), findsOneWidget);
    });
  });
}
