# T06 自動解決(強制実行時の名前確定)

## 目的

- 自動解決(強制実行時の名前確定)

## 入力と依存

- 依存: T05
- 同じworkspaceの`spec.md`、contract、decisions、仕様由来テスト。

## 変更範囲

- 旧planで定めた成果範囲。詳細は凍結履歴を参照する。

## 受け入れ証拠

- 警告がある状態で強制実行相当を要求すると、重複には `(1)(2)…` を付与、桁不足は桁を自動拡張して、衝突のない最終名一覧を返す。
  - 該当 REQ/INV(自動解決後は重複ゼロ)を覆う `test/spec_001_rename_core/` が通り、`flutter analyze`/`dart format` が PASS。
- 参考: T1、PRD §4.2 選択肢B

## 作業記録

旧ASDD 0.xから、実際に記録されていたcheckpointだけを移行した。将来予定やlive状態には使わない。

- 2026-07-27 / done / verifier PASS(試行1) / rename_engine.dart に ResolvedEntry・autoResolve・_expandDigits・_withSuffix(OP-004/REQ-010〜012/INV-003: 重複 (n) 付与・連番桁自動拡張・結果は重複/桁不足なし)を追加。flutter test 54/54、analyze 0 issue、format PASS。claim=Issue #7 assign。
  - 2026-07-27 / PR #12 作成(asdd/001-rename-core/T6 → dev, Closes #7)。
  - 2026-07-27 / 計画完了 / 全6タスク done。計画 状態 → done。全体の受け入れ条件を最終検証(spec_lint --strict PASS / test/spec_001_rename_core が flutter test 60/60 PASS / analyze 0 / format PASS / lib/core は Flutter 非依存)。完了検証で VER-005 未作成を検出し determinism_test を補完(FINDINGS 記録)。PR #12(T6)は dev マージ待ち。
