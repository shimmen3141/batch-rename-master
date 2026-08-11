# T04 RuleController への配線(初期復元 + 変更保存)

## 目的

- RuleController への配線(初期復元 + 変更保存)

## 入力と依存

- 依存: T03, 003:T02
- 同じworkspaceの`spec.md`、contract、decisions、仕様由来テスト。

## 変更範囲

- 旧planで定めた成果範囲。詳細は凍結履歴を参照する。

## 受け入れ証拠

- 起動時に `load()` の結果で `RuleController` を初期化し、`RuleController` の変更で `save()` される(fake ストアで検証)。復元失敗時は空ルールで開始。
  - 該当 REQ/VER を覆う unit/widget test が通り、`flutter analyze`/`dart format` PASS。
- 参考: T1、T3、003 の `RuleController`

## 作業記録

旧ASDD 0.xから、実際に記録されていたcheckpointだけを移行した。将来予定やlive状態には使わない。

- 2026-08-03 / 着手 / 担当: shimmen3141(Issue #41 を assign)。ブランチ asdd/007-rule-persistence/T4。
  - 2026-08-03 / done / verifier PASS(試行1・dispose 追試含む)。`lib/ui/rule_builder/persistent_rule_controller.dart`(`PersistentRuleController.restore` = 前回ルール復元で RuleController 初期化 + 変更購読で saveCurrentRule、dispose でリスナー解除+破棄)を追加。空ストア/壊れデータは空ルールで開始。REQ-008 を覆う wiring_test.dart 6件通過(spec_007 計28件、全体149)、`flutter analyze` 0 issue、`dart format` PASS。fake ストアで完結(実ストア不要)。
  - 2026-08-03 / PR #48 作成(asdd/007-rule-persistence/T4 → dev, Closes #41)。マージ待ちで停止。最後の T5(実 shared_preferences + 入口配線)は T4 マージ後。ここで初めて実デバイス確認(変更→再起動→復元)。
  - 2026-08-03 / PR #48 マージ済み(dev)。#41 close。
