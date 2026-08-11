# T02 状態層 RuleController(追加・削除・並び替え・差し替え・RenameRule 公開)

## 目的

- 状態層 RuleController(追加・削除・並び替え・差し替え・RenameRule 公開)

## 入力と依存

- 依存: T01
- 同じworkspaceの`spec.md`、contract、decisions、仕様由来テスト。

## 変更範囲

- 旧planで定めた成果範囲。詳細は凍結履歴を参照する。

## 受け入れ証拠

- `RuleController`(ChangeNotifier 等)が、編集中トークン列の保持・追加・削除・並び替え(onReorderItem 規約)・指定位置のトークン差し替えを T1 の REQ どおり提供し、`RenameRule get rule` を公開する。
  - 該当 REQ/VER を覆う `test/spec_003_rule_builder/` の unit test が通る。`flutter analyze` 0 issue、`dart format` PASS。`Widget` 構築に非依存。
- 参考: T1 の spec.md、001 の `Token`/`RenameRule`、002 の `FileListController`(reorder 規約・identity 追従の実装)

## 作業記録

旧ASDD 0.xから、実際に記録されていたcheckpointだけを移行した。将来予定やlive状態には使わない。

- 2026-08-02 / 着手 / 担当: shimmen3141(Issue #27 を assign)。ブランチ asdd/003-rule-builder/T2。
  - 2026-08-02 / done / verifier PASS(試行1)+レビューパス(P0/P1 なし)。`RuleController`(ChangeNotifier)を実装: addToken/removeAt/reorder(onReorderItem 規約・002 と一致)/replaceAt、`rule` はスナップショット公開。REQ-001〜007 を覆う rule_controller_test.dart 12件通過(全体107)、`flutter analyze` 0 issue、`dart format` PASS。Widget 非依存(foundation のみ)。
  - 2026-08-02 / PR #32 作成(asdd/003-rule-builder/T2 → dev, Closes #27)。マージ待ちで停止。次は T3/T4(依存 T2。互いに独立=並列可)。
  - 2026-08-02 / PR #32 マージ済み(dev)。#27 close。
