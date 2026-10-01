// 003 REQ-015(`008:T51` で定義、`008:T52` で実装): 一覧の件数が増えて、ゼロ埋め
// ありの連番の桁数が下限(REQ-014 と同じ式)を下回ったら、下限まで引き上げて知らせる。
// 代表例 15〜15d。
import 'package:batch_rename_master/core/rename_engine.dart';
import 'package:batch_rename_master/core/rule_serialization.dart';
import 'package:batch_rename_master/data/rule_store/rule_store.dart';
import 'package:batch_rename_master/ui/file_list/file_list_controller.dart';
import 'package:batch_rename_master/ui/rule_builder/persistent_rule_controller.dart';
import 'package:batch_rename_master/ui/rule_builder/rule_builder_workspace.dart';
import 'package:batch_rename_master/ui/rule_builder/rule_controller.dart';
import 'package:batch_rename_master/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

List<FileEntry> _files(int n) => [
  for (var i = 0; i < n; i++)
    FileEntry(
      name: 'f${i.toString().padLeft(3, '0')}.txt',
      modifiedAt: DateTime(2026, 8, 4),
      size: 0,
    ),
];

SequenceToken _seq(Token t) => t as SequenceToken;

void main() {
  group('RuleController.raiseSequenceDigits(REQ-015)', () {
    test('例15: 下限を下回る桁数を下限まで引き上げ、1回だけ通知する', () {
      final rule = RuleController(
        tokens: const [OriginalNameToken(), SequenceToken(digits: 2)],
      );
      var notified = 0;
      rule.addListener(() => notified++);

      final raises = rule.raiseSequenceDigits(150);

      expect(raises, [(index: 1, from: 2, to: 3)]);
      expect(_seq(rule.tokens[1]).digits, 3);
      expect(notified, 1);
      // ほかのトークンと連番のほかの値は変えない。
      expect(rule.tokens[0], isA<OriginalNameToken>());
      expect(_seq(rule.tokens[1]).start, 1);
      expect(_seq(rule.tokens[1]).increment, 1);
      expect(_seq(rule.tokens[1]).zeroPad, isTrue);
    });

    test('下限の式は開始番号と増分を含む(REQ-014 と同じ)', () {
      final rule = RuleController(
        tokens: const [SequenceToken(start: 90, digits: 2, increment: 5)],
      );
      // 最大 = 90 + (3 − 1) × 5 = 100 → 3 桁。
      expect(rule.raiseSequenceDigits(3), [(index: 0, from: 2, to: 3)]);
    });

    test('例15a: 件数が減っても下げない(通知もしない)', () {
      final rule = RuleController(tokens: const [SequenceToken(digits: 2)]);
      rule.raiseSequenceDigits(150);
      var notified = 0;
      rule.addListener(() => notified++);

      expect(rule.raiseSequenceDigits(50), isEmpty);
      expect(_seq(rule.tokens.single).digits, 3);
      expect(notified, 0);
    });

    test('下限ちょうど・上回る桁数は変えない', () {
      final rule = RuleController(tokens: const [SequenceToken(digits: 3)]);
      expect(rule.raiseSequenceDigits(150), isEmpty);
      expect(rule.raiseSequenceDigits(999), isEmpty);
      expect(_seq(rule.tokens.single).digits, 3);
    });

    test('例15b: ゼロ埋めなしの連番は触らない', () {
      final rule = RuleController(
        tokens: const [SequenceToken(digits: 2, zeroPad: false)],
      );
      var notified = 0;
      rule.addListener(() => notified++);

      expect(rule.raiseSequenceDigits(150), isEmpty);
      expect(_seq(rule.tokens.single).digits, 2);
      expect(notified, 0);
    });

    test('例15d: 連番が複数なら、下回るものだけを1回の変更で引き上げる', () {
      final rule = RuleController(
        tokens: const [
          SequenceToken(digits: 2),
          LiteralToken('_'),
          SequenceToken(digits: 4),
          SequenceToken(start: 5, digits: 1),
        ],
      );
      var notified = 0;
      rule.addListener(() => notified++);

      final raises = rule.raiseSequenceDigits(150);

      expect(raises, [
        (index: 0, from: 2, to: 3),
        (index: 3, from: 1, to: 3), // 5 + 149 = 154 → 3 桁
      ]);
      expect(_seq(rule.tokens[2]).digits, 4, reason: '下限を上回る連番は変えない');
      expect(notified, 1);
    });

    test('引き上げは保存される(007 REQ-008 の経路: 変更の通知で保存する)', () async {
      final store = InMemoryRuleStore(
        serializeRule(const RenameRule([SequenceToken(digits: 2)])),
      );
      final session = await PersistentRuleController.restore(store);
      addTearDown(session.dispose);

      session.controller.raiseSequenceDigits(150);
      await Future<void>.delayed(Duration.zero);

      final saved = deserializeRule((await store.read())!)!;
      expect(_seq(saved.tokens.single).digits, 3);
    });
  });

  group('画面: 件数が増えたら引き上げて知らせる(REQ-015)', () {
    Future<void> pump(
      WidgetTester tester,
      FileListController files,
      RuleController rule,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: appDarkTheme(),
          home: Scaffold(
            body: RuleBuilderWorkspace(fileList: files, rule: rule),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('例15: 一覧を50件から150件にすると桁3になり、2桁から3桁へと知らされる', (tester) async {
      final files = FileListController(files: _files(50));
      final rule = RuleController(tokens: const [SequenceToken(digits: 2)]);
      addTearDown(rule.dispose);
      await pump(tester, files, rule);
      expect(find.byKey(sequenceDigitsRaisedToastKey), findsNothing);
      expect(_seq(rule.tokens.single).digits, 2);

      files.setFiles(_files(150));
      await tester.pump();
      await tester.pump();

      expect(_seq(rule.tokens.single).digits, 3);
      expect(find.byKey(sequenceDigitsRaisedToastKey), findsOneWidget);
      expect(find.textContaining('2桁から3桁'), findsOneWidget);
      // 001 は桁不足を返さない(一覧へ引き上げたルールが流れている)。
      expect(files.warnings.whereType<DigitShortageWarning>(), isEmpty);
    });

    testWidgets('例15a: そのあと50件へ戻しても桁3のまま、知らせも出ない', (tester) async {
      final files = FileListController(files: _files(150));
      final rule = RuleController(tokens: const [SequenceToken(digits: 3)]);
      addTearDown(rule.dispose);
      await pump(tester, files, rule);

      files.setFiles(_files(50));
      await tester.pump();
      await tester.pump();

      expect(_seq(rule.tokens.single).digits, 3);
      expect(find.byKey(sequenceDigitsRaisedToastKey), findsNothing);
    });

    testWidgets('例15c: 復元したルールで起動し一覧が150件なら、起動時に引き上げて知らせる', (tester) async {
      final files = FileListController(files: _files(150));
      final rule = RuleController(tokens: const [SequenceToken(digits: 2)]);
      addTearDown(rule.dispose);
      await pump(tester, files, rule);

      expect(_seq(rule.tokens.single).digits, 3);
      expect(find.byKey(sequenceDigitsRaisedToastKey), findsOneWidget);
    });

    testWidgets('例15b: ゼロ埋めなしなら変わらず、知らせも出ない', (tester) async {
      final files = FileListController(files: _files(50));
      final rule = RuleController(
        tokens: const [SequenceToken(digits: 2, zeroPad: false)],
      );
      addTearDown(rule.dispose);
      await pump(tester, files, rule);

      files.setFiles(_files(150));
      await tester.pump();
      await tester.pump();

      expect(_seq(rule.tokens.single).digits, 2);
      expect(find.byKey(sequenceDigitsRaisedToastKey), findsNothing);
    });

    test('例15d の知らせは、変えた連番をそれぞれ読める', () {
      expect(
        sequenceDigitsRaisedMessage([
          (index: 0, from: 2, to: 3),
          (index: 3, from: 1, to: 3),
        ]),
        allOf(contains('2桁→3桁'), contains('1桁→3桁')),
      );
    });
  });
}
