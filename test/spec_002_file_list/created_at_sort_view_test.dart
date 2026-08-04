// VER-002(T6): 作成日時ソート時の警告表示と、行の日時サブ情報(FEAT-002 / Light)。
// 対象: REQ-011(不明件数と代替した旨の警告表示), REQ-013(行が両日時と不明かを提示)。
import 'package:batch_rename_master/core/rename_engine.dart';
import 'package:batch_rename_master/ui/file_list/file_list_controller.dart';
import 'package:batch_rename_master/ui/file_list/file_list_view.dart';
import 'package:batch_rename_master/ui/file_list/file_sort.dart';
import 'package:batch_rename_master/ui/theme/app_colors.dart';
import 'package:batch_rename_master/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

FileEntry _known(String name) => FileEntry(
  name: name,
  createdAt: DateTime(2023, 5, 6, 7, 8),
  modifiedAt: DateTime(2026, 8, 4, 16),
  size: 0,
);

FileEntry _unknown(String name) =>
    FileEntry(name: name, modifiedAt: DateTime(2026, 8, 4, 16), size: 0);

final _warningBanner = find.byKey(const Key('created-at-fallback-warning'));

Future<void> _pump(WidgetTester tester, FileListController c) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: appDarkTheme(),
      home: Scaffold(body: FileListView(controller: c)),
    ),
  );
}

void main() {
  group('REQ-011: 作成日時ソート時の警告表示', () {
    testWidgets('不明があるときだけ、件数と代替した旨を表示する', (tester) async {
      final c = FileListController(files: [_known('a.txt'), _unknown('b.png')]);
      await _pump(tester, c);

      // 既定(custom)では出ない。
      expect(_warningBanner, findsNothing);

      c.setSortMode(FileSortMode.createdAt);
      await tester.pump();

      expect(_warningBanner, findsOneWidget);
      expect(find.textContaining('1 件'), findsOneWidget);
      expect(find.textContaining('更新日時で代替'), findsOneWidget);
    });

    testWidgets('全件判明していれば表示しない', (tester) async {
      final c = FileListController(files: [_known('a.txt'), _known('b.txt')]);
      await _pump(tester, c);

      c.setSortMode(FileSortMode.createdAt);
      await tester.pump();

      expect(_warningBanner, findsNothing);
    });

    testWidgets('更新日時順へ切り替えると消える', (tester) async {
      final c = FileListController(files: [_unknown('b.png')]);
      await _pump(tester, c);

      c.setSortMode(FileSortMode.createdAt);
      await tester.pump();
      expect(_warningBanner, findsOneWidget);

      c.setSortMode(FileSortMode.modifiedAt);
      await tester.pump();
      expect(_warningBanner, findsNothing);
    });

    testWidgets('「更新日時順」チップで modifiedAt ソートへ切り替わる', (tester) async {
      final c = FileListController(files: [_known('a.txt')]);
      await _pump(tester, c);

      await tester.tap(find.text('更新日時順'));
      await tester.pump();

      expect(c.sortMode, FileSortMode.modifiedAt);
    });
  });

  group('REQ-013: 行の日時サブ情報', () {
    testWidgets('作成日時が判明している行は両日時を表示する', (tester) async {
      await _pump(tester, FileListController(files: [_known('a.txt')]));

      expect(find.textContaining('作成日時: 2023/5/6 07:08'), findsOneWidget);
      expect(find.textContaining('更新日時: 2026/8/4 16:00'), findsOneWidget);
    });

    testWidgets('作成日時が不明な行は「不明」と警告色で示す', (tester) async {
      await _pump(tester, FileListController(files: [_unknown('b.png')]));

      // 行のサブ情報(日時)の RichText を特定する(ヘッダ等の別テキストを拾わない)。
      final richText = tester
          .widgetList<RichText>(find.byType(RichText))
          .firstWhere((w) => w.text.toPlainText().contains('作成日時: '));
      final text = richText.text.toPlainText();
      expect(text, contains('作成日時: 不明'));
      expect(text, contains('更新日時: 2026/8/4 16:00'));

      // 不明部分はセマンティックな危険色(色の直書きをしない)。
      final leaves = <TextSpan>[];
      richText.text.visitChildren((span) {
        if (span is TextSpan && span.text != null) leaves.add(span);
        return true;
      });
      final unknownSpan = leaves.firstWhere(
        (span) => span.text!.contains('不明'),
      );
      expect(unknownSpan.style?.color, AppColors.dark.danger);
    });
  });
}
