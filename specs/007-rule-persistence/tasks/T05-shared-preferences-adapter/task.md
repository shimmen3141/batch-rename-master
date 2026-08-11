# T05 実ストア(shared_preferences アダプタ)+ アプリ入口配線(ホスト検証)

## 目的

- 実ストア(shared_preferences アダプタ)+ アプリ入口配線(ホスト検証)

## 入力と依存

- 依存: T04
- 同じworkspaceの`spec.md`、contract、decisions、仕様由来テスト。

## 変更範囲

- 旧planで定めた成果範囲。詳細は凍結履歴を参照する。

## 受け入れ証拠

- `RuleStore` の実装として `shared_preferences` アダプタを追加(依存追加)。`SharedPreferences.setMockInitialValues` を使ったモックテストで save/load が通る。
  - アプリ入口で実ストアを注入して復元/保存が働くよう配線する。
  - `flutter analyze`/`dart format`/`flutter test`(モック)PASS。**実機/エミュレータでの永続化(再起動で復元)確認はホスト側**(手順は emulator-verification.md)。
- 参考: T1、T4、`shared_preferences` パッケージ、`docs/development/emulator-verification.md`

## 作業記録

旧ASDD 0.xから、実際に記録されていたcheckpointだけを移行した。将来予定やlive状態には使わない。

- 2026-08-03 / 着手 / 担当: shimmen3141(Issue #42 を assign)。ブランチ asdd/007-rule-persistence/T5。
  - 2026-08-03 / done / verifier PASS(試行1)。`shared_preferences` を pubspec に追加(pub get 成功)。`lib/data/rule_store/shared_preferences_rule_store.dart`(実 `RuleStore` アダプタ)を追加、`lib/main.dart` を `SharedPreferences.getInstance → 実ストア → PersistentRuleController.restore → DemoApp` に配線(前回ルール復元 + 変更自動保存)。widget_test は RuleController 注入に追随。モックテスト shared_preferences_rule_store_test.dart 5件(公式 setMockInitialValues)通過。spec_007 計33件・全体154件通過、`flutter analyze` 0 issue、`dart format` PASS。**実永続化(再起動で復元)の実機/エミュレータ確認はホスト側の残作業**(emulator-verification.md)。
  - 2026-08-03 / 全体の受け入れ条件を最終検証: spec approved / `test/spec_007_rule_persistence/` 33件 PASS / analyze 0 / format PASS / 純粋層は fake で sandbox 検証 / 実ストア・配線は analyze/test(モック)まで。サンドボックスで検証可能な範囲は全てクリア。全タスク done。計画状態 approved→done(PR #49 の dev マージで確定)。ホストでの実永続化目視のみ残。
  - 2026-08-03 / PR #49 作成(asdd/007-rule-persistence/T5 → dev, Closes #42)。マージ待ちで停止。マージで 007 完了(5/5)。
