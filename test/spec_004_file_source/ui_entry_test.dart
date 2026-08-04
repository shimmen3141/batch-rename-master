// VER-003(T3): UI 入口の検証(REQ-004/005/006/007/008)。
// 「フォルダを開く」「ファイルを選ぶ」で作業セットへ追加、複数回で蓄積、
// Cancelled は無変化・通知なし、Failed は無変化のまま理由を通知、除去・全消去。
import 'package:batch_rename_master/core/rename_engine.dart';
import 'package:batch_rename_master/data/file_source/file_source.dart';
import 'package:batch_rename_master/ui/file_list/file_list_controller.dart';
import 'package:batch_rename_master/ui/file_list/file_list_view.dart';
import 'package:batch_rename_master/ui/file_source/file_source_bar.dart';
import 'package:batch_rename_master/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

FileEntry _entry(String name, {required String handle, String? location}) =>
    FileEntry(
      name: name,
      createdAt: DateTime(2026, 1, 1),
      modifiedAt: DateTime(2026, 1, 2),
      size: 10,
      sourceHandle: handle,
      sourceLocation: location,
    );

final _openFolder = find.byKey(const Key('open-folder-button'));
final _pickFiles = find.byKey(const Key('pick-files-button'));
final _clearFiles = find.byKey(const Key('clear-files-button'));

