// VER-002(T3): 行の場所サブ情報の表示(002 REQ-010)。
//
// **行が場所を出すのは、一覧に複数の場所が混ざっているときだけ**である
// (002 の決定。2026-09-18 に開発者が再承認。代表例 7b・7c / `008:T22`)。
// 1つだけなら読み込み帯が一覧全体として示すので、全行へ同じ名前は並べない。
// 混ざっているときは行ごとに出して、別フォルダの同名ファイルを見分けられる。
//
// REQ-010 の要求そのもの(**行データが表示用の場所を供給する**)は変わっていない —
// 変わったのは行UIが表示する条件である。
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
  testWidgets('代表例7c: 場所が2種類あると各行にその file の場所が出る(REQ-010)', (tester) async {
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
    expect(locations, hasLength(2));
    expect(locations[0], '写真');
    expect(locations[1], '書類');
    // 場所だけでなく日時も出ている(サブ情報として同格。REQ-010)。
    expect(_createdAts(tester).first, startsWith('作成日時: '));
  });

  testWidgets('代表例7b: 場所が1種類なら行には出ない(REQ-010)', (tester) async {
    // 帯が一覧全体として示すので、全行へ同じ名前を並べない。
    await _pump(
      tester,
      FileListController(
        files: [
          _entry('a.jpg', location: '写真'),
          _entry('b.pdf', location: '写真'),
        ],
      ),
    );

    expect(find.byKey(rowLocationKey), findsNothing);
    // **場所が消えても日時は残る**(消したのは場所だけである)。
    expect(_createdAts(tester), hasLength(2));
  });

  testWidgets('1件だけのときも行には出ない(場所は1種類である)', (tester) async {
    await _pump(
      tester,
      FileListController(files: [_entry('a.jpg', location: '写真')]),
    );

    expect(find.byKey(rowLocationKey), findsNothing);
    expect(_createdAts(tester).single, startsWith('作成日時: '));
  });

  testWidgets('別フォルダの同名ファイルは場所で見分けられる(REQ-010)', (tester) async {
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

  testWidgets('混在が解消されると場所は消える(両方向)', (tester) async {
    // **出る方向だけでは足りない。** 片方を外して1種類になったら消えること
    // (代表例7b)を同じ controller の遷移で固定する。
    final controller = FileListController(
      files: [
        _entry('a.jpg', location: '写真', handle: 'h:photos'),
        _entry('b.pdf', location: 'ダウンロード', handle: 'h:dl'),
      ],
    );
    await _pump(tester, controller);
    expect(_locations(tester), hasLength(2));

    controller.removeFile('h:dl');
    await tester.pump();

    expect(find.byKey(rowLocationKey), findsNothing);
  });

  testWidgets('場所を持たない行(デモデータ等)は日時のみ表示する', (tester) async {
    await _pump(tester, FileListController(files: [_entry('a.jpg')]));

    // 場所の行そのものが出ない。日時は出る。
    expect(find.byKey(rowLocationKey), findsNothing);
    expect(_createdAts(tester).single, startsWith('作成日時: '));
  });

  testWidgets('場所を持たない行が混ざっても、場所は1種類なので行には出さない', (tester) async {
    // 場所は1種類だが「不明な行」がある状態。**混在しているのは場所ではない**ので
    // 代表例7bのまま行には出さない — 出すと1行だけに名前が付いて、
    // 他の行が別の場所にあるかのように読める。
    await _pump(
      tester,
      FileListController(
        files: [
          _entry('a.jpg', location: '写真', handle: 'h:photos'),
          _entry('b.pdf', handle: 'h:demo'),
        ],
      ),
    );

    expect(find.byKey(rowLocationKey), findsNothing);
  });
}
