// VER-002(T6): 作成日時ソート時の警告表示と、行の日時サブ情報(FEAT-002 / Light)。
// 対象: REQ-011(不明件数と代替した旨の警告表示), REQ-013(行が両日時と不明かを提示)。
import 'package:batch_rename_master/core/rename_engine.dart';
import 'package:batch_rename_master/ui/file_list/file_list_controller.dart';
import 'package:batch_rename_master/ui/file_list/file_list_view.dart';
import 'package:batch_rename_master/ui/file_list/file_sort.dart';
import 'package:batch_rename_master/ui/file_list/rename_warning_view.dart';
import 'package:batch_rename_master/ui/theme/app_colors.dart';
import 'package:batch_rename_master/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

FileEntry _known(String name) => FileEntry(
  name: name,
  createdAt: DateTime(2023, 5, 6, 7, 8),
  modifiedAt: DateTime(2026, 8, 4, 16),
  size: 0,
);

FileEntry _unknown(String name) =>
    FileEntry(name: name, modifiedAt: DateTime(2026, 8, 4, 16), size: 0);

final _warningBanner = find.byKey(const Key('created-at-fallback-warning'));

Future<void> _pump(WidgetTester tester, FileListController c) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: appDarkTheme(),
      home: Scaffold(body: FileListView(controller: c)),
    ),
  );
}

