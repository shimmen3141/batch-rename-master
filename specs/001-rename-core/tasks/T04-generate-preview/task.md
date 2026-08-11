# T04 プレビュー生成(選択・並び順反映、連番の割り当て)

## 目的

- プレビュー生成(選択・並び順反映、連番の割り当て)

## 入力と依存

- 依存: T03
- 同じworkspaceの`spec.md`、contract、decisions、仕様由来テスト。

## 変更範囲

- 旧planで定めた成果範囲。詳細は凍結履歴を参照する。

## 受け入れ証拠

- 順序付き+選択状態のファイル一覧にルールを適用し、各ファイルの新名(プレビュー)を返す。連番は T1 で確定した単位(選択順/表示順)で割り当てる。
  - 該当 REQ/INV を覆う `test/spec_001_rename_core/` が通り、`flutter analyze`/`dart format` が PASS。
- 参考: T1、PRD §4.1

## 作業記録

旧ASDD 0.xから、実際に記録されていたcheckpointだけを移行した。将来予定やlive状態には使わない。

- 2026-07-26 / done / verifier PASS(試行1) / rename_engine.dart に PreviewEntry・generatePreview(REQ-006/OP-002: 選択のみ・表示順保持・上から連番、i番目=buildName(...,i,...))を追加。flutter test 34/34、analyze 0 issue、format PASS。claim=Issue #5 assign。
  - 2026-07-26 / PR #10 作成(asdd/001-rename-core/T4 → dev, Closes #5)。マージ待ちで停止。T5 は T4 の PR マージ後に着手可。
  - 2026-07-27 / PR #10 マージ(dev)。
