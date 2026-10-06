// 004 VER-005(008:T56): 一覧の folder 行から、同じ folder を一覧の状態で開き直す(REQ-021)。
//
// 観点: 入口は**一覧の所属 folder が1つのときだけ**出る。開くと所属 folder と一覧の
// ハンドルが渡り、確定は置き換え(REQ-004)で並びは 002 REQ-021 に従う。`Cancelled` は
// 無変化、`Failed`(folder が無い)は無変化のまま理由を通知する。読み込みと同じく
// **開く前に権限を確かめる**(013 REQ-004)。選択モード中は入口を出さない(002 REQ-018)。
//
// browser の起点と初期選択は `storage_browser_view_test.dart`、folder の実在の確認は
// `android_file_source_test.dart` が見る。**実機の見え方は `008:T56` の manual** が引き受ける。
import 'package:batch_rename_master/core/rename_engine.dart';
import 'package:batch_rename_master/data/file_source/file_source.dart';
import 'package:batch_rename_master/data/permission/storage_permission.dart';
import 'package:batch_rename_master/ui/file_list/file_list_controller.dart';
import 'package:batch_rename_master/ui/file_list/file_list_view.dart';
import 'package:batch_rename_master/ui/file_list/file_sort.dart';
import 'package:batch_rename_master/ui/file_list/removal_selection.dart';
import 'package:batch_rename_master/ui/file_source/file_kind.dart';
import 'package:batch_rename_master/ui/file_source/file_source_bar.dart';
import 'package:batch_rename_master/ui/file_source/same_folder_reopen.dart';
import 'package:batch_rename_master/ui/rule_builder/rule_builder_workspace.dart';
import 'package:batch_rename_master/ui/rule_builder/rule_controller.dart';
import 'package:batch_rename_master/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 開き直しを記録し、与えた結果を返す source。
class _ReopenSource implements FileSource, FolderReopenSource {
  _ReopenSource(this.results);

  final List<PickResult> results;
  final List<(String, Set<String>)> reopened = [];

  @override
  Future<PickResult> pickFiles({List<String> mimeTypes = const []}) async =>
      const Cancelled();

  @override
  Future<NameListResult> listNames(String folder) async =>
      NamesListed(const {});

  @override
  Future<PickResult> reopenFolder(
    String folder, {
    required Set<String> selected,
  }) async {
    reopened.add((folder, selected));
    return results.removeAt(0);
  }
}

class _Permission implements StoragePermissionPort {
  _Permission(this.state);

  StoragePermissionState state;
  int checks = 0;

  @override
  Future<StoragePermissionState> check() async {
    checks++;
    return state;
  }

  @override
  Future<bool> openSettings() async => true;
}

FileEntry _f(String name, {String folder = '/A', String? location = '内部/A'}) =>
    FileEntry(
      name: name,
      modifiedAt: DateTime(2026, 1, 1),
      size: 1,
      sourceHandle: '$folder/$name',
      sourceFolder: folder,
      sourceLocation: location,
    );

List<String> _names(FileListController c) =>
    c.items.map((e) => e.name).toList();

final _row = find.byKey(folderRowKey);
final _add = find.byKey(folderRowAddKey);

