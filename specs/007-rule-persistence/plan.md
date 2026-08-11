# 007 前回ルールの保存と復元

## 目的

直近に組み立てた「現在のルール」1件を永続化し、次回アプリ起動時にそのルールから始められるようにする。中核は 001 の `RenameRule`/`Token` の **JSON シリアライズ/デシリアライズ**(純粋 Dart。サンドボックスで完結検証)。永続ストレージは**ポート(抽象)**として定義し、in-memory fake でサンドボックス検証、実ストア(`shared_preferences` 等)はホスト検証とする。003 の `RuleController` に「初期ルールの復元」と「変更時の保存」を配線する。読み込み失敗・壊れたデータ時は**空ルールで開始**(低リスク)。

## 境界

### 対象

- `spec.md`、contract、既存テストが定めるこの機能の成果。
- 各タスクに移行した実装・検証・未完了受け入れ。

### 対象外

- 名前付きルールの**プリセット保存/読み込み**(複数保存・選択適用)は別機能。本機能とシリアライズ基盤を共有するが、UI・複数管理は含めない。
- リネーム履歴の永続化(undo スタック)は引き続き対象外(discovery スコープ境界)。005 のセッション内 undo とも別。
- トークンの評価・命名ロジックは 001、ルール編集 UI は 003。本機能は「現在のルール」の保存/復元だけを足す。

## 方針

- 配置: シリアライズ = `lib/core/`(純粋 Dart。001 と同じく `package:flutter`/`dart:io` 非依存)。永続化ポート・復元/保存・実ストア = `lib/data/rule_store/`(または既存慣習に合わせる)。
- シリアライズ: `RenameRule` ⇔ JSON(`Map<String,Object?>`/文字列)。各 `Token` 種別に `type` タグ + パラメータ。前方互換のため**バージョン欄**を持つ。未知 type・壊れた JSON はデシリアライズで `null`(呼び出し側が空ルールにフォールバック)。
- ストレージポート: `RuleStore`(`Future<String?> read()` / `Future<void> write(String)` 程度の最小 IF)。in-memory fake と実ストア(`shared_preferences` アダプタ)が実装。
- オーケストレーション: `read → デシリアライズ → 復元`、`RuleController 変更 → シリアライズ → write`。保存は過剰書き込みを避ける粒度で(詳細は仕様の open_questions)。
- 配線: `RuleController(tokens: 復元結果)` で起動、変更購読で保存。デモ/本番入口(`lib/main.dart`)に組み込む。

旧ASDD 0.xの状態欄とログは`history/asdd-0.x-plan.md`へ凍結した。現在の状態・依存・Issue/PRは`plan.json`と各`task.json`を正本とする。

## 全体の受け入れ証拠

- `spec.md` の Status が approved(Light)。
- T1 で定義される REQ/VER を覆う `test/spec_007_rule_persistence/` が `flutter test` で通る(serialization 12 + persistence 10 + wiring 6 + shared_preferences 5 = 33件)。
- `flutter analyze` 0 issue、`dart format --output=none --set-exit-if-changed .` PASS。
- シリアライズ層・復元/保存オーケストレーションは**純粋 Dart / fake ストア**でサンドボックス検証できる(実ストアなしで)。
- 実ストア(`shared_preferences`)実装とアプリ配線は、サンドボックスで analyze/test(モック)まで完了。**実永続化(再起動で復元)の実機/エミュレータ確認はホスト側の残作業**(手順は `docs/development/emulator-verification.md`)。

## 人間の決定

| 日付 | 論点(要旨) | 決定 | 決定者 |
|------|------------|------|--------|
| 2026-08-02 | 機能の分離 | 「前回ルールの復元」を 003(UI)から切り出した別機能。永続化の関心を独立 | 開発者 |
| 2026-08-02 | 仕様レベル | Light(復元失敗は空ルールで低リスク。シリアライズは round-trip テストで担保) | Claude(判定) |
| 2026-08-02 | プリセット保存 | 本機能の対象外(別機能)。シリアライズ基盤のみ共有 | 開発者 |
| 2026-08-02 | 番号 | 007(004〜006 の予約を保持) | 開発者 |
| 2026-08-02 | JSON type タグ名 | 一目で分かる語に確定: `original_name` / `text`(自由テキスト・区切り兼用の LiteralToken)/ `sequence_number` / `datetime`。正本は spec.md | 開発者 |

## タスク

タスクのID・依存・状態は`plan.json`と各`tasks/*/task.json`が正本。番号は安定した識別子であり、実行順ではない。

| ID | 詳細 |
|---|---|
| T01 | [task.md](tasks/T01-define-behavior/task.md) |
| T02 | [task.md](tasks/T02-serialize-rules/task.md) |
| T03 | [task.md](tasks/T03-rule-store-port/task.md) |
| T04 | [task.md](tasks/T04-connect-rule-controller/task.md) |
| T05 | [task.md](tasks/T05-shared-preferences-adapter/task.md) |
| T06 | [task.md](tasks/T06-verify-restart-persistence/task.md) |
