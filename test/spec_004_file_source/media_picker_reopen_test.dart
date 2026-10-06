// 004 VER-005(010:T09): 一覧の読み込み元(REQ-024)。
//
// 観点: 写真・動画の選択画面から読み込んだ一覧では、帯が「写真・動画」を示し、一覧の
// 先頭の行が**選択画面を**一覧のハンドルを選択済みにして開き直す(REQ-021 の browser の
// 入口は出さない)。確定は置き換え(REQ-004)で並びは 002 REQ-021、`Cancelled` は無変化、
// 選択モード中は入口を出さない(002 REQ-018)。「すべて」で読み込み直すと browser の
// 規則に戻る。一覧が空の間は読み込み元が無い。
//
// 選択画面の始まり方(選択済み・全件・並ばないものを外す)は `media_picker_view_test.dart`、
// browser の開き直しそのものは `same_folder_reopen_test.dart` が見る。**MediaStore の
// 改名後の path と実際の開き直しは `010:T09` の manual** が引き受ける。
import 'package:batch_rename_master/core/rename_engine.dart';
import 'package:batch_rename_master/data/file_source/file_source.dart';
import 'package:batch_rename_master/data/permission/storage_permission.dart';
import 'package:batch_rename_master/ui/file_list/file_list_controller.dart';
import 'package:batch_rename_master/ui/file_list/file_list_view.dart';
import 'package:batch_rename_master/ui/file_list/file_sort.dart';
import 'package:batch_rename_master/ui/file_list/removal_selection.dart';
import 'package:batch_rename_master/ui/file_source/file_kind.dart';
import 'package:batch_rename_master/ui/file_source/file_source_bar.dart';
import 'package:batch_rename_master/ui/file_source/list_origin.dart';
import 'package:batch_rename_master/ui/file_source/same_folder_reopen.dart';
import 'package:batch_rename_master/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Android の source(browser・開き直し・写真・動画の選択画面)。呼ばれた操作を記録し、
/// 与えた結果を順に返す。
class _AndroidSource
    implements FileSource, FolderReopenSource, MediaPickSource {
  _AndroidSource({
    List<PickResult> files = const [],
    List<PickResult> media = const [],
    List<PickResult> reopen = const [],
  }) : _files = [...files],
       _media = [...media],
       _reopen = [...reopen];

  final List<PickResult> _files;
  final List<PickResult> _media;
  final List<PickResult> _reopen;

  /// 選択画面を開いたときの初期選択(開いた回数分)。
  final List<Set<String>> mediaOpened = [];
  final List<(String, Set<String>)> folderReopened = [];

  @override
  Future<PickResult> pickFiles({List<String> mimeTypes = const []}) async =>
      _files.isEmpty ? const Cancelled() : _files.removeAt(0);

  @override
  Future<PickResult> pickMedia({Set<String> selected = const {}}) async {
    mediaOpened.add(selected);
    return _media.isEmpty ? const Cancelled() : _media.removeAt(0);
  }

  @override
  Future<PickResult> reopenFolder(
    String folder, {
    required Set<String> selected,
  }) async {
    folderReopened.add((folder, selected));
    return _reopen.isEmpty ? const Cancelled() : _reopen.removeAt(0);
  }

  @override
  Future<NameListResult> listNames(String folder) async =>
      NamesListed(const {});
}

class _DeniedPermission implements StoragePermissionPort {
  int checks = 0;

  @override
  Future<StoragePermissionState> check() async {
    checks++;
    return StoragePermissionState.denied;
  }

  @override
  Future<bool> openSettings() async => true;
}

/// 代表例 55 の a(`DCIM/Camera`)・b(`Pictures/Screenshots`)・c(`Download`)と、
/// 「すべて」で読み込む `/A` の e。
FileEntry _f(String folder, String name, String location) => FileEntry(
  name: name,
  modifiedAt: DateTime(2026, 10, 5),
  size: 1,
  sourceHandle: '$folder/$name',
  sourceFolder: folder,
  sourceLocation: location,
);

