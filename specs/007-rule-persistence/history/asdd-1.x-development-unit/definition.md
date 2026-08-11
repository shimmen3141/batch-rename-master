# 開発単位: 再起動をまたぐルール復元を受け入れ確認する

## 目的

既に実装された前回ルールの保存・復元が、Androidとdesktopの実ストアでprocess終了をまたいでも成立する証拠を得る。

## 根拠

- 仕様正本: `specs/007-rule-persistence/spec.md`
- 仕様由来test: `test/spec_007_rule_persistence/`
- 旧受け入れ条件: `specs/007-rule-persistence/plan.md`（cutoff前の履歴。statusには使わない）
- unit固有手順: `manual-verification.md`
- 共通host手順: `docs/development/emulator-verification.md`

## 境界

### 対象

- token種別・順序・設定値の自動保存。
- hot restartでの読み込み経路確認。
- processを完全終了したcold start後の復元。
- Androidとdesktopの実`shared_preferences` adapter。

### 対象外

- 名前付きpreset、複数rule、同期。
- 古いschemaからのmigration。
- 保存UIのvisual polish。

## 重要な決定

| 日付 | 決定 | 理由 |
|---|---|---|
| 2026-08-09 | 旧007を再実装せず、未取得だった実ストア・cold start証拠だけをunitにする | 自動testと配線は存在するが、旧planにhost側残作業が明記されていたため |

## 受け入れ証拠

| 観測する成果 | 証拠 |
|---|---|
| serialization・保存・配線testが通る | `flutter test test/spec_007_rule_persistence/` |
| 回帰・静的検査に不適合がない | `dart format --output=none --set-exit-if-changed .`、`flutter analyze`、`flutter test` |
| Androidでprocess終了後に同じruleが復元される | `manual-verification.md#android`の同一commit/build記録 |
| desktopでprocess終了後に同じruleが復元される | `manual-verification.md#desktop`の同一commit/build記録 |
| 仕様、実装、手動観測が一致する | exact commitと証拠に対する独立reviewのPASS |

## リスクと進め方

- 保存先を直接編集せず、利用者操作とprocess再起動で観測する。
- 製品不具合が出た場合はこのunitの実装checkpointとして扱う。schemaの意味変更が必要なら人間判断を求める。

## 未決定事項

- なし。
