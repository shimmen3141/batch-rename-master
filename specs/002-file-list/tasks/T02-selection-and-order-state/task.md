# T02 状態コントローラ(選択・ソート・カスタム順)

## 目的

- 状態コントローラ(選択・ソート・カスタム順)

## 入力と依存

- 依存: T01
- 同じworkspaceの`spec.md`、contract、decisions、仕様由来テスト。

## 変更範囲

- 旧planで定めた成果範囲。詳細は凍結履歴を参照する。

## 受け入れ証拠

- `FileListController` が、`List<FileEntry>` の保持・選択トグル・全選択/全解除・ソート種別切替(名前/作成日時/サイズ)・カスタム順(reorder)を、T1 の REQ どおりに提供する。ソートは安定。
  - 該当 REQ/VER を覆う `test/spec_002_file_list/` の unit test が `flutter test` で通る。
  - `flutter analyze` 0 issue、`dart format` PASS。コントローラは `Widget` 構築に依存しない。
- 参考: T1 の spec.md、001-rename-core の `FileEntry`

## 作業記録

旧ASDD 0.xから、実際に記録されていたcheckpointだけを移行した。将来予定やlive状態には使わない。

- 2026-08-01 / 着手 / 担当: shimmen3141(Issue #16 を assign)。ブランチ asdd/002-file-list/T2。
  - 2026-08-01 / done / verifier PASS(試行1)+レビューパス(P0/P1 なし)。`FileListController`(選択 identity Set・ソート4種・reorder→custom 自動切替・setRule)と `file_sort.dart`(自然順・大小無視・安定ソート)を実装。REQ-001〜005 を覆う controller_test.dart 17件通過、`flutter analyze` 0 issue、`dart format` PASS。プレビュー行データ(REQ-006/007)は T3。
  - 2026-08-01 / PR #21 作成(asdd/002-file-list/T2 → dev, Closes #16)。マージ待ちで停止。次の T3 は T2 のマージ後に実行可(依存 = done ∧ PR マージ済み)。
  - 2026-08-01 / PR #21 マージ済み(dev)。#16 close。参考デザイン PR #20 もマージ済み。
