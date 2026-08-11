# T05 ウィジェット: ドラッグ並び替え + カスタム順への自動切替

## 目的

- ウィジェット: ドラッグ並び替え + カスタム順への自動切替

## 入力と依存

- 依存: T04
- 同じworkspaceの`spec.md`、contract、decisions、仕様由来テスト。

## 変更範囲

- 旧planで定めた成果範囲。詳細は凍結履歴を参照する。

## 受け入れ証拠

- 行のドラッグ&ドロップで並び替えでき、並び替えが起きた瞬間にソート種別が「カスタム」へ切り替わる(PRD §3.1)。並び順の変更が連番・プレビューに反映される。
  - 該当 REQ/VER を覆う widget test が通り、`flutter analyze`/`dart format` PASS。
- 参考: T1、PRD §3.1

## 作業記録

旧ASDD 0.xから、実際に記録されていたcheckpointだけを移行した。将来予定やlive状態には使わない。

- 2026-08-02 / 着手 / 担当: shimmen3141(Issue #19 を assign)。ブランチ asdd/002-file-list/T5。
  - 2026-08-02 / done / verifier PASS(試行1)+レビューパス(P0/P1 なし)。`FileListView` を `ReorderableListView.builder` 化し、行末尾に `ReorderableDragStartListener` のドラッグハンドルを追加。並び替えで `sortMode` が custom へ自動切替し連番・プレビューへ反映(REQ-003)。Flutter 3.44 で `onReorder` が非推奨のため `onReorderItem`(newIndex=削除後の挿入先)を採用し、`controller.reorder` を同規約(removeAt→insert)へ整理。既存 T2 の reorder テスト3件を新規約に追随(結果の並びは不変、index 引数のみ調整)。reorder_view_test.dart 新規3件(直接コールバック駆動 + 実ジェスチャドラッグ + ハンドル表示)。spec_002 計35件通過、`flutter analyze` 0 issue、`dart format` PASS。
  - 2026-08-02 / 全体の受け入れ条件を最終検証: spec.md approved(Light)/ `test/spec_002_file_list/` 35件 PASS / `flutter analyze` 0 issue / `dart format --set-exit-if-changed .` PASS / コントローラ層は Widget 構築に非依存(`foundation.dart` のみ)。全条件クリア。計画は PR #24 の dev マージで done(5/5)。
  - 2026-08-02 / PR #24 作成(asdd/002-file-list/T5 → dev, Closes #19)。マージ待ちで停止。マージで 002 全タスク完了(5/5)→ 計画 done へ。
  - 2026-08-02 / PR #24 マージ済み(dev)。#19 close。全タスク done かつ全 PR マージ済み。
