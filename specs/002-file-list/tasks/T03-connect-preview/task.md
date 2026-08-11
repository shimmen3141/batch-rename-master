# T03 プレビュー連携(001 の generatePreview で行データ供給)

## 目的

- プレビュー連携(001 の generatePreview で行データ供給)

## 入力と依存

- 依存: T02, 001:T04
- 同じworkspaceの`spec.md`、contract、decisions、仕様由来テスト。

## 変更範囲

- 旧planで定めた成果範囲。詳細は凍結履歴を参照する。

## 受け入れ証拠

- コントローラが、現在の並び順・選択・注入された `RenameRule` から 001 の `generatePreview` を呼び、各行の (現在名, 変更後名 or 未選択時の表示) を供給する。選択・並び順・ルールの変更が行データに反映される。
  - 該当 REQ/VER を覆う unit test が通り、`flutter analyze`/`dart format` PASS。
- 参考: T1、001-rename-core.T4(`generatePreview`)、PRD §4.1

## 作業記録

旧ASDD 0.xから、実際に記録されていたcheckpointだけを移行した。将来予定やlive状態には使わない。

- 2026-08-01 / 着手 / 担当: shimmen3141(Issue #17 を assign)。ブランチ asdd/002-file-list/T3。
  - 2026-08-01 / done / verifier PASS(試行1)。`RowView`(row_view.dart)と `FileListController.rows` ゲッターを追加。001 の `generatePreview` に委譲(連番は再実装せず)し、選択状態を FileEntry.selected へ写した複製を表示順で渡す。未選択行は newName=null(REQ-007)。日時「現在」用に clock 注入で決定性確保。REQ-005/006/007 を覆う preview_rows_test.dart 10件通過(spec_002 計27件)、`flutter analyze` 0 issue、`dart format` PASS。verifier 指摘の doc コメント重複を整理。
  - 2026-08-01 / PR #22 作成(asdd/002-file-list/T3 → dev, Closes #17)。マージ待ちで停止。次の T4(ウィジェット層)は T3 のマージ後に実行可。
  - 2026-08-02 / PR #22 マージ済み(dev)。#17 close。