Future<void> _pump(
  WidgetTester tester,
  FileSource source,
  FileListController controller, {
  bool withList = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: appDarkTheme(),
      home: Scaffold(
        body: Column(
          children: [
            FileSourceBar(source: source, controller: controller),
            if (withList) Expanded(child: FileListView(controller: controller)),
          ],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('「フォルダを開く」で結果が作業セットへ追加される(REQ-007)', (tester) async {
    final controller = FileListController(files: const []);
    final source = FakeFileSource(
      folderResults: [
        Picked([
          _entry('a.txt', handle: 'h:a'),
          _entry('b.txt', handle: 'h:b'),
        ]),
      ],
    );
    await _pump(tester, source, controller);

    await tester.tap(_openFolder);
    await tester.pumpAndSettle();

    expect(controller.items.map((e) => e.name), ['a.txt', 'b.txt']);
    expect(controller.selectedCount, 2);
  });

  testWidgets('「ファイルを選ぶ」でも追加される(REQ-007)', (tester) async {
    final controller = FileListController(files: const []);
    final source = FakeFileSource(
      fileResults: [
        Picked([_entry('c.pdf', handle: 'h:c')]),
      ],
    );
    await _pump(tester, source, controller);

    await tester.tap(_pickFiles);
    await tester.pumpAndSettle();

    expect(controller.items.map((e) => e.name), ['c.pdf']);
    expect(source.fileCallCount, 1);
  });

  testWidgets('複数回押すと別フォルダ分が蓄積され、重複は追加されない(REQ-004)', (tester) async {
    final controller = FileListController(files: const []);
    final source = FakeFileSource(
      folderResults: [
        Picked([_entry('a.txt', handle: 'h:a', location: '写真')]),
        Picked([
          _entry('a.txt', handle: 'h:a', location: '写真'),
          _entry('b.txt', handle: 'h:b', location: 'ダウンロード'),
        ]),
      ],
    );
    await _pump(tester, source, controller);

    await tester.tap(_openFolder);
    await tester.pumpAndSettle();
    await tester.tap(_openFolder);
    await tester.pumpAndSettle();

    expect(controller.items.map((e) => e.name), ['a.txt', 'b.txt']);
    expect(controller.items.map((e) => e.sourceLocation), ['写真', 'ダウンロード']);
  });

  testWidgets('Cancelled は作業セット無変化・通知なし(REQ-008)', (tester) async {
    final controller = FileListController(
      files: [_entry('keep.txt', handle: 'h:keep')],
    );
    final source = FakeFileSource(folderResults: [const Cancelled()]);
    await _pump(tester, source, controller);

    await tester.tap(_openFolder);
    await tester.pumpAndSettle();

    expect(controller.items.map((e) => e.name), ['keep.txt']);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('Failed は作業セット無変化のまま理由を通知する(REQ-008)', (tester) async {
    final controller = FileListController(
      files: [_entry('keep.txt', handle: 'h:keep')],
    );
    final source = FakeFileSource(
      folderResults: [
        const Failed(PickError(PickErrorKind.permissionDenied, 'SAF 拒否')),
      ],
    );
    await _pump(tester, source, controller);

    await tester.tap(_openFolder);
    await tester.pumpAndSettle();

    expect(controller.items.map((e) => e.name), ['keep.txt']);
    expect(find.byKey(const Key('file-source-error')), findsOneWidget);
    expect(find.textContaining('アクセスが許可されませんでした'), findsOneWidget);
    expect(find.textContaining('SAF 拒否'), findsOneWidget);
  });

  testWidgets('IO 失敗はその理由で通知する(REQ-008)', (tester) async {
    final controller = FileListController(files: const []);
    final source = FakeFileSource(
      folderResults: [const Failed(PickError(PickErrorKind.io))],
    );
    await _pump(tester, source, controller);

    await tester.tap(_openFolder);
    await tester.pumpAndSettle();

    expect(find.textContaining('ファイルの読み込みに失敗しました'), findsOneWidget);
  });

  testWidgets('原因不明の失敗もその旨を通知する(REQ-008)', (tester) async {
    final controller = FileListController(files: const []);
    final source = FakeFileSource(
      folderResults: [const Failed(PickError(PickErrorKind.unknown))],
    );
    await _pump(tester, source, controller);

    await tester.tap(_openFolder);
    await tester.pumpAndSettle();

    expect(find.textContaining('ファイルを読み込めませんでした'), findsOneWidget);
  });

  testWidgets('空の Picked(空フォルダ)は無変化でエラーにもならない(REQ-001/007)', (tester) async {
    final controller = FileListController(files: const []);
    final source = FakeFileSource(folderResults: [const Picked([])]);
    await _pump(tester, source, controller);

    await tester.tap(_openFolder);
    await tester.pumpAndSettle();

    expect(controller.items, isEmpty);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('「すべて外す」で作業セットが空になる(REQ-006)', (tester) async {
    final controller = FileListController(
      files: [
        _entry('a.txt', handle: 'h:a'),
        _entry('b.txt', handle: 'h:b'),
      ],
    );
    await _pump(tester, FakeFileSource(), controller);

    await tester.tap(_clearFiles);
    await tester.pumpAndSettle();

    expect(controller.items, isEmpty);
    expect(controller.selectedCount, 0);
  });

  testWidgets('空の作業セットで「すべて外す」を押しても無変化(REQ-006)', (tester) async {
    final controller = FileListController(files: const []);
    var notified = 0;
    controller.addListener(() => notified++);
    await _pump(tester, FakeFileSource(), controller);

    await tester.tap(_clearFiles);
    await tester.pumpAndSettle();

    expect(controller.items, isEmpty);
    expect(notified, 0);
  });

  testWidgets('行の×で1件だけ作業セットから外れる(REQ-006)', (tester) async {
    final controller = FileListController(
      files: [
        _entry('a.txt', handle: 'h:a'),
        _entry('b.txt', handle: 'h:b'),
      ],
    );
    await _pump(tester, FakeFileSource(), controller, withList: true);

    await tester.tap(find.byTooltip('このファイルを外す').first);
    await tester.pumpAndSettle();

    expect(controller.items.map((e) => e.name), ['b.txt']);
  });

  testWidgets('読み込み結果がリストとプレビューに現れる(REQ-007)', (tester) async {
    final controller = FileListController(
      files: const [],
      rule: const RenameRule([
        LiteralToken('IMG_'),
        SequenceToken(start: 1, digits: 2, increment: 1),
      ]),
    );
    final source = FakeFileSource(
      folderResults: [
        Picked([
          _entry('one.jpg', handle: 'h:1'),
          _entry('two.jpg', handle: 'h:2'),
        ]),
      ],
    );
    await _pump(tester, source, controller, withList: true);

    await tester.tap(_openFolder);
    await tester.pumpAndSettle();

    expect(find.text('one.jpg'), findsOneWidget);
    expect(find.text('IMG_01.jpg'), findsOneWidget);
    expect(find.text('IMG_02.jpg'), findsOneWidget);
  });
}