Future<void> _pump(
  WidgetTester tester, {
  required FileListController controller,
  FileSource? source,
  StoragePermissionPort? permission,
  RemovalSelection? removalSelection,
  bool withEntry = true,
}) async {
  final reopen = SameFolderReopen();
  await tester.pumpWidget(
    MaterialApp(
      theme: appDarkTheme(),
      home: Scaffold(
        body: Column(
          children: [
            FileSourceBar(
              source: source ?? _ReopenSource([]),
              controller: controller,
              permission: permission ?? const UnrestrictedStoragePermission(),
              kinds: FileKind.values,
              removalSelection: removalSelection,
              reopen: reopen,
            ),
            Expanded(
              child: FileListView(
                controller: controller,
                removalSelection: removalSelection,
                onReopen: withEntry ? reopen.call : null,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _tapAdd(WidgetTester tester) async {
  await tester.tap(_add);
  await tester.pumpAndSettle();
}

void main() {
  group('入口を出す条件', () {
    testWidgets('所属folderが1つなら、一覧の先頭にfolder行と「＋ 追加」が出る', (tester) async {
      await _pump(tester, controller: FileListController(files: [_f('a')]));

      expect(_row, findsOneWidget);
      expect(_add.hitTestable(), findsOneWidget);
      expect(
        find.descendant(of: _row, matching: find.text('内部/A')),
        findsOneWidget,
      );
    });

    testWidgets('folder行は一覧の上にあり、スクロールしても残る', (tester) async {
      final c = FileListController(
        files: [for (var i = 0; i < 60; i++) _f('f$i')],
      );
      await _pump(tester, controller: c);
      final before = tester.getTopLeft(_row);

      await tester.drag(
        find.byType(ReorderableListView),
        const Offset(0, -600),
      );
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(_row), before);
      expect(
        tester.getBottomLeft(_row).dy,
        lessThanOrEqualTo(
          tester.getTopLeft(find.byType(ReorderableListView)).dy,
        ),
      );
    });

    testWidgets('所属folderが2つに分かれていれば出さない', (tester) async {
      await _pump(
        tester,
        controller: FileListController(
          files: [
            _f('a'),
            _f('b', folder: '/B', location: '内部/B'),
          ],
        ),
      );

      expect(_row, findsNothing);
    });

    testWidgets('所属folderを持たないitemがあれば出さない', (tester) async {
      await _pump(
        tester,
        controller: FileListController(
          files: [
            _f('a'),
            FileEntry(name: 'x', modifiedAt: DateTime(2026), size: 0),
          ],
        ),
      );

      expect(_row, findsNothing);
    });

    testWidgets('一覧が空なら出さない', (tester) async {
      await _pump(tester, controller: FileListController(files: const []));

      expect(_row, findsNothing);
    });

    testWidgets('開き直せない画面(desktop)では出さない', (tester) async {
      await _pump(
        tester,
        controller: FileListController(files: [_f('a')]),
        withEntry: false,
      );

      expect(_row, findsNothing);
    });

    testWidgets('選択モード中は「＋ 追加」を出さず、行の高さは変えない(002 REQ-018)', (tester) async {
      final selection = RemovalSelection();
      addTearDown(selection.dispose);
      final c = FileListController(files: [_f('a')]);
      final source = _ReopenSource([]);
      await _pump(
        tester,
        controller: c,
        source: source,
        removalSelection: selection,
      );
      final semantics = tester.ensureSemantics();
      final height = tester.getSize(_row).height;
      expect(find.semantics.byLabel('＋ 追加'), findsOneWidget);

      selection.enter();
      await tester.pumpAndSettle();

      expect(_row, findsOneWidget);
      expect(_add.hitTestable(), findsNothing);
      expect(tester.getSize(_row).height, height);
      expect(find.semantics.byLabel('＋ 追加'), findsNothing, reason: '読み上げない');
      semantics.dispose();
    });
  });

  group('開き直して確定する', () {
    testWidgets('代表例 36・37: 所属folderと一覧のハンドルを渡し、確定で置き換える', (tester) async {
      final c = FileListController(files: [_f('a'), _f('b')]);
      final source = _ReopenSource([
        Picked([_f('a'), _f('b'), _f('c')]),
      ]);
      await _pump(tester, controller: c, source: source);

      await _tapAdd(tester);

      expect(source.reopened.single.$1, '/A');
      expect(source.reopened.single.$2, {'/A/a', '/A/b'});
      expect(_names(c), ['a', 'b', 'c']);
      expect(c.selectedCount, 3);
    });

    testWidgets('代表例 38: 外して確定すると一覧から外れる', (tester) async {
      final c = FileListController(files: [_f('a'), _f('b')]);
      final source = _ReopenSource([
        Picked([_f('a'), _f('c')]),
      ]);
      await _pump(tester, controller: c, source: source);

      await _tapAdd(tester);

      expect(_names(c), ['a', 'c']);
    });

    testWidgets('手で並べた一覧は custom のまま、新しいfileが後ろへ入る(002 REQ-021)', (
      tester,
    ) async {
      final c = FileListController(files: [_f('a'), _f('b')])..reorder(1, 0);
      expect(c.sortMode, FileSortMode.custom);
      final source = _ReopenSource([
        Picked([_f('a'), _f('b'), _f('c')]),
      ]);
      await _pump(tester, controller: c, source: source);

      await _tapAdd(tester);

      expect(_names(c), ['b', 'a', 'c']);
      expect(c.sortMode, FileSortMode.custom);
    });

    testWidgets('代表例 39: 閉じたら一覧は変わらず、通知も出ない', (tester) async {
      final c = FileListController(files: [_f('a'), _f('b')]);
      await _pump(
        tester,
        controller: c,
        source: _ReopenSource([const Cancelled()]),
      );

      await _tapAdd(tester);

      expect(_names(c), ['a', 'b']);
      expect(find.byKey(const Key('file-source-error')), findsNothing);
    });

    testWidgets('代表例 42: folderが無ければ一覧を変えずに理由を出す', (tester) async {
      final c = FileListController(files: [_f('a'), _f('b')]);
      await _pump(
        tester,
        controller: c,
        source: _ReopenSource([
          const Failed(PickError(PickErrorKind.io, 'フォルダが見つかりません')),
        ]),
      );

      await _tapAdd(tester);

      expect(_names(c), ['a', 'b']);
      expect(find.byKey(const Key('file-source-error')), findsOneWidget);
      expect(find.textContaining('フォルダが見つかりません'), findsOneWidget);
    });

    testWidgets('行全体のtapでは開かない(`008:T24` の折りたたみのために空ける)', (tester) async {
      final source = _ReopenSource([const Cancelled()]);
      await _pump(
        tester,
        controller: FileListController(files: [_f('a')]),
        source: source,
      );

      await tester.tap(find.byKey(folderRowLabelKey));
      await tester.pumpAndSettle();

      expect(source.reopened, isEmpty);
    });

    testWidgets('権限が無ければ開かず、帯に説明を出す(013 REQ-001 / REQ-004)', (tester) async {
      final c = FileListController(files: [_f('a')]);
      final source = _ReopenSource([const Cancelled()]);
      final permission = _Permission(StoragePermissionState.denied);
      await _pump(
        tester,
        controller: c,
        source: source,
        permission: permission,
      );

      await _tapAdd(tester);

      expect(permission.checks, 1, reason: '開く前に確かめる');
      expect(source.reopened, isEmpty);
      expect(
        find.byKey(const Key('storage-permission-notice')),
        findsOneWidget,
      );
      expect(_names(c), ['a']);
    });

    testWidgets('開き直せないsourceなら何もしない', (tester) async {
      final c = FileListController(files: [_f('a')]);
      await _pump(
        tester,
        controller: c,
        source: FakeFileSource(fileResults: const []),
      );

      await _tapAdd(tester);

      expect(_names(c), ['a']);
      expect(find.byKey(const Key('file-source-error')), findsNothing);
    });
  });

  group('結線', () {
    for (final (label, width) in [('狭幅', 400.0), ('広幅', 1200.0)]) {
      testWidgets('RuleBuilderWorkspace は$labelでも入口を一覧へ渡す', (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        var calls = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: appDarkTheme(),
            home: Scaffold(
              body: RuleBuilderWorkspace(
                fileList: FileListController(files: [_f('a')]),
                rule: RuleController(),
                onReopen: () async => calls++,
              ),
            ),
          ),
        );
        await tester.pump();

        await tester.tap(_add);
        await tester.pump();

        expect(calls, 1);
      });
    }

    testWidgets('代表例 41: 改名した後は、改名後のハンドルで開き直す', (tester) async {
      final c = FileListController(files: [_f('a'), _f('b')]);
      final source = _ReopenSource([const Cancelled()]);
      await _pump(tester, controller: c, source: source);
      // 005 が改名の成功を反映する経路(REQ-018)。
      c.replaceItems({c.items.first: _f('z')});
      await tester.pump();

      await _tapAdd(tester);

      expect(source.reopened.single.$2, {'/A/z', '/A/b'});
    });
  });

  group('soleFolderOf / folderLabelOf', () {
    test('表示用の場所が揃わなければ所属folderのbasename', () {
      final items = [_f('a', location: 'x'), _f('b', location: 'y')];

      expect(soleFolderOf(items), '/A');
      expect(folderLabelOf(items, '/A'), 'A');
    });
  });
}