final _a = _f('/s/DCIM/Camera', 'a.jpg', '内部/DCIM/Camera');
final _b = _f('/s/Pictures/Screenshots', 'b.png', '内部/Pictures/Screenshots');
final _c = _f('/s/Download', 'c.mp4', '内部/Download');
final _e = _f('/s/A', 'e.txt', '内部/A');

List<String> _names(FileListController c) =>
    c.items.map((e) => e.name).toList();

final _row = find.byKey(folderRowKey);
final _add = find.byKey(folderRowAddKey);

String _barLabel(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(sourceLocationLabelKey)).data!;

String _rowLabel(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(folderRowLabelKey)).data!;

class _Harness {
  _Harness(this.controller) : origin = ListOriginState(controller);

  final FileListController controller;
  final ListOriginState origin;
}

Future<_Harness> _pump(
  WidgetTester tester, {
  required _AndroidSource source,
  List<FileEntry> files = const [],
  StoragePermissionPort permission = const UnrestrictedStoragePermission(),
  RemovalSelection? removalSelection,
}) async {
  final harness = _Harness(FileListController(files: files));
  addTearDown(harness.origin.dispose);
  final reopen = SameFolderReopen();
  await tester.pumpWidget(
    MaterialApp(
      theme: appDarkTheme(),
      home: Scaffold(
        body: Column(
          children: [
            FileSourceBar(
              source: source,
              controller: harness.controller,
              permission: permission,
              kinds: const [FileKind.media, FileKind.all],
              removalSelection: removalSelection,
              reopen: reopen,
              listOrigin: harness.origin,
            ),
            Expanded(
              child: FileListView(
                controller: harness.controller,
                removalSelection: removalSelection,
                onReopen: reopen.call,
                listOrigin: harness.origin,
              ),
            ),
          ],
        ),
      ),
    ),
  );
  return harness;
}

/// 帯から種類を選んで読み込む。
Future<void> _load(WidgetTester tester, FileKind kind) async {
  await tester.tap(find.byKey(const Key('pick-files-button')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key('file-kind-${kind.name}')));
  await tester.pumpAndSettle();
}

Future<void> _tapAdd(WidgetTester tester) async {
  await tester.tap(_add);
  await tester.pumpAndSettle();
}

