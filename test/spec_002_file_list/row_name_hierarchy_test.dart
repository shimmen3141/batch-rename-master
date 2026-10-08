// 008:T10 行の preview の大きさと、現在名・変更後名の強弱(2026-10-01 の要望)。
//
// - 「リネームリストで、写真のサイズが小さい」→ 参考designのリッチな行と同じ 52 にする。
// - 「変更前と変更後のファイル名の文字の大きさを変える」→ 現在名は小さく、変更後名は大きく太く。
// - 色は 008:T62(2026-10-08 の開発者の決定「変更前と矢印を白に近い色に」)で、T10 の
//   「変更前の名前の文字の色を薄く」から**本文の色**へ置き換えた。灰色の補足情報と分けるため。
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

  testWidgets('現在名は変更後名より小さく太字でなく、色は本文の色(008:T62)', (tester) async {
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
    // 色: 現在名は本文の色(白に近い)。補足情報の灰より明るい。**赤ではない** — 赤は
    // 問題があることだけに使う(変更後名の警告の色)。
    expect(current.color, colors.textPrimary);
    expect(current.color, isNot(colors.danger));
  });

  testWidgets('「→」は現在名と同じ本文の色(008:T62)で、軸が長く矢じりが小さい形(008:T63)', (tester) async {
    await _pump(tester);

    final arrow = tester.widget<Icon>(find.byKey(rowNameArrowKey));
    // 以前の `arrow_forward` は軸が短く矢じりが大きかった(2026-10-08 の開発者の要望)。
    expect(arrow.icon, Icons.arrow_right_alt);
    expect(arrow.color, AppColors.dark.textPrimary);
  });

  testWidgets('「→」は一回り大きく描くが、名前の行の高さは変えない(008:T63 attempt 1)', (tester) async {
    await _pump(tester);

    // 行に取る場所は 18。
    final box = tester.getRect(find.byKey(rowNameArrowScaleKey));
    expect(box.width, 18);
    expect(box.height, 18);
    // 描くのは 22 相当(矢尻が目立たなかったので一回り大きく)。中心は場所の中心のまま。
    final drawn = tester.getRect(find.byKey(rowNameArrowKey));
    expect(drawn.width, closeTo(22, 0.01));
    expect(drawn.center.dx, closeTo(box.center.dx, 0.01));
    expect(drawn.center.dy, closeTo(box.center.dy, 0.01));
    // 描いた矢印と変更後名の間を空ける(拡大した分で詰まらない)。
    expect(
      drawn.right + 2,
      lessThanOrEqualTo(tester.getRect(find.byKey(rowNewNameKey)).left),
    );
    // 名前の行の高さは変更後名の文字で決まる(矢印で高くならない)。
    final newName = tester.getRect(find.byKey(rowNewNameKey));
    expect(box.height, lessThanOrEqualTo(newName.height));
  });
}
