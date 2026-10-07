// 008:T59 リネーム画面の行のメリハリ(2026-10-07 の開発者の決定 案A)。
//
// 「リネーム前後の名前と補足情報では重要度が異なるが、ほぼ文字の色でしか区別されて
// いない」→ 補足情報(場所・日時・大きさ)を薄い面の帯に入れて名前の2段と間を空け、
// 変更後の名前を一段大きくする。補足情報の中身と強調(`T50`・`T22`・`T48`)は変えない。
import 'package:batch_rename_master/core/rename_engine.dart';
import 'package:batch_rename_master/ui/file_list/file_list_controller.dart';
import 'package:batch_rename_master/ui/file_list/file_list_view.dart';
import 'package:batch_rename_master/ui/file_list/file_sort.dart';
import 'package:batch_rename_master/ui/theme/app_colors.dart';
import 'package:batch_rename_master/ui/theme/app_theme.dart';
import 'package:batch_rename_master/ui/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

FileEntry _entry(String name, {String? location, bool createdKnown = true}) =>
    FileEntry(
      name: name,
      createdAt: createdKnown ? DateTime(2026, 12, 31, 23, 59) : null,
      modifiedAt: DateTime(2026, 12, 31, 23, 59),
      size: 2516582,
      sourceHandle: '${location ?? '/storage/emulated/0/DCIM'}/$name',
      sourceLocation: location,
    );

/// [files] の一覧を描き、その間の layout error(overflow を含む)を返す。
Future<List<String>> _pump(
  WidgetTester tester,
  FileListController controller, {
  Size size = const Size(411, 800),
  double textScale = 1.0,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final errors = <String>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) => errors.add(details.exception.toString());
  await tester.pumpWidget(
    MaterialApp(
      theme: appDarkTheme(),
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(body: FileListView(controller: controller)),
      ),
    ),
  );
  FlutterError.onError = previous;
  return errors;
}

Finder _inBand(Finder target) =>
    find.descendant(of: find.byKey(rowSubInfoKey).first, matching: target);

void main() {
  testWidgets('補足情報(場所・日時・大きさ)だけが帯に入り、名前は入らない', (tester) async {
    // 場所が2つ混ざると場所も出る(`T22`)。
    await _pump(
      tester,
      FileListController(
        files: [
          _entry('a.jpg', location: '/storage/emulated/0/DCIM'),
          _entry('b.jpg', location: '/storage/emulated/0/Download'),
        ],
      ),
    );

    expect(find.byKey(rowSubInfoKey), findsNWidgets(2));
    for (final key in [
      rowLocationKey,
      rowCreatedAtKey,
      rowModifiedAtKey,
      rowSizeKey,
    ]) {
      expect(_inBand(find.byKey(key)), findsOneWidget, reason: '$key');
    }
    expect(_inBand(find.byKey(rowCurrentNameKey)), findsNothing);
    expect(_inBand(find.byKey(rowNewNameKey)), findsNothing);
  });

  testWidgets('帯は薄い面で、変更後の名前との間を空け、行幅いっぱいに取る', (tester) async {
    await _pump(
      tester,
      FileListController(
        files: [_entry('a.jpg')],
        rule: const RenameRule([LiteralToken('x')]),
      ),
    );

    final band = tester.widget<Container>(find.byKey(rowSubInfoKey));
    final decoration = band.decoration! as BoxDecoration;
    expect(decoration.color, AppColors.dark.rowSubInfoSurface);
    expect(decoration.borderRadius, BorderRadius.circular(4));

    final bandRect = tester.getRect(find.byKey(rowSubInfoKey));
    final newName = tester.getRect(find.byKey(rowNewNameKey));
    final currentName = tester.getRect(find.byKey(rowCurrentNameKey));
    // `margin` の外側の上端 = 変更後の名前の行の下端。帯の面はそこから [rowSubInfoGap] 下。
    expect(bandRect.top, greaterThanOrEqualTo(newName.bottom));
    final paintedTop = bandRect.top + rowSubInfoGap;
    expect(paintedTop - newName.bottom, greaterThanOrEqualTo(rowSubInfoGap));
    // 名前の列と同じ幅(中身の幅に縮めない)。
    expect(bandRect.left, currentName.left);
    expect(bandRect.width, greaterThanOrEqualTo(newName.width));
    expect(
      bandRect.width,
      greaterThan(tester.getRect(find.byKey(rowSizeKey)).right - bandRect.left),
      reason: '中身より広い = 行幅いっぱい',
    );
  });

  testWidgets('変更後の名前は一段大きく(14)、変更前の名前より大きい', (tester) async {
    final c = FileListController(
      files: [_entry('a.jpg')],
      rule: const RenameRule([LiteralToken('x')]),
    );
    await _pump(tester, c);

    final newName = tester.widget<Text>(find.byKey(rowNewNameKey).first);
    final current = tester.widget<Text>(find.byKey(rowCurrentNameKey).first);
    expect(rowNewNameFontSize, AppFontSize.title);
    expect(newName.style!.fontSize, rowNewNameFontSize);
    expect(newName.style!.fontSize!, greaterThan(current.style!.fontSize!));
  });

  testWidgets('「変更なし」も変更後の名前と同じ大きさ', (tester) async {
    await _pump(tester, FileListController(files: [_entry('a.jpg')]));

    final unchanged = tester.widget<Text>(find.byKey(rowUnchangedKey));
    expect(unchanged.style!.fontSize, rowNewNameFontSize);
  });

  testWidgets('作成日時が不明なら、帯の中で赤く強調する(`T50`・002 REQ-013 を変えない)', (tester) async {
    final c = FileListController(files: [_entry('a.jpg', createdKnown: false)]);
    await _pump(tester, c);
    c.setSortMode(FileSortMode.createdAt);
    await tester.pump();

    final created = tester.widget<Text>(_inBand(find.byKey(rowCreatedAtKey)));
    expect(created.data, '作成日時: 不明');
    expect(created.style!.color, AppColors.dark.danger);
    expect(_inBand(find.byIcon(Icons.warning_amber_rounded)), findsOneWidget);
  });

  for (final width in [320.0, 360.0, 411.0, 1200.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('幅 $width × 文字倍率 $scale ではみ出さない', (tester) async {
        final errors = await _pump(
          tester,
          FileListController(
            files: [
              _entry('とても長い名前の写真' * 3, location: '/storage/a/b/c'),
              _entry('b.jpg', location: '/storage/emulated/0/Download'),
            ],
          ),
          size: Size(width, 800),
          textScale: scale,
        );
        expect(errors, isEmpty);
      });
    }
  }
}
