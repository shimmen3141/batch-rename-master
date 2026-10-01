// デモアプリのスモークテスト: サンプルデータで 002/003 を束ねた入口が
// 例外なく起動し、ファイルリストとルール編集の導線が出ることを確認する。
import 'package:batch_rename_master/main.dart';
import 'package:batch_rename_master/ui/file_list/file_list_view.dart';
import 'package:batch_rename_master/ui/file_source/file_source_bar.dart';
import 'package:batch_rename_master/ui/file_list/row_preview_view.dart';
import 'package:batch_rename_master/ui/rule_builder/rule_controller.dart';
import 'package:batch_rename_master/ui/rename_exec/rename_settings_button.dart';
import 'package:batch_rename_master/ui/theme/app_colors.dart';
import 'package:batch_rename_master/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'spec_002_file_list/removal_mode.dart';

void main() {
  testWidgets('デモアプリが起動しファイルリストを表示する', (tester) async {
    final rule = RuleController();
    addTearDown(rule.dispose);
    await tester.pumpWidget(DemoApp(ruleController: rule));
    await tester.pump();

    // ファイルリストとサンプルファイル、ルール編集導線が出る。
    expect(find.byType(FileListView), findsOneWidget);
    // 実行操作が加わった後も、先頭のサンプル行は表示される。
    expect(find.text('IMG_0009.jpg'), findsOneWidget);
    // 既定サイズ(800x600)はモバイル幅なのでルール設定の導線が出る。
    // 初期ルールは空なので、導線は未設定向けの表示になる(005 REQ-020)。
    expect(find.byKey(const Key('configure-rule')), findsOneWidget);
    expect(find.text('命名ルールを設定する'), findsOneWidget);
  });

  testWidgets('上部の見出しは低く小さい(008:T10 要望13)', (tester) async {
    // 2026-09-02 の要望13: 見出しが幅を取るので、小さくして一覧の場所を確保する。
    // 既定の AppBar は高さ 56・文字 22。
    final rule = RuleController();
    addTearDown(rule.dispose);
    await tester.pumpWidget(DemoApp(ruleController: rule));
    await tester.pump();

    expect(tester.getSize(find.byType(AppBar)).height, appBarHeight);
    expect(appBarHeight, lessThan(kToolbarHeight));
    final title = tester.widget<Text>(
      find.descendant(of: find.byType(AppBar), matching: find.text('一括リネーム')),
    );
    final style = DefaultTextStyle.of(
      tester.element(find.text('一括リネーム')),
    ).style.merge(title.style);
    expect(style.fontSize, appBarTitleFontSize);
    expect(appBarTitleFontSize, lessThan(22));
  });

  testWidgets('一覧の行の区切り線は他の境界線より少し濃い(008:T10 要望10)', (tester) async {
    // 2026-09-02 の要望10:「行の区切り線がやや薄いので、もう少しだけ濃くしても良いかも」。
    final rule = RuleController();
    addTearDown(rule.dispose);
    await tester.pumpWidget(DemoApp(ruleController: rule));
    await tester.pump();

    final colors = AppColors.dark;
    final row = find
        .ancestor(
          of: find.text('IMG_0009.jpg'),
          matching: find.byType(Container),
        )
        .evaluate()
        .map((e) => e.widget as Container)
        .firstWhere(
          (c) =>
              c.decoration is BoxDecoration &&
              (c.decoration! as BoxDecoration).border is Border &&
              ((c.decoration! as BoxDecoration).border! as Border)
                      .bottom
                      .width >
                  0 &&
              ((c.decoration! as BoxDecoration).border! as Border)
                      .bottom
                      .style !=
                  BorderStyle.none,
        );
    final bottom =
        ((row.decoration! as BoxDecoration).border! as Border).bottom;
    expect(bottom.color, colors.rowDivider);
    // 少しだけ濃い: 他の境界線より不透明で、それでも控えめ(白の 15% 未満)。
    expect(colors.rowDivider.a, greaterThan(colors.border.a));
    expect(colors.rowDivider.a, lessThan(0.15));
  });

  testWidgets('composition root がヘッダーへ歯車を置く(008:T43)', (tester) async {
    // test は Linux(desktop)で動くので、更新日時ずらしが有効 = 歯車が出る。
    // `main.dart` で置き忘れると設定そのものが画面から消える(フッターから移したため)。
    final rule = RuleController();
    addTearDown(rule.dispose);
    await tester.pumpWidget(DemoApp(ruleController: rule));
    await tester.pump();

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byKey(renameSettingsButtonKey),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(renameSettingsButtonKey));
    await tester.pumpAndSettle();
    expect(find.text(shiftModifiedAtLabel), findsOneWidget);
  });

  testWidgets('composition root が行へ preview の供給元を配る(008:T07)', (tester) async {
    // **配り忘れても画面は「それらしく」見える。** port が無い行は種別アイコンを
    // 出すので、`main.dart` で渡し忘れても T07 の機能が丸ごと消えたことに
    // 気付けない(013:T05 で3回FAILしたのと同じ型)。中間の widget ではなく
    // **行そのものが port を受け取っているか**を見る。
    final rule = RuleController();
    addTearDown(rule.dispose);
    await tester.pumpWidget(DemoApp(ruleController: rule));
    await tester.pump();

    final rows = tester.widgetList<RowPreviewView>(find.byType(RowPreviewView));
    expect(rows, isNotEmpty);
    expect(
      rows.every((row) => row.preview != null),
      isTrue,
      reason: '行に preview の供給元が届いていない',
    );
  });

  testWidgets('demo dataは2つのフォルダに分かれている(008:T23 / 質問2)', (tester) async {
    // **複数フォルダの混在は製品経路から到達できない**(Androidは 004 REQ-016 で
    // 1フォルダ、desktopのpickerも跨げない)。demoの初期値だけが、帯の
    // `複数のフォルダ` と行ごとの場所(002 代表例 7c)を実機で目視できる経路である。
    // ここを短い1フォルダに戻すと、その確認手段が黙って消える。
    final rule = RuleController();
    addTearDown(rule.dispose);
    await tester.pumpWidget(DemoApp(ruleController: rule));
    await tester.pump();

    expect(
      find.byKey(sourceLocationLabelKey),
      findsOneWidget,
      reason: '帯が場所を出していない',
    );
    expect(
      tester.widget<Text>(find.byKey(sourceLocationLabelKey)).data,
      '複数のフォルダ',
    );
    // 帯が `複数のフォルダ` を選ぶのは**場所が2種類以上あるときだけ**なので、
    // 上の1行がdemo dataが2フォルダに分かれていることの証拠になる。
    //
    // 行側も場所を出している(混在しているときだけ出る条件の表側)。
    // **「2種類見えるはず」とは書かない** — `ListView` は見えている行しか作らないので、
    // viewport の高さに依存した検査になる。
    expect(find.byType(FileListView), findsOneWidget);
    expect(
      find.byKey(rowLocationKey),
      findsWidgets,
      reason: '混在しているのに行が場所を出していない',
    );
  });

  testWidgets('demo dataの全行が外せる(008:T04 / 004 REQ-006)', (tester) async {
    // **選択モードの checkbox はハンドルを持つ行にだけ出る**(008:T28 で
    // 行の × から移した)。checkbox を廃止した後(002 REQ-016)は対象の
    // 出し入れが除去だけなので、ハンドルを持たない demo data では
    // **1件も外せない**(2026-09-18 の実機確認で観測した)。
    final rule = RuleController();
    addTearDown(rule.dispose);
    await tester.pumpWidget(DemoApp(ruleController: rule));
    await tester.pump();

    await enterRemovalMode(tester);
    // **`Checkbox` の総数では数えない。** demo の tree には行以外の checkbox も
    // 居る(下部バーの更新日時ずらし)。**作られた行を列挙して、その行の
    // checkbox が在るか**を見る — `ListView` は見えている行だけを作るので、
    // 「何個あるはず」と書くと viewport の高さに依存した検査になる。
    final builtRows = tester
        .widgetList<RowPreviewView>(
          find.byType(RowPreviewView, skipOffstage: false),
        )
        .map((row) => row.file)
        .toList();
    expect(builtRows, isNotEmpty);
    for (final file in builtRows) {
      final handle = file.sourceHandle;
      expect(handle, isNotNull, reason: '${file.name} に元場所ハンドルが無い');
      expect(
        find.byKey(removalMarkKeyOf(handle!), skipOffstage: false),
        findsOneWidget,
        reason: '${file.name} を選べない',
      );
    }
  });

  testWidgets('demo dataのハンドルは実在しうるpathにしない(008:T04)', (tester) async {
    // `/storage/emulated/0/DCIM/Camera/IMG_0009.jpg` のような値にすると、
    // **デモのつもりの操作が実機の本物のファイルを改名しうる**。
    final rule = RuleController();
    addTearDown(rule.dispose);
    await tester.pumpWidget(DemoApp(ruleController: rule));
    await tester.pump();

    final view = tester.widget<FileListView>(find.byType(FileListView));
    final items = view.controller.items;
    expect(items, isNotEmpty);
    for (final item in items) {
      expect(item.sourceHandle, startsWith('demo:'), reason: item.name);
      expect(item.sourceFolder, startsWith('demo:'), reason: item.name);
    }
  });
}
