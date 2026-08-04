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

/// 行サブ情報のプレーンテキスト一覧。
List<String> _subInfoTexts(WidgetTester tester) => tester
    .widgetList<RichText>(find.byType(RichText))
    .map((w) => w.text.toPlainText())
    .where((t) => t.contains('作成日時: '))
    .toList();

void main() {
  testWidgets('場所を持つ行はサブ情報に場所が表示される(REQ-010)', (tester) async {
    await _pump(
      tester,
      FileListController(files: [_entry('a.jpg', location: '写真')]),
    );

    expect(_subInfoTexts(tester).single, startsWith('写真 · '));
    expect(find.textContaining('写真'), findsWidgets);
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

    final texts = _subInfoTexts(tester);
    expect(texts, hasLength(2));
    expect(texts[0], startsWith('写真 · '));
    expect(texts[1], startsWith('ダウンロード · '));
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

    final texts = _subInfoTexts(tester);
    expect(texts[0], startsWith('写真 · '));
    expect(texts[1], startsWith('書類 · '));
  });

  testWidgets('場所を持たない行(デモデータ等)は日時のみ表示する', (tester) async {
    await _pump(tester, FileListController(files: [_entry('a.jpg')]));

    expect(_subInfoTexts(tester).single, startsWith('作成日時: '));
  });
}
