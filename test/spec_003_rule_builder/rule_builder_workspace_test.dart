// VER-002(T5 分): レスポンシブ外殻 + 002 setRule 連携。
// ルール変更が FileListController.setRule 経由でプレビューに反映されること、
// 画面幅でモバイル(ボトムシート)/デスクトップ(2ペイン)を切り替えることを検証。
import 'package:batch_rename_master/core/rename_engine.dart';
import 'package:batch_rename_master/ui/file_list/file_list_controller.dart';
import 'package:batch_rename_master/ui/file_list/file_list_view.dart';
import 'package:batch_rename_master/ui/rule_builder/rule_builder_view.dart';
import 'package:batch_rename_master/ui/rule_builder/rule_builder_workspace.dart';
import 'package:batch_rename_master/ui/rule_builder/rule_controller.dart';
import 'package:batch_rename_master/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

FileEntry _file(String name) => FileEntry(
  name: name,
  createdAt: DateTime(2026, 1, 1),
  modifiedAt: DateTime(2026, 1, 1),
  size: 0,
);

void _setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _pump(
  WidgetTester tester,
  FileListController fl,
  RuleController rc,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: appDarkTheme(),
      home: Scaffold(
        body: RuleBuilderWorkspace(fileList: fl, rule: rc),
      ),
    ),
  );
}

void main() {
  testWidgets('初期ルールとその後の変更が setRule 経由でプレビューに反映される(002 連携)', (tester) async {
    _setSize(tester, const Size(1000, 800)); // デスクトップ
    final fl = FileListController(files: [_file('a.txt')]);
    // 非空ルールで初期化 → 初期同期が働いて初めてプレビューに出る
    // (同期を外すと fl.rule は空のままで X.txt が描画されず、本テストが落ちる)。
    final rc = RuleController(tokens: const [LiteralToken('X')]);
    await _pump(tester, fl, rc);
    // 初期同期はフレーム後に走る(T6: ビルド中に通知しないため)。反映を1フレーム待つ。
    await tester.pump();

    expect(fl.rule.tokens, hasLength(1)); // 初期同期
    expect(find.text('X.txt'), findsOneWidget);

    // さらに元名トークンを追加 → 変更同期でプレビュー更新。
    rc.addToken(const OriginalNameToken());
    await tester.pump();

    expect(fl.rule.tokens, hasLength(2));
    expect(find.text('Xa.txt'), findsOneWidget); // 'X' + baseName('a') + '.txt'
  });

  testWidgets('デスクトップ幅では 2 ペイン(リスト + ルールが並ぶ)', (tester) async {
    _setSize(tester, const Size(1000, 800));
    final fl = FileListController(files: [_file('a.txt')]);
    final rc = RuleController();
    await _pump(tester, fl, rc);

    expect(find.byType(FileListView), findsOneWidget);
    expect(find.byType(RuleBuilderView), findsOneWidget); // インライン表示
  });

  testWidgets('モバイル幅ではリスト全面 + ボトムシートでルール編集', (tester) async {
    _setSize(tester, const Size(500, 800)); // モバイル
    final fl = FileListController(files: [_file('a.txt')]);
    final rc = RuleController();
    await _pump(tester, fl, rc);

    expect(find.byType(FileListView), findsOneWidget);
    expect(find.byType(RuleBuilderView), findsNothing); // インラインには出ない
    // 初期ルールは空なので未設定向けの表示になる(005 REQ-020)。導線自体は同じ。
    expect(find.byKey(const Key('configure-rule')), findsOneWidget);

    await tester.tap(find.byKey(const Key('configure-rule')));
    await tester.pumpAndSettle();

    expect(find.byType(RuleBuilderView), findsOneWidget); // シートで開く
    expect(find.text('＋ 連番'), findsOneWidget);
  });

  group('T6: 初期同期はビルド中に通知しない', () {
    testWidgets('同じ FileListController を購読する兄弟ウィジェットと同一フレームに置ける', (
      tester,
    ) async {
      _setSize(tester, const Size(1000, 800));
      final fl = FileListController(files: [_file('a.txt')]);
      final rc = RuleController(tokens: const [LiteralToken('X')]);

      // ワークスペースより前に、同じコントローラを購読する兄弟を置く。
      // 初期同期がビルド中に notifyListeners を呼ぶと、この兄弟が
      // 「setState() called during build」で落ちる(修正前の再現構成)。
      await tester.pumpWidget(
        MaterialApp(
          theme: appDarkTheme(),
          home: Scaffold(
            body: Column(
              children: [
                ListenableBuilder(
                  listenable: fl,
                  builder: (context, _) => Text('件数: ${fl.items.length}'),
                ),
                Expanded(
                  child: RuleBuilderWorkspace(fileList: fl, rule: rc),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump(); // 初期同期(フレーム後)を反映。

      expect(tester.takeException(), isNull);
      expect(find.text('件数: 1'), findsOneWidget);
      expect(find.text('X.txt'), findsOneWidget); // 初期ルールは反映される
    });

    testWidgets('兄弟がいても、その後のルール変更はプレビューへ反映される', (tester) async {
      _setSize(tester, const Size(1000, 800));
      final fl = FileListController(files: [_file('a.txt')]);
      final rc = RuleController(tokens: const [LiteralToken('X')]);
      await tester.pumpWidget(
        MaterialApp(
          theme: appDarkTheme(),
          home: Scaffold(
            body: Column(
              children: [
                ListenableBuilder(
                  listenable: fl,
                  builder: (context, _) => Text('件数: ${fl.items.length}'),
                ),
                Expanded(
                  child: RuleBuilderWorkspace(fileList: fl, rule: rc),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      rc.addToken(const OriginalNameToken());
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Xa.txt'), findsOneWidget);
    });
  });
}
