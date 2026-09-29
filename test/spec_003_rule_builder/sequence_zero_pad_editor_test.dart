// VER-002(014:T04 分): 連番のエディタのゼロ埋めの切り替え(REQ-013)と、桁数の
// 下限・自動の引き上げ(REQ-014)。代表例13〜17。
//
// **件数がエディタへ届く経路も見る**(003 spec VER-002 の注記)。件数を渡し忘れると
// 下限が常に0件のものになり、利用者には「下限が効かない」だけに見えて気づけない。
import 'package:batch_rename_master/core/rename_engine.dart';
import 'package:batch_rename_master/ui/file_list/file_list_controller.dart';
import 'package:batch_rename_master/ui/file_list/rename_warning_view.dart';
import 'package:batch_rename_master/ui/rule_builder/rule_builder_view.dart';
import 'package:batch_rename_master/ui/rule_builder/rule_builder_workspace.dart';
import 'package:batch_rename_master/ui/rule_builder/rule_controller.dart';
import 'package:batch_rename_master/ui/rule_builder/token_editors.dart';
import 'package:batch_rename_master/ui/rule_builder/token_presets.dart';
import 'package:batch_rename_master/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

FileEntry _file(String name) => FileEntry(
  name: name,
  createdAt: DateTime(2026, 1, 1),
  modifiedAt: DateTime(2026, 1, 1),
  size: 0,
);

Future<void> _pump(WidgetTester tester, RuleController c, int count) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: appDarkTheme(),
      home: Scaffold(
        body: RuleBuilderView(controller: c, itemCount: () => count),
      ),
    ),
  );
}

/// エディタの桁数の欄に出ている値。欄が無ければ null。
int? _digitsShown(WidgetTester tester) {
  final row = find.widgetWithText(Row, '桁数');
  if (row.evaluate().isEmpty) return null;
  final values = tester
      .widgetList<Text>(find.descendant(of: row, matching: find.byType(Text)))
      .map((t) => t.data)
      .whereType<String>()
      .map(int.tryParse)
      .whereType<int>();
  return values.single;
}

Finder _plus(String label) => find.descendant(
  of: find.widgetWithText(Row, label),
  matching: find.widgetWithIcon(IconButton, Icons.add),
);

Finder _minus(String label) => find.descendant(
  of: find.widgetWithText(Row, label),
  matching: find.widgetWithIcon(IconButton, Icons.remove),
);

/// 桁数の欄の「減らす」。
IconButton _digitsDec(WidgetTester tester) =>
    tester.widget<IconButton>(_minus('桁数'));

Future<void> _confirm(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(FilledButton, label));
  await tester.pumpAndSettle();
}

SequenceToken _seq(RuleController c) => c.tokens.single as SequenceToken;

