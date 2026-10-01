// 008:T10 行の preview の大きさと、現在名・変更後名の強弱(2026-10-01 の要望)。
//
// - 「リネームリストで、写真のサイズが小さい」→ 参考designのリッチな行と同じ 52 にする。
// - 「変更前と変更後のファイル名の文字の大きさを変える」「変更前の名前の文字の色を薄く」
//   → 現在名は小さく薄く、変更後名は大きく太く。
import 'package:batch_rename_master/core/rename_engine.dart';
import 'package:batch_rename_master/ui/file_list/file_list_controller.dart';
import 'package:batch_rename_master/ui/file_list/file_list_view.dart';
import 'package:batch_rename_master/ui/file_list/row_preview_view.dart';
import 'package:batch_rename_master/ui/theme/app_colors.dart';
import 'package:batch_rename_master/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

FileEntry _entry(String name) => FileEntry(
  name: name,
  modifiedAt: DateTime(2026, 8, 4, 16),
  size: 0,
  sourceHandle: '/storage/emulated/0/DCIM/$name',
);

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: appDarkTheme(),
      home: Scaffold(
        body: FileListView(
          controller: FileListController(
            files: [_entry('a.jpg')],
            rule: const RenameRule([OriginalNameToken(), LiteralToken('_1')]),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

TextStyle _styleOf(WidgetTester tester, Key key) {
  final finder = find.byKey(key);
  return DefaultTextStyle.of(
    tester.element(finder),
  ).style.merge(tester.widget<Text>(finder).style);
}

void main() {
  testWidgets('行の preview は参考designと同じ 52(以前の 40 より大きい)', (tester) async {
    await _pump(tester);

    expect(tester.getSize(find.byKey(rowPreviewKey)), const Size(52, 52));
  });

  testWidgets('現在名は変更後名より小さく薄く、変更後名は太字', (tester) async {
    await _pump(tester);
    const colors = AppColors.dark;

    final current = _styleOf(tester, rowCurrentNameKey);
    final next = _styleOf(tester, rowNewNameKey);
    expect(find.text('a.jpg'), findsOneWidget);
    expect(find.text('a_1.jpg'), findsOneWidget);

    // 大きさ: 現在名 < 変更後名(参考design: 11.5 と 13)。
    expect(current.fontSize, lessThan(next.fontSize!));
    // 太さ: 変更後名は太字。現在名は太字でない。
    expect(next.fontWeight, FontWeight.w700);
    expect(current.fontWeight ?? FontWeight.normal, FontWeight.normal);
    // 色: 現在名は本文の白より**暗く**(= 薄く)、それでも最も薄い段よりは明るい
    // (小さい字で読めなくならないため)。
    final luminance = current.color!.computeLuminance();
    expect(luminance, lessThan(colors.textPrimary.computeLuminance()));
    expect(luminance, greaterThan(colors.textMuted.computeLuminance()));
  });
}
