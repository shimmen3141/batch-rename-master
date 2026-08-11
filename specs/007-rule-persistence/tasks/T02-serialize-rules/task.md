# T02 シリアライズ: RenameRule/Token ⇔ JSON(純粋 Dart)

## 目的

- シリアライズ: RenameRule/Token ⇔ JSON(純粋 Dart)

## 入力と依存

- 依存: T01
- 同じworkspaceの`spec.md`、contract、decisions、仕様由来テスト。

## 変更範囲

- 旧planで定めた成果範囲。詳細は凍結履歴を参照する。

## 受け入れ証拠

- 全 Token 種別(元名/リテラル/連番/日時)と `RenameRule` の JSON 往復が可逆(round-trip)で、未知 type・壊れた JSON は `null` を返す(T1 の REQ どおり)。純粋 Dart(`package:flutter`/`dart:io` 非依存)。
  - 該当 REQ/VER を覆う unit test(各種別の例 + round-trip + 異常入力)が通る。`flutter analyze` 0 issue、`dart format` PASS。
- 参考: T1、001 の各 `Token` の引数・sealed 構造

## 作業記録

旧ASDD 0.xから、実際に記録されていたcheckpointだけを移行した。将来予定やlive状態には使わない。

- 2026-08-02 / 着手 / 担当: shimmen3141(Issue #39 を assign)。ブランチ asdd/007-rule-persistence/T2。
  - 2026-08-02 / done / verifier PASS(試行1・独自プローブ含む)+レビューパス(P0/P1 なし)。`lib/core/rule_serialization.dart`(純粋 Dart, `dart:convert` のみ)を追加: 確定スキーマ(`{"version":1,"tokens":[...]}`、type=original_name/text/sequence_number/datetime)で serializeRule/deserializeRule。異常系(不正JSON/未知type/欠損/型不一致/非対応バージョン)は例外を投げず null。REQ-001〜004 を覆う serialization_test.dart 12件通過(全体133)、`flutter analyze` 0 issue、`dart format` PASS。
  - 2026-08-02 / PR #46 作成(asdd/007-rule-persistence/T2 → dev, Closes #39)。マージ待ちで停止。次は T3(ストレージポート + fake + オーケストレーション。依存 T2。サンドボックス完結)。
  - 2026-08-02 / PR #46 マージ済み(dev)。#39 close。docs 統合の再着地 PR #45 もマージ済み(dev の develpoment→development)。
