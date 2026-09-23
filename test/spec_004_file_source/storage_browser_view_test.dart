import 'dart:ui' show SemanticsAction;

// 004 VER-005: app 内 file browser(REQ-015〜REQ-020)。
//
// 観点: 保存場所から始まり、階層を辿れる。現在地を常に示し、上位へ戻れるが
// **保存場所の root より上へは辿れない**。選択は同一フォルダ内に限り、移動すると
// 解除される。entry は絞り込まずにそのまま並ぶ。header・現在地の帯・footer の提示は
// `008:T38` の操作状態表どおりである(`008:T39`)。
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
import 'package:batch_rename_master/ui/theme/app_colors.dart';
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
    this.failures = const {},
    this.locationsFailure,
  });

  final Map<String, List<BrowserEntry>> tree;
  final List<StorageLocation> locationList;
  final Set<String> failures;

  /// 保存場所の一部を取得できなかったときの理由(`013:T12`)。
  final String? locationsFailure;

  final List<String> listed = [];

  @override
  Future<StorageLocations> locations() async =>
      StorageLocations(locationList, failure: locationsFailure);

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

/// header 中央。保存場所名か、選択中なら「N件選択中」(`008:T38`)。
String _title(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(browserTitleKey)).data!;

/// パンくずの区切りを先頭から読む(`008:T38` の現在地の帯)。
List<String> _breadcrumb(WidgetTester tester) => [
  for (
    var i = 0;
    find.byKey(browserBreadcrumbSegmentKey(i)).evaluate().isNotEmpty;
    i++
  )
    tester.widget<Text>(find.byKey(browserBreadcrumbSegmentKey(i))).data!,
];

/// [name] の file 行の checkbox が選ばれているか。
bool _isChecked(WidgetTester tester, String name) => tester
    .widget<Checkbox>(
      find.descendant(
        of: find.byKey(Key('browser-file-$name')),
        matching: find.byType(Checkbox),
      ),
    )
    .value!;

/// tooltip で操作名を持つ node(IconButton の名前は label ではなく tooltip に出る)。
SemanticsFinder _byTooltip(String tooltip) =>
    find.semantics.byPredicate((node) => node.tooltip == tooltip);

Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(find.byKey(browserMenuKey));
  await tester.pumpAndSettle();
}

/// ケバブの「すべて選択」を押す(004 REQ-020)。
Future<void> _selectAll(WidgetTester tester) async {
  await _openMenu(tester);
  await tester.tap(find.byKey(browserSelectAllKey));
  await tester.pumpAndSettle();
}

const _root = '/storage/emulated/0';

/// 一覧の Scrollable。**パンくずも横方向の Scrollable なので区別する。**
final _listScrollable = find.descendant(
  of: find.byType(ListView),
  matching: find.byType(Scrollable),
);

/// header 左に出ているもの(`008:T38` の状態表の「header 左」)。
enum _Leading { none, up, locations, clear }

/// 状態表の1行を検査する。**表の列をそのまま引数にする。**
Future<void> _expectRow(
  WidgetTester tester, {
  required _Leading leading,
  required String title,
  required List<String>? breadcrumb,
  required bool selectAllEnabled,
  required bool clearItem,
  required bool confirmEnabled,
}) async {
  // header 左: `←`(2種類)と`×`は同じ位置を共有し、同時には出ない。
  final leadingKeys = {
    _Leading.up: const Key('browser-up'),
    _Leading.locations: const Key('browser-locations'),
    _Leading.clear: browserClearSelectionKey,
  };
  for (final MapEntry(key: kind, value: key) in leadingKeys.entries) {
    expect(
      find.byKey(key),
      kind == leading ? findsOneWidget : findsNothing,
      reason: 'header左は $leading',
    );
  }
  expect(find.byType(BackButton), findsNothing, reason: '暗黙の戻るは出さない');
  expect(find.byType(CloseButton), findsNothing, reason: '画面を閉じる×は出さない');
  if (leading == _Leading.up || leading == _Leading.locations) {
    final icon = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(leadingKeys[leading]!),
        matching: find.byType(Icon),
      ),
    );
    expect(icon.icon, Icons.arrow_back, reason: '上へ戻るのは`←`');
  }
  if (leading == _Leading.clear) {
    final icon = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(browserClearSelectionKey),
        matching: find.byType(Icon),
      ),
    );
    expect(icon.icon, Icons.close);
  }

  // header 中央。
  expect(_title(tester), title);

  // 現在地の帯。
  if (breadcrumb == null) {
    expect(find.byKey(browserBreadcrumbKey), findsNothing);
  } else {
    expect(_breadcrumb(tester), breadcrumb);
  }

  // footer: 「リネーム画面に戻る」は常に押せ、「確定」は選択があるときだけ押せる。
  expect(
    tester.widget<OutlinedButton>(find.byKey(browserBackToRenameKey)).enabled,
    isTrue,
  );
  expect(find.text('リネーム画面に戻る'), findsOneWidget);
  expect(
    tester
        .widget<FilledButton>(find.byKey(const Key('browser-confirm')))
        .enabled,
    confirmEnabled,
  );

  // header 右: ケバブは常にある。項目は開いて確かめ、閉じて戻す。
  expect(find.byKey(browserMenuKey), findsOneWidget);
  await _openMenu(tester);
  expect(
    tester
        .widget<PopupMenuItem<VoidCallback>>(find.byKey(browserSelectAllKey))
        .enabled,
    selectAllEnabled,
    reason: '「すべて選択」は常設し、押せないときは無効',
  );
  expect(
    find.byKey(browserMenuClearSelectionKey),
    clearItem ? findsOneWidget : findsNothing,
    reason: '「選択をすべて解除」は1件でも選択があるときだけ',
  );
  // barrier を押して閉じる(項目は選ばない)。
  await tester.tapAt(const Offset(4, 300));
  await tester.pumpAndSettle();
  expect(find.byKey(browserSelectAllKey), findsNothing);
}

