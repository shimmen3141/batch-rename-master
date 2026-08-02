/// 「現在のルール」1件を保存/読み出すストレージの抽象ポート(FEAT-007)。
///
/// 実装は差し替え可能（in-memory fake / `shared_preferences` 等）。永続化の中身は
/// 文字列（[serializeRule] の JSON）で、シリアライズの詳細はポートの関知外。
abstract interface class RuleStore {
  /// 保存済み文字列を返す（未保存なら `null`。REQ-005）。
  Future<String?> read();

  /// [data] を「現在のルール」として保存する（以後の [read] は最後に書いた値。REQ-005）。
  Future<void> write(String data);
}

/// メモリ上に保持する [RuleStore] 実装（サンドボックス検証用の fake、兼 既定実装）。
///
/// [seed] を与えると初期の保存値になる（壊れたデータでの復元フォールバック検証等に使う）。
class InMemoryRuleStore implements RuleStore {
  InMemoryRuleStore([this._data]);

  String? _data;

  @override
  Future<String?> read() async => _data;

  @override
  Future<void> write(String data) async => _data = data;
}
