# T03 連番・日時トークンの評価

## 目的

- 連番・日時トークンの評価

## 入力と依存

- 依存: T02
- 同じworkspaceの`spec.md`、contract、decisions、仕様由来テスト。

## 変更範囲

- 旧planで定めた成果範囲。詳細は凍結履歴を参照する。

## 受け入れ証拠

- 連番トークン(開始番号・桁数ゼロ埋め・増分)と日時トークン(基準・フォーマット)の評価が、T1 で確定した REQ どおりに動く。
  - 該当 REQ/VER を覆う `test/spec_001_rename_core/` が通り、`flutter analyze`/`dart format` が PASS。
- 参考: T1、PRD §3.2

## 作業記録

旧ASDD 0.xから、実際に記録されていたcheckpointだけを移行した。将来予定やlive状態には使わない。

- 2026-07-26 / done / verifier PASS(試行1) / token.dart に SequenceToken(REQ-003)・DateTimeToken/DateTimeSource・日時整形(REQ-004: 最長一致・大小区別・基準切替・非該当リテラル・INV-004 時計非参照)を追加。flutter test 28/28、analyze 0 issue、format PASS。claim=Issue #4 assign。
  - 2026-07-26 / PR #9 作成(asdd/001-rename-core/T3 → dev, Closes #4)。マージ待ちで停止。T4 は T3 の PR マージ後に着手可。
  - 2026-07-26 / PR #9 マージ(dev)。開発者が sync ワークフローに dev トリガを追加、dev push で投影が走り #3/#4 クローズを確認。
