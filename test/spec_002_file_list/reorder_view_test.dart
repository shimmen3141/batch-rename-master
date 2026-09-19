// VER-002(続き): ドラッグ並び替えと「カスタム順」自動切替の検証(REQ-003)。
// 並び順の変更が連番・プレビューへ反映されることも確認する。
import 'package:batch_rename_master/core/rename_engine.dart';
import 'package:batch_rename_master/ui/file_list/file_list_controller.dart';
import 'package:batch_rename_master/ui/file_list/file_list_view.dart';
import 'package:batch_rename_master/ui/file_list/file_sort.dart';
import 'package:batch_rename_master/ui/theme/app_colors.dart';
import 'package:batch_rename_master/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

FileEntry _f(String name) => FileEntry(
  name: name,
  createdAt: DateTime(2026, 1, 1),
  modifiedAt: DateTime(2026, 1, 1),
  size: 0,
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

double _yOf(WidgetTester tester, String text) =>
    tester.getTopLeft(find.text(text)).dy;

/// [text] を含む行の面の色(塗っていなければ `null`)。
///
/// 行の `Container` は**装飾を持つ最も近い祖先**である(中の preview や警告は
/// 名前の兄弟なので間に入らない)。
Color? _rowColor(WidgetTester tester, String text) {
  final container = tester.widget<Container>(
    find
        .ancestor(
          of: find.text(text),
          matching: find.byWidgetPredicate(
            (w) => w is Container && w.decoration is BoxDecoration,
          ),
        )
        .first,
  );
  return (container.decoration as BoxDecoration).color;
}

void main() {
  testWidgets('onReorder が controller.reorder を駆動し custom へ自動切替(REQ-003)', (
    tester,
  ) async {
    final c = FileListController(
      files: [_f('a.txt'), _f('b.txt'), _f('c.txt')],
      rule: _seq2,
    );
    c.setSortMode(FileSortMode.name); // custom 以外から始める
    await _pump(tester, c);
    expect(c.sortMode, FileSortMode.name);

    // ReorderableListView のコールバックを直接駆動(onReorderItem 規約の検証)。
    final rlv = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );
    rlv.onReorderItem!(0, 1); // a を取り出し index1 へ -> [b, a, c]
    await tester.pump();

    expect(c.sortMode, FileSortMode.custom); // 自動切替
    expect(c.items.map((e) => e.name).toList(), ['b.txt', 'a.txt', 'c.txt']);
    // 連番は新しい表示順で振り直し: b=01, a=02, c=03。
    expect(_yOf(tester, 'b.txt'), lessThan(_yOf(tester, 'a.txt')));
    expect(find.text('01.txt'), findsOneWidget);
    expect(find.text('03.txt'), findsOneWidget);
  });

  testWidgets('ドラッグハンドルの操作で実際に並び替わり custom になる(REQ-003)', (tester) async {
    final c = FileListController(
      files: [_f('a.txt'), _f('b.txt'), _f('c.txt')],
      rule: _seq2,
    );
    await _pump(tester, c);
    expect(_yOf(tester, 'a.txt'), lessThan(_yOf(tester, 'b.txt')));

    // 先頭行のハンドルを掴んで下方向へドラッグする。
    final handle = find.byIcon(Icons.drag_handle).first;
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 250));
    await gesture.moveBy(const Offset(0, 60));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 60));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(c.sortMode, FileSortMode.custom);
    // 先頭の a.txt が動いた(もう最上段ではない)。
    expect(c.items.first.name, isNot('a.txt'));
  });

  testWidgets('つまみに触れた瞬間に行の色が変わり、一拍の振動が鳴る(008:T32)', (tester) async {
    // **動かし始めるまで待たない**(2026-09-19 の2回目の実機確認)。Flutter の
    // 並び替えは「触れてから約18px 動いた時点」でドラッグ開始と判定するので、
    // `proxyDecorator` だけでは色が遅れる。つまみは触れた瞬間からもう動かせる。
    final haptics = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add('${call.arguments}');
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final c = FileListController(
      files: [_f('a.txt'), _f('b.txt')],
      rule: _seq2,
    );
    await _pump(tester, c);
    final colors = appDarkTheme().extension<AppColors>()!;
    expect(_rowColor(tester, 'a.txt'), isNot(colors.surface));

    final handle = find.byIcon(Icons.drag_handle).first;
    final gesture = await tester.startGesture(tester.getCenter(handle));
    // **1 frame だけ回す。指はまだ動かしていない。**
    await tester.pump();

    expect(_rowColor(tester, 'a.txt'), colors.surface);
    expect(haptics, hasLength(1));

    // 動かし始めても見た目は変わらない(`proxyDecorator` が同じ色で引き継ぐ)。
    await gesture.moveBy(const Offset(0, 30));
    await tester.pumpAndSettle();
    final dragged = tester.widget<Material>(find.byKey(draggingRowKey));
    expect(dragged.color, colors.surface);
    // **選択モードの選択行とは別の色である。** 同じ色だと「掴んでいる」と
    // 「選んでいる」が読み分けられない(`008:T29` で分けた区別)。
    expect(dragged.color, isNot(colors.selectedSurface));
    // 浮き上がりも残す(面の色を足すだけにする)。
    expect(dragged.elevation, greaterThan(0));

    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.byKey(draggingRowKey), findsNothing);
    expect(_rowColor(tester, 'a.txt'), isNot(colors.surface));
    // **触れている間に1回だけ**(離すまで鳴り続けない)。
    expect(haptics, hasLength(1));
  });

  testWidgets('ドラッグハンドルが各行に表示される', (tester) async {
    final c = FileListController(
      files: [_f('a.txt'), _f('b.txt')],
      rule: _seq2,
    );
    await _pump(tester, c);
    expect(find.byIcon(Icons.drag_handle), findsNWidgets(2));
  });
}
