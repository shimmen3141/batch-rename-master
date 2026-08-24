// VER-003(T3): UI 入口の検証(REQ-004/REQ-005/REQ-006/REQ-007/REQ-008)。
// 種類選択 → ファイル選択 → リスト置き換え、種類ごとの分岐、
// Cancelled は無変化・通知なし、Failed は無変化のまま理由を通知、除去・全消去。
import 'package:batch_rename_master/core/rename_engine.dart';
import 'package:batch_rename_master/data/file_source/file_source.dart';
import 'package:batch_rename_master/ui/file_list/file_list_controller.dart';
import 'package:batch_rename_master/ui/file_list/file_list_view.dart';
import 'package:batch_rename_master/ui/file_source/file_kind.dart';
import 'package:batch_rename_master/ui/file_source/file_source_bar.dart';
import 'package:batch_rename_master/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:batch_rename_master/data/permission/storage_permission.dart';
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

final _pickFiles = find.byKey(const Key('pick-files-button'));

/// 「ファイルを選ぶ」→ 種類シートで [kind] を選ぶ(新導線。REQ-011)。
Future<void> _pickKind(WidgetTester tester, FileKind kind) async {
  await tester.tap(_pickFiles);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key('file-kind-${kind.name}')));
  await tester.pumpAndSettle();
}

