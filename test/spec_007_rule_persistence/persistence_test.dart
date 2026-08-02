// VER-002: RuleStore 契約 + 復元/保存オーケストレーションの検証(FEAT-007 / Light)。
// 対象: REQ-005(store 契約), REQ-006(loadLastRule), REQ-007(saveCurrentRule)。
import 'package:batch_rename_master/core/rename_rule.dart';
import 'package:batch_rename_master/core/rule_serialization.dart';
import 'package:batch_rename_master/core/token.dart';
import 'package:batch_rename_master/data/rule_store/rule_persistence.dart';
import 'package:batch_rename_master/data/rule_store/rule_store.dart';
import 'package:flutter_test/flutter_test.dart';

const _rule = RenameRule([
  OriginalNameToken(),
  LiteralToken('_'),
  SequenceToken(start: 1, digits: 2, increment: 1),
]);

void main() {
  group('REQ-005: RuleStore(InMemoryRuleStore)の契約', () {
    test('未書き込みなら read は null', () async {
      final store = InMemoryRuleStore();
      expect(await store.read(), isNull);
    });

    test('write の後の read は最後に書いた値', () async {
      final store = InMemoryRuleStore();
      await store.write('a');
      await store.write('b');
      expect(await store.read(), 'b');
    });

    test('seed を与えると初期値になる', () async {
      final store = InMemoryRuleStore('seeded');
      expect(await store.read(), 'seeded');
    });
  });

  group('REQ-006: loadLastRule', () {
    test('空ストアは空ルール', () async {
      final rule = await loadLastRule(InMemoryRuleStore());
      expect(rule.tokens, isEmpty);
    });

    test('壊れたデータは空ルール(例外なし)', () async {
      final rule = await loadLastRule(InMemoryRuleStore('{壊れた'));
      expect(rule.tokens, isEmpty);
    });

    test('非対応バージョンのデータも空ルール', () async {
      final rule = await loadLastRule(
        InMemoryRuleStore('{"version":99,"tokens":[]}'),
      );
      expect(rule.tokens, isEmpty);
    });

    test('正当な保存は復元される', () async {
      final store = InMemoryRuleStore(serializeRule(_rule));
      final rule = await loadLastRule(store);
      expect(rule.tokens.length, 3);
      expect(rule.tokens[0], isA<OriginalNameToken>());
      expect((rule.tokens[1] as LiteralToken).value, '_');
      expect((rule.tokens[2] as SequenceToken).digits, 2);
    });
  });

  group('REQ-007: saveCurrentRule', () {
    test('save→load でルールが往復する', () async {
      final store = InMemoryRuleStore();
      await saveCurrentRule(store, _rule);
      final restored = await loadLastRule(store);
      expect(restored.tokens.length, 3);
      expect((restored.tokens[2] as SequenceToken).digits, 2);
    });

    test('保存内容はシリアライズ結果に等しい', () async {
      final store = InMemoryRuleStore();
      await saveCurrentRule(store, _rule);
      expect(await store.read(), serializeRule(_rule));
    });

    test('空ルールも保存・復元できる(例外なし)', () async {
      final store = InMemoryRuleStore();
      await saveCurrentRule(store, RenameRule.empty);
      final restored = await loadLastRule(store);
      expect(restored.tokens, isEmpty);
    });
  });
}
