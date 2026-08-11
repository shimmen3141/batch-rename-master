# T01 振る舞い仕様の作成(Light)

## 目的

- 振る舞い仕様の作成(Light)

## 入力と依存

- 依存: なし
- 同じworkspaceの`spec.md`、contract、decisions、仕様由来テスト。

## 変更範囲

- 旧planで定めた成果範囲。詳細は凍結履歴を参照する。

## 受け入れ証拠

- 選択(既定状態・トグル・全選択/全解除)、ソート(名前/作成日時/サイズ/カスタム)、ドラッグでのカスタム順自動切替、プレビュー連携(選択・並び順・ルールから各行の現在名/変更後名を供給)の REQ と検証観点(VER)が定義されている。
  - open_questions に「既定の選択状態(全選択/全解除)」「名前ソートの順序(自然順/辞書順・大小・ロケール)」「ソート方向(昇順固定/昇降トグル)」「未チェック行の変更後名の表示」「同値時のソート安定性」を挙げる。
  - spec.md の「反証ログ」に反証観点と検出・対処が記録されている(0件ならその旨)。
  - 仕様が draft でインデックス登録され、完了報告にレビュー依頼が含まれる(approved 化は人間。**後続タスクは仕様が approved まで実行不可**)。
- 参考: create-verifiable-spec skill、`docs/proposals/001-PRD.md` §3.1/§4.1、discovery.md(002)

## 作業記録

旧ASDD 0.xから、実際に記録されていたcheckpointだけを移行した。将来予定やlive状態には使わない。

- 2026-07-27 / 着手 / 担当: shimmen3141(暫定 claim)。002 plan.md が dev/main 未到達で Issue 未投影のため claim を plan.md 側に置く(T1 PR の dev マージで projection が 002 Issue を作成)。状態 → in_progress。
  - 2026-07-27 / done / verifier PASS(試行1) / Light 仕様 spec.md 作成(選択・ソート4種・カスタム順自動切替・001 generatePreview 連携の REQ-001〜007/VER-001〜002、反証ログ、open_questions 6件に推奨デフォルト併記)。**spec.md の approved(人間)待ち。後続 T2 は仕様承認まで実行不可**。
  - 2026-07-27 / PR #14 作成(asdd/002-file-list/T1 → dev)。spec.md レビュー・承認待ちで停止。マージで 002 の Issue が projection される。
  - 2026-08-01 / spec.md approved / 開発者承認(未解決事項への個別回答: 初期ソートを「入力順(custom)のまま」で確定=現行 spec の ASSUMED と一致)。設計が既定選択・ソート4種・自動カスタム順・ライブプレビューを追認。spec.md の Status draft→approved、未解決事項6件を確定値へ。**後続 T2 は PR #14 の dev マージ(002 Issue projection)後に /run-plan で実行可**。
  - 2026-08-01 / PR #14 マージ済み(dev)。002 Issue が projection(T1→#15 … T5→#19)。
  - 2026-08-02 / 計画完了 / 002 全タスク(T1〜T5)done・全 PR マージ済み・全体の受け入れ条件クリア。計画状態 in_progress → done。
