# T01 振る舞い仕様の作成(Light)

## 目的

- 振る舞い仕様の作成(Light)

## 入力と依存

- 依存: なし
- 同じworkspaceの`spec.md`、contract、decisions、仕様由来テスト。

## 変更範囲

- 旧planで定めた成果範囲。詳細は凍結履歴を参照する。

## 受け入れ証拠

- シリアライズの往復(全 Token 種別 + RenameRule)、未知 type・壊れた入力の扱い(null/空フォールバック)、ストレージポートの契約、復元(起動時)/保存(変更時)の振る舞いの REQ と VER が定義されている。
  - open_questions に「JSON スキーマ(type タグ名・バージョン欄)」「保存の粒度(変更のたび/デバウンス)」「読み込み失敗時の扱い(空ルール確定)」「空ルールを保存するか」を挙げる。
  - 反証ログに反証観点と検出・対処が記録されている(0件ならその旨)。
  - 仕様が draft でインデックス登録され、完了報告にレビュー依頼が含まれる(approved 化は人間。**後続タスクは仕様が approved まで実行不可**)。
- 参考: create-verifiable-spec skill、001 の `token.dart`/`rename_rule.dart`、003 の `rule_controller.dart`、002 の spec.md(書き方)

## 作業記録

旧ASDD 0.xから、実際に記録されていたcheckpointだけを移行した。将来予定やlive状態には使わない。

- 2026-08-02 / 着手 / 担当: shimmen3141(Issue #38 を assign)。ブランチ asdd/007-rule-persistence/T1。
  - 2026-08-02 / done / verifier PASS(試行1)。Light 仕様 spec.md 作成(シリアライズ round-trip/異常系 REQ-001〜004、RuleStore 契約と復元/保存 REQ-005〜007、配線 REQ-008、VER-001〜003、反証ログ5観点、open_questions 5件に推奨デフォルト併記)。**spec.md の approved(人間)待ち。後続 T2 は仕様承認まで実行不可**。
  - 2026-08-02 / PR #43 作成(asdd/007-rule-persistence/T1 → dev, Closes #38)。spec.md レビュー・承認待ちで停止。
  - 2026-08-02 / 補足 / PR #43 は spec が draft のまま dev マージされた(承認前)。開発者承認を受けて別 PR で spec.md を approved 化する(下記)。
  - 2026-08-02 / spec.md approved / 開発者承認(JSON type タグ名を確定: original_name / text / sequence_number / datetime。他 open_questions は推奨どおり)。LiteralToken は自由テキスト・区切り兼用のため type は単一(`text`)。dev の spec は draft でマージ済みだったため、別 PR で Status draft→approved と type タグ名確定を反映。**後続 T2 はこの承認 PR の dev マージ後に /run-plan で実行可**。
  - 2026-08-02 / spec 承認 PR #44 マージ済み(dev)。spec.md approved 確定。
  - 2026-08-02 / 計画承認 / 開発者承認(「承認します」)。状態 draft → approved。番号 007(004〜006 の予約保持)・仕様 Light・プリセット保存は別機能、で確定。T1 実行は 007 plan.md の dev 到達(コミット→投影)後。
  - 2026-08-02 / 計画投影 / PR #37 マージで 007 の Issue projection(T1→#38 … T5→#42)。状態 → in_progress。
