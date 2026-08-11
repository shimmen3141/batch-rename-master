# T05 ドライラン検証(重複・桁不足の警告生成)

## 目的

- ドライラン検証(重複・桁不足の警告生成)

## 入力と依存

- 依存: T04
- 同じworkspaceの`spec.md`、contract、decisions、仕様由来テスト。

## 変更範囲

- 旧planで定めた成果範囲。詳細は凍結履歴を参照する。

## 受け入れ証拠

- プレビュー結果に対し、重複する新名・連番桁不足の箇所を警告として列挙する(実行はしない)。
  - 該当 REQ/VER(異常系含む)を覆う `test/spec_001_rename_core/` が通り、`flutter analyze`/`dart format` が PASS。
- 参考: T1、PRD §4.2

## 作業記録

旧ASDD 0.xから、実際に記録されていたcheckpointだけを移行した。将来予定やlive状態には使わない。

- 2026-07-27 / done / verifier PASS(試行1) / rename_engine.dart に Warning 階層(Duplicate/DigitShortage/EmptyName)と validate(OP-003/REQ-007〜009: 最終名集合ベースの重複、連番桁不足、空名)を追加。flutter test 46/46、analyze 0 issue、format PASS。claim=Issue #6 assign。
  - 2026-07-27 / PR #11 作成(asdd/001-rename-core/T5 → dev, Closes #6)。マージ待ちで停止。T6 は T5 の PR マージ後に着手可(最後のタスク)。
  - 2026-07-27 / PR #11 マージ(dev)。
