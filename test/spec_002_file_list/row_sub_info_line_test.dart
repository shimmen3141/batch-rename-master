// 008:T62 補足情報の左の縦線(2026-10-08 の開発者の決定)。
//
// 原文: 「補足情報の左辺に太めの縦線を引く(notionの引用のような感じ)ことで、補足情報を
// 強調せずにまとまりにできると思いました。」
//
// 線は補足情報(場所・日時・大きさ)だけにかかり、名前の2段にはかからない。面は塗らない
// (`T59` の帯は不採用。塗った面が無いことは `row_emphasis_test.dart` が見る)。
import 'package:batch_rename_master/core/rename_engine.dart';
import 'package:batch_rename_master/ui/file_list/file_list_controller.dart';
import 'package:batch_rename_master/ui/file_list/file_list_view.dart';
import 'package:batch_rename_master/ui/file_list/file_sort.dart';
import 'package:batch_rename_master/ui/theme/app_colors.dart';
import 'package:batch_rename_master/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

FileEntry _entry(String name, String location) => FileEntry(
  name: name,
  createdAt: DateTime(2026, 9, 30, 8, 5),
  modifiedAt: DateTime(2026, 10, 1, 9, 5),
  size: 2516582,
  sourceHandle: '$location/$name',
  sourceLocation: location,
);

Future<void> _pump(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(411, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: appDarkTheme(),
      home: Scaffold(
        body: FileListView(
          controller: FileListController(
            // 場所が2つ混ざるので場所も出る(`T22`)。作成日時順なので作成日時も出る。
            files: [
              _entry('a.jpg', '/storage/emulated/0/DCIM'),
              _entry('b.jpg', '/storage/emulated/0/Download'),
            ],
            rule: const RenameRule([OriginalNameToken(), LiteralToken('_1')]),
          )..setSortMode(FileSortMode.createdAt),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// 1行目の [key] の widget。
Finder _first(Key key) => find.byKey(key).first;

void main() {
  testWidgets('補足情報の左に、補足情報の文字と同じ灰の太めの縦線がある', (tester) async {
    await _pump(tester);
    const colors = AppColors.dark;

    final box = tester.widget<Container>(_first(rowSubInfoLineKey));
    final decoration = box.decoration! as BoxDecoration;
    final border = decoration.border! as Border;
    expect(border.left.width, rowSubInfoLineWidth);
    expect(rowSubInfoLineWidth, greaterThanOrEqualTo(2));
    expect(border.left.color, colors.textMuted);
    expect(border.left.style, BorderStyle.solid);
    // 左だけ。上下右には引かない(枠にしない)。
    expect(border.top, BorderSide.none);
    expect(border.right, BorderSide.none);
    expect(border.bottom, BorderSide.none);
    // 面は塗らない。
    expect(decoration.color, isNull);
  });

  testWidgets('線は補足情報(場所・日時・大きさ)の高さ全体にかかり、名前にはかからない', (tester) async {
    await _pump(tester);

    final line = _first(rowSubInfoLineKey);
    final lineRect = tester.getRect(line);
    for (final key in [rowLocationKey, rowCreatedAtKey, rowSizeKey]) {
      final target = _first(key);
      expect(
        find.descendant(of: line, matching: target),
        findsOneWidget,
        reason: '$key は線の中',
      );
      final rect = tester.getRect(target);
      expect(rect.top, greaterThanOrEqualTo(lineRect.top));
      expect(rect.bottom, lessThanOrEqualTo(lineRect.bottom));
      // 文字は線の右(線の太さ + 間)から始まる。
      expect(
        rect.left,
        greaterThanOrEqualTo(
          lineRect.left + rowSubInfoLineWidth + rowSubInfoLineGap,
        ),
      );
    }
    // 線ごと、名前の左端(`→` が取る場所の左端)からわずかに字下げする(attempt 1 の
    // 要望)。`→` は描くときだけ拡大する(`008:T63`)ので、拡大前の場所で測る。
    expect(rowSubInfoIndent, greaterThan(0));
    expect(
      lineRect.left,
      tester.getRect(_first(rowNameArrowScaleKey)).left + rowSubInfoIndent,
    );
    for (final key in [rowCurrentNameKey, rowNewNameKey, rowNameArrowKey]) {
      expect(
        find.descendant(of: line, matching: _first(key)),
        findsNothing,
        reason: '$key は線の外',
      );
      expect(
        tester.getRect(_first(key)).bottom,
        lessThanOrEqualTo(lineRect.top),
      );
    }
  });
}
