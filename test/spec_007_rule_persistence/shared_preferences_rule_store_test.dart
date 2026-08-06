// VER(T5): shared_preferences 実ストアアダプタのモック検証(REQ-005/REQ-006/REQ-007)。
// 実永続化(再起動での復元)はホスト/実機で確認する(emulator-verification.md)。
import 'package:batch_rename_master/core/rename_rule.dart';
import 'package:batch_rename_master/core/token.dart';
import 'package:batch_rename_master/data/rule_store/rule_persistence.dart';
import 'package:batch_rename_master/data/rule_store/shared_preferences_rule_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SharedPreferencesRuleStore> _store(Map<String, Object> initial) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  return SharedPreferencesRuleStore(prefs);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('未保存なら read は null(REQ-005)', () async {
    final store = await _store({});
    expect(await store.read(), isNull);
  });

  test('write の後の read は最後の値(REQ-005)', () async {
    final store = await _store({});
    await store.write('a');
    await store.write('b');
    expect(await store.read(), 'b');
  });

  test('既存の保存値を読み出す', () async {
    final store = await _store({'current_rule': 'seeded'});
    expect(await store.read(), 'seeded');
  });

  test('serialize→write→load でルールが往復する(REQ-006/REQ-007)', () async {
    final store = await _store({});
    const rule = RenameRule([
      OriginalNameToken(),
      LiteralToken('_'),
      SequenceToken(start: 1, digits: 2, increment: 1),
    ]);
    await saveCurrentRule(store, rule);
    final restored = await loadLastRule(store);
    expect(restored.tokens.length, 3);
    expect((restored.tokens[2] as SequenceToken).digits, 2);
  });

  test('壊れた保存値は空ルールへフォールバック(REQ-006)', () async {
    final store = await _store({'current_rule': '{壊れた'});
    final restored = await loadLastRule(store);
    expect(restored.tokens, isEmpty);
  });
}
