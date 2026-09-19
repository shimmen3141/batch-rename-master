// 008:T08 読み込み導線と場所の提示。
//
// 004 の読み込み契約(REQ-007/008/011/012)は変えていない。ここが固定するのは
// **帯が「いま何がどこから入っているか」を示す**ことと、**読み込み button の文言が
// 読み込み済みかどうかで変わる**ことである(2026-09-02 の要望11・12)。
//
// 場所の提示は行側と二重に出さない。**場所が1つなら行は出さない**(002 の決定改訂・
// `008:T22`)ので、帯が唯一の出所になる。**場所が2つ以上のときは帯が具体名を出さず**、
// どの行がどの folder かは行側が示す。
import 'package:batch_rename_master/core/rename_engine.dart';
import 'package:batch_rename_master/data/file_source/file_source.dart';
import 'package:batch_rename_master/data/permission/storage_permission.dart';
import 'package:batch_rename_master/ui/file_list/file_list_controller.dart';
import 'package:batch_rename_master/ui/file_list/removal_undo.dart';
import 'package:batch_rename_master/ui/file_source/file_kind.dart';
import 'package:batch_rename_master/ui/file_source/file_source_bar.dart';
import 'package:batch_rename_master/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:batch_rename_master/ui/file_list/file_list_view.dart';
import 'package:batch_rename_master/ui/file_list/removal_selection.dart';
import 'package:flutter_test/flutter_test.dart';

import '../spec_002_file_list/removal_mode.dart';

FileEntry _entry(String name, {required String handle, String? location}) =>
    FileEntry(
      name: name,
      createdAt: DateTime(2026, 1, 1),
      modifiedAt: DateTime(2026, 1, 2),
      size: 10,
      sourceHandle: handle,
      sourceLocation: location,
    );

Future<void> _pump(WidgetTester tester, FileListController controller) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: appDarkTheme(),
      home: Scaffold(
        body: FileSourceBar(
          source: FakeFileSource(),
          controller: controller,
          permission: const UnrestrictedStoragePermission(),
          kinds: FileKind.values,
        ),
      ),
    ),
  );
}

