# T05 レスポンシブ外殻(モバイル=ボトムシート/デスクトップ=2ペイン)+ 002 setRule 連携

## 目的

- レスポンシブ外殻(モバイル=ボトムシート/デスクトップ=2ペイン)+ 002 setRule 連携

## 入力と依存

- 依存: T03, T04, 002:T03
- 同じworkspaceの`spec.md`、contract、decisions、仕様由来テスト。

## 変更範囲

- 旧planで定めた成果範囲。詳細は凍結履歴を参照する。

## 受け入れ証拠

- 画面幅に応じてモバイル=ModalBottomSheet / デスクトップ=2ペインで T3/T4 を提示する(PRD §3.2)。境界は T1 で確定した値。
  - `RuleController` の変更が 002 の `FileListController.setRule` に渡り、プレビュー(変更後名)へ反映されることを widget test で確認する。
  - `flutter analyze`/`dart format` PASS。
- 参考: T1、002 の `FileListController.setRule`/`FileListView`、PRD §3.2

## 作業記録

旧ASDD 0.xから、実際に記録されていたcheckpointだけを移行した。将来予定やlive状態には使わない。

- 2026-08-02 / 着手 / 担当: shimmen3141(Issue #30 を assign)。ブランチ asdd/003-rule-builder/T5。
  - 2026-08-02 / done / verifier PASS(試行1)+レビューパス(初期同期テストを非空ルールで強化)。`RuleBuilderWorkspace`(StatefulWidget)を追加: `RuleController` の変更を listener で `FileListController.setRule` へ同期(初期同期 + 変更同期、dispose/didUpdateWidget で解除)、幅 840dp を境にモバイル(リスト全面+ボトムシートでルール編集)/デスクトップ(左リスト+右ルールの2ペイン)を切替。rule_builder_workspace_test.dart 3件(spec_003 計26件)、`flutter analyze` 0 issue、`dart format` PASS。
  - 2026-08-02 / 全体の受け入れ条件を最終検証: spec approved(Light)/ `test/spec_003_rule_builder/` 26件 PASS(全体121)/ analyze 0 / format PASS / RuleController は Widget 非依存 / 002 setRule 連携を widget test で確認。全条件クリア。全タスク done。計画状態 approved→done(PR #35 の dev マージで確定)。
  - 2026-08-02 / PR #35 作成(asdd/003-rule-builder/T5 → dev, Closes #30)。マージ待ちで停止。マージで 003 完了(5/5)。
