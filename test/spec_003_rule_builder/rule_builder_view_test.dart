// VER-002(T3 分): トークン Chip 列の描画と 追加/削除/並び替え → 状態反映。
// 対象: REQ-002(addToken)/ REQ-003(removeAt)/ REQ-004(reorder)。詳細エディタは T4、
// 002 setRule 連携は T5。
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

void main() {
  testWidgets('空のときはヒントを表示し、5種の追加ボタンがある', (tester) async {
    final c = RuleController();
    await _pump(tester, c);
    expect(find.text('↓ 下のボタンから要素を追加'), findsOneWidget);
    for (final label in const ['＋ 元の名前', '＋ 自由テキスト', '＋ 区切り', '＋ 連番', '＋ 日時']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('追加ボタンで既定トークンが追加され Chip が表示される(REQ-002)', (tester) async {
    final c = RuleController();
    await _pump(tester, c);

    await tester.tap(find.text('＋ 連番'));
    await tester.pump();
    expect(c.tokens, hasLength(1));
    expect(c.tokens.single, isA<SequenceToken>());
    expect(find.text('連番(2桁)'), findsOneWidget);

    await tester.tap(find.text('＋ 区切り'));
    await tester.pump();
    expect(c.tokens, hasLength(2));
    expect(find.text('_'), findsOneWidget);
  });

  testWidgets('Chip の削除ボタンで該当トークンが取り除かれる(REQ-003)', (tester) async {
    final c = RuleController(
      tokens: const [OriginalNameToken(), SequenceToken(start: 1, digits: 2)],
    );
    await _pump(tester, c);
    expect(find.text('元の名前'), findsOneWidget);
    expect(find.text('連番(2桁)'), findsOneWidget);

    // 先頭 Chip(元の名前)の削除ボタンを押す。
    await tester.tap(find.byTooltip('削除').first);
    await tester.pump();

    expect(c.tokens, hasLength(1));
    expect(c.tokens.single, isA<SequenceToken>());
    expect(find.text('元の名前'), findsNothing);
  });

  testWidgets('onReorderItem で並び替わる(REQ-004)', (tester) async {
    final c = RuleController(
      tokens: const [OriginalNameToken(), LiteralToken('_'), SequenceToken()],
    );
    await _pump(tester, c);

    final rlv = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );
    rlv.onReorderItem!(0, 2); // 元名を末尾へ -> ['_', 連番, 元名]
    await tester.pump();

    expect(c.tokens[0], isA<LiteralToken>());
    expect(c.tokens[1], isA<SequenceToken>());
    expect(c.tokens[2], isA<OriginalNameToken>());
  });

  testWidgets('各トークン種別のラベルを表示する', (tester) async {
    final c = RuleController(
      tokens: const [
        OriginalNameToken(),
        LiteralToken('テキスト'),
        DateTimeToken(source: DateTimeSource.created, format: 'YYYYMMDD'),
      ],
    );
    await _pump(tester, c);
    expect(find.text('元の名前'), findsOneWidget);
    expect(find.text('テキスト'), findsOneWidget);
    expect(find.text('日時 YYYYMMDD'), findsOneWidget);
  });
}
