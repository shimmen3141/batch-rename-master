// デモアプリのスモークテスト: サンプルデータで 002/003 を束ねた入口が
// 例外なく起動し、ファイルリストとルール編集の導線が出ることを確認する。
import 'package:batch_rename_master/main.dart';
import 'package:batch_rename_master/ui/file_list/file_list_view.dart';
import 'package:batch_rename_master/ui/file_list/row_preview_view.dart';
import 'package:batch_rename_master/ui/rule_builder/rule_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

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
    expect(find.text('変更する名前を設定する'), findsOneWidget);
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
}