/// 帯と一覧を**製品と同じ組み合わせ**で描く(`008:T29`)。
///
/// `一覧を空にする` は一覧のケバブ(`すべてをリネーム対象から外す`)へ移り、
/// 選択モード中は帯の `別フォルダへ` が隠れるので、**両方が同じ
/// [RemovalSelection] を読む**形でないと確かめられない。
Future<void> _pumpWithList(
  WidgetTester tester,
  FileListController controller, {
  RemovalSelection? selection,
}) async {
  final shared = selection ?? RemovalSelection();
  await tester.pumpWidget(
    MaterialApp(
      theme: appDarkTheme(),
      home: Scaffold(
        body: Column(
          children: [
            FileSourceBar(
              source: FakeFileSource(),
              controller: controller,
              permission: const UnrestrictedStoragePermission(),
              kinds: FileKind.values,
              removalSelection: shared,
            ),
            Expanded(
              child: FileListView(
                controller: controller,
                removalSelection: shared,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// 帯が示している場所。**出ていなければ `null`** ("場所を出さない"と"空文字"を区別する)。
String? _location(WidgetTester tester) {
  final found = find.byKey(sourceLocationLabelKey);
  if (found.evaluate().isEmpty) return null;
  return tester.widget<Text>(found).data;
}

/// 読み込み button の文言。
String _pickLabel(WidgetTester tester) => tester
    .widget<Text>(
      find.descendant(
        of: find.byKey(const Key('pick-files-button')),
        matching: find.byType(Text),
      ),
    )
    .data!;

/// 画面幅を固定して帯を描く(配置の検査用)。
Future<void> _pumpAtWidth(
  WidgetTester tester,
  FileListController controller, {
  double width = 360,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 640));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await _pump(tester, controller);
}

void main() {
  group('帯の幅と配置(実機確認 2026-09-18 の指摘)', () {
    testWidgets('読み込み前でも帯は画面幅いっぱいに広がる', (tester) async {
      // 中身の幅しか持たないと、短い帯が画面の中央に浮く(実機で観測した)。
      await _pumpAtWidth(tester, FileListController(files: const []));

      expect(tester.getSize(find.byKey(sourceBarKey)).width, 360);
    });

    testWidgets('読み込み後も帯は画面幅いっぱいに広がる', (tester) async {
      await _pumpAtWidth(
        tester,
        FileListController(
          files: [_entry('a.jpg', handle: 'h:a', location: 'Camera')],
        ),
      );

      expect(tester.getSize(find.byKey(sourceBarKey)).width, 360);
    });

    testWidgets('狭幅・大きい文字でも帯がはみ出さない', (tester) async {
      // **独立review attempt 3 の N-1。** button 群を `Row` へ直に並べていたとき、
      // 320dp・倍率1.3 で 17px はみ出した。`008:T16` / `T18` が床にしてきた格子で測る。
      // はみ出しは画面に赤帯として出るだけで、**test は黙って通ってしまう**ので
      // `FlutterError.onError` を捕まえる。
      for (final width in [320.0, 360.0, 411.0]) {
        for (final scale in [1.0, 1.3, 2.0]) {
          for (final location in [null, 'DCIM', '内部ストレージ/DCIM/t07-fixtures']) {
            final errors = <String>[];
            final previous = FlutterError.onError;
            FlutterError.onError = (details) =>
                errors.add(details.exception.toString());
            await tester.binding.setSurfaceSize(Size(width, 640));
            addTearDown(() => tester.binding.setSurfaceSize(null));
            await tester.pumpWidget(
              MaterialApp(
                theme: appDarkTheme(),
                home: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: Scaffold(
                    body: FileSourceBar(
                      source: FakeFileSource(),
                      controller: FileListController(
                        files: location == null
                            ? const []
                            : [
                                _entry(
                                  'a.jpg',
                                  handle: 'h:a',
                                  location: location,
                                ),
                              ],
                      ),
                      permission: const UnrestrictedStoragePermission(),
                      kinds: FileKind.values,
                    ),
                  ),
                ),
              ),
            );
            FlutterError.onError = previous;
            expect(
              errors.where((e) => e.contains('overflow')),
              isEmpty,
              reason: '幅 $width / 文字 $scale / 場所 $location で帯がはみ出している',
            );
          }
        }
      }
    });

    testWidgets('読み込み button の位置は folder 名の長さで動かない', (tester) async {
      // **これが実機の指摘の本体である。** 名前の長さで button が動くと、
      // 押す場所を毎回探すことになる。長い名前は省略されて button を押し出さない。
      await _pumpAtWidth(
        tester,
        FileListController(
          files: [_entry('a.jpg', handle: 'h:a', location: 'DCIM')],
        ),
      );
      final shortName = tester.getRect(
        find.byKey(const Key('pick-files-button')),
      );

      await _pumpAtWidth(
        tester,
        FileListController(
          files: [
            _entry(
              'a.jpg',
              handle: 'h:a',
              location:
                  'Internal shared storage/DCIM/t07-fixtures-very-long-name',
            ),
          ],
        ),
      );
      final longName = tester.getRect(
        find.byKey(const Key('pick-files-button')),
      );

      expect(longName, shortName);
      // 省略されていること自体も固定する(省略せずに押し出す実装を排除する)。
      // **ここは1 segmentだけが残る幅**なので、`008:T23` 後も末尾からの省略になる
      // (`t07-fixtures-very-long-name` が入りきらない)。先頭からの省略は下の
      // 「狭幅でも末尾の folder 名が残る」で固定している。
      expect(
        tester
            .renderObject<RenderParagraph>(find.byKey(sourceLocationLabelKey))
            .didExceedMaxLines,
        isTrue,
      );
    });

    testWidgets('狭幅でも、場所の末尾の folder 名が残る(008:T23)', (tester) async {
      // **2026-09-18 の実機確認の指摘。** 末尾から削ると `Internal shared st…` と
      // なり、**どのfolderから読み込んでも同じ表示**になる(004 の独立review
      // attempt 2 の P2-1 が保存場所名だけの表示を否定したのと同じ理由)。
      const path = 'Internal shared storage/DCIM/t07-fixtures';
      final errors = <String>[];
      final previous = FlutterError.onError;
      FlutterError.onError = (details) =>
          errors.add(details.exception.toString());
      await _pumpAtWidth(
        tester,
        FileListController(
          files: [_entry('a.jpg', handle: 'h:a', location: path)],
        ),
      );
      FlutterError.onError = previous;

      final shown = _location(tester)!;
      expect(shown, isNot(path), reason: 'この幅では縮むはずである');
      expect(shown, endsWith('t07-fixtures'), reason: '末尾が消えている: $shown');
      expect(
        shown.startsWith('Internal'),
        isFalse,
        reason: '共通の接頭辞だけが残っている: $shown',
      );
      // 縮めた結果がはみ出していないことも見る(省略せずに押し出す実装を排除する)。
      expect(errors.where((e) => e.contains('overflow')), isEmpty);
    });

    testWidgets('幅が足りるときは場所を丸ごと出す(008:T23)', (tester) async {
      // 常に先頭を落とす実装を排除する。`…/` は**入らないときだけ**出る。
      const path = 'Internal shared storage/DCIM/t07-fixtures';
      await _pumpAtWidth(
        tester,
        FileListController(
          files: [_entry('a.jpg', handle: 'h:a', location: path)],
        ),
        width: 1200,
      );

      expect(_location(tester), path);
    });
  });

  testWidgets('読み込み前は「未選択」と「ファイルを選ぶ」(要望11)', (tester) async {
    await _pump(tester, FileListController(files: const []));

    expect(_location(tester), '未選択');
    expect(_pickLabel(tester), 'ファイルを選ぶ');
    // **逆向きも固定する。** 読み込み前に「別フォルダへ」が出てはならない。
    expect(find.text('別フォルダへ'), findsNothing);
  });

  testWidgets('場所が1つなら、その folder 名と「別フォルダへ」(要望11)', (tester) async {
    await _pump(
      tester,
      FileListController(
        files: [
          _entry('a.jpg', handle: 'h:a', location: 'Camera'),
          _entry('b.jpg', handle: 'h:b', location: 'Camera'),
        ],
      ),
    );

    expect(_location(tester), 'Camera');
    expect(_pickLabel(tester), '別フォルダへ');
    // 読み込み後に「ファイルを選ぶ」へ戻らない。
    expect(find.text('ファイルを選ぶ'), findsNothing);
  });

  testWidgets('場所が2つ以上なら、具体名を出さず複数であることだけを示す(要望12)', (tester) async {
    await _pump(
      tester,
      FileListController(
        files: [
          _entry('a.jpg', handle: 'h:a', location: '写真'),
          _entry('b.jpg', handle: 'h:b', location: 'ダウンロード'),
        ],
      ),
    );

    expect(_location(tester), '複数のフォルダ');
    // **どちらの folder 名も帯には出ない**(要望12: 具体的なフォルダ名を表示しない)。
    expect(find.text('写真'), findsNothing);
    expect(find.text('ダウンロード'), findsNothing);
    expect(_pickLabel(tester), '別フォルダへ');
  });

  testWidgets('場所を持たない行だけのときは、嘘の場所も「未選択」も出さない', (tester) async {
    // デモデータのように `sourceLocation` が無い経路。ファイルは入っているので
    // 「未選択」は誤りであり、folder 名も無いので出せるものが無い。
    await _pump(
      tester,
      FileListController(files: [_entry('a.jpg', handle: 'h:a')]),
    );

    expect(_location(tester), isNull);
    expect(find.text('未選択'), findsNothing);
    // button の文言は読み込み済みとして扱う(一覧は空でない)。
    expect(_pickLabel(tester), '別フォルダへ');
  });

  testWidgets('場所を持たない行が混ざっても、名前は1つなので「複数のフォルダ」にしない', (tester) async {
    // `null` を場所の一種として数えると、名前が1つしか無いのに「複数のフォルダ」に
    // なる(独立review attempt 1 の P3-4。対照 `M275`)。行側の同種のtestと対になる。
    await _pump(
      tester,
      FileListController(
        files: [
          _entry('a.jpg', handle: 'h:a', location: '写真'),
          _entry('b.pdf', handle: 'h:demo'),
        ],
      ),
    );

    expect(_location(tester), '写真');
    expect(find.text('複数のフォルダ'), findsNothing);
  });

  testWidgets('一覧を空にすると「未選択」と「ファイルを選ぶ」へ戻る(両方向)', (tester) async {
    final controller = FileListController(
      files: [_entry('a.jpg', handle: 'h:a', location: 'Camera')],
    );
    await _pumpWithList(tester, controller);
    expect(_location(tester), 'Camera');
    // **帯にはもう置かない**(`008:T29` で一覧のケバブへ移した)。
    // 「選択を全部外す」と読める名前に戻していないことも見る(`008:T03` の決定)。
    expect(find.byKey(const Key('clear-files-button')), findsNothing);
    expect(find.text('すべて外す'), findsNothing);

    await clearAllFiles(tester);

    expect(_location(tester), '未選択');
    expect(_pickLabel(tester), 'ファイルを選ぶ');
  });

  testWidgets('選択モード中は「別フォルダへ」を出さない(008:T29)', (tester) async {
    // 外す作業の最中に読み込み直しの導線が並んでいると、一覧が丸ごと置き換わる
    // 操作(004 REQ-004)と取り違えやすい。**帯そのもの(場所)は隠さない。**
    final controller = FileListController(
      files: [_entry('a.jpg', handle: 'h:a', location: 'Camera')],
    );
    await _pumpWithList(tester, controller);
    expect(find.byKey(const Key('pick-files-button')), findsOneWidget);

    await enterRemovalMode(tester);

    expect(find.byKey(const Key('pick-files-button')), findsNothing);
    expect(_location(tester), 'Camera');

    await tester.tap(find.byKey(removalModeExitKey));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pick-files-button')), findsOneWidget);
  });

  testWidgets('一覧を空にする操作も取り消せる(002 REQ-017・代表例6d)', (tester) async {
    final controller = FileListController(
      files: [
        _entry('a.jpg', handle: 'h:a', location: 'Camera'),
        _entry('b.jpg', handle: 'h:b', location: 'Camera'),
      ],
    );
    await _pumpWithList(tester, controller);

    await clearAllFiles(tester);
    expect(controller.items, isEmpty);

    expect(find.byKey(removalUndoKey), findsOneWidget);
    await tester.tap(find.text('元に戻す'));
    await tester.pumpAndSettle();

    // 操作前の並びのまま戻る。
    expect(controller.items.map((f) => f.name), ['a.jpg', 'b.jpg']);
    expect(_location(tester), 'Camera');
  });

  testWidgets('選択を全部外してもファイルは入っているので「別フォルダへ」のまま', (tester) async {
    // 要望11の「ファイルが選択されていないとき」は**一覧が空のとき**と読んでいる。
    // 行の checkbox を全部外しただけなら、読み込み先を選び直す導線の意味は変わらない。
    final controller = FileListController(
      files: [_entry('a.jpg', handle: 'h:a', location: 'Camera')],
    );
    await _pump(tester, controller);

    controller.clearAll();
    await tester.pump();

    expect(controller.selectedCount, 0);
    expect(_location(tester), 'Camera');
    expect(_pickLabel(tester), '別フォルダへ');
  });
}
