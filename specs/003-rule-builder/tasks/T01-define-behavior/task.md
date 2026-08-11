# T01 振る舞い仕様の作成(Light)

## 目的

- 振る舞い仕様の作成(Light)

## 入力と依存

- 依存: なし
- 同じworkspaceの`spec.md`、contract、decisions、仕様由来テスト。

## 変更範囲

- 旧planで定めた成果範囲。詳細は凍結履歴を参照する。

## 受け入れ証拠

- トークンの追加(5種)・削除・並び替え(D&D)・詳細差し替え、`RenameRule` の組み上げと変更通知の REQ と検証観点(VER)が定義されている。
  - open_questions に「詳細エディタの入力範囲・既定値(連番 start/digits/increment、日時 source/format プリセット、自由テキスト空許容)」「区切りプリセットの集合」「レスポンシブのブレークポイント(モバイル/デスクトップ境界)」「空ルール・全削除時の扱い」を挙げる。
  - 反証ログに反証観点と検出・対処が記録されている(0件ならその旨)。
  - 仕様が draft でインデックス登録され、完了報告にレビュー依頼が含まれる(approved 化は人間。**後続タスクは仕様が approved まで実行不可**)。
- 参考: create-verifiable-spec skill、PRD §3.2、discovery.md(003)、001 の `token.dart`/`rename_rule.dart`、002 の spec.md(状態層の書き方)

## 作業記録

旧ASDD 0.xから、実際に記録されていたcheckpointだけを移行した。将来予定やlive状態には使わない。

- 2026-08-02 / 着手 / 担当: shimmen3141(Issue #26 を assign)。ブランチ asdd/003-rule-builder/T1。
  - 2026-08-02 / done / verifier PASS(試行1)。Light 仕様 spec.md 作成(RuleController の状態・操作 REQ-001〜007/VER-001〜002、反証ログ5観点、open_questions 5件に推奨デフォルト併記)。reorder は 002 と同じ onReorderItem 規約。**spec.md の approved(人間)待ち。後続 T2 は仕様承認まで実行不可**。
  - 2026-08-02 / PR #31 作成(asdd/003-rule-builder/T1 → dev, Closes #26)。spec.md レビュー・承認待ちで停止。
  - 2026-08-02 / spec.md approved / 開発者承認(「承認します」)。レビューでの指示・回答を open_questions に反映して確定: 連番 digits=2、区切りプリセットに全角スペース追加、自由テキストは空不可(エディタで未入力時は確定無効・T4/VER-002)、連番は正のみ(start≥0・digits≥1・increment≥1、負・降順は除外)、日時はプリセット+自由入力(自由入力欄のUIはT4で検討)、レスポンシブ境界840dp、空ルール許容。spec.md Status draft→approved。**後続 T2 は PR #31 の dev マージ後に /run-plan で実行可**。
  - 2026-08-02 / PR #31 マージ済み(dev)。#26 close。マージ済みローカルブランチを整理。
  - 2026-08-02 / 計画承認 / 開発者承認(「承認します」)。状態 draft → approved。除外2件(プリセット保存=別機能 / 元名大小変換=001未対応で除外)を開発者確定。新要求「前回ルールの復元」は**別機能として計画**(開発者選択)。将来機能2件(前回ルール復元・プリセット保存)を discovery.md に記録。T1 実行は 003 plan.md の dev 到達(#25 マージ後にコミット→投影)を待つ。
  - 2026-08-02 / 計画投影 / PR #25 マージで 003 の Issue projection(T1→#26 … T5→#30)。状態 → in_progress。