void main() {
  group('sequenceMinDigits(REQ-014 の下限)', () {
    test('最大の番号の桁数', () {
      expect(sequenceMinDigits(start: 90, increment: 1, itemCount: 20), 3);
      expect(sequenceMinDigits(start: 1, increment: 1, itemCount: 20), 2);
      expect(sequenceMinDigits(start: 1, increment: 1, itemCount: 99), 2);
      expect(sequenceMinDigits(start: 1, increment: 1, itemCount: 100), 3);
      expect(sequenceMinDigits(start: 90, increment: 5, itemCount: 3), 3);
      expect(sequenceMinDigits(start: 1, increment: 1, itemCount: 9), 1);
    });
    test('0件なら開始番号の桁数', () {
      expect(sequenceMinDigits(start: 100, increment: 1, itemCount: 0), 3);
      expect(sequenceMinDigits(start: 1, increment: 1, itemCount: 0), 1);
    });
  });

  group('REQ-014: 桁数の下限と自動の引き上げ', () {
    testWidgets('例13: 開始を上げると桁数が下限まで上がり、下限未満には下げられない', (tester) async {
      // 11件・開始89・桁2 → 最大99。開始を90にすると最大100で下限3。
      final c = RuleController(
        tokens: const [SequenceToken(start: 89, digits: 2)],
      );
      await _pump(tester, c, 11);
      await tester.tap(find.text('連番(2桁)'));
      await tester.pumpAndSettle();
      expect(_digitsShown(tester), 2);

      await tester.tap(_plus('開始番号'));
      await tester.pump();
      expect(_digitsShown(tester), 3, reason: '下限まで引き上げる');
      expect(_digitsDec(tester).onPressed, isNull, reason: '下限未満には下げられない');
      expect(find.text('11件・開始90なので3桁以上'), findsOneWidget);
      // 確定するまでルールは変わらない(REQ-011)。
      expect(_seq(c).digits, 2);

      await _confirm(tester, '確定');
      expect(_seq(c).start, 90);
      expect(_seq(c).digits, 3);
    });

    testWidgets('例14: 開始を戻しても桁数は自動で下げない(手で下げられる)', (tester) async {
      final c = RuleController(
        tokens: const [SequenceToken(start: 89, digits: 2)],
      );
      await _pump(tester, c, 11);
      await tester.tap(find.text('連番(2桁)'));
      await tester.pumpAndSettle();
      await tester.tap(_plus('開始番号'));
      await tester.pump();
      expect(_digitsShown(tester), 3);

      await tester.tap(_minus('開始番号'));
      await tester.pump();
      expect(_digitsShown(tester), 3, reason: '自動では下げない');
      expect(_digitsDec(tester).onPressed, isNotNull);
      await tester.tap(_minus('桁数'));
      await tester.pump();
      expect(_digitsShown(tester), 2);
    });

    testWidgets('増分を上げても下限まで引き上げる', (tester) async {
      // 11件・開始1・増分9 → 最大91(2桁)。増分10 → 最大101(3桁)。
      final c = RuleController(
        tokens: const [SequenceToken(start: 1, digits: 2, increment: 9)],
      );
      await _pump(tester, c, 11);
      await tester.tap(find.text('連番(2桁)'));
      await tester.pumpAndSettle();
      expect(_digitsShown(tester), 2);
      await tester.tap(_plus('増分'));
      await tester.pump();
      expect(_digitsShown(tester), 3);
      // 下限の理由に増分も書く(開始と件数だけでは3桁の理由が読めない)。
      expect(find.text('11件・開始1・増分10なので3桁以上'), findsOneWidget);
    });

    testWidgets('例15: 件数が後から増えた連番は、下限まで上げた値で開く。キャンセルでは変わらない', (tester) async {
      final c = RuleController(
        tokens: const [SequenceToken(start: 1, digits: 2)],
      );
      await _pump(tester, c, 150);
      await tester.tap(find.text('連番(2桁)'));
      await tester.pumpAndSettle();
      expect(_digitsShown(tester), 3);

      await tester.tap(find.text('キャンセル'));
      await tester.pumpAndSettle();
      expect(_seq(c).digits, 2, reason: 'ルールを黙って書き換えない');

      await tester.tap(find.text('連番(2桁)'));
      await tester.pumpAndSettle();
      await _confirm(tester, '確定');
      expect(_seq(c).digits, 3);
    });

    testWidgets('例17: 0件なら開始番号の桁数が下限', (tester) async {
      final c = RuleController(
        tokens: const [SequenceToken(start: 99, digits: 2)],
      );
      await _pump(tester, c, 0);
      await tester.tap(find.text('連番(2桁)'));
      await tester.pumpAndSettle();
      await tester.tap(_plus('開始番号'));
      await tester.pump();
      expect(_digitsShown(tester), 3);
    });

    testWidgets('追加のエディタでも同じ下限を使う(REQ-012)', (tester) async {
      final c = RuleController();
      await _pump(tester, c, 150);
      await tester.tap(find.text('＋ 連番'));
      await tester.pumpAndSettle();
      expect(_digitsShown(tester), 3, reason: '初期値の2桁を下限まで上げて開く');
      await _confirm(tester, '追加');
      expect(_seq(c).digits, 3);
      expect(_seq(c).zeroPad, isTrue);
    });
  });

  group('REQ-013: ゼロ埋めの切り替え', () {
    testWidgets('例16: ゼロ埋めなしにすると桁数を求めず、確定したトークンが持つ', (tester) async {
      final c = RuleController(
        tokens: const [SequenceToken(start: 1, digits: 2)],
      );
      await _pump(tester, c, 10);
      await tester.tap(find.text('連番(2桁)'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<SwitchListTile>(find.byKey(sequenceZeroPadKey)).value,
        isTrue,
      );

      await tester.tap(find.byKey(sequenceZeroPadKey));
      await tester.pump();
      expect(_digitsShown(tester), isNull, reason: '桁数の入力を求めない');

      await _confirm(tester, '確定');
      expect(_seq(c).zeroPad, isFalse);
      expect(_seq(c).digits, 2, reason: '値は保持する');
      expect(find.text('連番(ゼロ埋めなし)'), findsOneWidget);
    });

    testWidgets('ゼロ埋めへ戻すと保持した桁数が戻り、下限を下回れば引き上げる', (tester) async {
      final c = RuleController(
        tokens: const [SequenceToken(start: 1, digits: 1, zeroPad: false)],
      );
      await _pump(tester, c, 150);
      await tester.tap(find.text('連番(ゼロ埋めなし)'));
      await tester.pumpAndSettle();
      expect(_digitsShown(tester), isNull);

      await tester.tap(find.byKey(sequenceZeroPadKey));
      await tester.pump();
      expect(_digitsShown(tester), 3);
      await _confirm(tester, '確定');
      expect(_seq(c).zeroPad, isTrue);
      expect(_seq(c).digits, 3);
    });

    testWidgets('ゼロ埋めなしのあいだは開始を変えても桁数を引き上げない', (tester) async {
      final c = RuleController(
        tokens: const [SequenceToken(start: 99, digits: 1, zeroPad: false)],
      );
      await _pump(tester, c, 1);
      await tester.tap(find.text('連番(ゼロ埋めなし)'));
      await tester.pumpAndSettle();
      await tester.tap(_plus('開始番号'));
      await tester.pump();
      await _confirm(tester, '確定');
      expect(_seq(c).start, 100);
      expect(_seq(c).digits, 1, reason: 'ゼロ埋めなしでは下限を当てない');
    });
  });

  group('連番を文字で見せる所(014:T04)', () {
    test('ゼロ埋めなしでは桁数を見せない', () {
      const off = SequenceToken(start: 1, digits: 3, zeroPad: false);
      const on = SequenceToken(start: 1, digits: 3);
      expect(tokenLabel(off), '連番(ゼロ埋めなし)');
      expect(tokenLabel(on), '連番(3桁)');
      expect(describeToken(off), '連番 ゼロ埋めなし');
      expect(describeToken(on), '連番 3 桁');
      expect(describeTokenChip(off), '[1…]');
      expect(describeTokenChip(on), '[001…]');
    });
  });

  group('件数がエディタへ届く(composition の経路)', () {
    for (final (name, size) in [
      ('広幅(2ペイン)', const Size(1000, 800)),
      ('狭幅(シート)', const Size(400, 800)),
    ]) {
      testWidgets('$name: 一覧の件数で下限が決まる', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        final fl = FileListController(
          files: [for (var i = 0; i < 150; i++) _file('f$i.txt')],
        );
        final rc = RuleController(
          tokens: const [SequenceToken(start: 1, digits: 2)],
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: appDarkTheme(),
            home: Scaffold(
              body: RuleBuilderWorkspace(fileList: fl, rule: rc),
            ),
          ),
        );
        await tester.pump();
        if (size.width < 840) {
          await tester.tap(find.byKey(const Key('configure-rule')));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text('連番(2桁)').last);
        await tester.pumpAndSettle();
        expect(_digitsShown(tester), 3, reason: '150件なので3桁以上');
      });
    }
  });
}
