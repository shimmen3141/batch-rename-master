// VER-002: 除去のための一時的な選択モード(002 REQ-018)の検証。
// 代表例 6e〜6j に対応する。
//
// **このモードの選択は rename 対象の選択ではない。** 選ぶのは「これから外す候補」で、
// モードをやめれば消える(REQ-016 の「一覧＝ rename 対象」は保たれる)。
// `008:T27` で開発者が承認した。
import 'package:batch_rename_master/core/rename_engine.dart';
import 'package:batch_rename_master/ui/file_list/file_list_controller.dart';
import 'package:batch_rename_master/ui/file_list/file_list_view.dart';
import 'package:batch_rename_master/ui/file_list/file_sort.dart';
import 'package:batch_rename_master/ui/file_list/removal_undo.dart';
import 'package:batch_rename_master/ui/file_list/removal_selection.dart';
import 'package:batch_rename_master/ui/theme/app_colors.dart';
import 'package:batch_rename_master/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'removal_mode.dart';

FileEntry _f(String name, {String? handle, String? sourceLocation}) =>
    FileEntry(
      name: name,
      createdAt: DateTime(2026, 1, 1),
      modifiedAt: DateTime(2026, 1, 1),
      size: 0,
      sourceHandle: handle,
      sourceLocation: sourceLocation,
    );

const _seq2 = RenameRule([SequenceToken(start: 1, digits: 2)]);

/// a / b / c の3件(すべて外せる)。
List<FileEntry> _abc() => [
  _f('a.txt', handle: 'h:a'),
  _f('b.txt', handle: 'h:b'),
  _f('c.txt', handle: 'h:c'),
];

Future<void> _pump(
  WidgetTester tester,
  FileListController c, {
  RemovalSelection? selection,
  VoidCallback? onEditRule,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: appDarkTheme(),
      home: Scaffold(
        body: FileListView(
          controller: c,
          removalSelection: selection,
          onEditRule: onEditRule,
        ),
      ),
    ),
  );
}

Future<TestGesture> _startLongPress(WidgetTester tester, Finder target) async {
  final gesture = await tester.startGesture(tester.getCenter(target));
  await tester.pump(const Duration(milliseconds: 600));
  return gesture;
}

