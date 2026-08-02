# 計画: ルール永続化(前回ルールの復元)(rule-persistence)

- 状態: approved <!-- draft → approved(人間が変更) → in_progress → done -->
- 作成日: 2026-08-02
- 元情報: `specs/discovery.md`「追加の機能候補」、`lib/core/token.dart`、`lib/ui/rule_builder/rule_controller.dart`
- 仕様: Light: spec.md(正しさの定義はそちらが正本)
- 番号: 007(discovery の 004 SAF / 005 実行 / 006 Windows の予約を保つため、意図的に歯抜け。discovery「NNN は計画化時に確定」に従う)

## 背景・目的

直近に組み立てた「現在のルール」1件を永続化し、次回アプリ起動時にそのルールから始められるようにする。中核は 001 の `RenameRule`/`Token` の **JSON シリアライズ/デシリアライズ**(純粋 Dart。サンドボックスで完結検証)。永続ストレージは**ポート(抽象)**として定義し、in-memory fake でサンドボックス検証、実ストア(`shared_preferences` 等)はホスト検証とする。003 の `RuleController` に「初期ルールの復元」と「変更時の保存」を配線する。読み込み失敗・壊れたデータ時は**空ルールで開始**(低リスク)。

## スコープ外

- 名前付きルールの**プリセット保存/読み込み**(複数保存・選択適用)は別機能。本機能とシリアライズ基盤を共有するが、UI・複数管理は含めない。
- リネーム履歴の永続化(undo スタック)は引き続き対象外(discovery スコープ境界)。005 のセッション内 undo とも別。
- トークンの評価・命名ロジックは 001、ルール編集 UI は 003。本機能は「現在のルール」の保存/復元だけを足す。

## 全体の受け入れ条件

- [ ] `spec.md` の Status が approved(Light)。
- [ ] T1 で定義される REQ/VER を覆う `test/spec_007_rule_persistence/` が `flutter test` で通る。
- [ ] `flutter analyze` 0 issue、`dart format --output=none --set-exit-if-changed .` PASS。
- [ ] シリアライズ層・復元/保存オーケストレーションは**純粋 Dart / fake ストア**でサンドボックス検証できる(実ストアなしで)。
- [ ] 実ストア(`shared_preferences`)実装とアプリ配線は、サンドボックスで analyze/test(モック)まで、実永続化はホストで確認(手順は `docs/development/emulator-verification.md`)。

## 設計方針

- 配置: シリアライズ = `lib/core/`(純粋 Dart。001 と同じく `package:flutter`/`dart:io` 非依存)。永続化ポート・復元/保存・実ストア = `lib/data/rule_store/`(または既存慣習に合わせる)。
- シリアライズ: `RenameRule` ⇔ JSON(`Map<String,Object?>`/文字列)。各 `Token` 種別に `type` タグ + パラメータ。前方互換のため**バージョン欄**を持つ。未知 type・壊れた JSON はデシリアライズで `null`(呼び出し側が空ルールにフォールバック)。
- ストレージポート: `RuleStore`(`Future<String?> read()` / `Future<void> write(String)` 程度の最小 IF)。in-memory fake と実ストア(`shared_preferences` アダプタ)が実装。
- オーケストレーション: `read → デシリアライズ → 復元`、`RuleController 変更 → シリアライズ → write`。保存は過剰書き込みを避ける粒度で(詳細は仕様の open_questions)。
- 配線: `RuleController(tokens: 復元結果)` で起動、変更購読で保存。デモ/本番入口(`lib/main.dart`)に組み込む。

## 決定事項

| 日付 | 論点(要旨) | 決定 | 決定者 |
|------|------------|------|--------|
| 2026-08-02 | 機能の分離 | 「前回ルールの復元」を 003(UI)から切り出した別機能。永続化の関心を独立 | 開発者 |
| 2026-08-02 | 仕様レベル | Light(復元失敗は空ルールで低リスク。シリアライズは round-trip テストで担保) | Claude(判定) |
| 2026-08-02 | プリセット保存 | 本機能の対象外(別機能)。シリアライズ基盤のみ共有 | 開発者 |
| 2026-08-02 | 番号 | 007(004〜006 の予約を保持) | 開発者 |

## タスク一覧

| ID | タスク | 規模 | 依存 | 状態 | issue |
|----|--------|------|------|------|-------|
| T1 | 振る舞い仕様の作成(Light) | S | - | pending | #38 |
| T2 | シリアライズ: RenameRule/Token ⇔ JSON(純粋 Dart) | M | T1 | pending | #39 |
| T3 | ストレージポート + in-memory fake + 復元/保存オーケストレーション | M | T2 | pending | #40 |
| T4 | RuleController への配線(初期復元 + 変更保存) | S | T3, 003-rule-builder.T2 | pending | #41 |
| T5 | 実ストア(shared_preferences アダプタ)+ アプリ入口配線(ホスト検証) | M | T4 | pending | #42 |

