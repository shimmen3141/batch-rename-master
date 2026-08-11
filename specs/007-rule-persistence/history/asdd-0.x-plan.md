# 計画: ルール永続化(前回ルールの復元)(rule-persistence)

- 状態: approved <!-- draft → approved(人間が変更)。進行状態はタスクから導出される -->
- 書式: 2
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

- [x] `spec.md` の Status が approved(Light)。
- [x] T1 で定義される REQ/VER を覆う `test/spec_007_rule_persistence/` が `flutter test` で通る(serialization 12 + persistence 10 + wiring 6 + shared_preferences 5 = 33件)。
- [x] `flutter analyze` 0 issue、`dart format --output=none --set-exit-if-changed .` PASS。
- [x] シリアライズ層・復元/保存オーケストレーションは**純粋 Dart / fake ストア**でサンドボックス検証できる(実ストアなしで)。
- [x] 実ストア(`shared_preferences`)実装とアプリ配線は、サンドボックスで analyze/test(モック)まで完了。**実永続化(再起動で復元)の実機/エミュレータ確認はホスト側の残作業**(手順は `docs/development/emulator-verification.md`)。

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
| 2026-08-02 | JSON type タグ名 | 一目で分かる語に確定: `original_name` / `text`(自由テキスト・区切り兼用の LiteralToken)/ `sequence_number` / `datetime`。正本は spec.md | 開発者 |

## タスク一覧

