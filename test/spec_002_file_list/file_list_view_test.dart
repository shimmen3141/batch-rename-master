// VER-002: ファイルリストの描画層(ウィジェット操作 → 状態反映)の検証。
// 対象: REQ-002(ソート切替)/ REQ-004(チェックボックス・全選択/全解除)/
//       REQ-006/REQ-007(行の現在名・変更後名の表示)。ドラッグ並び替え(REQ-003)は T5。
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

void main() {
  testWidgets('現在名と選択行の変更後名を表示する(REQ-006)', (tester) async {
    final c = FileListController(
      files: [_f('a.txt'), _f('b.txt')],
      rule: _seq2,
    );
    await _pump(tester, c);
    expect(find.text('a.txt'), findsOneWidget);
    expect(find.text('b.txt'), findsOneWidget);
    expect(find.text('01.txt'), findsOneWidget);
    expect(find.text('02.txt'), findsOneWidget);
  });

  testWidgets('チェックボックスのタップで選択が反転し、未選択行は — 表示(REQ-004/REQ-007)', (
    tester,
  ) async {
    final files = [_f('a.txt'), _f('b.txt')];
    final c = FileListController(files: files, rule: _seq2);
    await _pump(tester, c);
    expect(c.selectedOf(files[0]), isTrue);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();

    expect(c.selectedOf(files[0]), isFalse);
    // 先頭行が未選択になり変更後名は — に、残る選択行 b は 01 に振り直し。
    expect(find.text('—'), findsOneWidget);
    expect(find.text('01.txt'), findsOneWidget);
    expect(find.text('02.txt'), findsNothing);
  });

  testWidgets('ソートチップのタップで sortMode と表示順が変わる(REQ-002)', (tester) async {
    final c = FileListController(
      files: [_f('b.txt'), _f('a.txt')],
      rule: _seq2,
    );
    await _pump(tester, c);
    expect(c.sortMode, FileSortMode.custom);

    await tester.tap(find.text('元の名前順'));
    await tester.pump();

    expect(c.sortMode, FileSortMode.name);
    // 名前順で a.txt が b.txt より上に並ぶ。
    final yA = tester.getTopLeft(find.text('a.txt')).dy;
    final yB = tester.getTopLeft(find.text('b.txt')).dy;
    expect(yA, lessThan(yB));
  });

  testWidgets('全選択トグルで全解除→全選択が切り替わる(REQ-004)', (tester) async {
    final files = [_f('a.txt'), _f('b.txt'), _f('c.txt')];
    final c = FileListController(files: files, rule: _seq2);
    await _pump(tester, c);
    expect(c.selectedCount, 3);

    await tester.tap(find.byKey(const Key('select-all-toggle')));
    await tester.pump();
    expect(c.selectedCount, 0);
    expect(find.text('—'), findsNWidgets(3));

    await tester.tap(find.byKey(const Key('select-all-toggle')));
    await tester.pump();
    expect(c.selectedCount, 3);
  });

  testWidgets('選択件数ラベルを表示する', (tester) async {
    final c = FileListController(files: [_f('a'), _f('b')], rule: _seq2);
    await _pump(tester, c);
    expect(find.text('2 / 2 件を選択'), findsOneWidget);
  });
}
