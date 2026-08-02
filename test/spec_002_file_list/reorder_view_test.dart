// VER-002(続き): ドラッグ並び替えと「カスタム順」自動切替の検証(REQ-003)。
// 並び順の変更が連番・プレビューへ反映されることも確認する。
import 'package:batch_rename_master/core/rename_engine.dart';
import 'package:batch_rename_master/ui/file_list/file_list_controller.dart';
import 'package:batch_rename_master/ui/file_list/file_list_view.dart';
import 'package:batch_rename_master/ui/file_list/file_sort.dart';
import 'package:batch_rename_master/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

FileEntry _f(String name) => FileEntry(
  name: name,
  createdAt: DateTime(2026, 1, 1),
  modifiedAt: DateTime(2026, 1, 1),
  size: 0,
);

const _seq2 = RenameRule([SequenceToken(start: 1, digits: 2)]);

Future<void> _pump(WidgetTester tester, FileListController c) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: appDarkTheme(),
      home: Scaffold(body: FileListView(controller: c)),
    ),
  );
}

double _yOf(WidgetTester tester, String text) =>
    tester.getTopLeft(find.text(text)).dy;

void main() {
  testWidgets('onReorder が controller.reorder を駆動し custom へ自動切替(REQ-003)', (
    tester,
  ) async {
    final c = FileListController(
      files: [_f('a.txt'), _f('b.txt'), _f('c.txt')],
      rule: _seq2,
    );
    c.setSortMode(FileSortMode.name); // custom 以外から始める
    await _pump(tester, c);
    expect(c.sortMode, FileSortMode.name);

    // ReorderableListView のコールバックを直接駆動(onReorderItem 規約の検証)。
    final rlv = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );
    rlv.onReorderItem!(0, 1); // a を取り出し index1 へ -> [b, a, c]
    await tester.pump();

    expect(c.sortMode, FileSortMode.custom); // 自動切替
    expect(c.items.map((e) => e.name).toList(), ['b.txt', 'a.txt', 'c.txt']);
    // 連番は新しい表示順で振り直し: b=01, a=02, c=03。
    expect(_yOf(tester, 'b.txt'), lessThan(_yOf(tester, 'a.txt')));
    expect(find.text('01.txt'), findsOneWidget);
    expect(find.text('03.txt'), findsOneWidget);
  });

  testWidgets('ドラッグハンドルの操作で実際に並び替わり custom になる(REQ-003)', (tester) async {
    final c = FileListController(
      files: [_f('a.txt'), _f('b.txt'), _f('c.txt')],
      rule: _seq2,
    );
    await _pump(tester, c);
    expect(_yOf(tester, 'a.txt'), lessThan(_yOf(tester, 'b.txt')));

    // 先頭行のハンドルを掴んで下方向へドラッグする。
    final handle = find.byIcon(Icons.drag_handle).first;
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 250));
    await gesture.moveBy(const Offset(0, 60));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 60));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(c.sortMode, FileSortMode.custom);
    // 先頭の a.txt が動いた(もう最上段ではない)。
    expect(c.items.first.name, isNot('a.txt'));
  });

  testWidgets('ドラッグハンドルが各行に表示される', (tester) async {
    final c = FileListController(
      files: [_f('a.txt'), _f('b.txt')],
      rule: _seq2,
    );
    await _pump(tester, c);
    expect(find.byIcon(Icons.drag_handle), findsNWidgets(2));
  });
}
