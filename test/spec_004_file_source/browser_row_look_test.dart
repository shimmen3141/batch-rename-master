// 008:T58 app 内 browser の行(2026-10-07 の開発者の要望)。
//
// - preview 枠は 56dp、行は folder もファイルも 72dp。
// - folder は灰色で**塗った**四角、preview を出せないファイルは同じ色の**線**の四角。
// - 名前は folder もファイルも同じ大きさ。2行目に更新日時(ファイルは大きさも)。
//   日時を読めなかった entry は2行目を出さず、行は残す(004 REQ-017)。
//
// 並び順は port(`AndroidStorageBrowser`)が決める。`android_storage_browser_test.dart`
// が見る。
import 'dart:typed_data';

import 'package:batch_rename_master/data/file_source/storage_browser.dart';
import 'package:batch_rename_master/data/preview/file_preview.dart';
import 'package:batch_rename_master/ui/file_list/row_preview_view.dart';
import 'package:batch_rename_master/ui/file_source/storage_browser_view.dart';
import 'package:batch_rename_master/ui/theme/app_colors.dart';
import 'package:batch_rename_master/ui/theme/app_theme.dart';
import 'package:batch_rename_master/ui/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _root = '/storage/emulated/0';

class _FakeBrowser implements StorageBrowserPort {
  _FakeBrowser(
    this.entries, {
    this.locationList = const [StorageLocation(name: '内部ストレージ', root: _root)],
  });

  final List<BrowserEntry> entries;
  final List<StorageLocation> locationList;

  @override
  Future<StorageLocations> locations() async => StorageLocations(locationList);

  @override
  Future<DirectoryListing> list(String folder) async =>
      DirectoryListed(folder == _root ? entries : const []);
}

/// 8x8 の PNG。**test の中で作らない**(fake async で `toImage` が止まる)。
final _png = Uint8List.fromList([
  137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, //
  0, 0, 0, 8, 0, 0, 0, 8, 8, 2, 0, 0, 0, 75, 109, 41, //
  220, 0, 0, 0, 17, 73, 68, 65, 84, 120, 218, 99, 48, 78, 59, 131, //
  21, 49, 12, 45, 9, 0, 185, 134, 89, 65, 110, 38, 132, 252, 0, 0, //
  0, 0, 73, 69, 78, 68, 174, 66, 96, 130,
]);

final _entries = [
  BrowserEntry(
    name: 'DCIM',
    path: '$_root/DCIM',
    isDirectory: true,
    modifiedAt: DateTime(2026, 9, 30, 8, 5),
  ),
  BrowserEntry(
    name: 'photo.jpg',
    path: '$_root/photo.jpg',
    isDirectory: false,
    modifiedAt: DateTime(2026, 10, 1, 9, 5),
    size: 2516582,
  ),
  BrowserEntry(
    name: 'memo.pdf',
    path: '$_root/memo.pdf',
    isDirectory: false,
    modifiedAt: DateTime(2026, 5, 1, 21, 30),
    size: 2048,
  ),
  const BrowserEntry(
    name: 'broken-link',
    path: '$_root/broken-link',
    isDirectory: false,
  ),
];