<!-- 状態: pending / in_progress / done / blocked。Tn は不変。実行順は依存列と行順で表す -->

## タスク詳細

### T1: 振る舞い仕様の作成(Light)

- 変更対象: specs/007-rule-persistence/spec.md
- 受け入れ条件:
  - [ ] シリアライズの往復(全 Token 種別 + RenameRule)、未知 type・壊れた入力の扱い(null/空フォールバック)、ストレージポートの契約、復元(起動時)/保存(変更時)の振る舞いの REQ と VER が定義されている。
  - [ ] open_questions に「JSON スキーマ(type タグ名・バージョン欄)」「保存の粒度(変更のたび/デバウンス)」「読み込み失敗時の扱い(空ルール確定)」「空ルールを保存するか」を挙げる。
  - [ ] 反証ログに反証観点と検出・対処が記録されている(0件ならその旨)。
  - [ ] 仕様が draft でインデックス登録され、完了報告にレビュー依頼が含まれる(approved 化は人間。**後続タスクは仕様が approved まで実行不可**)。
- 参考: create-verifiable-spec skill、001 の `token.dart`/`rename_rule.dart`、003 の `rule_controller.dart`、002 の spec.md(書き方)

### T2: シリアライズ(RenameRule/Token ⇔ JSON)

- 変更対象: lib/core/, test/spec_007_rule_persistence/
- 受け入れ条件:
  - [ ] 全 Token 種別(元名/リテラル/連番/日時)と `RenameRule` の JSON 往復が可逆(round-trip)で、未知 type・壊れた JSON は `null` を返す(T1 の REQ どおり)。純粋 Dart(`package:flutter`/`dart:io` 非依存)。
  - [ ] 該当 REQ/VER を覆う unit test(各種別の例 + round-trip + 異常入力)が通る。`flutter analyze` 0 issue、`dart format` PASS。
- 参考: T1、001 の各 `Token` の引数・sealed 構造

### T3: ストレージポート + fake + オーケストレーション

- 変更対象: lib/data/rule_store/(または慣習配置), test/spec_007_rule_persistence/
- 受け入れ条件:
  - [ ] `RuleStore` ポートと in-memory fake を定義し、`save(rule)`→`load()` が現在ルールを往復する。空ストア/壊れたデータ時は空ルールを返す(T1 の REQ どおり)。
  - [ ] 該当 REQ/VER を覆う unit test が fake ストアで通り、`flutter analyze`/`dart format` PASS。実ストア不要で検証できる。
- 参考: T1、T2 のシリアライズ

### T4: RuleController への配線(初期復元 + 変更保存)

- 変更対象: lib/ui/rule_builder/ または lib/data/, test/spec_007_rule_persistence/
- 受け入れ条件:
  - [ ] 起動時に `load()` の結果で `RuleController` を初期化し、`RuleController` の変更で `save()` される(fake ストアで検証)。復元失敗時は空ルールで開始。
  - [ ] 該当 REQ/VER を覆う unit/widget test が通り、`flutter analyze`/`dart format` PASS。
- 参考: T1、T3、003 の `RuleController`

### T5: 実ストア(shared_preferences)+ アプリ入口配線(ホスト検証)

- 変更対象: pubspec.yaml, lib/data/rule_store/, lib/main.dart, test/spec_007_rule_persistence/
- 受け入れ条件:
  - [ ] `RuleStore` の実装として `shared_preferences` アダプタを追加(依存追加)。`SharedPreferences.setMockInitialValues` を使ったモックテストで save/load が通る。
  - [ ] アプリ入口で実ストアを注入して復元/保存が働くよう配線する。
  - [ ] `flutter analyze`/`dart format`/`flutter test`(モック)PASS。**実機/エミュレータでの永続化(再起動で復元)確認はホスト側**(手順は emulator-verification.md)。
- 参考: T1、T4、`shared_preferences` パッケージ、`docs/development/emulator-verification.md`

## 作業ログ

- 2026-08-02 / 計画承認 / 開発者承認(「承認します」)。状態 draft → approved。番号 007(004〜006 の予約保持)・仕様 Light・プリセット保存は別機能、で確定。T1 実行は 007 plan.md の dev 到達(コミット→投影)後。

<!-- /run-plan が着手・完了を追記する。テンプレの書式に従う -->
