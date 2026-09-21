import 'dart:ui' show SemanticsAction;

// 004 VER-005: app 内 file browser(REQ-015〜REQ-020)。
//
// 観点: 保存場所から始まり、既知の場所への近道を示し、階層を辿れる。現在地を常に
// 示し、上位へ戻れるが**保存場所の root より上へは辿れない**。選択は同一フォルダ内に
// 限り、移動すると解除される。entry は絞り込まずにそのまま並ぶ。
//
// **`test/spec_004_file_source/` に置く。** 004 spec の VER-005 が成果物を
// 「ディレクトリ + 種別」で指定しており、そこが規範側の locator である
// (独立review attempt 1 の P1-3)。port の実装は
// `android_storage_browser_test.dart` が見る。
//
// 一覧を port にしてあるので、階層も失敗も Linux 上で再現できる。
// **実機の mount 構成と実際の書き込み可否は `013:T08`** が引き受ける
// (`task.md` の宣言表)。
import 'package:batch_rename_master/data/file_source/android_file_source.dart';
import 'package:batch_rename_master/data/file_source/file_source.dart';
import 'package:batch_rename_master/data/file_source/storage_browser.dart';
import 'package:batch_rename_master/ui/file_source/file_kind.dart';
import 'package:batch_rename_master/ui/file_source/storage_browser_view.dart';
import 'package:batch_rename_master/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// folder -> entry の対応で階層を作る fake。
class _FakeBrowser implements StorageBrowserPort {
  _FakeBrowser({
    required this.tree,
    this.locationList = const [
      StorageLocation(name: '内部ストレージ', root: '/storage/emulated/0'),
    ],
    this.shortcutNames = const [],
    this.failures = const {},
    this.locationsFailure,
  });

  final Map<String, List<BrowserEntry>> tree;
  final List<StorageLocation> locationList;
  final List<String> shortcutNames;
  final Set<String> failures;

  /// 保存場所の一部を取得できなかったときの理由(`013:T12`)。
  final String? locationsFailure;

  final List<String> listed = [];

  @override
  Future<StorageLocations> locations() async =>
      StorageLocations(locationList, failure: locationsFailure);

  @override
  Future<List<BrowserEntry>> shortcuts(StorageLocation location) async => [
    for (final name in shortcutNames)
      BrowserEntry(
        name: name,
        path: '${location.root}/$name',
        isDirectory: true,
      ),
  ];

  @override
  Future<DirectoryListing> list(String folder) async {
    listed.add(folder);
    if (failures.contains(folder)) {
      return const DirectoryListingFailed(
        PickError(PickErrorKind.permissionDenied, '読めません'),
      );
    }
    return DirectoryListed(tree[folder] ?? const []);
  }
}

BrowserEntry _file(String folder, String name) =>
    BrowserEntry(name: name, path: '$folder/$name', isDirectory: false);

BrowserEntry _dir(String folder, String name) =>
    BrowserEntry(name: name, path: '$folder/$name', isDirectory: true);

/// 確定した選択を受け取る箱。`_open` の戻り値では push の完了を待てない。
class _Result {
  BrowserSelection? value;
  bool closed = false;
}

