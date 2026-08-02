// VER-002(T4 分): 各トークンの詳細エディタ → replaceAt で差し替え(REQ-005)。
// 自由テキストの空不可(確定無効)、区切りプリセット、連番ステッパー、日時プリセットを検証。
import 'package:batch_rename_master/core/rename_engine.dart';
import 'package:batch_rename_master/ui/rule_builder/rule_builder_view.dart';
import 'package:batch_rename_master/ui/rule_builder/rule_controller.dart';
import 'package:batch_rename_master/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, RuleController c) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: appDarkTheme(),
      home: Scaffold(body: RuleBuilderView(controller: c)),
    ),
  );
}

FilledButton _confirmButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, '確定'));

void main() {
  testWidgets('自由テキスト: 空だと確定無効、入力後に replaceAt で差し替え(REQ-005)', (tester) async {
    final c = RuleController(tokens: const [LiteralToken('旧')]);
    await _pump(tester, c);

    await tester.tap(find.text('旧'));
    await tester.pumpAndSettle();
    expect(find.text('テキスト / 区切り'), findsOneWidget);

    // 空にすると確定は無効。
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    expect(_confirmButton(tester).onPressed, isNull);

    // 非空で確定可能 → 差し替え。
    await tester.enterText(find.byType(TextField), 'ABC');
    await tester.pump();
    expect(_confirmButton(tester).onPressed, isNotNull);
    await tester.tap(find.widgetWithText(FilledButton, '確定'));
    await tester.pumpAndSettle();

    expect(c.tokens.single, isA<LiteralToken>());
    expect((c.tokens.single as LiteralToken).value, 'ABC');
    expect(find.text('ABC'), findsOneWidget); // Chip 更新
  });

  testWidgets('区切りプリセットを選ぶと値が入る', (tester) async {
    final c = RuleController(tokens: const [LiteralToken('x')]);
    await _pump(tester, c);
    await tester.tap(find.text('x'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('_（アンダーバー）'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '確定'));
    await tester.pumpAndSettle();

    expect((c.tokens.single as LiteralToken).value, '_');
  });

  testWidgets('連番: ステッパーで桁数を増やして差し替え(REQ-005)', (tester) async {
    final c = RuleController(
      tokens: const [SequenceToken(start: 1, digits: 2)],
    );
    await _pump(tester, c);
    await tester.tap(find.text('連番(2桁)'));
    await tester.pumpAndSettle();

    // 桁数(2番目のステッパー)の + を1回。
    await tester.tap(find.byTooltip('増やす').at(1));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '確定'));
    await tester.pumpAndSettle();

    expect((c.tokens.single as SequenceToken).digits, 3);
    expect(find.text('連番(3桁)'), findsOneWidget);
  });

  testWidgets('連番: start は 0 未満に減らせない', (tester) async {
    final c = RuleController(
      tokens: const [SequenceToken(start: 0, digits: 2)],
    );
    await _pump(tester, c);
    await tester.tap(find.text('連番(2桁)'));
    await tester.pumpAndSettle();

    // 開始番号(先頭ステッパー)の - は無効(start=0)。
    final minus = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.remove_circle_outline).first,
    );
    expect(minus.onPressed, isNull);
  });

  testWidgets('日時: 基準とプリセットで差し替え(REQ-005)', (tester) async {
    final c = RuleController(
      tokens: const [
        DateTimeToken(source: DateTimeSource.created, format: 'YYYYMMDD'),
      ],
    );
    await _pump(tester, c);
    await tester.tap(find.text('日時 YYYYMMDD'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('更新日時'));
    await tester.pump();
    await tester.tap(find.text('YYYY-MM-DD')); // プリセット
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '確定'));
    await tester.pumpAndSettle();

    final t = c.tokens.single as DateTimeToken;
    expect(t.source, DateTimeSource.modified);
    expect(t.format, 'YYYY-MM-DD');
    expect(find.text('日時 YYYY-MM-DD'), findsOneWidget);
  });

  testWidgets('元の名前: 設定項目がなくエディタは開かない', (tester) async {
    final c = RuleController(tokens: const [OriginalNameToken()]);
    await _pump(tester, c);
    await tester.tap(find.text('元の名前'));
    await tester.pumpAndSettle();

    expect(find.text('確定'), findsNothing);
    expect(c.tokens.single, isA<OriginalNameToken>());
  });
}