void main() {
  group('REQ-011: 作成日時ソート時の警告表示', () {
    testWidgets('不明があるときだけ、件数と代替した旨を表示する', (tester) async {
      final c = FileListController(files: [_known('a.txt'), _unknown('b.png')]);
      await _pump(tester, c);

      // 既定(名前順)では出ない。
      expect(_warningBanner, findsNothing);

      c.setSortMode(FileSortMode.createdAt);
      await tester.pump();

      expect(_warningBanner, findsOneWidget);
      expect(find.textContaining('1 件'), findsOneWidget);
      expect(find.textContaining('更新日時で代替'), findsOneWidget);
    });

    testWidgets('全件判明していれば表示しない', (tester) async {
      final c = FileListController(files: [_known('a.txt'), _known('b.txt')]);
      await _pump(tester, c);

      c.setSortMode(FileSortMode.createdAt);
      await tester.pump();

      expect(_warningBanner, findsNothing);
    });

    testWidgets('更新日時順へ切り替えると消える', (tester) async {
      final c = FileListController(files: [_unknown('b.png')]);
      await _pump(tester, c);

      c.setSortMode(FileSortMode.createdAt);
      await tester.pump();
      expect(_warningBanner, findsOneWidget);

      c.setSortMode(FileSortMode.modifiedAt);
      await tester.pump();
      expect(_warningBanner, findsNothing);
    });

    testWidgets('メニューの「更新日時 古い順」で modifiedAt ソートへ切り替わる', (tester) async {
      final c = FileListController(files: [_known('a.txt')]);
      await _pump(tester, c);

      await tester.tap(find.byKey(sortControlKey));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          sortOptionKeyOf(FileSortMode.modifiedAt, SortDirection.ascending),
        ),
      );
      await tester.pumpAndSettle();

      expect(c.sortMode, FileSortMode.modifiedAt);
    });

    testWidgets('作成日時の降順でも出し、手で並べると消える(例26)', (tester) async {
      final c = FileListController(
        files: [_known('a.txt'), _unknown('b.png'), _known('c.txt')],
      );
      await _pump(tester, c);

      c.setSortMode(
        FileSortMode.createdAt,
        direction: SortDirection.descending,
      );
      await tester.pump();
      expect(_warningBanner, findsOneWidget);

      c.reorder(0, 1);
      await tester.pump();
      expect(_warningBanner, findsNothing);
    });

    testWidgets('「並び順:」を付け、「リネーム:」の行と印の位置・印と文の間を揃える(2026-09-30 の開発者の指定)', (
      tester,
    ) async {
      final c = FileListController(
        // 拡張子を揃える。全件が同じ名前になるので「リネーム: N 件の問題」も出る。
        files: [_known('a.txt'), _unknown('b.txt')],
        rule: const RenameRule([LiteralToken('same')]),
      );
      c.setSortMode(FileSortMode.createdAt);
      await _pump(tester, c);

      expect(find.text('並び順: 作成日時不明の 1 件は更新日時で代替しています'), findsOneWidget);
      final fallbackIcon = tester.getRect(
        find.descendant(
          of: _warningBanner,
          matching: find.byIcon(Icons.warning_amber_rounded),
        ),
      );
      final countIcon = tester.getRect(
        find.descendant(
          of: find.byKey(warningCountKey),
          matching: find.byIcon(Icons.warning_amber_rounded),
        ),
      );
      expect(countIcon.left, fallbackIcon.left);
      expect(countIcon.size, fallbackIcon.size);
      final fallbackText = tester.getRect(find.textContaining('並び順: 作成日時不明'));
      final countText = tester.getRect(find.textContaining('リネーム: '));
      expect(
        countText.left - countIcon.right,
        fallbackText.left - fallbackIcon.right,
      );
    });

    testWidgets('警告は上の帯の下のメッセージのバナーに出る(2026-09-30 の開発者の指定)', (tester) async {
      final c = FileListController(files: [_known('a.txt'), _unknown('b.png')]);
      c.setSortMode(FileSortMode.createdAt);
      await _pump(tester, c);

      final banner = find.byKey(messageBannerKey);
      expect(
        find.descendant(of: banner, matching: _warningBanner),
        findsOneWidget,
      );
      // 上の帯(並び順とケバブ)より下。
      expect(
        tester.getRect(_warningBanner).top,
        greaterThanOrEqualTo(tester.getRect(find.byKey(sortControlKey)).bottom),
      );
    });

    testWidgets('メッセージが増減すると、バナーの高さが滑らかに変わる', (tester) async {
      final c = FileListController(files: [_known('a.txt'), _unknown('b.png')]);
      await _pump(tester, c);
      final banner = find.byKey(messageBannerKey);
      final before = tester.getSize(banner).height;

      c.setSortMode(FileSortMode.createdAt);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      final middle = tester.getSize(banner).height;
      await tester.pumpAndSettle();
      final after = tester.getSize(banner).height;

      // 途中の高さを経る(一度に跳ばない)。
      expect(after, greaterThan(before));
      expect(middle, greaterThan(before));
      expect(middle, lessThan(after));
    });

    testWidgets('狭幅・文字 2.0 でも警告の全文が切れない', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final c = FileListController(files: [_known('a.txt'), _unknown('b.png')]);
      c.setSortMode(
        FileSortMode.createdAt,
        direction: SortDirection.descending,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: appDarkTheme(),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(2),
            ),
            child: Scaffold(body: FileListView(controller: c)),
          ),
        ),
      );
      expect(tester.takeException(), isNull);

      final warning = tester.getRect(_warningBanner);
      expect(warning.right, lessThanOrEqualTo(320));
      // 件数と代替した旨を失わない。
      expect(find.textContaining('1 件'), findsOneWidget);
      expect(find.textContaining('更新日時で代替'), findsOneWidget);
    });
  });

  // 008:T60 で REQ-013 を更新した: **行が出す日時は、並び順またはルールが使っている
  // 日時だけ**(2026-10-07 の開発者の承認)。見出しは「作成:」「更新:」、表示上同じなら
  // 「作成・更新:」、どちらも使っていなければ見出しなしの更新日時(`008:T61`)。
  group('REQ-013: 行の日時サブ情報', () {
    String? textOf(WidgetTester tester, Key key) {
      final finder = find.byKey(key);
      if (finder.evaluate().isEmpty) return null;
      return tester.widget<Text>(finder).data;
    }

    const createdRule = RenameRule([
      DateTimeToken(source: DateTimeSource.created, format: 'YYYY'),
    ]);
    const modifiedRule = RenameRule([
      DateTimeToken(source: DateTimeSource.modified, format: 'YYYY'),
    ]);

    testWidgets('どちらも使っていなければ、更新日時だけを見出しなしで出す', (tester) async {
      await _pump(tester, FileListController(files: [_known('a.txt')]));

      expect(textOf(tester, rowModifiedAtKey), '2026/8/4 16:00');
      expect(textOf(tester, rowCreatedAtKey), isNull);
    });

    testWidgets('例14: 名前順・ルールが作成日時を使わないなら、不明でも作成日時を出さない', (tester) async {
      final c = FileListController(files: [_unknown('b.png')]);
      await _pump(tester, c);

      expect(textOf(tester, rowCreatedAtKey), isNull);
      expect(textOf(tester, rowModifiedAtKey), '2026/8/4 16:00');
      expect(find.textContaining('不明'), findsNothing);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    });

    testWidgets('例14b: 名前順でもルールが作成日時を使えば「作成: 不明」を出す', (tester) async {
      final c = FileListController(
        files: [_unknown('b.png')],
        rule: createdRule,
      );
      await _pump(tester, c);

      expect(textOf(tester, rowCreatedAtKey), '作成: 不明');
      expect(textOf(tester, rowModifiedAtKey), isNull, reason: '更新日時は使っていない');
    });

    testWidgets('例15: 作成日時ソートのとき、不明な行は「作成: 不明」を警告色で示す', (tester) async {
      final c = FileListController(files: [_unknown('b.png')]);
      await _pump(tester, c);
      c.setSortMode(FileSortMode.createdAt);
      await tester.pump();

      final createdAt = tester.widget<Text>(find.byKey(rowCreatedAtKey));
      expect(createdAt.data, '作成: 不明');
      // 不明はセマンティックな危険色(色の直書きをしない)。
      expect(createdAt.style?.color, AppColors.dark.danger);
      expect(textOf(tester, rowModifiedAtKey), isNull, reason: '更新日時は使っていない');
    });

    testWidgets('例14d: ルールが更新日時だけを使えば「更新:」だけ', (tester) async {
      final c = FileListController(
        files: [_known('a.txt')],
        rule: modifiedRule,
      );
      await _pump(tester, c);

      expect(textOf(tester, rowModifiedAtKey), '更新: 2026/8/4 16:00');
      expect(textOf(tester, rowCreatedAtKey), isNull);
    });

    testWidgets('両方を使い、値が違えば両方を出す(更新日時は強調しない)', (tester) async {
      final c = FileListController(
        files: [_known('a.txt'), _unknown('b.png')],
        rule: modifiedRule,
      );
      await _pump(tester, c);
      c.setSortMode(FileSortMode.createdAt);
      await tester.pump();

      final created = tester
          .widgetList<Text>(find.byKey(rowCreatedAtKey))
          .map((t) => t.data)
          .toList();
      final modified = tester
          .widgetList<Text>(find.byKey(rowModifiedAtKey))
          .toList();
      expect(created, containsAll(['作成: 2023/5/6 07:08', '作成: 不明']));
      expect(modified.map((t) => t.data), everyElement('更新: 2026/8/4 16:00'));
      // 強調の対象は代替された作成日時だけである。
      for (final t in modified) {
        expect(t.style?.color, isNot(AppColors.dark.danger));
      }
    });

    testWidgets('例14c: 両方を使い、表示上同じ値なら「作成・更新:」にまとめる', (tester) async {
      final same = FileEntry(
        name: 'same.jpg',
        createdAt: DateTime(2026, 8, 4, 16, 0, 12),
        modifiedAt: DateTime(2026, 8, 4, 16, 0, 47),
        size: 0,
      );
      final c = FileListController(files: [same], rule: modifiedRule);
      await _pump(tester, c);
      c.setSortMode(FileSortMode.createdAt);
      await tester.pump();

      expect(textOf(tester, rowCreatedAtKey), '作成・更新: 2026/8/4 16:00');
      expect(textOf(tester, rowModifiedAtKey), isNull, reason: '1つにまとめる');
    });
  });
}
