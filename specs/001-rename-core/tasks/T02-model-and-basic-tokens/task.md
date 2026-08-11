# T02 ドメインモデル + 単純トークン評価(元名・自由テキスト)

## 目的

- ドメインモデル + 単純トークン評価(元名・自由テキスト)

## 入力と依存

- 依存: T01
- 同じworkspaceの`spec.md`、contract、decisions、仕様由来テスト。

## 変更範囲

- 旧planで定めた成果範囲。詳細は凍結履歴を参照する。

## 受け入れ証拠

- FileEntry(名前・ベース名・拡張子・作成/更新日時・サイズ)、Token 階層、RenameRule を定義。
  - 「元ファイル名」「自由テキスト」トークンの評価に対応する REQ を覆う `test/spec_001_rename_core/` が `flutter test` で通る。
  - `flutter analyze` 0 issue、`dart format` PASS、エンジンは Flutter に非依存。
- 参考: T1 の spec.md / behavior-contract.json

## 作業記録

旧ASDD 0.xから、実際に記録されていたcheckpointだけを移行した。将来予定やlive状態には使わない。

- 2026-07-26 / done / verifier PASS(試行1) / lib/core に FileEntry・Token(sealed: 元名/リテラル)・RenameContext・RenameRule・buildName を実装(REQ-001/002/005・INV-001/002・OP-001)。flutter test 15/15、flutter analyze 0 issue、dart format PASS、lib/core は Flutter/dart:io 非依存(CON-001)。claim=Issue #3 assign。
  - 2026-07-26 / PR #8 作成(asdd/001-rename-core/T2 → dev, Closes #3)。マージ待ちで停止。T3 は T2 の PR マージ後に着手可。
  - 2026-07-26 / PR #8 マージ(dev)。CI(pull_request トリガ)success を確認。
  - 2026-07-26 / 仕様承認 / 開発者承認(「behavior-contract.json は承認します」「接尾辞書式はあなたの提案で確定」)。contract status draft → approved、open_questions 解消(空)、spec.md Status approved。lint --strict PASS 継続。**T2 が実行可能に**。
