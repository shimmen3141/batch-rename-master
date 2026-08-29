// 008:T07 行の preview と種別アイコンへの落ち方。
//
// **preview が出せないことは破綻ではない。** 出せないとき・読めなかったとき・
// 供給元が無いときのそれぞれで、行が種別アイコンに落ちて高さも位置も揺れない
// ことを固定する。`013 ADR-002` の退避経路(SAF の document URI)もここに含む。
import 'dart:typed_data';

import 'package:batch_rename_master/core/file_entry.dart';
import 'package:batch_rename_master/data/preview/file_preview.dart';
import 'package:batch_rename_master/ui/file_list/file_list_controller.dart';
import 'package:batch_rename_master/ui/file_list/file_list_view.dart';
import 'package:batch_rename_master/ui/file_list/row_preview_view.dart';
import 'package:batch_rename_master/ui/rule_builder/rule_builder_workspace.dart';
import 'package:batch_rename_master/ui/rule_builder/rule_controller.dart';
import 'package:batch_rename_master/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

FileEntry _entry(String name, {String? handle}) => FileEntry(
  name: name,
  modifiedAt: DateTime(2026, 8, 4, 16),
  size: 0,
  sourceHandle: handle ?? '/storage/emulated/0/DCIM/$name',
);

/// 行に出せる最小の PNG(8x8 の単色)。
///
/// **test の中で作らない。** `testWidgets` は fake async の中で走るので、
/// `Picture.toImage` の Future が完了せず止まる。byte 列を直接持つ。
final _png = Uint8List.fromList([
  137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, //
  0, 0, 0, 8, 0, 0, 0, 8, 8, 2, 0, 0, 0, 75, 109, 41, //
  220, 0, 0, 0, 17, 73, 68, 65, 84, 120, 218, 99, 48, 78, 59, 131, //
  21, 49, 12, 45, 9, 0, 185, 134, 89, 65, 110, 38, 132, 252, 0, 0, //
  0, 0, 73, 69, 78, 68, 174, 66, 96, 130,
]);

Future<void> _pump(
  WidgetTester tester,
  List<FileEntry> files, {
  FilePreviewPort? preview,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: appDarkTheme(),
      home: Scaffold(
        body: FileListView(
          controller: FileListController(files: files),
          filePreview: preview,
        ),
      ),
    ),
  );
  // preview の要求は非同期。応答(microtask)を流してから組み直す。
  //
  // **`pumpAndSettle` を使わない。** `Image.memory` の decode は test の fake async
  // では完了せず、settle を待つと止まる。ここで見たいのは「行に何が置かれたか」
  // であって、絵が decode されたかではない。
  await tester.pump();
  await tester.pump();
}

/// 行の preview 枠の中に出ているアイコン(preview が出ていれば `null`)。
IconData? _iconIn(WidgetTester tester, int index) {
  final icons = find.descendant(
    of: find.byKey(rowPreviewKey).at(index),
    matching: find.byType(Icon),
  );
  if (icons.evaluate().isEmpty) return null;
  return tester.widget<Icon>(icons.first).icon;
}

