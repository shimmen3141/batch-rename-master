# T03 ストレージポート + in-memory fake + 復元/保存オーケストレーション

## 目的

- ストレージポート + in-memory fake + 復元/保存オーケストレーション

## 入力と依存

- 依存: T02
- 同じworkspaceの`spec.md`、contract、decisions、仕様由来テスト。

## 変更範囲

- 旧planで定めた成果範囲。詳細は凍結履歴を参照する。

## 受け入れ証拠

- `RuleStore` ポートと in-memory fake を定義し、`save(rule)`→`load()` が現在ルールを往復する。空ストア/壊れたデータ時は空ルールを返す(T1 の REQ どおり)。
  - 該当 REQ/VER を覆う unit test が fake ストアで通り、`flutter analyze`/`dart format` PASS。実ストア不要で検証できる。
- 参考: T1、T2 のシリアライズ

## 作業記録

旧ASDD 0.xから、実際に記録されていたcheckpointだけを移行した。将来予定やlive状態には使わない。

- 2026-08-02 / 着手 / 担当: shimmen3141(Issue #40 を assign)。ブランチ asdd/007-rule-persistence/T3。
  - 2026-08-02 / done / verifier PASS(試行1)+レビューパス(P0/P1 なし)。`lib/data/rule_store/rule_store.dart`(抽象 `RuleStore` + `InMemoryRuleStore` fake)と `rule_persistence.dart`(`loadLastRule`/`saveCurrentRule`)を追加。両フォールバック経路(read null / deserialize null)で空ルール、store 経由 round-trip、fake のみで完結(実ストア不要)。flutter/dart:io 非依存。REQ-005〜007 を覆う persistence_test.dart 10件通過(spec_007 計22件、全体143)、`flutter analyze` 0 issue、`dart format` PASS。
  - 2026-08-02 / PR #47 作成(asdd/007-rule-persistence/T3 → dev, Closes #40)。マージ待ちで停止。次は T4(RuleController 配線。依存 T3 + 003-rule-builder.T2。fake で sandbox 検証)。
  - 2026-08-02 / PR #47 マージ済み(dev)。#40 close。
