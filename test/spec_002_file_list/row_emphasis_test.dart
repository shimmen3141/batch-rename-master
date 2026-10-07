// 008:T59 リネーム画面の行のメリハリ(2026-10-07 の開発者の決定 案A)。
//
// 変更後の名前を一段大きくする。案Aの「補足情報を薄い面の帯に入れる」は同日の
// エミュレータ確認で「あまりわかりやすくならなかった」ので消した(帯が無いことを見る)。
// 補足情報の中身と強調(`T50`・`T22`・`T48`)は変えない。
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

/// [target] を包む、色で塗った面(`DecoratedBox` の `BoxDecoration.color` と
/// `ColoredBox` の両方。`Container(color:)` は後者になる)。画面の背景と透明な面は数えない。
/// 選ばれていない行には無い。
Iterable<Color> _paintedAncestorsOf(WidgetTester tester, Finder target) => [
  ...tester
      .widgetList<DecoratedBox>(
        find.ancestor(of: target, matching: find.byType(DecoratedBox)),
      )
      .map((box) => box.decoration)
      .whereType<BoxDecoration>()
      .map((d) => d.color)
      .whereType<Color>(),
  ...tester
      .widgetList<ColoredBox>(
        find.ancestor(of: target, matching: find.byType(ColoredBox)),
      )
      .map((box) => box.color),
].where((c) => c.a > 0 && c != AppColors.dark.background);

void main() {
  testWidgets('補足情報は帯に入れない(2026-10-07 のエミュレータ確認で消した)', (tester) async {
    await _pump(
      tester,
      FileListController(
        files: [
          _entry('a.jpg', location: '/storage/emulated/0/DCIM'),
          _entry('b.jpg', location: '/storage/emulated/0/Download'),
        ],
      ),
    );

    // 並び順もルールも日時を使っていないので、日時は見出しなしの更新日時だけ
    // (002 REQ-013。`008:T61`)。
    for (final key in [rowLocationKey, rowModifiedAtKey, rowSizeKey]) {
      expect(
        _paintedAncestorsOf(tester, find.byKey(key).first),
        isEmpty,
        reason: '$key を塗った面で包まない',
      );
    }
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

  testWidgets('作成日時が不明なら赤く強調する(`T50`・002 REQ-013 を変えない)', (tester) async {
    final c = FileListController(files: [_entry('a.jpg', createdKnown: false)]);
    await _pump(tester, c);
    c.setSortMode(FileSortMode.createdAt);
    await tester.pump();

    final created = tester.widget<Text>(find.byKey(rowCreatedAtKey));
    expect(created.data, '作成: 不明');
    expect(created.style!.color, AppColors.dark.danger);
    // 一覧上部の警告帯にも同じアイコンがあるので、作成日時と同じ `Row` の中を見る。
    expect(
      find.descendant(
        of: find
            .ancestor(
              of: find.byKey(rowCreatedAtKey),
              matching: find.byType(Row),
            )
            .first,
        matching: find.byIcon(Icons.warning_amber_rounded),
      ),
      findsOneWidget,
    );
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