void main() {
  testWidgets('通常表示には1件ごとの除去操作が無い(REQ-016・代表例6e)', (tester) async {
    // `008:T27` の決定: × と並び替えのつまみが行の右端で隣り合って
    // 押し間違えうるので、**通常表示から除去操作そのものを外した**。
    final c = FileListController(files: _abc(), rule: _seq2);
    await _pump(tester, c);

    expect(find.byTooltip('このファイルを外す'), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
    // 一覧は変わっていない(除去操作が無いだけで、対象は全件である)。
    expect(c.items.length, 3);
  });

  testWidgets('長押しでモードへ入り、その行が選ばれている(REQ-018・代表例6f)', (tester) async {
    final c = FileListController(files: _abc(), rule: _seq2);
    await _pump(tester, c);

    await tester.longPress(find.text('b.txt'));
    await tester.pump();

    // **選ばれているのは長押しした行だけ。**
    expect(
      tester.widget<Checkbox>(find.byKey(removalMarkKeyOf('h:b'))).value,
      isTrue,
    );
    expect(
      tester.widget<Checkbox>(find.byKey(removalMarkKeyOf('h:a'))).value,
      isFalse,
    );
    expect(removalModeCountText(tester), '1件選択中');
    // **一覧は変わらない。** rename 対象は全件のままである。
    expect(c.items.map((f) => f.name), ['a.txt', 'b.txt', 'c.txt']);
    expect(c.selectedCount, 3);
  });

  testWidgets('長押しの往復では今回追加した行だけを外す(REQ-018・代表例6k)', (tester) async {
    final selection = RemovalSelection();
    final c = FileListController(files: _abc(), rule: _seq2);
    await _pump(tester, c, selection: selection);

    final gesture = await _startLongPress(tester, find.text('a.txt'));
    await gesture.moveTo(tester.getCenter(find.text('b.txt')));
    await tester.pump();
    await gesture.moveTo(tester.getCenter(find.text('c.txt')));
    await tester.pump();
    await gesture.moveTo(tester.getCenter(find.text('b.txt')));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    // a → b → c → b は c だけを戻す。開始行と経路上の b は残る。
    expect(selection.marked, {'h:a', 'h:b'});
  });

  testWidgets('モード中の長押し往復は以前の候補を保つ(REQ-018・代表例6l)', (tester) async {
    final selection = RemovalSelection();
    final c = FileListController(files: _abc(), rule: _seq2);
    await _pump(tester, c, selection: selection);
    await enterRemovalMode(tester);
    await toggleRemovalMark(tester, 'h:a');

    final gesture = await _startLongPress(tester, find.text('b.txt'));
    await gesture.moveTo(tester.getCenter(find.text('c.txt')));
    await tester.pump();
    await gesture.moveTo(tester.getCenter(find.text('b.txt')));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    // 開始前からある a は、このドラッグが戻っても外れない。
    expect(selection.marked, {'h:a', 'h:b'});
  });

  testWidgets('長押し前の通常ドラッグは候補を作らない(REQ-018・代表例6o)', (tester) async {
    final c = FileListController(files: _abc(), rule: _seq2);
    await _pump(tester, c);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('a.txt')),
    );
    await gesture.moveTo(tester.getCenter(find.text('c.txt')));
    await gesture.up();
    await tester.pump();

    expect(find.byKey(removalModeCountKey), findsNothing);
  });

  testWidgets('端の保持で実在する行だけを連続して選びながらスクロールする(REQ-018・代表例6m/6n)', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 300));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final selection = RemovalSelection();
    final files = [
      for (var i = 0; i < 12; i++)
        _f(
          'file-$i.txt',
          handle: 'h:$i',
          // 場所を持つ行と持たない行を混ぜ、表示行高を固定値で仮定できない形にする。
          sourceLocation: i == 0 ? '/folder-a' : (i == 2 ? '/folder-b' : null),
        ),
    ];
    final c = FileListController(files: files, rule: _seq2);
    await _pump(tester, c, selection: selection);

    final gesture = await _startLongPress(tester, find.text('file-0.txt'));
    final list = tester.getRect(find.byType(ReorderableListView));
    await gesture.moveTo(Offset(list.center.dx, list.bottom - 2));
    await tester.pump();
    // Timer tick ごとに固定された指位置で新しく表示された行を同じ経路として追う。
    // widget test では frame を刻み、実機の連続 frame と同じ timer tick を流す。
    for (var tick = 0; tick < 260; tick++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pump();
    final markedWhenLifted = selection.marked;
    await tester.pump(const Duration(seconds: 1));

    final handles = {for (var i = 0; i < 12; i++) 'h:$i'};
    expect(selection.marked, markedWhenLifted);
    expect(selection.marked, isNotEmpty);
    expect(selection.marked, everyElement(isIn(handles)));
    // 終端では overscroll せず、実在する末尾行までで止まる。
    expect(selection.marked, contains('h:11'));
  });

  testWidgets(
    '開始行がoffscreenになった後も上から中央でscrollを止め、下端で反転して往路を戻す(2026-09-21 manual FAIL)',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 360));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final selection = RemovalSelection();
      final files = [
        for (var i = 0; i < 40; i++) _f('long-$i.txt', handle: 'h:long-$i'),
      ];
      final c = FileListController(files: files, rule: _seq2);
      await _pump(tester, c, selection: selection);
      final target = find.text('long-20.txt');
      await tester.scrollUntilVisible(
        target,
        120,
        scrollable: find.descendant(
          of: find.byType(ReorderableListView),
          matching: find.byType(Scrollable),
        ),
      );
      final gesture = await _startLongPress(tester, target);
      final list = tester.getRect(find.byType(ReorderableListView));
      await gesture.moveTo(Offset(list.center.dx, list.top + 2));
      for (var tick = 0; tick < 140; tick++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(target, findsNothing); // 開始行は dispose されるほど遠くへ流れる。

      // 中央へ戻すと、開始行の GestureDetector が消えていても timer は止まる。
      await gesture.moveTo(list.center);
      await tester.pump();
      final scrollable = tester.state<ScrollableState>(
        find.descendant(
          of: find.byType(ReorderableListView),
          matching: find.byType(Scrollable),
        ),
      );
      final stoppedAt = scrollable.position.pixels;
      for (var tick = 0; tick < 40; tick++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(scrollable.position.pixels, closeTo(stoppedAt, 1));

      // 同じ active pointer を下端へ戻すと下scrollへ反転し、往路の候補を解除する。
      await gesture.moveTo(Offset(list.center.dx, list.bottom - 2));
      for (var tick = 0; tick < 180; tick++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pump();
      expect(selection.marked, isNot(contains('h:long-19')));
      expect(selection.marked, contains('h:long-21'));
    },
  );

  testWidgets('開始行がoffscreenになった後も下から上へ反転し、往路候補を解除する(2026-09-21 manual FAIL)', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 360));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final selection = RemovalSelection();
    final files = [
      for (var i = 0; i < 40; i++) _f('reverse-$i.txt', handle: 'h:reverse-$i'),
    ];
    final c = FileListController(files: files, rule: _seq2);
    await _pump(tester, c, selection: selection);
    final target = find.text('reverse-20.txt');
    await tester.scrollUntilVisible(
      target,
      120,
      scrollable: find.descendant(
        of: find.byType(ReorderableListView),
        matching: find.byType(Scrollable),
      ),
    );
    final gesture = await _startLongPress(tester, target);
    final list = tester.getRect(find.byType(ReorderableListView));
    await gesture.moveTo(Offset(list.center.dx, list.bottom - 2));
    for (var tick = 0; tick < 140; tick++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(target, findsNothing);

    await gesture.moveTo(Offset(list.center.dx, list.top + 2));
    for (var tick = 0; tick < 180; tick++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pump();

    expect(selection.marked, isNot(contains('h:reverse-21')));
    expect(selection.marked, contains('h:reverse-19'));
  });

  testWidgets(
    '開始行がoffscreenになった後のcancelは親Listenerでauto-scrollを止める(2026-09-21 manual FAIL)',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 360));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final files = [
        for (var i = 0; i < 40; i++) _f('cancel-$i.txt', handle: 'h:cancel-$i'),
      ];
      final c = FileListController(files: files, rule: _seq2);
      await _pump(tester, c);
      final target = find.text('cancel-20.txt');
      await tester.scrollUntilVisible(
        target,
        120,
        scrollable: find.descendant(
          of: find.byType(ReorderableListView),
          matching: find.byType(Scrollable),
        ),
      );
      final gesture = await _startLongPress(tester, target);
      final list = tester.getRect(find.byType(ReorderableListView));
      await gesture.moveTo(Offset(list.center.dx, list.top + 2));
      for (var tick = 0; tick < 140; tick++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(target, findsNothing);

      await gesture.cancel();
      await tester.pump();
      final scrollable = tester.state<ScrollableState>(
        find.descendant(
          of: find.byType(ReorderableListView),
          matching: find.byType(Scrollable),
        ),
      );
      final stoppedAt = scrollable.position.pixels;
      for (var tick = 0; tick < 40; tick++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(scrollable.position.pixels, closeTo(stoppedAt, 1));
    },
  );

  testWidgets(
    'headerへ入った長押しdragでも上へauto-scrollし、深いほど速い(2026-09-21 manual FAIL)',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 420));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      Future<double> moveUpFromHeader(double beyondTop) async {
        final files = [
          for (var i = 0; i < 20; i++) _f('up-$i.txt', handle: 'h:up-$i'),
        ];
        final c = FileListController(files: files, rule: _seq2);
        await _pump(tester, c);
        final target = find.text('up-10.txt');
        await tester.scrollUntilVisible(
          target,
          120,
          scrollable: find.descendant(
            of: find.byType(ReorderableListView),
            matching: find.byType(Scrollable),
          ),
        );
        await tester.pumpAndSettle();

        final gesture = await _startLongPress(tester, target);
        final list = tester.getRect(find.byType(ReorderableListView));
        final before = tester.getTopLeft(target).dy;
        await gesture.moveTo(Offset(list.center.dx, list.top - beyondTop));
        for (var tick = 0; tick < 20; tick++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        final movedDown = tester.getTopLeft(target).dy - before;
        await gesture.up();
        await tester.pump();
        return movedDown;
      }

      final nearHeader = await moveUpFromHeader(8);
      final pastHeader = await moveUpFromHeader(96);

      expect(nearHeader, greaterThan(0));
      expect(pastHeader, greaterThan(nearHeader));
    },
  );

  testWidgets('最下段から選択を始めても下部UIを隠す前後で開始行の位置を保つ(2026-09-21 manual FAIL)', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 520));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final files = [
      for (var i = 0; i < 12; i++) _f('bottom-$i.txt', handle: 'h:bottom-$i'),
    ];
    final c = FileListController(files: files, rule: _seq2);
    await _pump(tester, c, onEditRule: () {});
    final list = find.byType(ReorderableListView);
    await tester.drag(list, const Offset(0, -2000));
    await tester.pumpAndSettle();
    final last = find.text('bottom-11.txt');
    expect(last, findsOneWidget);
    final before = tester.getTopLeft(last).dy;

    final gesture = await _startLongPress(tester, last);
    await tester.pump();
    final after = tester.getTopLeft(last).dy;
    await gesture.up();

    expect(after, closeTo(before, 1));
    expect(find.byKey(const Key('configure-rule')), findsNothing);
  });

  testWidgets('モード中は並び替えの操作を出さない(REQ-018)', (tester) async {
    // 押し間違いを消すのが目的なので、モード中につまみを残すと目的が半分戻る。
    // `カスタム順` chip も REQ-014 が言う「手動並び替えの提示」なので出さない。
    final c = FileListController(files: _abc(), rule: _seq2);
    await _pump(tester, c);
    expect(find.byIcon(Icons.drag_handle), findsWidgets);
    expect(find.text('カスタム順'), findsOneWidget);

    await enterRemovalMode(tester);

    expect(find.byIcon(Icons.drag_handle), findsNothing);
    expect(find.text('カスタム順'), findsNothing);
    // **ソート自体は常に出す**(REQ-014。閲覧・確認の用途がある)。
    expect(find.text('元の名前順'), findsOneWidget);
  });

  testWidgets('モード中の長押しでは並び替えが始まらない(REQ-018)', (tester) async {
    // `ReorderableListView` は既定で長押しドラッグを持つ。切り忘れると、
    // **選ぶつもりの長押しが並べ替えになる**。
    final c = FileListController(files: _abc(), rule: _seq2);
    await _pump(tester, c);
    await enterRemovalMode(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('a.txt')),
    );
    await tester.pump(const Duration(seconds: 1));
    await gesture.moveBy(const Offset(0, 120));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(c.items.map((f) => f.name), ['a.txt', 'b.txt', 'c.txt']);
    expect(c.sortMode, FileSortMode.custom);
  });

  testWidgets('つまみを長押ししてからドラッグしても並び替えができる(REQ-003/REQ-014)', (tester) async {
    // **長押ししてからドラッグは Android の既定の並び替え操作**である。行ごと
    // 長押しで包むと、つまみの上の長押しも行が取り、500ms で選択モードが開いて
    // `showDragHandle` が false になる — **つまみが消えて、掴んだままの指では
    // 並び替えを始められない**(独立reviewが実測: 450ms は並び替わり、520ms で
    // モードが開いた)。`pump(250ms)` で動かす既存の並び替えtestはこの手前を通る。
    final c = FileListController(files: _abc(), rule: _seq2);
    await _pump(tester, c);

    final handle = tester.getCenter(find.byIcon(Icons.drag_handle).first);
    final gesture = await tester.startGesture(handle);
    // **長押しの閾値(500ms)を越えて保持する。**
    await tester.pump(const Duration(milliseconds: 800));
    await gesture.moveBy(const Offset(0, 70));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 70));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    // 並び替わっている(a が下がった)。
    expect(c.items.first.name, isNot('a.txt'));
    // **選択モードは開いていない。**
    expect(find.byKey(removalModeCountKey), findsNothing);
  });

  testWidgets('一覧が空になってから戻っても、モードは復活しない(REQ-018)', (tester) async {
    // 畳んだ画面にはヘッダの × が無いので、**利用者には片付ける手段が無い**。
    // 状態を残すと「一覧を空にする → 元に戻す」で誰も押していないのにモードが
    // 戻り、前の外す候補が選択済みで復活する(独立reviewが製品構成で実測した)。
    final files = _abc();
    final c = FileListController(files: files, rule: _seq2);
    await _pump(tester, c);
    await tester.longPress(find.text('b.txt'));
    await tester.pump();
    expect(removalModeCountText(tester), '1件選択中');

    c.setFiles(const []);
    await tester.pumpAndSettle();
    // 取り消しで元の一覧が戻る(002 代表例 6d)。
    c.setFiles(files);
    await tester.pumpAndSettle();

    expect(find.byKey(removalModeCountKey), findsNothing);
    expect(find.byKey(listMenuKey), findsOneWidget);
    // **前の候補も残っていない。**
    await enterRemovalMode(tester);
    expect(removalModeCountText(tester), '0件選択中');
  });

  testWidgets('モード中の長押しでは選択が巻き戻らない(REQ-018)', (tester) async {
    // 長押しは「入る」操作なので、既に入っているところで効くと**選んだ分が
    // その1件へ上書きされる**(利用者の操作なしに選択が失われる)。
    final c = FileListController(files: _abc(), rule: _seq2);
    await _pump(tester, c);
    await enterRemovalMode(tester);
    await toggleRemovalMark(tester, 'h:a');
    await toggleRemovalMark(tester, 'h:c');

    await tester.longPress(find.text('b.txt'));
    await tester.pumpAndSettle();

    // **モード中の長押しは tap として通る**(切り替えになる)。それはよい。
    // 起きてはいけないのは、**選んだ2件が捨てられてこの1件だけになる**ことである。
    expect(removalModeCountText(tester), '3件選択中');
    expect(
      tester.widget<Checkbox>(find.byKey(removalMarkKeyOf('h:a'))).value,
      isTrue,
    );
    expect(
      tester.widget<Checkbox>(find.byKey(removalMarkKeyOf('h:c'))).value,
      isTrue,
    );
  });

  testWidgets('選んだ2件をまとめて外し、モードを抜ける(REQ-018・代表例6g)', (tester) async {
    final c = FileListController(files: _abc(), rule: _seq2);
    await _pump(tester, c);

    await tester.longPress(find.text('b.txt'));
    await tester.pump();
    await toggleRemovalMark(tester, 'h:c');
    expect(removalModeCountText(tester), '2件選択中');
    await removeMarked(tester);

    expect(c.items.map((f) => f.name), ['a.txt']);
    // **モードは抜ける**(外し終えたら選ぶ作業も終わり)。
    expect(find.byKey(removalModeCountKey), findsNothing);
    expect(find.byKey(listMenuKey), findsOneWidget);
    // 通知は1回で、外した件数を言う。
    expect(find.text('2 件を一覧から外しました'), findsOneWidget);
  });

  testWidgets('まとめて外した分は1回の取り消しで全件戻る(REQ-017・代表例6h)', (tester) async {
    final c = FileListController(files: _abc(), rule: _seq2);
    await _pump(tester, c);

    await enterRemovalMode(tester);
    await toggleRemovalMark(tester, 'h:b');
    await toggleRemovalMark(tester, 'h:c');
    await removeMarked(tester);
    expect(c.items.map((f) => f.name), ['a.txt']);

    await tester.tap(find.text('元に戻す'));
    await tester.pumpAndSettle();

    // **2件とも元の位置へ**戻る(末尾へ付け足さない)。
    expect(c.items.map((f) => f.name), ['a.txt', 'b.txt', 'c.txt']);
    expect(find.byKey(removalUndoStaleKey), findsNothing);
  });

  testWidgets('選んだままやめても一覧は変わらない(REQ-018・代表例6i)', (tester) async {
    final c = FileListController(files: _abc(), rule: _seq2);
    await _pump(tester, c);

    await tester.longPress(find.text('b.txt'));
    await tester.pump();
    await toggleRemovalMark(tester, 'h:c');
    await tester.tap(find.byKey(removalModeExitKey));
    await tester.pumpAndSettle();

    expect(c.items.map((f) => f.name), ['a.txt', 'b.txt', 'c.txt']);
    expect(c.selectedCount, 3);
    // 除去していないので通知も出ない。
    expect(find.byKey(removalUndoKey), findsNothing);

    // **選択は破棄される** — 入り直したとき前回の選択が残っていない。
    await enterRemovalMode(tester);
    expect(removalModeCountText(tester), '0件選択中');
  });

  testWidgets('長押し以外の入口からも入れる(REQ-018・代表例6j)', (tester) async {
    // **長押しはマウスでも発火するが、押せることが画面から読めない。**
    // 支援技術からも辿りにくいので、常設の入口が要る。
    final c = FileListController(files: _abc(), rule: _seq2);
    await _pump(tester, c);

    expect(find.byKey(listMenuKey), findsOneWidget);
    await enterRemovalMode(tester);

    expect(find.byKey(removalModeCountKey), findsOneWidget);
    expect(find.byKey(removalModeRemoveKey), findsOneWidget);
    expect(find.byKey(removalModeExitKey), findsOneWidget);
    // 入口はモード中のケバブには無い(同じ操作を二重に出さない)。
    await openListMenu(tester);
    expect(find.byKey(removalModeEnterKey), findsNothing);
    expect(find.byKey(menuSelectAllKey), findsOneWidget);
    expect(find.byKey(menuClearAllKey), findsOneWidget);
  });

  testWidgets('一覧が空ならケバブごと出さない(REQ-018)', (tester) async {
    final c = FileListController(files: const [], rule: _seq2);
    await _pump(tester, c);

    expect(find.byKey(listMenuKey), findsNothing);
  });

  testWidgets('0件では外せない(REQ-018)', (tester) async {
    // 「外す」を押せるのに何も起きない/全件外れる、のどちらも誤りである。
    final c = FileListController(files: _abc(), rule: _seq2);
    await _pump(tester, c);

    await enterRemovalMode(tester);

    expect(removalModeCountText(tester), '0件選択中');
    expect(
      tester.widget<IconButton>(find.byKey(removalModeRemoveKey)).onPressed,
      isNull,
    );
    // 押しても一覧は変わらない。
    await tester.tap(find.byKey(removalModeRemoveKey));
    await tester.pumpAndSettle();
    expect(c.items.length, 3);
    expect(find.byKey(removalUndoKey), findsNothing);
  });

  testWidgets('長押しで入った後に選択を外すとモードを抜ける(008:T29)', (tester) async {
    // 長押しは1件選ばれた状態で始まるので、その1件を外すと0件になる。
    // **0件へ戻ったら抜ける**(2026-09-19 の決定)。
    final c = FileListController(files: _abc(), rule: _seq2);
    await _pump(tester, c);

    await tester.longPress(find.text('b.txt'));
    await tester.pump();
    await toggleRemovalMark(tester, 'h:b');

    expect(removalModeCountText(tester), isNull);
    expect(c.items.map((f) => f.name), ['a.txt', 'b.txt', 'c.txt']);
  });

  testWidgets('元場所ハンドルを持たない行は選べない(004 REQ-006)', (tester) async {
    // ハンドルが無いと除去の対象を指せない。**選べるのに外れない件数**を
    // 出すほうが悪いので、その行には切り替えを出さない。
    final c = FileListController(
      files: [
        _f('a.txt', handle: 'h:a'),
        _f('b.txt'),
      ],
      rule: _seq2,
    );
    await _pump(tester, c);

    await enterRemovalMode(tester);

    expect(find.byKey(removalMarkKeyOf('h:a')), findsOneWidget);
    expect(find.byType(Checkbox), findsOneWidget);
    // 長押ししてもモードへ入らない(入っても選べないので、入口にしない)。
    await tester.tap(find.byKey(removalModeExitKey));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('b.txt'));
    await tester.pump();
    expect(find.byKey(removalModeCountKey), findsNothing);
  });

  testWidgets('通常表示では行タップに除去の意味を持たせない(REQ-016)', (tester) async {
    // tap で外れると、スクロールの誤タップでファイルが消える。
    final c = FileListController(files: _abc(), rule: _seq2);
    await _pump(tester, c);

    await tester.tap(find.text('b.txt'));
    await tester.pumpAndSettle();

    expect(c.items.map((f) => f.name), ['a.txt', 'b.txt', 'c.txt']);
    expect(find.byKey(removalModeCountKey), findsNothing);
    // **溜めてもいない。** 一覧が変わらないだけでは足りない — 通常表示の tap が
    // 候補を足していると、モードへ入った瞬間に身に覚えのない件数が出る
    // (スクロール中の誤 tap がそのまま候補になる。独立reviewの N-1)。
    await enterRemovalMode(tester);
    expect(removalModeCountText(tester), '0件選択中');
  });

  testWidgets('モード中に一覧が空になったら通常表示へ戻る(REQ-018)', (tester) async {
    // 読み込み直しで一覧が空になると、選ぶものが無いモードに閉じ込められる。
    final c = FileListController(files: _abc(), rule: _seq2);
    await _pump(tester, c);
    await enterRemovalMode(tester);

    c.setFiles(const []);
    // **最初の frame から通常表示である。** frame の後の片付けだけに頼ると、
    // 空の一覧に選択モードのヘッダが1 frame残る(独立review attempt 2 が
    // `M312` を `pump()` 一発で落とせると示した)。畳み込みと片付けの両方を見る。
    await tester.pump();
    expect(find.byKey(removalModeCountKey), findsNothing);

    await tester.pumpAndSettle();

    expect(find.byKey(removalModeCountKey), findsNothing);
    expect(find.byKey(removalModeRemoveKey), findsNothing);
  });

  testWidgets('候補が一覧から消えて0件になったらモードを抜ける(008:T29)', (tester) async {
    // **見えている0件と内部の0件を揃える。** 改名の取り消し(005 REQ-018 で項目の
    // ハンドルが入れ替わる)で候補が消えると、画面は「0件選択中」なのに内部には
    // 残っていて「0件で抜ける」が効かなかった(独立review attempt 1 の P3)。
    final files = _abc();
    final c = FileListController(files: files, rule: _seq2);
    await _pump(tester, c);
    await enterRemovalMode(tester);
    await toggleRemovalMark(tester, 'h:a');
    expect(removalModeCountText(tester), '1件選択中');

    // a のハンドルが入れ替わる(改名とその取り消しで起きる形)。
    c.replaceItems({files.first: _f('a.txt', handle: 'h:a2')});
    await tester.pumpAndSettle();

    expect(removalModeCountText(tester), isNull);
    expect(find.byKey(listMenuKey), findsOneWidget);
    // 一覧は変わっていない(抜けただけ)。
    expect(c.items.length, 3);
  });

  testWidgets('候補の一部だけが消えてもモードは続く(008:T29)', (tester) async {
    final files = _abc();
    final c = FileListController(files: files, rule: _seq2);
    await _pump(tester, c);
    await enterRemovalMode(tester);
    await toggleRemovalMark(tester, 'h:a');
    await toggleRemovalMark(tester, 'h:b');

    c.replaceItems({files.first: _f('a.txt', handle: 'h:a2')});
    await tester.pumpAndSettle();

    expect(removalModeCountText(tester), '1件選択中');
  });

  testWidgets('選択の印は円である(008:T29 / 要望2)', (tester) async {
    final c = FileListController(files: _abc(), rule: _seq2);
    await _pump(tester, c);
    await enterRemovalMode(tester);

    expect(
      tester.widget<Checkbox>(find.byKey(removalMarkKeyOf('h:a'))).shape,
      isA<CircleBorder>(),
    );
  });

  testWidgets('モード中に読み込み直すと、消えた行は数に入らない(REQ-018)', (tester) async {
    // 控えたハンドルがもう一覧に無いことがある。件数が実際に外せる数と
    // 食い違うと、「2 件」と出して1件しか外れない。
    final c = FileListController(files: _abc(), rule: _seq2);
    await _pump(tester, c);
    await enterRemovalMode(tester);
    await toggleRemovalMark(tester, 'h:b');
    await toggleRemovalMark(tester, 'h:c');

    c.setFiles([_f('b.txt', handle: 'h:b'), _f('x.txt', handle: 'h:x')]);
    await tester.pumpAndSettle();

    expect(removalModeCountText(tester), '1件選択中');
    await removeMarked(tester);
    expect(c.items.map((f) => f.name), ['x.txt']);
  });

  testWidgets('端末の戻るでモードをやめる(画面は閉じない)', (tester) async {
    // REQ-018 が課す「やめる操作」はヘッダの × が満たすが、選択モードを
    // 戻るで抜けられる期待は強い。**一覧は変わらない**(やめるだけ)。
    final c = FileListController(files: _abc(), rule: _seq2);
    await _pump(tester, c);
    await tester.longPress(find.text('b.txt'));
    await tester.pump();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byKey(removalModeCountKey), findsNothing);
    expect(find.byKey(listMenuKey), findsOneWidget);
    expect(c.items.map((f) => f.name), ['a.txt', 'b.txt', 'c.txt']);
  });

  testWidgets('通常表示には選択の語を出さず、モード中だけ件数を出す(002 REQ-016)', (tester) async {
    // **通常表示に「選択」を出さないのは REQ-016 である**(一覧＝rename対象)。
    // モード中の `〇件選択中` は `T29` で開発者が選んだ文言で、`T27` の決定節が
    // 勧めていた「外すことを名指しする見出し」を上書きしている。誤読を防ぐ役割は
    // **外すアイコンの tooltip とケバブの文言**が引き受ける。
    final c = FileListController(files: _abc(), rule: _seq2);
    await _pump(tester, c);
    expect(find.textContaining('選択'), findsNothing);
    expect(find.textContaining('件'), findsOneWidget); // 総件数だけ

    await enterRemovalMode(tester);
    await toggleRemovalMark(tester, 'h:a');

    expect(removalModeCountText(tester), '1件選択中');
    // 外す操作は**アイコン1つ**で、押せることは tooltip が言う(要望4)。
    expect(
      tester.widget<IconButton>(find.byKey(removalModeRemoveKey)).tooltip,
      '選んだファイルをリネーム候補から外す',
    );
    // ケバブの文言は結果を名指しする。
    await openListMenu(tester);
    expect(find.text('すべてをリネーム対象から外す'), findsOneWidget);
    expect(find.text('すべて選択'), findsOneWidget);
  });

  testWidgets('モード中は下部の帯(ルール設定と実行)を出さない(008:T29)', (tester) async {
    // 外す作業の最中に実行の導線が並んでいると混乱する(2026-09-19 の要望7)。
    // **005 は提示の場所・文言・UI部品を自由とする点に残している** — REQ-019 が
    // 課すのは「実行が始まらない・実ファイルを1件も変えない」という振る舞いである。
    final c = FileListController(files: _abc(), rule: _seq2);
    await tester.pumpWidget(
      MaterialApp(
        theme: appDarkTheme(),
        home: Scaffold(
          body: FileListView(controller: c, onEditRule: () {}),
        ),
      ),
    );
    expect(find.byKey(const Key('configure-rule')), findsOneWidget);

    await enterRemovalMode(tester);

    expect(find.byKey(const Key('configure-rule')), findsNothing);

    await tester.tap(find.byKey(removalModeExitKey));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('configure-rule')), findsOneWidget);
  });

  testWidgets('ケバブの「すべて選択」で全件が候補になる(008:T29)', (tester) async {
    final c = FileListController(files: _abc(), rule: _seq2);
    await _pump(tester, c);

    await selectAllForRemoval(tester);

    expect(removalModeCountText(tester), '3件選択中');
    await removeMarked(tester);
    expect(c.items, isEmpty);
    // 取り消せる(002 REQ-017)。
    await tester.tap(find.text('元に戻す'));
    await tester.pumpAndSettle();
    expect(c.items.map((f) => f.name), ['a.txt', 'b.txt', 'c.txt']);
  });

  testWidgets('ケバブの「すべてをリネーム対象から外す」で一覧が空になる(004 REQ-006)', (tester) async {
    // `008:T29` で読み込み帯の `一覧を空にする` から移した操作である。
    // **取り消せる**(002 REQ-017・代表例6d)。
    final c = FileListController(files: _abc(), rule: _seq2);
    await _pump(tester, c);

    await clearAllFiles(tester);

    expect(c.items, isEmpty);
    await tester.tap(find.text('元に戻す'));
    await tester.pumpAndSettle();
    expect(c.items.map((f) => f.name), ['a.txt', 'b.txt', 'c.txt']);
  });

  testWidgets('選択が0件へ戻るとモードを抜ける(008:T29)', (tester) async {
    // **入った直後の0件では抜けない** — ヘッダの入口(REQ-018 (b))は0件で始まるので、
    // そこで抜けると入口が機能しなくなる。抜けるのは**利用者が選択を外して0件になった**ときである。
    final c = FileListController(files: _abc(), rule: _seq2);
    await _pump(tester, c);

    await enterRemovalMode(tester);
    expect(removalModeCountText(tester), '0件選択中'); // 入った直後は抜けない

    await toggleRemovalMark(tester, 'h:b');
    expect(removalModeCountText(tester), '1件選択中');
    await toggleRemovalMark(tester, 'h:b');

    expect(removalModeCountText(tester), isNull);
    expect(find.byKey(listMenuKey), findsOneWidget);
    expect(c.items.map((f) => f.name), ['a.txt', 'b.txt', 'c.txt']);
  });

  testWidgets('選んだ行は面が染まり、checkboxは右端に出る(008:T29)', (tester) async {
    // **左に出すと preview と名前が横へずれてかくつく**(実機で観測)。
    final c = FileListController(files: _abc(), rule: _seq2);
    await _pump(tester, c);
    final before = tester.getTopLeft(find.text('a.txt'));
    final nameWidthBefore = tester
        .getSize(find.byKey(rowNewNameKey).first)
        .width;

    await enterRemovalMode(tester);

    // 行の読み始めが動かない。
    expect(tester.getTopLeft(find.text('a.txt')), before);
    // checkbox は名前より右にある。
    expect(
      tester.getCenter(find.byKey(removalMarkKeyOf('h:a'))).dx,
      greaterThan(tester.getCenter(find.text('a.txt')).dx),
    );

    // **枠の幅が同じ**なので、行の中身が使える幅も変わらない(かくつきの本体)。
    // 右端の枠だけを見ると checkbox と つまみ のどちらが居るかの話になるが、
    // **効くのは中身の幅**なので、変更後名の欄の幅で見る。
    expect(
      tester.getSize(find.byKey(rowNewNameKey).first).width,
      nameWidthBefore,
    );

    await toggleRemovalMark(tester, 'h:a');

    // 選んだ行だけ面が染まる。
    final colors = AppColors.dark;
    Color? rowColor(String name) {
      final box = tester.widget<Container>(
        find
            .ancestor(of: find.text(name), matching: find.byType(Container))
            .first,
      );
      return (box.decoration as BoxDecoration?)?.color;
    }

    expect(rowColor('a.txt'), colors.selectedSurface);
    expect(rowColor('b.txt'), isNot(colors.selectedSurface));
  });
}