const _twoLocations = [
  StorageLocation(name: '内部ストレージ', root: _root),
  StorageLocation(name: 'SD カード', root: '/storage/1A2B'),
];

/// root に file 2件と folder、その下に file 2件と空 folder を持つ木。
Map<String, List<BrowserEntry>> _stateTree() => {
  _root: [_dir(_root, 'A'), _file(_root, 'r1.txt'), _file(_root, 'r2.txt')],
  '$_root/A': [
    _dir('$_root/A', 'B'),
    _dir('$_root/A', 'empty'),
    _file('$_root/A', 'a1.txt'),
    _file('$_root/A', 'a2.txt'),
  ],
  '$_root/A/B': [_file('$_root/A/B', 'b1.txt')],
  '$_root/A/empty': const [],
};

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

  group('REQ-015: 保存場所から始まり、階層を辿れる', () {
    testWidgets('保存場所が2つ以上あるときは一覧から始まり、選ぶと中身が出る', (tester) async {
      final browser = _FakeBrowser(
        tree: {
          _root: [_dir(_root, 'A'), _file(_root, 'memo.txt')],
        },
        locationList: const [
          StorageLocation(name: '内部ストレージ', root: _root),
          StorageLocation(name: 'SD カード', root: '/storage/1A2B'),
        ],
      );
      await _open(tester, browser);

      expect(find.byKey(const Key('browser-location-内部ストレージ')), findsOneWidget);
      expect(find.byKey(const Key('browser-location-SD カード')), findsOneWidget);
      expect(
        find.byKey(const Key('browser-folder-A')),
        findsNothing,
        reason: '選ぶまで中へ入らない',
      );

      await tester.tap(find.byKey(const Key('browser-location-内部ストレージ')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('browser-folder-A')), findsOneWidget);
      expect(find.byKey(const Key('browser-file-memo.txt')), findsOneWidget);
    });

    testWidgets('保存場所が1つだけのときは一覧を挟まず、rootの中身が出る', (tester) async {
      // **選択肢が1つしかない画面を1回押させない**(`013:T07` の U1)。
      final browser = _FakeBrowser(
        tree: {
          _root: [_dir(_root, 'A'), _file(_root, 'memo.txt')],
        },
      );
      await _open(tester, browser);

      expect(find.byKey(const Key('browser-folder-A')), findsOneWidget);
      expect(find.byKey(const Key('browser-file-memo.txt')), findsOneWidget);
      expect(
        find.byKey(const Key('browser-location-内部ストレージ')),
        findsNothing,
        reason: '1件の一覧を挟まない',
      );
      expect(_title(tester), '内部ストレージ', reason: 'どの保存場所にいるかはheaderが示す');
      expect(_breadcrumb(tester), ['内部ストレージ']);
    });

    testWidgets('保存場所を取得できていなければ、1件でも一覧を出す', (tester) async {
      // **「1つだけ」と言い切れない。** 取れなかったことを知らせる notice は一覧の側に
      // あるので、黙って中へ入ると**装着しているSDカードが並ばないことに気づけない**
      // (`013:T08` の実機観測)。
      final browser = _FakeBrowser(
        tree: {
          _root: [_dir(_root, 'A')],
        },
        locationsFailure: '一部を取得できませんでした',
      );
      await _open(tester, browser);

      expect(find.byKey(const Key('browser-location-内部ストレージ')), findsOneWidget);
      expect(
        find.byKey(const Key('browser-locations-failure')),
        findsOneWidget,
      );
    });

    testWidgets('既知の名前のfolderは一覧に1回しか並ばない(近道を出さない)', (tester) async {
      // **近道は2026-09-22の`008:T11`で取りやめた**(REQ-015)。近道は保存場所のrootでだけ
      // 出て、行き先は同じ画面に並ぶ同名folderと同一pathであり、手数を減らしていなかった。
      // **同じfolderが2回並ぶことが混乱の本体だった。**
      final browser = _FakeBrowser(
        tree: {
          _root: [_dir(_root, 'DCIM'), _dir(_root, 'Download')],
        },
      );
      await _open(tester, browser);

      expect(find.byKey(const Key('browser-folder-DCIM')), findsOneWidget);
      expect(find.byKey(const Key('browser-folder-Download')), findsOneWidget);
      expect(
        find.textContaining('DCIM'),
        findsOneWidget,
        reason: '近道と実体で二重に出ない',
      );
      expect(find.textContaining('Download'), findsOneWidget);
      expect(find.byIcon(Icons.star_outline), findsNothing);
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

    testWidgets('現在地を常に示し、階層を辿ると更新される', (tester) async {
      final browser = _FakeBrowser(
        tree: {
          _root: [_dir(_root, 'A')],
          '$_root/A': [_file('$_root/A', 'a.txt')],
        },
      );
      await _open(tester, browser);

      expect(_breadcrumb(tester), ['内部ストレージ']);

      await tester.tap(find.byKey(const Key('browser-folder-A')));
      await tester.pumpAndSettle();

      // **現在地はパンくず**(`008:T38`)。headerは保存場所名のまま。
      expect(_breadcrumb(tester), ['内部ストレージ', 'A']);
      expect(_title(tester), '内部ストレージ');
      expect(find.byKey(const Key('browser-file-a.txt')), findsOneWidget);
    });

    testWidgets('rootでは「上へ」を出さない(004 代表例 26d)', (tester) async {
      // **上位へ戻る操作は無いか無効。** 保存場所が複数あるときは、代わりに
      // 保存場所を切り替える導線を出す(上位 path へ辿るのではない)。
      final browser = _FakeBrowser(
        tree: {
          _root: [_dir(_root, 'A')],
          '$_root/A': [_file('$_root/A', 'a.txt')],
        },
        locationList: const [
          StorageLocation(name: '内部ストレージ', root: _root),
          StorageLocation(name: 'SD カード', root: '/storage/1A2B'),
        ],
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

    testWidgets('上へ戻るのは `←` である(013:T07 の U3)', (tester) async {
      // `↑` より馴染むという指摘。**辿る先は1つ上のfolderのままで、keyもtooltipも
      // 変えていない。**
      final browser = _FakeBrowser(
        tree: {
          _root: [_dir(_root, 'A')],
          '$_root/A': [_file('$_root/A', 'a.txt')],
        },
      );
      await _open(tester, browser);
      await tester.tap(find.byKey(const Key('browser-folder-A')));
      await tester.pumpAndSettle();

      final icon = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(const Key('browser-up')),
          matching: find.byType(Icon),
        ),
      );
      expect(icon.icon, Icons.arrow_back);
    });

    testWidgets('保存場所が1つだけなら、切り替えの導線を出さない', (tester) async {
      // **要求は「複数あるときは閉じずに切り替えられる」ことまで**で、切り替え先が
      // 無い端末で出すかは自由(004 spec の自由とする点)。**押しても1件の一覧が出る
      // だけの空振りになるので出さない。**
      final browser = _FakeBrowser(
        tree: {
          _root: [_dir(_root, 'A')],
        },
      );
      await _open(tester, browser);

      expect(find.byKey(const Key('browser-up')), findsNothing);
      expect(find.byKey(const Key('browser-locations')), findsNothing);
    });

    testWidgets('上位へ戻れる。保存場所を切り替えても上位pathを辿らない', (tester) async {
      // **保存場所が複数あるときは、browserを閉じずに切り替えられる**(REQ-015)。
      final browser = _FakeBrowser(
        tree: {
          _root: [_dir(_root, 'A')],
          '$_root/A': [_file('$_root/A', 'a.txt')],
          '/storage/1A2B': [_file('/storage/1A2B', 'sd.txt')],
        },
        locationList: const [
          StorageLocation(name: '内部ストレージ', root: _root),
          StorageLocation(name: 'SD カード', root: '/storage/1A2B'),
        ],
      );
      await _open(tester, browser);
      await tester.tap(find.byKey(const Key('browser-location-内部ストレージ')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('browser-folder-A')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('browser-up')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('browser-folder-A')), findsOneWidget);

      // root では保存場所を切り替える導線になる。**上位の path は辿らない。**
      await tester.tap(find.byKey(const Key('browser-locations')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('browser-location-内部ストレージ')), findsOneWidget);

      // **閉じずにSDカードへ移れる。**
      await tester.tap(find.byKey(const Key('browser-location-SD カード')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('browser-file-sd.txt')), findsOneWidget);

      // **`/storage` を列挙しに行っていない。**
      expect(browser.listed, isNot(contains('/storage')));
      expect(browser.listed, isNot(contains('/')));
    });

    test('一覧を挟まずに入る保存場所の決定(純関数)', () {
      const internal = StorageLocation(name: '内部ストレージ', root: _root);
      const sd = StorageLocation(name: 'SD カード', root: '/storage/1A2B');

      expect(soleLocation(const StorageLocations([internal])), internal);
      expect(soleLocation(const StorageLocations([internal, sd])), isNull);
      expect(soleLocation(const StorageLocations([])), isNull);
      expect(
        soleLocation(const StorageLocations([internal], failure: '一部が取れない')),
        isNull,
        reason: '取れていないなら「1つだけ」と言い切れない',
      );
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
            _dir('$_root/A', 'B'),
            _file('$_root/A', 'a1.txt'),
            _file('$_root/A', 'a2.txt'),
          ],
          '$_root/A/B': [_file('$_root/A/B', 'b1.txt')],
        },
      );
      final result = await _open(tester, browser);
      await tester.tap(find.byKey(const Key('browser-folder-A')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('browser-file-a1.txt')));
      await tester.tap(find.byKey(const Key('browser-file-a2.txt')));
      await tester.pumpAndSettle();
      expect(_title(tester), '2件選択中');

      // 選択したまま `/A/B` へ移動する(選択中は`←`が無いので、下へ入る)。
      await tester.tap(find.byKey(const Key('browser-folder-B')));
      await tester.pumpAndSettle();

      expect(_title(tester), '内部ストレージ', reason: '移動で解除される');
      // **移動後のheaderは必ず`←`側の形に戻る**(`008:T38`)。
      expect(find.byKey(browserClearSelectionKey), findsNothing);
      expect(find.byKey(const Key('browser-up')), findsOneWidget);
      // 確定できるのは `/A/B` の中だけ。
      await tester.tap(find.byKey(const Key('browser-file-b1.txt')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('browser-confirm')));
      await tester.pumpAndSettle();
      expect(result.value!.folder, '$_root/A/B');
      expect(result.value!.paths, ['$_root/A/B/b1.txt']);
    });

    testWidgets('解除してから保存場所を選び直すと、選択は残らない', (tester) async {
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

      // **選択中は保存場所の一覧へ戻る導線が`×`に替わる**(`008:T38`)。
      expect(find.byKey(const Key('browser-locations')), findsNothing);
      await tester.tap(find.byKey(browserClearSelectionKey));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('browser-locations')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('browser-location-SD カード')));
      await tester.pumpAndSettle();

      expect(_title(tester), 'SD カード');
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('browser-confirm')))
            .onPressed,
        isNull,
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

    testWidgets('「リネーム画面に戻る」は「決定していない」を返す(004 REQ-001)', (tester) async {
      final browser = _FakeBrowser(
        tree: {
          _root: [_file(_root, 'r.txt')],
        },
      );
      final result = await _open(tester, browser);

      await tester.tap(find.byKey(const Key('browser-file-r.txt')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(browserBackToRenameKey));
      await tester.pumpAndSettle();

      expect(result.closed, isTrue);
      expect(result.value, isNull, reason: '選んでいても、閉じたら確定しない');
    });

    testWidgets('システムバックは「リネーム画面に戻る」と同じ(`008:T38`)', (tester) async {
      final browser = _FakeBrowser(
        tree: {
          _root: [_dir(_root, 'A')],
          '$_root/A': [_file('$_root/A', 'a.txt')],
        },
      );
      final result = await _open(tester, browser);
      await tester.tap(find.byKey(const Key('browser-folder-A')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('browser-file-a.txt')));
      await tester.pumpAndSettle();

      // **親folderへ戻るのでも、選択を解除するのでもない。**
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(result.closed, isTrue);
      expect(result.value, isNull);
    });

    testWidgets('1件も選んでいなければ確定できない', (tester) async {
      final browser = _FakeBrowser(
        tree: {
          _root: [_file(_root, 'r.txt')],
        },
      );
      await _open(tester, browser);

      final confirm = tester.widget<FilledButton>(
        find.byKey(const Key('browser-confirm')),
      );
      expect(confirm.onPressed, isNull);
    });
  });

  group('REQ-020: app内browserの範囲選択と全選択', () {
    testWidgets('全選択は現在folderのfileだけを選び、folderを含めない', (tester) async {
      final browser = _FakeBrowser(
        tree: {
          _root: [
            _dir(_root, 'folder'),
            _file(_root, 'a.txt'),
            _file(_root, 'b.txt'),
          ],
        },
      );
      final result = await _open(tester, browser);

      await _selectAll(tester);
      expect(_title(tester), '2件選択中');

      await tester.tap(find.byKey(const Key('browser-confirm')));
      await tester.pumpAndSettle();
      expect(result.value!.paths, ['$_root/a.txt', '$_root/b.txt']);
      expect(result.value!.paths, isNot(contains('$_root/folder')));
    });

    testWidgets('全選択と一括解除は支援技術から操作名とtap actionで実行できる', (tester) async {
      final semantics = tester.ensureSemantics();
      await _open(
        tester,
        _FakeBrowser(
          tree: {
            _root: [_file(_root, 'a.txt'), _file(_root, 'b.txt')],
          },
        ),
      );

      // ケバブは操作名で辿れる。
      tester.semantics.tap(_byTooltip('その他の操作'));
      await tester.pumpAndSettle();
      final selectAll = tester.getSemantics(find.byKey(browserSelectAllKey));
      expect(selectAll.label, 'すべて選択');
      expect(
        selectAll.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );
      tester.semantics.tap(find.semantics.byLabel('すべて選択'));
      await tester.pumpAndSettle();
      expect(_title(tester), '2件選択中');

      // **一括解除もケバブから操作名で実行できる**(004 REQ-020)。
      tester.semantics.tap(_byTooltip('その他の操作'));
      await tester.pumpAndSettle();
      final clear = tester.getSemantics(
        find.byKey(browserMenuClearSelectionKey),
      );
      expect(clear.label, '選択をすべて解除');
      expect(clear.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      tester.semantics.tap(find.semantics.byLabel('選択をすべて解除').first);
      await tester.pumpAndSettle();
      expect(_title(tester), '内部ストレージ');
      expect(_isChecked(tester, 'a.txt'), isFalse);
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

      expect(_title(tester), '2件選択中');
      expect(
        _isChecked(tester, 'c.txt'),
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

      expect(_title(tester), '2件選択中');
      expect(
        _isChecked(tester, 'a.txt'),
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

      await tester.drag(find.byType(ListView), const Offset(0, -180));
      await tester.pumpAndSettle();

      expect(_title(tester), '内部ストレージ', reason: '何も選ばれていない');
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
      final target = find.byKey(const Key('browser-file-long-20.txt'));
      await tester.scrollUntilVisible(target, 120, scrollable: _listScrollable);
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
      final scrollable = tester.state<ScrollableState>(_listScrollable);
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

  group('008:T38 操作状態表(008:T39)', () {
    testWidgets('保存場所の一覧', (tester) async {
      await _open(
        tester,
        _FakeBrowser(tree: _stateTree(), locationList: _twoLocations),
      );
      await _expectRow(
        tester,
        leading: _Leading.none,
        title: 'ファイルを選ぶ',
        breadcrumb: null,
        selectAllEnabled: false,
        clearItem: false,
        confirmEnabled: false,
      );
    });

    testWidgets('root(保存場所が複数): 0件 → 一部 → 全件', (tester) async {
      await _open(
        tester,
        _FakeBrowser(tree: _stateTree(), locationList: _twoLocations),
      );
      await tester.tap(find.byKey(const Key('browser-location-内部ストレージ')));
      await tester.pumpAndSettle();

      await _expectRow(
        tester,
        leading: _Leading.locations,
        title: '内部ストレージ',
        breadcrumb: ['内部ストレージ'],
        selectAllEnabled: true,
        clearItem: false,
        confirmEnabled: false,
      );

      await tester.tap(find.byKey(const Key('browser-file-r1.txt')));
      await tester.pumpAndSettle();
      await _expectRow(
        tester,
        leading: _Leading.clear,
        title: '1件選択中',
        breadcrumb: ['内部ストレージ'],
        selectAllEnabled: true,
        clearItem: true,
        confirmEnabled: true,
      );

      await _selectAll(tester);
      await _expectRow(
        tester,
        leading: _Leading.clear,
        title: '2件選択中',
        breadcrumb: ['内部ストレージ'],
        selectAllEnabled: false,
        clearItem: true,
        confirmEnabled: true,
      );
    });

    testWidgets('root(保存場所が1件): 0件 → 一部 → 全件', (tester) async {
      await _open(tester, _FakeBrowser(tree: _stateTree()));

      await _expectRow(
        tester,
        leading: _Leading.none,
        title: '内部ストレージ',
        breadcrumb: ['内部ストレージ'],
        selectAllEnabled: true,
        clearItem: false,
        confirmEnabled: false,
      );

      await tester.tap(find.byKey(const Key('browser-file-r2.txt')));
      await tester.pumpAndSettle();
      await _expectRow(
        tester,
        leading: _Leading.clear,
        title: '1件選択中',
        breadcrumb: ['内部ストレージ'],
        selectAllEnabled: true,
        clearItem: true,
        confirmEnabled: true,
      );

      await _selectAll(tester);
      await _expectRow(
        tester,
        leading: _Leading.clear,
        title: '2件選択中',
        breadcrumb: ['内部ストレージ'],
        selectAllEnabled: false,
        clearItem: true,
        confirmEnabled: true,
      );
    });

    testWidgets('下位folder: 0件 → 一部 → 全件', (tester) async {
      await _open(tester, _FakeBrowser(tree: _stateTree()));
      await tester.tap(find.byKey(const Key('browser-folder-A')));
      await tester.pumpAndSettle();

      await _expectRow(
        tester,
        leading: _Leading.up,
        title: '内部ストレージ',
        breadcrumb: ['内部ストレージ', 'A'],
        selectAllEnabled: true,
        clearItem: false,
        confirmEnabled: false,
      );

      await tester.tap(find.byKey(const Key('browser-file-a1.txt')));
      await tester.pumpAndSettle();
      await _expectRow(
        tester,
        leading: _Leading.clear,
        title: '1件選択中',
        breadcrumb: ['内部ストレージ', 'A'],
        selectAllEnabled: true,
        clearItem: true,
        confirmEnabled: true,
      );

      await _selectAll(tester);
      await _expectRow(
        tester,
        leading: _Leading.clear,
        title: '2件選択中',
        breadcrumb: ['内部ストレージ', 'A'],
        selectAllEnabled: false,
        clearItem: true,
        confirmEnabled: true,
      );
    });

    testWidgets('空のfolder', (tester) async {
      await _open(tester, _FakeBrowser(tree: _stateTree()));
      await tester.tap(find.byKey(const Key('browser-folder-A')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('browser-folder-empty')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('browser-listing-empty')), findsOneWidget);
      await _expectRow(
        tester,
        leading: _Leading.up,
        title: '内部ストレージ',
        breadcrumb: ['内部ストレージ', 'A', 'empty'],
        selectAllEnabled: false,
        clearItem: false,
        confirmEnabled: false,
      );
    });

    testWidgets('`←`はfolder内なら親folderへ、rootなら保存場所の一覧へ戻る', (tester) async {
      final browser = _FakeBrowser(
        tree: _stateTree(),
        locationList: _twoLocations,
      );
      await _open(tester, browser);
      await tester.tap(find.byKey(const Key('browser-location-内部ストレージ')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('browser-folder-A')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('browser-folder-B')));
      await tester.pumpAndSettle();
      expect(_breadcrumb(tester), ['内部ストレージ', 'A', 'B']);

      await tester.tap(find.byKey(const Key('browser-up')));
      await tester.pumpAndSettle();
      expect(_breadcrumb(tester), ['内部ストレージ', 'A']);
      await tester.tap(find.byKey(const Key('browser-up')));
      await tester.pumpAndSettle();
      expect(_breadcrumb(tester), ['内部ストレージ']);

      await tester.tap(find.byKey(const Key('browser-locations')));
      await tester.pumpAndSettle();
      expect(_title(tester), 'ファイルを選ぶ');
      expect(find.byKey(const Key('browser-location-SD カード')), findsOneWidget);
      // **rootより上のfilesystemへは辿っていない**(REQ-015)。
      expect(browser.listed, isNot(contains('/storage')));
    });

    testWidgets('`×`は全解除だけを意味し、画面を閉じない', (tester) async {
      final result = await _open(tester, _FakeBrowser(tree: _stateTree()));
      await tester.tap(find.byKey(const Key('browser-folder-A')));
      await tester.pumpAndSettle();
      await _selectAll(tester);
      expect(_title(tester), '2件選択中');

      await tester.tap(find.byKey(browserClearSelectionKey));
      await tester.pumpAndSettle();

      expect(result.closed, isFalse, reason: '`×`で画面は閉じない');
      expect(_isChecked(tester, 'a1.txt'), isFalse);
      expect(_isChecked(tester, 'a2.txt'), isFalse);
      // **移動していない**: 同じfolderの`←`側の形に戻る。
      await _expectRow(
        tester,
        leading: _Leading.up,
        title: '内部ストレージ',
        breadcrumb: ['内部ストレージ', 'A'],
        selectAllEnabled: true,
        clearItem: false,
        confirmEnabled: false,
      );
    });

    testWidgets('ケバブの「選択をすべて解除」も全解除だけで、画面を閉じない', (tester) async {
      final result = await _open(tester, _FakeBrowser(tree: _stateTree()));
      await tester.tap(find.byKey(const Key('browser-file-r1.txt')));
      await tester.tap(find.byKey(const Key('browser-file-r2.txt')));
      await tester.pumpAndSettle();

      await _openMenu(tester);
      await tester.tap(find.byKey(browserMenuClearSelectionKey));
      await tester.pumpAndSettle();

      expect(result.closed, isFalse);
      expect(_isChecked(tester, 'r1.txt'), isFalse);
      expect(_isChecked(tester, 'r2.txt'), isFalse);
      expect(_title(tester), '内部ストレージ');
      expect(find.byKey(const Key('browser-file-r1.txt')), findsOneWidget);
    });

    testWidgets('解除後に選び直して確定すると、解除した分は返らない', (tester) async {
      final result = await _open(tester, _FakeBrowser(tree: _stateTree()));
      await _selectAll(tester);
      await tester.tap(find.byKey(browserClearSelectionKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('browser-file-r2.txt')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('browser-confirm')));
      await tester.pumpAndSettle();

      expect(result.value!.paths, ['$_root/r2.txt']);
    });

    testWidgets('ケバブは選択の有無にかかわらず右端の同じ位置にある', (tester) async {
      await _open(tester, _FakeBrowser(tree: _stateTree()));
      final before = tester.getRect(find.byKey(browserMenuKey));
      final appBar = tester.getRect(find.byType(AppBar));
      expect(before.right, closeTo(appBar.right, 16), reason: '右端');

      await tester.tap(find.byKey(const Key('browser-file-r1.txt')));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(browserMenuKey)), before);
    });

    testWidgets('`←`と`×`は同じ位置を共有する', (tester) async {
      await _open(tester, _FakeBrowser(tree: _stateTree()));
      await tester.tap(find.byKey(const Key('browser-folder-A')));
      await tester.pumpAndSettle();
      final up = tester.getRect(find.byKey(const Key('browser-up')));

      await tester.tap(find.byKey(const Key('browser-file-a1.txt')));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(browserClearSelectionKey)), up);
    });

    testWidgets('操作名が戻る・全解除・画面を閉じるで区別される(semantics)', (tester) async {
      final semantics = tester.ensureSemantics();
      await _open(tester, _FakeBrowser(tree: _stateTree()));
      await tester.tap(find.byKey(const Key('browser-folder-A')));
      await tester.pumpAndSettle();

      final up = tester.getSemantics(find.byKey(const Key('browser-up')));
      expect(up.tooltip, '上のフォルダへ');
      expect(up.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      final back = tester.getSemantics(find.byKey(browserBackToRenameKey));
      expect(back.label, 'リネーム画面に戻る');
      expect(back.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

      await tester.tap(find.byKey(const Key('browser-file-a1.txt')));
      await tester.pumpAndSettle();
      final clear = tester.getSemantics(find.byKey(browserClearSelectionKey));
      expect(clear.tooltip, '選択をすべて解除');
      expect(
        {up.tooltip, back.label, clear.tooltip},
        hasLength(3),
        reason: '3つの操作名が重ならない',
      );

      // **`×`をsemanticsで押しても画面は閉じず、解除される。**
      tester.semantics.tap(_byTooltip('選択をすべて解除'));
      await tester.pumpAndSettle();
      expect(_title(tester), '内部ストレージ');
      expect(find.byKey(const Key('browser-up')), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('file行のcheckboxはメイン一覧(T29)へ揃う: 右端・円・アクセント色', (tester) async {
      await _open(tester, _FakeBrowser(tree: _stateTree()));
      final row = find.byKey(const Key('browser-file-r1.txt'));
      final checkbox = find.descendant(
        of: row,
        matching: find.byType(Checkbox),
      );
      final name = find.descendant(of: row, matching: find.text('r1.txt'));

      expect(
        tester.getCenter(checkbox).dx,
        greaterThan(tester.getRect(name).right),
        reason: 'checkboxは名前の右',
      );
      final widget = tester.widget<Checkbox>(checkbox);
      final colors = appDarkTheme().extension<AppColors>()!;
      expect(widget.shape, isA<CircleBorder>());
      expect(widget.activeColor, colors.selectionMark);
      expect(widget.checkColor, colors.onPrimary);

      ListTile tile() => tester.widget<ListTile>(
        find.descendant(of: row, matching: find.byType(ListTile)),
      );
      expect(tile().tileColor, isNull, reason: '選ばれていない行は面を染めない');
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(_isChecked(tester, 'r1.txt'), isTrue);
      expect(tile().tileColor, colors.selectedSurface, reason: '選択済みの面');
    });

    testWidgets('folder行はcheckboxを持たず、navigationとして識別できる', (tester) async {
      await _open(tester, _FakeBrowser(tree: _stateTree()));
      final folder = find.byKey(const Key('browser-folder-A'));
      expect(
        find.descendant(of: folder, matching: find.byType(Checkbox)),
        findsNothing,
      );
      expect(
        find.descendant(of: folder, matching: find.byIcon(Icons.chevron_right)),
        findsOneWidget,
      );
    });

    test('パンくずは保存場所名から始まり、rootより上を作らない(純関数)', () {
      const internal = StorageLocation(name: '内部ストレージ', root: _root);
      expect(breadcrumbOf(internal, _root), [(name: '内部ストレージ', path: _root)]);
      expect(breadcrumbOf(internal, '$_root/A/B'), [
        (name: '内部ストレージ', path: _root),
        (name: 'A', path: '$_root/A'),
        (name: 'B', path: '$_root/A/B'),
      ]);
      // root の外は名指ししない。
      expect(breadcrumbOf(internal, '/storage'), [
        (name: '内部ストレージ', path: _root),
      ]);
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
      await tester.tap(find.byKey(const Key('browser-folder-Android')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('browser-restricted-notice')),
        findsOneWidget,
      );
      // **隠さない。** 選べる。
      await tester.tap(find.byKey(const Key('browser-file-x.txt')));
      await tester.pumpAndSettle();
      expect(_title(tester), '1件選択中');
    });
  });

  group('空のfolderと、開けなかったfolderを区別する(013:T07 の U6)', () {
    testWidgets('空のfolderは「ファイルはありません」を出す', (tester) async {
      // **「読み込み中」「開けなかった」「空」が同じ見た目(何も無い)になるのを避ける。**
      // 004 REQ-017 は0件のときの提示を定めていないので、要求は変えていない。
      final browser = _FakeBrowser(
        tree: {
          _root: [_dir(_root, 'empty')],
          '$_root/empty': const [],
        },
      );
      await _open(tester, browser);
      await tester.tap(find.byKey(const Key('browser-folder-empty')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('browser-listing-empty')), findsOneWidget);
      expect(
        find.byKey(const Key('browser-listing-failed')),
        findsNothing,
        reason: '開けなかったのとは別物',
      );
    });

    testWidgets('開けなかったfolderは空とは別の提示になる', (tester) async {
      final browser = _FakeBrowser(
        tree: {
          _root: [_dir(_root, 'locked')],
        },
        failures: {'$_root/locked'},
      );
      await _open(tester, browser);
      await tester.tap(find.byKey(const Key('browser-folder-locked')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('browser-listing-failed')), findsOneWidget);
      expect(find.byKey(const Key('browser-listing-empty')), findsNothing);
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
  Future<DirectoryListing> list(String folder) async =>
      const DirectoryListed([]);
}