/// 種類「すべて」で読み込む(既定の経路)。
Future<void> _pickAll(WidgetTester tester) => _pickKind(tester, FileKind.all);
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
            FileSourceBar(
              source: source,
              controller: controller,
              permission: const UnrestrictedStoragePermission(),
            ),
            if (withList) Expanded(child: FileListView(controller: controller)),
          ],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('種類「すべて」で選んだ結果がリストになる(REQ-007)', (tester) async {
    final controller = FileListController(files: const []);
    final source = FakeFileSource(
      fileResults: [
        Picked([
          _entry('a.txt', handle: 'h:a'),
          _entry('b.txt', handle: 'h:b'),
        ]),
      ],
    );
    await _pump(tester, source, controller);

    await _pickAll(tester);
    await tester.pumpAndSettle();

    expect(controller.items.map((e) => e.name), ['a.txt', 'b.txt']);
    expect(controller.selectedCount, 2);
  });

  testWidgets('選んだファイルが1件でもリストになる(REQ-007)', (tester) async {
    final controller = FileListController(files: const []);
    final source = FakeFileSource(
      fileResults: [
        Picked([_entry('c.pdf', handle: 'h:c')]),
      ],
    );
    await _pump(tester, source, controller);

    await _pickAll(tester);

    expect(controller.items.map((e) => e.name), ['c.pdf']);
    expect(source.fileCallCount, 1);
  });

  testWidgets('1回の選択に別フォルダのファイルが混ざると、両方載って警告も出る(REQ-004/REQ-012)', (
    tester,
  ) async {
    final controller = FileListController(files: const []);
    final source = FakeFileSource(
      fileResults: [
        Picked([
          _entry('a.txt', handle: 'h:a', location: '写真'),
          _entry('b.txt', handle: 'h:b', location: 'ダウンロード'),
        ]),
      ],
    );
    await _pump(tester, source, controller);

    await _pickAll(tester);

    expect(controller.items.map((e) => e.name), ['a.txt', 'b.txt']);
    expect(controller.items.map((e) => e.sourceLocation), ['写真', 'ダウンロード']);
    expect(find.byKey(const Key('multi-folder-warning')), findsOneWidget);
  });

  testWidgets('Cancelled はリスト無変化・通知なし(REQ-008)', (tester) async {
    final controller = FileListController(
      files: [_entry('keep.txt', handle: 'h:keep')],
    );
    final source = FakeFileSource(fileResults: [const Cancelled()]);
    await _pump(tester, source, controller);

    await _pickAll(tester);
    await tester.pumpAndSettle();

    expect(controller.items.map((e) => e.name), ['keep.txt']);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('Failed はリスト無変化のまま理由を通知する(REQ-008)', (tester) async {
    final controller = FileListController(
      files: [_entry('keep.txt', handle: 'h:keep')],
    );
    final source = FakeFileSource(
      fileResults: [
        const Failed(PickError(PickErrorKind.permissionDenied, 'SAF 拒否')),
      ],
    );
    await _pump(tester, source, controller);

    await _pickAll(tester);
    await tester.pumpAndSettle();

    expect(controller.items.map((e) => e.name), ['keep.txt']);
    expect(find.byKey(const Key('file-source-error')), findsOneWidget);
    expect(find.textContaining('アクセスが許可されませんでした'), findsOneWidget);
    expect(find.textContaining('SAF 拒否'), findsOneWidget);
  });

  testWidgets('IO 失敗はその理由で通知する(REQ-008)', (tester) async {
    final controller = FileListController(files: const []);
    final source = FakeFileSource(
      fileResults: [const Failed(PickError(PickErrorKind.io))],
    );
    await _pump(tester, source, controller);

    await _pickAll(tester);
    await tester.pumpAndSettle();

    expect(find.textContaining('ファイルの読み込みに失敗しました'), findsOneWidget);
  });

  testWidgets('原因不明の失敗もその旨を通知する(REQ-008)', (tester) async {
    final controller = FileListController(files: const []);
    final source = FakeFileSource(
      fileResults: [const Failed(PickError(PickErrorKind.unknown))],
    );
    await _pump(tester, source, controller);

    await _pickAll(tester);
    await tester.pumpAndSettle();

    expect(find.textContaining('ファイルを読み込めませんでした'), findsOneWidget);
  });

  testWidgets('空の Picked(空フォルダ)は無変化でエラーにもならない(REQ-001/REQ-007)', (
    tester,
  ) async {
    final controller = FileListController(files: const []);
    final source = FakeFileSource(fileResults: [const Picked([])]);
    await _pump(tester, source, controller);

    await _pickAll(tester);
    await tester.pumpAndSettle();

    expect(controller.items, isEmpty);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('「すべて外す」でリストが空になる(REQ-006)', (tester) async {
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

  testWidgets('リストが空なら「すべて外す」は無効(T4: 件数に追随)', (tester) async {
    final controller = FileListController(files: const []);
    await _pump(tester, FakeFileSource(), controller);

    expect(tester.widget<TextButton>(_clearFiles).onPressed, isNull);
  });

  testWidgets('ファイルが入ると「すべて外す」が有効になり、外すとまた無効に戻る', (tester) async {
    final controller = FileListController(files: const []);
    final source = FakeFileSource(
      fileResults: [
        Picked([_entry('a.txt', handle: 'h:a')]),
      ],
    );
    await _pump(tester, source, controller);
    expect(tester.widget<TextButton>(_clearFiles).onPressed, isNull);

    await _pickAll(tester);
    await tester.pumpAndSettle();
    expect(tester.widget<TextButton>(_clearFiles).onPressed, isNotNull);

    await tester.tap(_clearFiles);
    await tester.pumpAndSettle();

    expect(controller.items, isEmpty);
    expect(tester.widget<TextButton>(_clearFiles).onPressed, isNull);
  });

  testWidgets('行の×で1件だけリストから外れる(REQ-006)', (tester) async {
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

  testWidgets('種類「画像」「動画」は枠のみで、未実装であることを示す(REQ-011)', (tester) async {
    final controller = FileListController(files: const []);
    final source = FakeFileSource(
      fileResults: [
        Picked([_entry('a.txt', handle: 'h:a')]),
      ],
    );
    await _pump(tester, source, controller);

    await _pickKind(tester, FileKind.image);

    expect(find.byKey(const Key('file-kind-unimplemented')), findsOneWidget);
    expect(find.textContaining('写真機能で対応予定'), findsOneWidget);
    // 読み込みは行われない(ソースも呼ばれない)。
    expect(controller.items, isEmpty);
    expect(source.fileCallCount, 0);
  });

  testWidgets('種類「文書」は MIME フィルタを渡して読み込む(REQ-011)', (tester) async {
    final controller = FileListController(files: const []);
    final source = FakeFileSource(
      fileResults: [
        Picked([_entry('report.pdf', handle: 'h:r')]),
      ],
    );
    await _pump(tester, source, controller);

    await _pickKind(tester, FileKind.document);

    expect(controller.items.map((e) => e.name), ['report.pdf']);
    expect(source.lastMimeTypes, contains('application/pdf'));
  });

  testWidgets('種類「すべて」は絞り込まない(REQ-011)', (tester) async {
    final controller = FileListController(files: const []);
    final source = FakeFileSource(fileResults: [const Picked([])]);
    await _pump(tester, source, controller);

    await _pickAll(tester);

    expect(source.lastMimeTypes, isEmpty);
  });

  testWidgets('例15: 親フォルダが跨る選択は警告する(REQ-012)', (tester) async {
    final controller = FileListController(files: const []);
    final source = FakeFileSource(
      fileResults: [
        Picked([
          _entry('a.txt', handle: 'h:a', location: '写真'),
          _entry('b.txt', handle: 'h:b', location: 'ダウンロード'),
        ]),
      ],
    );
    await _pump(tester, source, controller);

    await _pickAll(tester);

    expect(find.byKey(const Key('multi-folder-warning')), findsOneWidget);
    // 読み込み自体は行う。
    expect(controller.items, hasLength(2));
  });

  testWidgets('例16: 親フォルダが1つだけなら警告しない(REQ-012)', (tester) async {
    final controller = FileListController(files: const []);
    final source = FakeFileSource(
      fileResults: [
        Picked([
          _entry('a.txt', handle: 'h:a', location: '写真'),
          _entry('b.txt', handle: 'h:b', location: '写真'),
        ]),
      ],
    );
    await _pump(tester, source, controller);

    await _pickAll(tester);

    expect(find.byKey(const Key('multi-folder-warning')), findsNothing);
  });

  testWidgets('2回目の選択は前回を残さず置き換える(蓄積しない。REQ-004)', (tester) async {
    final controller = FileListController(files: const []);
    final source = FakeFileSource(
      fileResults: [
        Picked([_entry('a.txt', handle: 'h:a')]),
        Picked([_entry('b.txt', handle: 'h:b')]),
      ],
    );
    await _pump(tester, source, controller);

    await _pickAll(tester);
    await _pickAll(tester);

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
      fileResults: [
        Picked([
          _entry('one.jpg', handle: 'h:1'),
          _entry('two.jpg', handle: 'h:2'),
        ]),
      ],
    );
    await _pump(tester, source, controller, withList: true);

    await _pickAll(tester);
    await tester.pumpAndSettle();

    expect(find.text('one.jpg'), findsOneWidget);
    expect(find.text('IMG_01.jpg'), findsOneWidget);
    expect(find.text('IMG_02.jpg'), findsOneWidget);
  });
}
