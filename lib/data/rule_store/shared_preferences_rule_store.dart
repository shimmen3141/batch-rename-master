import 'package:shared_preferences/shared_preferences.dart';

import 'rule_store.dart';

/// `shared_preferences` を用いた [RuleStore] の実装(FEAT-007 T5)。
///
/// 「現在のルール」1件を [key] の文字列として端末に永続化する。Android / Windows
/// など各プラットフォームで動作する。テストは `SharedPreferences.setMockInitialValues`
/// で検証でき、実永続化(再起動での復元)はホスト/実機で確認する。
class SharedPreferencesRuleStore implements RuleStore {
  SharedPreferencesRuleStore(this._prefs, {this.key = 'current_rule'});

  final SharedPreferences _prefs;

  /// 保存キー。既定は `current_rule`。
  final String key;

  @override
  Future<String?> read() async => _prefs.getString(key);

  @override
  Future<void> write(String data) async {
    await _prefs.setString(key, data);
  }
}
