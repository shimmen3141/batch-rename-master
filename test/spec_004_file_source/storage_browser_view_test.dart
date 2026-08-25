// 004 VER-005: app 内 file browser(REQ-015〜REQ-019)。
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
  });

  final Map<String, List<BrowserEntry>> tree;
  final List<StorageLocation> locationList;
  final List<String> shortcutNames;
  final Set<String> failures;
  final List<String> listed = [];

  @override
  Future<List<StorageLocation>> locations() async => locationList;

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
