import '../../data/rule_store/rule_persistence.dart';
import '../../data/rule_store/rule_store.dart';
import 'rule_controller.dart';

/// 永続化と結線した [RuleController] のセッション(FEAT-007 REQ-008)。
///
/// [restore] で [RuleStore] から前回のルールを復元して [controller] を作り、以降の
/// 変更を [saveCurrentRule] で保存する。復元失敗時は空ルールで開始する
/// ([loadLastRule] のフォールバック)。保存は best-effort（変更のたび fire-and-forget）。
class PersistentRuleController {
  PersistentRuleController._(this.controller, this._store) {
    controller.addListener(_save);
  }

  /// 復元済みの編集用コントローラ。
  final RuleController controller;
  final RuleStore _store;

  /// [store] から前回ルールを復元し、変更保存を配線したセッションを返す。
  static Future<PersistentRuleController> restore(RuleStore store) async {
    final rule = await loadLastRule(store);
    return PersistentRuleController._(
      RuleController(tokens: rule.tokens),
      store,
    );
  }

  void _save() {
    // 変更のたび現在のルールを保存(REQ-007。best-effort・非同期)。
    saveCurrentRule(_store, controller.rule);
  }

  /// リスナー解除とコントローラ破棄。
  void dispose() {
    controller.removeListener(_save);
    controller.dispose();
  }
}
