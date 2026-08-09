// デモアプリのスモークテスト: サンプルデータで 002/003 を束ねた入口が
// 例外なく起動し、ファイルリストとルール編集の導線が出ることを確認する。
import 'package:batch_rename_master/main.dart';
import 'package:batch_rename_master/ui/file_list/file_list_view.dart';
import 'package:batch_rename_master/ui/rule_builder/rule_controller.dart';
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
    // 既定サイズ(800x600)はモバイル幅なのでルール編集ボタンが出る。
    expect(find.text('ルールを編集'), findsOneWidget);
  });
}
