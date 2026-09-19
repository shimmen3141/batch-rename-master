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
import 'package:batch_rename_master/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'removal_mode.dart';

FileEntry _f(String name, {String? handle}) => FileEntry(
  name: name,
  createdAt: DateTime(2026, 1, 1),
  modifiedAt: DateTime(2026, 1, 1),
  size: 0,
  sourceHandle: handle,
);

const _seq2 = RenameRule([SequenceToken(start: 1, digits: 2)]);

/// a / b / c の3件(すべて外せる)。
List<FileEntry> _abc() => [
  _f('a.txt', handle: 'h:a'),
  _f('b.txt', handle: 'h:b'),
  _f('c.txt', handle: 'h:c'),
];

Future<void> _pump(WidgetTester tester, FileListController c) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: appDarkTheme(),
      home: Scaffold(body: FileListView(controller: c)),
    ),
  );
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
    expect(tester.widget<Text>(find.byKey(removalModeCountKey)).data, '1 件');
    // **一覧は変わらない。** rename 対象は全件のままである。
    expect(c.items.map((f) => f.name), ['a.txt', 'b.txt', 'c.txt']);
    expect(c.selectedCount, 3);
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
    expect(tester.widget<Text>(find.byKey(removalModeCountKey)).data, '1 件');

    c.setFiles(const []);
    await tester.pumpAndSettle();
    // 取り消しで元の一覧が戻る(002 代表例 6d)。
    c.setFiles(files);
    await tester.pumpAndSettle();

    expect(find.byKey(removalModeCountKey), findsNothing);
    expect(find.byKey(removalModeEnterKey), findsOneWidget);
    // **前の候補も残っていない。**
    await enterRemovalMode(tester);
    expect(tester.widget<Text>(find.byKey(removalModeCountKey)).data, '0 件');
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
    expect(tester.widget<Text>(find.byKey(removalModeCountKey)).data, '3 件');
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
    expect(tester.widget<Text>(find.byKey(removalModeCountKey)).data, '2 件');
    await removeMarked(tester);

    expect(c.items.map((f) => f.name), ['a.txt']);
    // **モードは抜ける**(外し終えたら選ぶ作業も終わり)。
    expect(find.byKey(removalModeCountKey), findsNothing);
    expect(find.byKey(removalModeEnterKey), findsOneWidget);
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
    expect(tester.widget<Text>(find.byKey(removalModeCountKey)).data, '0 件');
  });

  testWidgets('長押し以外の入口からも入れる(REQ-018・代表例6j)', (tester) async {
    // **長押しはマウスでも発火するが、押せることが画面から読めない。**
    // 支援技術からも辿りにくいので、常設の入口が要る。
    final c = FileListController(files: _abc(), rule: _seq2);
    await _pump(tester, c);

    expect(find.byKey(removalModeEnterKey), findsOneWidget);
    await enterRemovalMode(tester);

    expect(find.byKey(removalModeCountKey), findsOneWidget);
    expect(find.byKey(removalModeRemoveKey), findsOneWidget);
    expect(find.byKey(removalModeExitKey), findsOneWidget);
    // 入口は入った後のヘッダには無い(同じ操作を二重に出さない)。
    expect(find.byKey(removalModeEnterKey), findsNothing);
  });

  testWidgets('一覧が空なら入口を出さない(REQ-018)', (tester) async {
    final c = FileListController(files: const [], rule: _seq2);
    await _pump(tester, c);

    expect(find.byKey(removalModeEnterKey), findsNothing);
  });

  testWidgets('0件では外せない(REQ-018)', (tester) async {
    // 「外す」を押せるのに何も起きない/全件外れる、のどちらも誤りである。
    final c = FileListController(files: _abc(), rule: _seq2);
    await _pump(tester, c);

    await enterRemovalMode(tester);

    expect(tester.widget<Text>(find.byKey(removalModeCountKey)).data, '0 件');
    expect(
      tester.widget<TextButton>(find.byKey(removalModeRemoveKey)).onPressed,
      isNull,
    );
    // 押しても一覧は変わらない。
    await tester.tap(find.byKey(removalModeRemoveKey));
    await tester.pumpAndSettle();
    expect(c.items.length, 3);
    expect(find.byKey(removalUndoKey), findsNothing);
  });

  testWidgets('選択を外すと件数が戻り、外せなくなる(REQ-018)', (tester) async {
    final c = FileListController(files: _abc(), rule: _seq2);
    await _pump(tester, c);

    await tester.longPress(find.text('b.txt'));
    await tester.pump();
    await toggleRemovalMark(tester, 'h:b');

    expect(tester.widget<Text>(find.byKey(removalModeCountKey)).data, '0 件');
    expect(
      tester.widget<TextButton>(find.byKey(removalModeRemoveKey)).onPressed,
      isNull,
    );
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
    expect(tester.widget<Text>(find.byKey(removalModeCountKey)).data, '0 件');
  });

  testWidgets('モード中に一覧が空になったら通常表示へ戻る(REQ-018)', (tester) async {
    // 読み込み直しで一覧が空になると、選ぶものが無いモードに閉じ込められる。
    final c = FileListController(files: _abc(), rule: _seq2);
    await _pump(tester, c);
    await enterRemovalMode(tester);

    c.setFiles(const []);
    await tester.pumpAndSettle();

    expect(find.byKey(removalModeCountKey), findsNothing);
    expect(find.byKey(removalModeRemoveKey), findsNothing);
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

    expect(tester.widget<Text>(find.byKey(removalModeCountKey)).data, '1 件');
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
    expect(find.byKey(removalModeEnterKey), findsOneWidget);
    expect(c.items.map((f) => f.name), ['a.txt', 'b.txt', 'c.txt']);
  });

  testWidgets('モード中もヘッダに「選択」の語を出さない(002 T27 の決定)', (tester) async {
    // `T03` で UI から消した語である。`〇件選択中` だと「選んだものを rename する」
    // と読まれうるので、**外すことを名指しする**見出しにしてある。
    final c = FileListController(files: _abc(), rule: _seq2);
    await _pump(tester, c);
    expect(find.textContaining('選択'), findsNothing);

    await enterRemovalMode(tester);

    expect(find.textContaining('選択'), findsNothing);
    expect(find.text('外すファイルを選ぶ'), findsWidgets);
    expect(find.text('リネーム候補から外す'), findsOneWidget);
  });
}