Future<void> _open(
  WidgetTester tester, {
  List<BrowserEntry>? entries,
  List<StorageLocation>? locations,
  Size size = const Size(411, 900),
  double textScale = 1.0,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: appDarkTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: StorageBrowserView(
        browser: locations == null
            ? _FakeBrowser(entries ?? _entries)
            : _FakeBrowser(entries ?? _entries, locationList: locations),
        preview: FakeFilePreview(
          byHandle: {'$_root/photo.jpg': PreviewReady(_png)},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _row(String name, {bool folder = false}) =>
    find.byKey(Key(folder ? 'browser-folder-$name' : 'browser-file-$name'));

Finder _in(Finder row, Finder target) =>
    find.descendant(of: row, matching: target);

BoxDecoration _decorationOf(WidgetTester tester, Finder finder) {
  final widget = tester.widget(finder);
  return switch (widget) {
    Container(:final decoration) => decoration! as BoxDecoration,
    DecoratedBox(:final decoration) => decoration as BoxDecoration,
    _ => throw StateError('装飾を持たない: $widget'),
  };
}

void main() {
  testWidgets('folder もファイルも行は 72dp、preview 枠は 56dp', (tester) async {
    await _open(tester);

    for (final row in [
      _row('DCIM', folder: true),
      _row('photo.jpg'),
      _row('memo.pdf'),
      _row('broken-link'),
    ]) {
      expect(tester.getSize(row).height, browserRowHeight, reason: '$row');
    }
    expect(
      tester.getSize(
        _in(_row('DCIM', folder: true), find.byKey(browserFolderTileKey)),
      ),
      const Size.square(browserPreviewSize),
    );
    for (final name in ['photo.jpg', 'memo.pdf', 'broken-link']) {
      expect(
        tester.getSize(_in(_row(name), find.byKey(rowPreviewKey))),
        const Size.square(browserPreviewSize),
        reason: name,
      );
    }
    expect(browserPreviewSize, 56);
    expect(browserRowHeight, 72);
  });

  testWidgets('folder は灰色で塗った四角、preview を出せないファイルは同じ色の線の四角', (tester) async {
    await _open(tester);
    final colors = AppColors.dark;

    final folder = _decorationOf(
      tester,
      _in(_row('DCIM', folder: true), find.byKey(browserFolderTileKey)),
    );
    expect(folder.color, colors.previewTile, reason: '塗る');
    expect(folder.border, isNull, reason: '線は無い');
    final folderIcon = tester.widget<Icon>(
      _in(_row('DCIM', folder: true), find.byIcon(Icons.folder)),
    );
    expect(folderIcon.color, colors.textSecondary, reason: 'アイコンの色は変えない');
    expect(
      folderIcon.size,
      browserPreviewSize * 0.45,
      reason: '四角に対して大きすぎない(2026-10-07 のエミュレータ確認)',
    );

    final outline = _decorationOf(
      tester,
      _in(_row('memo.pdf'), find.byKey(rowPreviewOutlineKey)),
    );
    expect(outline.color, isNull, reason: '塗らない');
    expect(outline.border, Border.all(color: colors.previewTile));

    // 絵が出ている行には線の枠が無い。
    expect(
      _in(_row('photo.jpg'), find.byKey(rowPreviewOutlineKey)),
      findsNothing,
    );
    expect(_in(_row('photo.jpg'), find.byType(Image)), findsOneWidget);
  });

  testWidgets('2行目: ファイルは更新日時と大きさ、folder は更新日時だけ、読めなければ出さない', (tester) async {
    await _open(tester);

    String detailOf(Finder row) =>
        tester.widget<Text>(_in(row, find.byKey(browserRowDetailKey))).data!;

    expect(detailOf(_row('photo.jpg')), '2026/10/1 09:05 · 2.4 MB');
    expect(detailOf(_row('memo.pdf')), '2026/5/1 21:30 · 2 KB');
    expect(detailOf(_row('DCIM', folder: true)), '2026/9/30 08:05');
    expect(
      _in(_row('broken-link'), find.byKey(browserRowDetailKey)),
      findsNothing,
    );
    expect(_row('broken-link'), findsOneWidget, reason: '行は残す(REQ-017)');

    final detail = tester.widget<Text>(
      _in(_row('photo.jpg'), find.byKey(browserRowDetailKey)),
    );
    expect(detail.style!.color, AppColors.dark.textMuted, reason: '薄い灰色');
  });

  testWidgets('名前は folder もファイルも同じ大きさで、以前より大きい', (tester) async {
    await _open(tester);

    double nameSizeOf(Finder row, String name) =>
        tester.widget<Text>(_in(row, find.text(name))).style!.fontSize!;

    expect(
      nameSizeOf(_row('DCIM', folder: true), 'DCIM'),
      AppFontSize.titleLarge,
    );
    expect(nameSizeOf(_row('photo.jpg'), 'photo.jpg'), AppFontSize.titleLarge);
  });

  testWidgets('並びは port が返した順のまま(画面で並べ替えない)', (tester) async {
    await _open(tester);

    final tops = [
      tester.getTopLeft(_row('DCIM', folder: true)).dy,
      tester.getTopLeft(_row('photo.jpg')).dy,
      tester.getTopLeft(_row('memo.pdf')).dy,
      tester.getTopLeft(_row('broken-link')).dy,
    ];
    expect(tops, [...tops]..sort());
  });

  testWidgets('保存場所の一覧も同じ大きさ: 行 72・シアンの線の四角(塗らない)・名前 15', (tester) async {
    await _open(
      tester,
      locations: const [
        StorageLocation(name: '内部ストレージ', root: _root),
        StorageLocation(name: 'SD カード', root: '/storage/1234-ABCD'),
      ],
    );
    final colors = AppColors.dark;

    for (final name in ['内部ストレージ', 'SD カード']) {
      final row = find.byKey(Key('browser-location-$name'));
      expect(tester.getSize(row).height, browserRowHeight, reason: name);
      final tile = _in(row, find.byKey(browserLocationTileKey));
      expect(tester.getSize(tile), const Size.square(browserPreviewSize));
      final decoration = _decorationOf(tester, tile);
      expect(decoration.color, isNull, reason: '塗らない');
      expect(decoration.border, Border.all(color: colors.primary));
      final icon = tester.widget<Icon>(_in(row, find.byIcon(Icons.sd_storage)));
      expect(icon.color, colors.primary);
      expect(icon.size, browserPreviewSize * 0.45);
      expect(
        tester.widget<Text>(_in(row, find.text(name))).style!.fontSize,
        AppFontSize.titleLarge,
      );
    }
  });

  for (final width in [320.0, 360.0, 411.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('幅 $width × 文字倍率 $scale で長い名前でもはみ出さない', (tester) async {
        final long = 'とても長い名前のフォルダ' * 4;
        await _open(
          tester,
          size: Size(width, 800),
          textScale: scale,
          entries: [
            BrowserEntry(
              name: long,
              path: '$_root/$long',
              isDirectory: true,
              modifiedAt: DateTime(2026, 12, 31, 23, 59),
            ),
            BrowserEntry(
              name: '$long.jpg',
              path: '$_root/$long.jpg',
              isDirectory: false,
              modifiedAt: DateTime(2026, 12, 31, 23, 59),
              size: 1288490189,
            ),
          ],
        );

        expect(tester.takeException(), isNull);
        expect(find.byKey(browserRowDetailKey), findsNWidgets(2));
      });
    }
  }
}
