import '../../core/rename_rule.dart';
import '../../core/rule_serialization.dart';
import 'rule_store.dart';

/// 復元/保存のオーケストレーション(FEAT-007)。[RuleStore] とシリアライズを繋ぐ。

/// 保存済みのルールを復元する(REQ-006)。
///
/// [store] に保存が無い（`read()==null`）か、壊れていて [deserializeRule] が
/// `null` の場合は空ルール（[RenameRule.empty]）を返す。
Future<RenameRule> loadLastRule(RuleStore store) async {
  final raw = await store.read();
  if (raw == null) return RenameRule.empty;
  return deserializeRule(raw) ?? RenameRule.empty;
}

/// 現在のルールを保存する(REQ-007)。空ルールも保存対象。
Future<void> saveCurrentRule(RuleStore store, RenameRule rule) =>
    store.write(serializeRule(rule));