| ID | タスク | 規模 | 依存 | 仕様 | issue |
|----|--------|------|------|------|-------|
| T1 | 振る舞い仕様の作成(Light) | S | - | - | #38 |
| T2 | シリアライズ: RenameRule/Token ⇔ JSON(純粋 Dart) | M | T1 | REQ-001, REQ-002, REQ-003, REQ-004 | #39 |
| T3 | ストレージポート + in-memory fake + 復元/保存オーケストレーション | M | T2 | REQ-005, REQ-006, REQ-007 | #40 |
| T4 | RuleController への配線(初期復元 + 変更保存) | S | T3, 003-rule-builder.T2 | REQ-008 | #41 |
| T5 | 実ストア(shared_preferences アダプタ)+ アプリ入口配線(ホスト検証) | M | T4 | REQ-005 | #42 |

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
- 状態: done
- ログ:
  - 2026-08-02 / 着手 / 担当: shimmen3141(Issue #38 を assign)。ブランチ asdd/007-rule-persistence/T1。
  - 2026-08-02 / done / verifier PASS(試行1)。Light 仕様 spec.md 作成(シリアライズ round-trip/異常系 REQ-001〜004、RuleStore 契約と復元/保存 REQ-005〜007、配線 REQ-008、VER-001〜003、反証ログ5観点、open_questions 5件に推奨デフォルト併記)。**spec.md の approved(人間)待ち。後続 T2 は仕様承認まで実行不可**。
  - 2026-08-02 / PR #43 作成(asdd/007-rule-persistence/T1 → dev, Closes #38)。spec.md レビュー・承認待ちで停止。
  - 2026-08-02 / 補足 / PR #43 は spec が draft のまま dev マージされた(承認前)。開発者承認を受けて別 PR で spec.md を approved 化する(下記)。
  - 2026-08-02 / spec.md approved / 開発者承認(JSON type タグ名を確定: original_name / text / sequence_number / datetime。他 open_questions は推奨どおり)。LiteralToken は自由テキスト・区切り兼用のため type は単一(`text`)。dev の spec は draft でマージ済みだったため、別 PR で Status draft→approved と type タグ名確定を反映。**後続 T2 はこの承認 PR の dev マージ後に /run-plan で実行可**。
  - 2026-08-02 / spec 承認 PR #44 マージ済み(dev)。spec.md approved 確定。
  - 2026-08-02 / 計画承認 / 開発者承認(「承認します」)。状態 draft → approved。番号 007(004〜006 の予約保持)・仕様 Light・プリセット保存は別機能、で確定。T1 実行は 007 plan.md の dev 到達(コミット→投影)後。
  - 2026-08-02 / 計画投影 / PR #37 マージで 007 の Issue projection(T1→#38 … T5→#42)。状態 → in_progress。

### T2: シリアライズ(RenameRule/Token ⇔ JSON)

- 変更対象: lib/core/, test/spec_007_rule_persistence/
- 受け入れ条件:
  - [ ] 全 Token 種別(元名/リテラル/連番/日時)と `RenameRule` の JSON 往復が可逆(round-trip)で、未知 type・壊れた JSON は `null` を返す(T1 の REQ どおり)。純粋 Dart(`package:flutter`/`dart:io` 非依存)。
  - [ ] 該当 REQ/VER を覆う unit test(各種別の例 + round-trip + 異常入力)が通る。`flutter analyze` 0 issue、`dart format` PASS。
- 参考: T1、001 の各 `Token` の引数・sealed 構造
- 状態: done
- ログ:
  - 2026-08-02 / 着手 / 担当: shimmen3141(Issue #39 を assign)。ブランチ asdd/007-rule-persistence/T2。
  - 2026-08-02 / done / verifier PASS(試行1・独自プローブ含む)+レビューパス(P0/P1 なし)。`lib/core/rule_serialization.dart`(純粋 Dart, `dart:convert` のみ)を追加: 確定スキーマ(`{"version":1,"tokens":[...]}`、type=original_name/text/sequence_number/datetime)で serializeRule/deserializeRule。異常系(不正JSON/未知type/欠損/型不一致/非対応バージョン)は例外を投げず null。REQ-001〜004 を覆う serialization_test.dart 12件通過(全体133)、`flutter analyze` 0 issue、`dart format` PASS。
  - 2026-08-02 / PR #46 作成(asdd/007-rule-persistence/T2 → dev, Closes #39)。マージ待ちで停止。次は T3(ストレージポート + fake + オーケストレーション。依存 T2。サンドボックス完結)。
  - 2026-08-02 / PR #46 マージ済み(dev)。#39 close。docs 統合の再着地 PR #45 もマージ済み(dev の develpoment→development)。

### T3: ストレージポート + fake + オーケストレーション

- 変更対象: lib/data/rule_store/(または慣習配置), test/spec_007_rule_persistence/
- 受け入れ条件:
  - [ ] `RuleStore` ポートと in-memory fake を定義し、`save(rule)`→`load()` が現在ルールを往復する。空ストア/壊れたデータ時は空ルールを返す(T1 の REQ どおり)。
  - [ ] 該当 REQ/VER を覆う unit test が fake ストアで通り、`flutter analyze`/`dart format` PASS。実ストア不要で検証できる。
- 参考: T1、T2 のシリアライズ
- 状態: done
- ログ:
  - 2026-08-02 / 着手 / 担当: shimmen3141(Issue #40 を assign)。ブランチ asdd/007-rule-persistence/T3。
  - 2026-08-02 / done / verifier PASS(試行1)+レビューパス(P0/P1 なし)。`lib/data/rule_store/rule_store.dart`(抽象 `RuleStore` + `InMemoryRuleStore` fake)と `rule_persistence.dart`(`loadLastRule`/`saveCurrentRule`)を追加。両フォールバック経路(read null / deserialize null)で空ルール、store 経由 round-trip、fake のみで完結(実ストア不要)。flutter/dart:io 非依存。REQ-005〜007 を覆う persistence_test.dart 10件通過(spec_007 計22件、全体143)、`flutter analyze` 0 issue、`dart format` PASS。
  - 2026-08-02 / PR #47 作成(asdd/007-rule-persistence/T3 → dev, Closes #40)。マージ待ちで停止。次は T4(RuleController 配線。依存 T3 + 003-rule-builder.T2。fake で sandbox 検証)。
  - 2026-08-02 / PR #47 マージ済み(dev)。#40 close。

### T4: RuleController への配線(初期復元 + 変更保存)

- 変更対象: lib/ui/rule_builder/ または lib/data/, test/spec_007_rule_persistence/
- 受け入れ条件:
  - [ ] 起動時に `load()` の結果で `RuleController` を初期化し、`RuleController` の変更で `save()` される(fake ストアで検証)。復元失敗時は空ルールで開始。
  - [ ] 該当 REQ/VER を覆う unit/widget test が通り、`flutter analyze`/`dart format` PASS。
- 参考: T1、T3、003 の `RuleController`
- 状態: done
- ログ:
  - 2026-08-03 / 着手 / 担当: shimmen3141(Issue #41 を assign)。ブランチ asdd/007-rule-persistence/T4。
  - 2026-08-03 / done / verifier PASS(試行1・dispose 追試含む)。`lib/ui/rule_builder/persistent_rule_controller.dart`(`PersistentRuleController.restore` = 前回ルール復元で RuleController 初期化 + 変更購読で saveCurrentRule、dispose でリスナー解除+破棄)を追加。空ストア/壊れデータは空ルールで開始。REQ-008 を覆う wiring_test.dart 6件通過(spec_007 計28件、全体149)、`flutter analyze` 0 issue、`dart format` PASS。fake ストアで完結(実ストア不要)。
  - 2026-08-03 / PR #48 作成(asdd/007-rule-persistence/T4 → dev, Closes #41)。マージ待ちで停止。最後の T5(実 shared_preferences + 入口配線)は T4 マージ後。ここで初めて実デバイス確認(変更→再起動→復元)。
  - 2026-08-03 / PR #48 マージ済み(dev)。#41 close。

### T5: 実ストア(shared_preferences)+ アプリ入口配線(ホスト検証)

- 変更対象: pubspec.yaml, lib/data/rule_store/, lib/main.dart, test/spec_007_rule_persistence/
- 受け入れ条件:
  - [ ] `RuleStore` の実装として `shared_preferences` アダプタを追加(依存追加)。`SharedPreferences.setMockInitialValues` を使ったモックテストで save/load が通る。
  - [ ] アプリ入口で実ストアを注入して復元/保存が働くよう配線する。
  - [ ] `flutter analyze`/`dart format`/`flutter test`(モック)PASS。**実機/エミュレータでの永続化(再起動で復元)確認はホスト側**(手順は emulator-verification.md)。
- 参考: T1、T4、`shared_preferences` パッケージ、`docs/development/emulator-verification.md`
- 状態: done
- ログ:
  - 2026-08-03 / 着手 / 担当: shimmen3141(Issue #42 を assign)。ブランチ asdd/007-rule-persistence/T5。
  - 2026-08-03 / done / verifier PASS(試行1)。`shared_preferences` を pubspec に追加(pub get 成功)。`lib/data/rule_store/shared_preferences_rule_store.dart`(実 `RuleStore` アダプタ)を追加、`lib/main.dart` を `SharedPreferences.getInstance → 実ストア → PersistentRuleController.restore → DemoApp` に配線(前回ルール復元 + 変更自動保存)。widget_test は RuleController 注入に追随。モックテスト shared_preferences_rule_store_test.dart 5件(公式 setMockInitialValues)通過。spec_007 計33件・全体154件通過、`flutter analyze` 0 issue、`dart format` PASS。**実永続化(再起動で復元)の実機/エミュレータ確認はホスト側の残作業**(emulator-verification.md)。
  - 2026-08-03 / 全体の受け入れ条件を最終検証: spec approved / `test/spec_007_rule_persistence/` 33件 PASS / analyze 0 / format PASS / 純粋層は fake で sandbox 検証 / 実ストア・配線は analyze/test(モック)まで。サンドボックスで検証可能な範囲は全てクリア。全タスク done。計画状態 approved→done(PR #49 の dev マージで確定)。ホストでの実永続化目視のみ残。
  - 2026-08-03 / PR #49 作成(asdd/007-rule-persistence/T5 → dev, Closes #42)。マージ待ちで停止。マージで 007 完了(5/5)。