Future<_Result> _open(WidgetTester tester, StorageBrowserPort browser) async {
  final result = _Result();
  await tester.pumpWidget(
    MaterialApp(
      theme: appDarkTheme(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              key: const Key('open-browser'),
              onPressed: () async {
                result.value = await Navigator.of(context)
                    .push<BrowserSelection>(
                      MaterialPageRoute(
                        builder: (_) => StorageBrowserView(browser: browser),
                      ),
                    );
                result.closed = true;
              },
              child: const Text('開く'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('open-browser')));
  await tester.pumpAndSettle();
  return result;
}

Future<TestGesture> _startLongPress(WidgetTester tester, Finder target) async {
  final gesture = await tester.startGesture(tester.getCenter(target));
  await tester.pump(const Duration(milliseconds: 600));
  return gesture;
}

String _selectedCount(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('browser-selected-count'))).data!;

const _root = '/storage/emulated/0';

void main() {
  group('004 REQ-011: 種類はplatformで異なる', () {
    // **Android に「文書」は出さない** — app 内 browser には MIME filter の手段が
    // 無く、拡張子で絞る判定を新設しない(REQ-017)。
    test('Android は3つで、文書を含まない', () {
      expect(fileKindsFor(isAndroid: true), [
        FileKind.image,
        FileKind.video,
        FileKind.all,
      ]);
    });

    test('desktop は4つで、文書を含む(013 は desktop を変えない)', () {
      expect(fileKindsFor(isAndroid: false), [
        FileKind.image,
        FileKind.video,
        FileKind.document,
        FileKind.all,
      ]);
    });
  });

  group('REQ-015: 保存場所から始まり、近道を示し、階層を辿れる', () {
    testWidgets('保存場所の一覧が出て、選ぶと中身と近道が出る', (tester) async {
      final browser = _FakeBrowser(
        tree: {
          _root: [_dir(_root, 'A'), _file(_root, 'memo.txt')],
        },
        locationList: const [
          StorageLocation(name: '内部ストレージ', root: _root),
          StorageLocation(name: 'SD カード', root: '/storage/1A2B'),
        ],
        shortcutNames: const ['Download', 'DCIM'],
      );
      await _open(tester, browser);

      expect(find.byKey(const Key('browser-location-内部ストレージ')), findsOneWidget);
      expect(find.byKey(const Key('browser-location-SD カード')), findsOneWidget);

      await tester.tap(find.byKey(const Key('browser-location-内部ストレージ')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('browser-shortcut-Download')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('browser-shortcut-DCIM')), findsOneWidget);
      expect(find.byKey(const Key('browser-folder-A')), findsOneWidget);
      expect(find.byKey(const Key('browser-file-memo.txt')), findsOneWidget);
    });

    testWidgets('辿ったfolderごとに、表示用の場所を知らせる(004 REQ-009)', (tester) async {
      // 行の「場所」に使う。**保存場所名だけにすると、どのfolderから読み込んでも
      // 同じ表示になる**(独立review attempt 2 のP2-1)。root のときは保存場所名、
      // その下では「保存場所名/相対path」。
      final named = <String, String>{};
      final browser = _FakeBrowser(
        tree: {
          _root: [_dir(_root, 'DCIM')],
          '$_root/DCIM': [_dir('$_root/DCIM', 'Camera')],
          '$_root/DCIM/Camera': [_file('$_root/DCIM/Camera', 'p.jpg')],
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: appDarkTheme(),
          home: StorageBrowserView(
            browser: browser,
            onLocationName: (folder, name) => named[folder] = name,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('browser-location-内部ストレージ')));
      await tester.pumpAndSettle();
      expect(named[_root], '内部ストレージ');

      await tester.tap(find.byKey(const Key('browser-folder-DCIM')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('browser-folder-Camera')));
      await tester.pumpAndSettle();

      expect(named['$_root/DCIM'], '内部ストレージ/DCIM');
      expect(
        named['$_root/DCIM/Camera'],
        '内部ストレージ/DCIM/Camera',
        reason: '辿った先ごとに違う値になる',
      );
    });

    testWidgets('近道は保存場所の始まりだけに出す', (tester) async {
      // 004 REQ-015 は「保存場所の一覧から始まり、既知の場所への**近道**を示し、
      // そこからフォルダ階層を辿れる」と定めている。**辿った先にも出すと、
      // どこにいるのか分からなくなる。**
      final browser = _FakeBrowser(
        tree: {
          _root: [_dir(_root, 'A')],
          '$_root/A': [_file('$_root/A', 'a.txt')],
        },
        shortcutNames: const ['Download'],
      );
      final _ = await _open(tester, browser);
      await tester.tap(find.byKey(const Key('browser-location-内部ストレージ')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('browser-shortcut-Download')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('browser-folder-A')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('browser-shortcut-Download')), findsNothing);
    });

    testWidgets('現在地を常に示し、階層を辿ると更新される', (tester) async {
      final browser = _FakeBrowser(
        tree: {
          _root: [_dir(_root, 'A')],
          '$_root/A': [_file('$_root/A', 'a.txt')],
        },
      );
      await _open(tester, browser);
      await tester.tap(find.byKey(const Key('browser-location-内部ストレージ')));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Text>(find.byKey(const Key('browser-current-location')))
            .data,
        '内部ストレージ',
      );

      await tester.tap(find.byKey(const Key('browser-folder-A')));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Text>(find.byKey(const Key('browser-current-location')))
            .data,
        '内部ストレージ/A',
      );
      expect(find.byKey(const Key('browser-file-a.txt')), findsOneWidget);
    });

    testWidgets('rootでは「上へ」を出さない(004 代表例 26d)', (tester) async {
      // **上位へ戻る操作は無いか無効。** 代わりに保存場所を選び直す導線を出す
      // (上位 path へ辿るのではない)。
      final browser = _FakeBrowser(
        tree: {
          _root: [_dir(_root, 'A')],
          '$_root/A': [_file('$_root/A', 'a.txt')],
        },
      );
      final _ = await _open(tester, browser);
      await tester.tap(find.byKey(const Key('browser-location-内部ストレージ')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('browser-up')), findsNothing);
      expect(find.byKey(const Key('browser-locations')), findsOneWidget);

      await tester.tap(find.byKey(const Key('browser-folder-A')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('browser-up')),
        findsOneWidget,
        reason: 'rootの下では出す',
      );
      expect(find.byKey(const Key('browser-locations')), findsNothing);
    });

    testWidgets('上位へ戻れる。保存場所を選び直しても上位pathを辿らない', (tester) async {
      final browser = _FakeBrowser(
        tree: {
          _root: [_dir(_root, 'A')],
          '$_root/A': [_file('$_root/A', 'a.txt')],
        },
      );
      await _open(tester, browser);
      await tester.tap(find.byKey(const Key('browser-location-内部ストレージ')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('browser-folder-A')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('browser-up')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('browser-folder-A')), findsOneWidget);

      // root では保存場所を選び直す導線になる。**上位の path は辿らない。**
      await tester.tap(find.byKey(const Key('browser-locations')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('browser-location-内部ストレージ')), findsOneWidget);
      // **`/storage` を列挙しに行っていない。**
      expect(browser.listed, isNot(contains('/storage')));
      expect(browser.listed, isNot(contains('/')));
    });

    test('辿れる上限は保存場所のrootである(純関数)', () {
      expect(canGoUp(folder: '$_root/A/B', root: _root), isTrue);
      expect(canGoUp(folder: '$_root/A', root: _root), isTrue);
      expect(canGoUp(folder: _root, root: _root), isFalse);
      // root の外は「上へ辿れる」と答えない。
      expect(canGoUp(folder: '/storage', root: _root), isFalse);
      expect(canGoUp(folder: '/', root: _root), isFalse);
    });
  });

  group('REQ-015: 保存場所を取得できなかったことを黙らせない(013:T12)', () {
    testWidgets('**欠落の理由が画面に出る**', (tester) async {
      // 「媒体が無い端末」と「列挙できていない」を利用者が区別できないと、
      // 装着している SD カードが並ばないことに気づけない(`013:T08` の実機観測)。
      await _open(
        tester,
        _FakeBrowser(
          tree: const {_root: []},
          locationList: const [StorageLocation(name: '内部ストレージ', root: _root)],
          locationsFailure: '保存場所を取得できませんでした: EACCES',
        ),
      );

      expect(
        find.byKey(const Key('browser-locations-failure')),
        findsOneWidget,
      );
      expect(find.textContaining('EACCES'), findsOneWidget);
      // **保存場所そのものは出す。** 欠落は全滅ではない。
      expect(find.text('内部ストレージ'), findsOneWidget);
    });

    testWidgets('**port が投げても読み込み中で止まらない**(理由を出す)', (tester) async {
      await _open(tester, _ThrowingBrowser());

      expect(
        find.byKey(const Key('browser-locations-failure')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('browser-loading')), findsNothing);
    });

    testWidgets('取得できていれば出さない', (tester) async {
      await _open(tester, _FakeBrowser(tree: const {_root: []}));

      expect(find.byKey(const Key('browser-locations-failure')), findsNothing);
    });
  });

  group('REQ-016: 選択は同一フォルダ内に限る', () {
    testWidgets('フォルダを移動すると選択は解除される', (tester) async {
      final browser = _FakeBrowser(
        tree: {
          _root: [_dir(_root, 'A'), _dir(_root, 'B'), _file(_root, 'r.txt')],
          '$_root/A': [
            _file('$_root/A', 'a1.txt'),
            _file('$_root/A', 'a2.txt'),
          ],
          '$_root/B': [_file('$_root/B', 'b1.txt')],
        },
      );
      await _open(tester, browser);
      await tester.tap(find.byKey(const Key('browser-location-内部ストレージ')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('browser-folder-A')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('browser-file-a1.txt')));
      await tester.tap(find.byKey(const Key('browser-file-a2.txt')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const Key('browser-selected-count')))
            .data,
        '2 件を選択中',
      );

      // `/B` へ移動する。
      await tester.tap(find.byKey(const Key('browser-up')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('browser-folder-B')));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Text>(find.byKey(const Key('browser-selected-count')))
            .data,
        '0 件を選択中',
        reason: '移動で解除される',
      );
      // 確定できるのは `/B` の中だけ。
      expect(find.byKey(const Key('browser-file-b1.txt')), findsOneWidget);
      expect(find.byKey(const Key('browser-file-a1.txt')), findsNothing);
    });

    testWidgets('保存場所を選び直しても選択は残らない', (tester) async {
      final browser = _FakeBrowser(
        tree: {
          _root: [_file(_root, 'r.txt')],
          '/storage/1A2B': [_file('/storage/1A2B', 's.txt')],
        },
        locationList: const [
          StorageLocation(name: '内部ストレージ', root: _root),
          StorageLocation(name: 'SD カード', root: '/storage/1A2B'),
        ],
      );
      final _ = await _open(tester, browser);
      await tester.tap(find.byKey(const Key('browser-location-内部ストレージ')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('browser-file-r.txt')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('browser-locations')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('browser-location-SD カード')));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Text>(find.byKey(const Key('browser-selected-count')))
            .data,
        '0 件を選択中',
      );
    });

    testWidgets('確定すると、選んだfileとその親フォルダが1つ返る', (tester) async {
      final browser = _FakeBrowser(
        tree: {
          _root: [_dir(_root, 'A')],
          '$_root/A': [
            _file('$_root/A', 'a1.txt'),
            _file('$_root/A', 'a2.txt'),
          ],
        },
      );
      final result = await _open(tester, browser);

      await tester.tap(find.byKey(const Key('browser-location-内部ストレージ')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('browser-folder-A')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('browser-file-a1.txt')));
      await tester.tap(find.byKey(const Key('browser-file-a2.txt')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('browser-confirm')));
      await tester.pumpAndSettle();

      final selection = result.value!;
      expect(selection.folder, '$_root/A', reason: '親フォルダは1つ');
      expect(selection.paths, ['$_root/A/a1.txt', '$_root/A/a2.txt']);
    });

    testWidgets('閉じると「決定していない」が返る(004 REQ-001)', (tester) async {
      final browser = _FakeBrowser(
        tree: {
          _root: [_file(_root, 'r.txt')],
        },
      );
      final result = await _open(tester, browser);

      await tester.tap(find.byKey(const Key('browser-location-内部ストレージ')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('browser-file-r.txt')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('browser-cancel')));
      await tester.pumpAndSettle();

      expect(result.closed, isTrue);
      expect(result.value, isNull, reason: '選んでいても、閉じたら確定しない');
    });

    testWidgets('1件も選んでいなければ確定できない', (tester) async {
      final browser = _FakeBrowser(
        tree: {
          _root: [_file(_root, 'r.txt')],
        },
      );
      await _open(tester, browser);
      await tester.tap(find.byKey(const Key('browser-location-内部ストレージ')));
      await tester.pumpAndSettle();

      final confirm = tester.widget<FilledButton>(
        find.byKey(const Key('browser-confirm')),
      );
      expect(confirm.onPressed, isNull);
    });
  });

  group('REQ-020: app内browserの範囲選択と全選択', () {
    testWidgets('全選択は現在folderのfileだけを選び、folderと近道を含めない', (tester) async {
      final browser = _FakeBrowser(
        tree: {
          _root: [
            _dir(_root, 'folder'),
            _file(_root, 'a.txt'),
            _file(_root, 'b.txt'),
          ],
        },
        shortcutNames: const ['Download'],
      );
      final result = await _open(tester, browser);
      await tester.tap(find.byKey(const Key('browser-location-内部ストレージ')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(browserSelectAllKey));
      await tester.pump();
      expect(_selectedCount(tester), '2 件を選択中');

      await tester.tap(find.byKey(const Key('browser-confirm')));
      await tester.pumpAndSettle();
      expect(result.value!.paths, ['$_root/a.txt', '$_root/b.txt']);
      expect(result.value!.paths, isNot(contains('$_root/folder')));
      expect(result.value!.paths, isNot(contains('$_root/Download')));
    });

    testWidgets('全選択は支援技術から操作名とtap actionで実行できる', (tester) async {
      final semantics = tester.ensureSemantics();
      await _open(
        tester,
        _FakeBrowser(
          tree: {
            _root: [_file(_root, 'a.txt'), _file(_root, 'b.txt')],
          },
        ),
      );
      await tester.tap(find.byKey(const Key('browser-location-内部ストレージ')));
      await tester.pumpAndSettle();

      final node = tester.getSemantics(
        find.byKey(browserSelectAllSemanticsKey),
      );
      expect(node.label, 'すべて選択');
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      tester.binding.rootPipelineOwner.semanticsOwner!.performAction(
        node.id,
        SemanticsAction.tap,
      );
      await tester.pump();

      expect(_selectedCount(tester), '2 件を選択中');
      semantics.dispose();
    });

    testWidgets('長押しdragの往復は今回追加したfileだけを解除する', (tester) async {
      await _open(
        tester,
        _FakeBrowser(
          tree: {
            _root: [
              _file(_root, 'a.txt'),
              _file(_root, 'b.txt'),
              _file(_root, 'c.txt'),
            ],
          },
        ),
      );
      await tester.tap(find.byKey(const Key('browser-location-内部ストレージ')));
      await tester.pumpAndSettle();

      final gesture = await _startLongPress(
        tester,
        find.byKey(const Key('browser-file-a.txt')),
      );
      await gesture.moveTo(
        tester.getCenter(find.byKey(const Key('browser-file-b.txt'))),
      );
      await tester.pump();
      await gesture.moveTo(
        tester.getCenter(find.byKey(const Key('browser-file-c.txt'))),
      );
      await tester.pump();
      await gesture.moveTo(
        tester.getCenter(find.byKey(const Key('browser-file-b.txt'))),
      );
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(_selectedCount(tester), '2 件を選択中');
      expect(
        tester
            .widget<CheckboxListTile>(find.byType(CheckboxListTile).at(2))
            .value,
        isFalse,
        reason: 'a→b→c→b の戻りで c だけを解除する',
      );
    });

    testWidgets('drag開始前から選択済みのfileは往復しても保護する', (tester) async {
      await _open(
        tester,
        _FakeBrowser(
          tree: {
            _root: [
              _file(_root, 'a.txt'),
              _file(_root, 'b.txt'),
              _file(_root, 'c.txt'),
            ],
          },
        ),
      );
      await tester.tap(find.byKey(const Key('browser-location-内部ストレージ')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('browser-file-a.txt')));
      await tester.pump();

      final gesture = await _startLongPress(
        tester,
        find.byKey(const Key('browser-file-b.txt')),
      );
      await gesture.moveTo(
        tester.getCenter(find.byKey(const Key('browser-file-c.txt'))),
      );
      await tester.pump();
      await gesture.moveTo(
        tester.getCenter(find.byKey(const Key('browser-file-a.txt'))),
      );
      await tester.pump();
      await gesture.moveTo(
        tester.getCenter(find.byKey(const Key('browser-file-b.txt'))),
      );
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(_selectedCount(tester), '2 件を選択中');
      expect(
        tester
            .widget<CheckboxListTile>(find.byType(CheckboxListTile).at(0))
            .value,
        isTrue,
        reason: 'drag開始前から選ばれていた a は解除しない',
      );
    });

    testWidgets('長押し前の通常scrollはfileを選択しない', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 360));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _open(
        tester,
        _FakeBrowser(
          tree: {
            _root: [for (var i = 0; i < 20; i++) _file(_root, 'scroll-$i.txt')],
          },
        ),
      );
      await tester.tap(find.byKey(const Key('browser-location-内部ストレージ')));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, -180));
      await tester.pumpAndSettle();

      expect(_selectedCount(tester), '0 件を選択中');
    });

    testWidgets('開始行がoffscreenでも中央で止まり、反転して往路の選択を解除する', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 360));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final result = await _open(
        tester,
        _FakeBrowser(
          tree: {
            _root: [for (var i = 0; i < 40; i++) _file(_root, 'long-$i.txt')],
          },
        ),
      );
      await tester.tap(find.byKey(const Key('browser-location-内部ストレージ')));
      await tester.pumpAndSettle();
      final target = find.byKey(const Key('browser-file-long-20.txt'));
      await tester.scrollUntilVisible(
        target,
        120,
        scrollable: find.byType(Scrollable),
      );
      await tester.drag(find.byType(ListView), const Offset(0, 70));
      await tester.pumpAndSettle();

      final gesture = await _startLongPress(tester, target);
      final list = tester.getRect(find.byType(ListView));
      await gesture.moveTo(Offset(list.center.dx, list.top + 2));
      for (var tick = 0; tick < 140; tick++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(target, findsNothing);

      await gesture.moveTo(list.center);
      await tester.pump();
      final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
      final stoppedAt = scrollable.position.pixels;
      for (var tick = 0; tick < 40; tick++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(scrollable.position.pixels, closeTo(stoppedAt, 1));

      await gesture.moveTo(Offset(list.center.dx, list.bottom - 2));
      for (var tick = 0; tick < 180; tick++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pump();
      await tester.tap(find.byKey(const Key('browser-confirm')));
      await tester.pumpAndSettle();

      expect(result.value!.paths, isNot(contains('$_root/long-19.txt')));
      expect(result.value!.paths, contains('$_root/long-21.txt'));
    });
  });

  group('REQ-017: 絞り込まない', () {
    testWidgets('隠しファイルもサブフォルダもそのまま並ぶ', (tester) async {
      final browser = _FakeBrowser(
        tree: {
          _root: [
            _dir(_root, 'sub'),
            _file(_root, '.hidden'),
            _file(_root, 'memo.txt'),
          ],
        },
      );
      await _open(tester, browser);
      await tester.tap(find.byKey(const Key('browser-location-内部ストレージ')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('browser-folder-sub')), findsOneWidget);
      expect(find.byKey(const Key('browser-file-.hidden')), findsOneWidget);
      expect(find.byKey(const Key('browser-file-memo.txt')), findsOneWidget);
    });
  });

  group('REQ-018: 改名できない可能性の注記', () {
    test('どこで示すかの判定(純関数)', () {
      expect(showsRestrictedNotice('$_root/Android'), isTrue);
      expect(showsRestrictedNotice('$_root/Android/data'), isTrue);
      expect(showsRestrictedNotice('$_root/Android/obb'), isTrue);
      expect(showsRestrictedNotice('$_root/Android/data/com.x/files'), isTrue);
      // 書き込める場所では示さない。
      expect(showsRestrictedNotice('$_root/Android/media'), isFalse);
      expect(showsRestrictedNotice('$_root/Android/media/com.x'), isFalse);
      // 関係ない場所でも示さない。
      expect(showsRestrictedNotice('$_root/Download'), isFalse);
      expect(showsRestrictedNotice(_root), isFalse);
      // 名前が似ているだけの folder は対象にしない。
      expect(showsRestrictedNotice('$_root/AndroidStudio'), isFalse);
    });

    testWidgets('注記を出しても表示や選択は妨げない', (tester) async {
      final browser = _FakeBrowser(
        tree: {
          _root: [_dir(_root, 'Android')],
          '$_root/Android': [_file('$_root/Android', 'x.txt')],
        },
      );
      await _open(tester, browser);
      await tester.tap(find.byKey(const Key('browser-location-内部ストレージ')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('browser-folder-Android')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('browser-restricted-notice')),
        findsOneWidget,
      );
      // **隠さない。** 選べる。
      await tester.tap(find.byKey(const Key('browser-file-x.txt')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const Key('browser-selected-count')))
            .data,
        '1 件を選択中',
      );
    });
  });

  group('列挙に失敗しても例外を投げず、理由を出す(004 REQ-001)', () {
    testWidgets('開けなかったフォルダは理由を示す', (tester) async {
      final browser = _FakeBrowser(
        tree: {
          _root: [_dir(_root, 'locked')],
        },
        failures: {'$_root/locked'},
      );
      await _open(tester, browser);
      await tester.tap(find.byKey(const Key('browser-location-内部ストレージ')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('browser-folder-locked')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('browser-listing-failed')), findsOneWidget);
    });
  });
}

/// **約束を破って投げる** browser。守りが構造で入っているかを見るために使う。
class _ThrowingBrowser implements StorageBrowserPort {
  @override
  Future<StorageLocations> locations() async => throw StateError('列挙が落ちた');

  @override
  Future<List<BrowserEntry>> shortcuts(StorageLocation location) async => [];

  @override
  Future<DirectoryListing> list(String folder) async =>
      const DirectoryListed([]);
}