void main() {
  group('帯と入口', () {
    testWidgets('例56: 写真・動画から folder をまたいで読み込むと、帯は「写真・動画」で警告は出ない', (
      tester,
    ) async {
      final h = await _pump(
        tester,
        source: _AndroidSource(
          media: [
            Picked([_a, _b]),
          ],
        ),
      );

      await _load(tester, FileKind.media);

      expect(_names(h.controller), ['a.jpg', 'b.png']);
      expect(h.origin.current, ListOrigin.mediaPicker);
      expect(_barLabel(tester), '写真・動画');
      expect(find.text('複数のフォルダ'), findsNothing);
      expect(find.byKey(const Key('multi-folder-warning')), findsNothing);
      // 所属 folder が2つでも、選択画面を開き直す入口は出る。
      expect(_row, findsOneWidget);
      expect(_rowLabel(tester), '写真・動画');
      expect(_add.hitTestable(), findsOneWidget);
    });

    testWidgets('例64: 所属 folder が1つでも、帯は「写真・動画」で、入口は選択画面を開く(browser は開かない)', (
      tester,
    ) async {
      final source = _AndroidSource(
        media: [
          Picked([_a]),
        ],
      );
      await _pump(tester, source: source);

      await _load(tester, FileKind.media);
      expect(_barLabel(tester), '写真・動画');
      expect(_rowLabel(tester), '写真・動画', reason: 'folder 名の行(REQ-021)ではない');

      await _tapAdd(tester);

      expect(source.mediaOpened, hasLength(2));
      expect(source.folderReopened, isEmpty);
    });

    testWidgets('例66: 「すべて」で読み込み直すと、帯は folder 名で、入口は browser を開く', (
      tester,
    ) async {
      final source = _AndroidSource(
        media: [
          Picked([_a, _b]),
        ],
        files: [
          Picked([_e]),
        ],
      );
      final h = await _pump(tester, source: source);
      await _load(tester, FileKind.media);

      await _load(tester, FileKind.all);

      expect(_names(h.controller), ['e.txt']);
      expect(h.origin.current, ListOrigin.browser);
      expect(_barLabel(tester), '内部/A');
      expect(_rowLabel(tester), '内部/A');

      await _tapAdd(tester);

      expect(source.folderReopened.single.$1, '/s/A');
      expect(source.mediaOpened, hasLength(1), reason: '読み込んだ1回だけ');
    });

    testWidgets('「すべて」から読み込んだ複数フォルダの一覧は、従来どおり「複数のフォルダ」で入口は無い', (tester) async {
      final h = await _pump(
        tester,
        source: _AndroidSource(
          files: [
            Picked([_a, _b]),
          ],
        ),
      );

      await _load(tester, FileKind.all);

      expect(h.origin.current, ListOrigin.browser);
      expect(_barLabel(tester), '複数のフォルダ');
      expect(_row, findsNothing);
    });

    testWidgets('選択画面を閉じた(Cancelled)だけでは、読み込み元は変わらない', (tester) async {
      final h = await _pump(
        tester,
        source: _AndroidSource(
          files: [
            Picked([_e]),
          ],
        ),
      );
      await _load(tester, FileKind.all);

      await _load(tester, FileKind.media);

      expect(_names(h.controller), ['e.txt']);
      expect(h.origin.current, ListOrigin.browser);
      expect(_barLabel(tester), '内部/A');
    });

    testWidgets('選択モード中は「＋ 追加」を出さず、行は残す(002 REQ-018)', (tester) async {
      final selection = RemovalSelection();
      addTearDown(selection.dispose);
      await _pump(
        tester,
        source: _AndroidSource(
          media: [
            Picked([_a, _b]),
          ],
        ),
        removalSelection: selection,
      );
      await _load(tester, FileKind.media);
      final height = tester.getSize(_row).height;

      selection.enter();
      await tester.pumpAndSettle();

      expect(_row, findsOneWidget);
      expect(_add.hitTestable(), findsNothing);
      expect(tester.getSize(_row).height, height);
    });

    testWidgets('一覧が空になると読み込み元は無く、帯は「未選択」で入口も無い', (tester) async {
      final h = await _pump(
        tester,
        source: _AndroidSource(
          media: [
            Picked([_a, _b]),
          ],
        ),
      );
      await _load(tester, FileKind.media);
      final before = h.controller.items.toList();

      h.controller.clearFiles();
      await tester.pumpAndSettle();

      expect(h.origin.current, isNull);
      expect(_barLabel(tester), '未選択');
      expect(_row, findsNothing);

      // 除去の取り消し(002 REQ-017)は読み込みではない。戻った一覧の読み込み元は
      // 最後に置き換えた読み込み(写真・動画)のまま。
      h.controller.restoreFiles(
        before,
        sortMode: FileSortMode.name,
        sortDirection: SortDirection.ascending,
      );
      await tester.pumpAndSettle();

      expect(h.origin.current, ListOrigin.mediaPicker);
      expect(_barLabel(tester), '写真・動画');
    });

    testWidgets('選択画面で何も選ばずに確定した(空の Picked)なら、読み込み元は無い', (tester) async {
      final h = await _pump(
        tester,
        source: _AndroidSource(media: [const Picked([])]),
        files: [_e],
      );

      await _load(tester, FileKind.media);

      expect(h.controller.items, isEmpty);
      expect(h.origin.current, isNull);
      expect(_barLabel(tester), '未選択');
    });
  });

  group('選択画面を開き直して確定する', () {
    testWidgets('例61: 一覧のハンドルを選択済みにして開き、確定で置き換える', (tester) async {
      final source = _AndroidSource(
        media: [
          Picked([_a, _b]),
          Picked([_a, _b, _c]),
        ],
      );
      final h = await _pump(tester, source: source);
      await _load(tester, FileKind.media);

      await _tapAdd(tester);

      expect(source.mediaOpened.last, {_a.sourceHandle, _b.sourceHandle});
      expect(_names(h.controller), ['a.jpg', 'b.png', 'c.mp4']);
      expect(h.controller.selectedCount, 3);
      expect(h.origin.current, ListOrigin.mediaPicker);
      expect(_barLabel(tester), '写真・動画');
      expect(find.byKey(const Key('multi-folder-warning')), findsNothing);
    });

    testWidgets('例62: 閉じたら一覧は変わらず、通知も出ない', (tester) async {
      final h = await _pump(
        tester,
        source: _AndroidSource(
          media: [
            Picked([_a, _b]),
            const Cancelled(),
          ],
        ),
      );
      await _load(tester, FileKind.media);

      await _tapAdd(tester);

      expect(_names(h.controller), ['a.jpg', 'b.png']);
      expect(find.byKey(const Key('file-source-error')), findsNothing);
    });

    testWidgets('並ばなくなったファイルは、確定すると一覧から外れる', (tester) async {
      final h = await _pump(
        tester,
        source: _AndroidSource(
          media: [
            Picked([_a, _b]),
            Picked([_b]),
          ],
        ),
      );
      await _load(tester, FileKind.media);

      await _tapAdd(tester);

      expect(_names(h.controller), ['b.png']);
    });

    testWidgets('手で並べた一覧は custom のまま、新しいファイルが後ろへ入る(002 REQ-021)', (
      tester,
    ) async {
      final h = await _pump(
        tester,
        source: _AndroidSource(
          media: [
            Picked([_a, _b]),
            Picked([_a, _b, _c]),
          ],
        ),
      );
      await _load(tester, FileKind.media);
      h.controller.reorder(1, 0);
      expect(h.controller.sortMode, FileSortMode.custom);

      await _tapAdd(tester);

      expect(_names(h.controller), ['b.png', 'a.jpg', 'c.mp4']);
      expect(h.controller.sortMode, FileSortMode.custom);
    });

    testWidgets('例63: 改名した後は、改名後のハンドルで開き直す', (tester) async {
      final source = _AndroidSource(
        media: [
          Picked([_a, _b]),
        ],
      );
      final h = await _pump(tester, source: source);
      await _load(tester, FileKind.media);
      // 005 が改名の成功を反映する経路(REQ-018)。
      final z = _f('/s/DCIM/Camera', 'z.jpg', '内部/DCIM/Camera');
      h.controller.replaceItems({
        h.controller.items.firstWhere((e) => e.name == 'a.jpg'): z,
      });
      await tester.pump();

      await _tapAdd(tester);

      expect(source.mediaOpened.last, {z.sourceHandle, _b.sourceHandle});
    });

    testWidgets('失敗したら一覧を変えずに理由を出す(REQ-008)', (tester) async {
      final h = await _pump(
        tester,
        source: _AndroidSource(
          media: [
            Picked([_a, _b]),
            const Failed(PickError(PickErrorKind.unknown, '写真・動画の選択画面を開けません')),
          ],
        ),
      );
      await _load(tester, FileKind.media);

      await _tapAdd(tester);

      expect(_names(h.controller), ['a.jpg', 'b.png']);
      expect(find.byKey(const Key('file-source-error')), findsOneWidget);
    });

    testWidgets('権限が無ければ開かず、帯に説明を出す(013 REQ-001 / REQ-004)', (tester) async {
      final source = _AndroidSource();
      final permission = _DeniedPermission();
      final h = await _pump(tester, source: source, permission: permission);
      // 権限を確かめずに一覧を置いた状態を作る(読み込みの後で取り消された場合)。
      h.origin.record(ListOrigin.mediaPicker);
      h.controller.setFiles([_a, _b]);
      await tester.pumpAndSettle();

      await _tapAdd(tester);

      expect(permission.checks, 1, reason: '開く前に確かめる');
      expect(source.mediaOpened, isEmpty);
      expect(
        find.byKey(const Key('storage-permission-notice')),
        findsOneWidget,
      );
    });
  });
}
