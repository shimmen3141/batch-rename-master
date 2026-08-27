// VER-002(T3): 行の場所サブ情報の表示(002 REQ-010)。
// 場所は同名・非同名に関わらず常時表示し、別フォルダの同名ファイルを見分けられる。
import 'package:batch_rename_master/core/rename_engine.dart';
import 'package:batch_rename_master/ui/file_list/file_list_controller.dart';
import 'package:batch_rename_master/ui/file_list/file_list_view.dart';
import 'package:batch_rename_master/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

FileEntry _entry(String name, {String? location, String? handle}) => FileEntry(
  name: name,
  createdAt: DateTime(2023, 5, 6, 7, 8),
  modifiedAt: DateTime(2026, 8, 4, 16),
  size: 0,
  sourceHandle: handle,
  sourceLocation: location,
);

Future<void> _pump(WidgetTester tester, FileListController c) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: appDarkTheme(),
      home: Scaffold(body: FileListView(controller: c)),
    ),
  );
}

/// 各行のサブ情報が示す場所(表示順)。
///
/// 008:T07 で場所と日時を別の行へ分けた。場所が**その行に出ていること**が
/// REQ-010 の要求で、日時と同じ文字列に連結されていることではない。
List<String> _locations(WidgetTester tester) => tester
    .widgetList<Text>(find.byKey(rowLocationKey))
    .map((w) => w.data!)
    .toList();

/// 各行のサブ情報が示す作成日時(表示順)。
List<String> _createdAts(WidgetTester tester) => tester
    .widgetList<Text>(find.byKey(rowCreatedAtKey))
    .map((w) => w.data!)
    .toList();

void main() {
  testWidgets('場所を持つ行はサブ情報に場所が表示される(REQ-010)', (tester) async {
    await _pump(
      tester,
      FileListController(files: [_entry('a.jpg', location: '写真')]),
    );

    expect(_locations(tester).single, '写真');
    // 場所だけでなく日時も同じ行に出ている(サブ情報として同格。REQ-010)。
    expect(_createdAts(tester).single, startsWith('作成日時: '));
  });

  testWidgets('別フォルダの同名ファイルを場所で見分けられる(REQ-010)', (tester) async {
    await _pump(
      tester,
      FileListController(
        files: [
          _entry('IMG_001.jpg', location: '写真', handle: 'h:photos'),
          _entry('IMG_001.jpg', location: 'ダウンロード', handle: 'h:dl'),
        ],
      ),
    );

    final locations = _locations(tester);
    expect(locations, hasLength(2));
    expect(locations[0], '写真');
    expect(locations[1], 'ダウンロード');
  });

  testWidgets('同名でなくても場所は常時表示される(REQ-010)', (tester) async {
    await _pump(
      tester,
      FileListController(
        files: [
          _entry('a.jpg', location: '写真'),
          _entry('b.pdf', location: '書類'),
        ],
      ),
    );

    final locations = _locations(tester);
    expect(locations[0], '写真');
    expect(locations[1], '書類');
  });

  testWidgets('場所を持たない行(デモデータ等)は日時のみ表示する', (tester) async {
    await _pump(tester, FileListController(files: [_entry('a.jpg')]));

    // 場所の行そのものが出ない。日時は出る。
    expect(find.byKey(rowLocationKey), findsNothing);
    expect(_createdAts(tester).single, startsWith('作成日時: '));
  });
}