void main() {
  testWidgets('preview の供給元が無くても行は種別アイコンを出す', (tester) async {
    // demo データや preview を持たない画面。**実 file を触らない。**
    await _pump(tester, [_entry('a.jpg'), _entry('b.pdf')]);

    expect(find.byKey(rowPreviewKey), findsNWidgets(2));
    expect(_iconIn(tester, 0), Icons.image_outlined);
    expect(_iconIn(tester, 1), Icons.description_outlined);
  });

  testWidgets('thumbnail が返れば行に絵が出る', (tester) async {
    await _pump(
      tester,
      [_entry('a.jpg')],
      preview: FakeFilePreview(
        byHandle: {'/storage/emulated/0/DCIM/a.jpg': PreviewReady(_png)},
      ),
    );

    expect(find.byType(Image), findsOneWidget);
    // 絵が出ている行にはアイコンを重ねない。
    expect(_iconIn(tester, 0), isNull);
  });

  testWidgets('対象外の file は種別アイコンへ落ちる', (tester) async {
    await _pump(
      tester,
      [_entry('report.pdf')],
      preview: FakeFilePreview(
        fallback: const PreviewUnsupported('preview を出さない種別'),
      ),
    );

    expect(find.byType(Image), findsNothing);
    expect(_iconIn(tester, 0), Icons.description_outlined);
  });

  testWidgets('読めなかった file は対象外と別のアイコンになる', (tester) async {
    await _pump(tester, [
      _entry('broken.jpg'),
    ], preview: FakeFilePreview(fallback: const PreviewFailed('壊れている')));

    // **画像アイコンではない。** 読めなかったことを、preview の無い file と
    // 同じ見た目にしない(型で分けた区別が画面まで残っている)。
    expect(_iconIn(tester, 0), Icons.broken_image_outlined);
    expect(_iconIn(tester, 0), isNot(Icons.image_outlined));
  });

  testWidgets('preview の有無で行の高さが変わらない', (tester) async {
    await _pump(
      tester,
      [_entry('withPreview.jpg'), _entry('noPreview.pdf')],
      preview: FakeFilePreview(
        byHandle: {
          '/storage/emulated/0/DCIM/withPreview.jpg': PreviewReady(_png),
        },
        fallback: const PreviewUnsupported('対象外'),
      ),
    );

    final first = tester.getSize(find.byKey(rowPreviewKey).at(0));
    final second = tester.getSize(find.byKey(rowPreviewKey).at(1));
    expect(first, second);
  });

  testWidgets('退避中(SAF の document URI)の行は種別アイコンへ落ちる', (tester) async {
    // 013 ADR-002 の退避先。**行は静かに種別アイコンへ落ちる。**
    //
    // 「読みに行かない」こと自体は port 側の責務で、
    // `test/preview/file_preview_test.dart` が検査している。ここが見るのは
    // 「対象外が返ったとき行がどうなるか」だけである。
    final preview = FakeFilePreview(
      fallback: const PreviewUnsupported('元場所ハンドルが path ではない'),
    );
    await _pump(tester, [
      _entry(
        'a.jpg',
        handle: 'content://com.android.externalstorage.documents/doc/1',
      ),
    ], preview: preview);

    expect(_iconIn(tester, 0), Icons.image_outlined);
    expect(find.byType(Image), findsNothing);
  });

  // **production が通る合成を test も通す。** `main.dart` は
  // `RuleBuilderWorkspace` へ port を渡し、そこから `FileListView` へ流れる。
  // 途中で渡し忘れても行は種別アイコンで「それらしく」見えるため、
  // 出力を見るだけでは気付けない(013:T05 で3回FAILしたのと同じ型)。
  //
  // **狭い側と広い側は別の分岐である。** `RuleBuilderWorkspace` は幅 840 を境に
  // `_buildNarrow` と `_buildWide` を切り替え、`FileListView` を**それぞれが別々に
  // 組み立てる**。片方だけ通しても、もう片方の渡し忘れは検出できない。
  for (final (label, size) in [
    ('狭い画面', Size(400, 800)),
    ('広い画面(2ペイン)', Size(1200, 800)),
  ]) {
    testWidgets('$label の合成経路(RuleBuilderWorkspace 越し)でも行に preview が届く', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final rule = RuleController();
      addTearDown(rule.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appDarkTheme(),
          home: Scaffold(
            body: RuleBuilderWorkspace(
              fileList: FileListController(files: [_entry('a.jpg')]),
              rule: rule,
              filePreview: FakeFilePreview(
                byHandle: {
                  '/storage/emulated/0/DCIM/a.jpg': PreviewReady(_png),
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(Image), findsOneWidget);
    });
  }

  testWidgets('要求中に行が外れても、届いた応答で作り直そうとしない', (tester) async {
    // scroll で行が捨てられた後に応答が届く経路。`setState() called after
    // dispose()` になると、その後の frame が組めなくなる。
    final port = FakeFilePreview(
      byHandle: {'/storage/emulated/0/DCIM/a.jpg': PreviewReady(_png)},
    )..hold = true;

    await tester.pumpWidget(
      MaterialApp(
        theme: appDarkTheme(),
        home: Scaffold(
          body: RowPreviewView(file: _entry('a.jpg'), preview: port),
        ),
      ),
    );
    await tester.pump();

    // 行が一覧から消える。
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
    );
    await tester.pump();

    // **その後で**応答が届く。
    port.release();
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('同じ枠が別の file を指したら、前の file の応答は捨てる', (tester) async {
    // `RowPreviewView` 自身の契約。一覧の行は `ValueKey(row.source)` を持つので
    // file が変わると State ごと作り直されるが、**この widget は枠を使い回された
    // ときも正しく振る舞う**必要がある(`T13` は browser の行で使う)。
    final port = FakeFilePreview(
      byHandle: {'/storage/emulated/0/DCIM/first.jpg': PreviewReady(_png)},
      fallback: const PreviewUnsupported('二つ目には preview が無い'),
    )..hold = true;

    Future<void> pumpFor(FileEntry file) => tester.pumpWidget(
      MaterialApp(
        theme: appDarkTheme(),
        home: Scaffold(
          // key を固定して State を使い回させる(didUpdateWidget の経路)。
          body: RowPreviewView(
            key: const ValueKey('fixed'),
            file: file,
            preview: port,
          ),
        ),
      ),
    );

    await pumpFor(_entry('first.jpg'));
    await tester.pump();

    // 二つ目は**すぐ返す**。両方を同時に返すと後勝ちで二つ目が上書きし、
    // guard が無くても通ってしまう(順序を作らないと検査にならない)。
    port.hold = false;
    await pumpFor(_entry('second.pdf'));
    await tester.pump();
    await tester.pump();
    expect(_iconIn(tester, 0), Icons.description_outlined);

    // **その後で**一つ目の要求の応答(絵あり)が遅れて届く。
    port.release();
    await tester.pump();
    await tester.pump();

    // 一つ目の絵を二つ目の枠へ描いていない。
    expect(find.byType(Image), findsNothing);
    expect(_iconIn(tester, 0), Icons.description_outlined);
  });
}
