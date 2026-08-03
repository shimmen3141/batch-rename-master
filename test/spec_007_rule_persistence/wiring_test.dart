// VER-003: RuleController 配線(初期復元 + 変更保存)の検証(FEAT-007 REQ-008)。
import 'package:batch_rename_master/core/rename_rule.dart';
import 'package:batch_rename_master/core/rule_serialization.dart';
import 'package:batch_rename_master/core/token.dart';
import 'package:batch_rename_master/data/rule_store/rule_persistence.dart';
import 'package:batch_rename_master/data/rule_store/rule_store.dart';
import 'package:batch_rename_master/ui/rule_builder/persistent_rule_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('REQ-008: 初期復元', () {
    test('空ストアなら空ルールで開始', () async {
      final p = await PersistentRuleController.restore(InMemoryRuleStore());
      expect(p.controller.tokens, isEmpty);
      p.dispose();
    });

    test('保存済みルールを復元して初期化', () async {
      const saved = RenameRule([
        OriginalNameToken(),
        SequenceToken(start: 1, digits: 2, increment: 1),
      ]);
      final store = InMemoryRuleStore(serializeRule(saved));
      final p = await PersistentRuleController.restore(store);
      expect(p.controller.tokens.length, 2);
      expect(p.controller.tokens[0], isA<OriginalNameToken>());
      expect((p.controller.tokens[1] as SequenceToken).digits, 2);
      p.dispose();
    });

    test('壊れたデータは空ルールで開始(復元失敗フォールバック)', () async {
      final p = await PersistentRuleController.restore(
        InMemoryRuleStore('{壊れた'),
      );
      expect(p.controller.tokens, isEmpty);
      p.dispose();
    });
  });

  group('REQ-008: 変更保存', () {
    test('トークン追加で保存され、次回 load に反映される', () async {
      final store = InMemoryRuleStore();
      final p = await PersistentRuleController.restore(store);

      p.controller.addToken(const LiteralToken('X'));
      final reloaded = await loadLastRule(store);
      expect(reloaded.tokens.single, isA<LiteralToken>());
      expect((reloaded.tokens.single as LiteralToken).value, 'X');
      p.dispose();
    });

    test('複数変更後は最後の状態が保存される', () async {
      final store = InMemoryRuleStore();
      final p = await PersistentRuleController.restore(store);

      p.controller.addToken(const OriginalNameToken());
      p.controller.addToken(const LiteralToken('_'));
      p.controller.removeAt(0);

      final reloaded = await loadLastRule(store);
      expect(reloaded.tokens.length, 1);
      expect((reloaded.tokens.single as LiteralToken).value, '_');
      p.dispose();
    });

    test('復元→変更→別セッションで再復元すると引き継がれる', () async {
      final store = InMemoryRuleStore();
      final first = await PersistentRuleController.restore(store);
      first.controller.addToken(const SequenceToken(start: 5, digits: 3));
      first.dispose();

      final second = await PersistentRuleController.restore(store);
      expect(second.controller.tokens.single, isA<SequenceToken>());
      expect((second.controller.tokens.single as SequenceToken).start, 5);
      second.dispose();
    });
  });
}
