// VER-002: ファイルリストの描画層(ウィジェット操作 → 状態反映)の検証。
// 対象: REQ-002(ソート切替)/ **REQ-016(選択の切り替えを提示しない)** /
//       **REQ-017(除去の取り消し)** / REQ-006/REQ-007(行の現在名・変更後名の表示)。
//       ドラッグ並び替え(REQ-003)は T5。
//
// **REQ-004(`toggleSelection`/`selectAll`/`clearAll`)はここでは検証しない。**
// `008:T03` の決定で行 UI が選択の切り替えを提示しなくなり、REQ-004 は状態層の
// 要求になった(検証は VER-001 = `controller_test.dart` / `preview_rows_test.dart`)。
import 'package:batch_rename_master/core/rename_engine.dart';
import 'package:batch_rename_master/ui/file_list/file_list_controller.dart';
import 'package:batch_rename_master/ui/file_list/file_list_view.dart';
import 'package:batch_rename_master/ui/file_list/file_sort.dart';
import 'package:batch_rename_master/ui/file_list/removal_undo.dart';
import 'package:batch_rename_master/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

FileEntry _f(String name, {String? handle}) => FileEntry(
  name: name,
  createdAt: DateTime(2026, 1, 1),
  modifiedAt: DateTime(2026, 1, 1),
  size: 0,
  // **元場所ハンドルを持つ行だけ個別に外せる**(004 REQ-006)。除去の検査では要る。
  sourceHandle: handle,
);

const _seq2 = RenameRule([SequenceToken(start: 1, digits: 2)]);

Future<void> _pump(WidgetTester tester, FileListController c) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: appDarkTheme(),
      home: Scaffold(body: FileListView(controller: c)),
    ),
  );
}

void main() {
  testWidgets('現在名と選択行の変更後名を表示する(REQ-006)', (tester) async {
    final c = FileListController(
      files: [_f('a.txt'), _f('b.txt')],
      rule: _seq2,
    );
    await _pump(tester, c);
    expect(find.text('a.txt'), findsOneWidget);
    expect(find.text('b.txt'), findsOneWidget);
    expect(find.text('01.txt'), findsOneWidget);
    expect(find.text('02.txt'), findsOneWidget);
  });

  testWidgets('行に checkbox が無く、一覧の全件が変更後名を持つ(REQ-016・代表例6e)', (tester) async {
    // `008:T03` の決定: 一覧にあるファイルはすべて rename 対象である。
    // **選択を切り替える導線を出さない。** 状態層の `toggleSelection` は残るが
    // (REQ-004)、UI からは呼ばれないので全件が選択されたままになる(REQ-008)。
    final files = [_f('a.txt'), _f('b.txt')];
    final c = FileListController(files: files, rule: _seq2);
    await _pump(tester, c);

    expect(find.byType(Checkbox), findsNothing);
    expect(find.byKey(const Key('select-all-toggle')), findsNothing);
    expect(c.selectedCount, 2);
    // 全件が変更後名を持つ(`—` の行が無い)。
    expect(find.text('—'), findsNothing);
    expect(find.text('01.txt'), findsOneWidget);
    expect(find.text('02.txt'), findsOneWidget);
  });

  testWidgets('ソートチップのタップで sortMode と表示順が変わる(REQ-002)', (tester) async {
    final c = FileListController(
      files: [_f('b.txt'), _f('a.txt')],
      rule: _seq2,
    );
    await _pump(tester, c);
    expect(c.sortMode, FileSortMode.custom);

    await tester.tap(find.text('元の名前順'));
    await tester.pump();

    expect(c.sortMode, FileSortMode.name);
    // 名前順で a.txt が b.txt より上に並ぶ。
    final yA = tester.getTopLeft(find.text('a.txt')).dy;
    final yB = tester.getTopLeft(find.text('b.txt')).dy;
    expect(yA, lessThan(yB));
  });

  testWidgets('総件数を表示し、「n/n 件を選択」は出さない(REQ-016)', (tester) async {
    final c = FileListController(files: [_f('a'), _f('b')], rule: _seq2);
    await _pump(tester, c);

    expect(tester.widget<Text>(find.byKey(fileCountKey)).data, '2 件');
    // **選択の言い回しを残さない。** 「2 / 2 件を選択」が出ていると、
    // 選択という概念がまだあるように読める。
    expect(find.textContaining('選択'), findsNothing);
  });

  testWidgets('行の × で外すと、取り消して元の位置へ戻せる(REQ-017・代表例6b/6c)', (tester) async {
    final files = [
      _f('a.txt', handle: 'h:a'),
      _f('b.txt', handle: 'h:b'),
      _f('c.txt', handle: 'h:c'),
    ];
    final c = FileListController(files: files, rule: _seq2);
    await _pump(tester, c);

    // 2番目(b)を外す。
    await tester.tap(find.byTooltip('このファイルを外す').at(1));
    await tester.pumpAndSettle();
    expect(c.items.map((f) => f.name), ['a.txt', 'c.txt']);
    // 連番は残った2件で詰め直される(代表例6b)。
    expect(find.text('02.txt'), findsOneWidget);
    expect(find.text('03.txt'), findsNothing);

    // 取り消す。
    expect(find.byKey(removalUndoKey), findsOneWidget);
    await tester.tap(find.text('元に戻す'));
    await tester.pumpAndSettle();

    // **末尾へ付け足さない** — 元の位置(2番目)へ戻る(代表例6c)。
    expect(c.items.map((f) => f.name), ['a.txt', 'b.txt', 'c.txt']);
  });

  testWidgets('取り消しで、一覧の警告に使う占有名も戻る(005 REQ-026)', (tester) async {
    // 取り消しは `setFiles` で戻すが、**`setFiles` は占有名を捨てる**
    // (置き換え後の folder と無関係になるため)。控えを戻さないと、
    // 外して戻しただけで**一覧の重複警告が弱くなる**。
    final files = [_f('a.txt', handle: 'h:a'), _f('b.txt', handle: 'h:b')];
    final c = FileListController(files: files, rule: _seq2);
    c.setOccupiedNames({
      'folder': {'keep.txt'},
    });
    await _pump(tester, c);

    await tester.tap(find.byTooltip('このファイルを外す').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('元に戻す'));
    await tester.pumpAndSettle();

    expect(c.occupiedNames, {
      'folder': {'keep.txt'},
    });
  });

  testWidgets('一致しない除去では取り消しを出さない(REQ-009の無変化)', (tester) async {
    // 「外しました」と出しておいて何も外れていないのは嘘になる。
    final c = FileListController(
      files: [_f('a.txt', handle: 'h:a')],
      rule: _seq2,
    );
    await _pump(tester, c);
    final context = tester.element(find.byType(FileListView));

    removeUndoably(context, c, () => c.removeFile('h:存在しない'));
    await tester.pumpAndSettle();

    expect(find.byKey(removalUndoKey), findsNothing);
  });
}
