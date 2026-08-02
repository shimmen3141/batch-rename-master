# 計画: ルール構築UI(トークンビルダー)(rule-builder)

- 状態: done <!-- draft → approved(人間が変更) → in_progress → done -->
- 作成日: 2026-08-02
- 元情報: `specs/discovery.md`(003)、`docs/proposals/001-PRD.md` §3.2、`docs/design/Bulk Renamer.html`
- 仕様: Light: spec.md(正しさの定義はそちらが正本)

## 背景・目的

命名ルールを組み立てる UI。トークン(元のファイル名 / 自由テキスト / 区切り / 連番 / 日時)を Chip として追加・削除・並び替え(D&D)し、タップで各トークンの詳細設定を編集する。編集結果は 001 の `RenameRule`(`List<Token>`)として組み上がり、002 の `FileListController.setRule` に渡してリアルタイムプレビューへ反映する。002 と同じく、ウィジェットから分離した状態層 `RuleController` を先に作り unit test で固定し、その上に薄いウィジェット層(ビルダー・詳細エディタ・レスポンシブ外殻)を載せて widget test で検証する。

## スコープ外

- 命名ロジック本体(トークンの評価・プレビュー生成・検証)は 001(done)。003 は 001 の `Token`/`RenameRule` を**組み立てるだけ**。
- ファイル一覧・選択・ソート・プレビュー表示は 002(done)。003 は組み上げた `RenameRule` を `setRule` で渡すのみ。
- **ルールのプリセット保存・読み込み**(参考デザインにあるが永続化を伴う)は 003 の対象外。必要なら別機能として discover-requirements → 計画(永続化の正しさは別途仕様)。
- **元のファイル名トークンの大文字/小文字変換**(参考デザインの keep/upper/lower)は 001 が未対応のため対象外。実装するなら先に 001 仕様の拡張(→再承認)が必要(discovery.md 001 の将来拡張)。
- 実ファイルのリネーム実行は 005。

## 全体の受け入れ条件

- [x] `spec.md` の Status が approved(Light)。
- [x] T1 で定義される REQ/VER を覆う `test/spec_003_rule_builder/` が `flutter test` で通る(unit 12 + widget 14 = 26件)。
- [x] `flutter analyze` 0 issue、`dart format --output=none --set-exit-if-changed .` PASS。
- [x] `RuleController` はウィジェット(`Widget` の構築)に依存せず、ロジックが unit test 単体で検証できる(`foundation.dart` のみ)。
- [x] 組み上げた `RenameRule` が 002 の `FileListController.setRule` 経由でプレビューへ反映される(rule_builder_workspace_test.dart で結合を確認)。

## 設計方針

- 配置: `lib/ui/rule_builder/`。状態層 = `RuleController`(編集中の `List<Token>` を保持し、追加・削除・並び替え・トークン差し替えを提供、`RenameRule get rule` を公開して変更を通知)。001 の `Token` は不変値なので、詳細編集は「新しい `Token` インスタンスへの差し替え」で表現する。
- トークン種別: 元のファイル名(`OriginalNameToken`)/ 自由テキスト(`LiteralToken`)/ 区切り(`LiteralToken` のプリセット `-` `_` 空白)/ 連番(`SequenceToken`)/ 日時(`DateTimeToken`)。区切りは自由テキストと同一実体で、UI 上プリセットとして提供(001 期の決定を踏襲)。
- ウィジェット層は `RuleController` を描画する薄い層。色は 002 で作った `AppColors`(セマンティックカラー)を再利用し、視覚は参考デザインに準拠。レイアウトは振る舞い非依存。
- レスポンシブ: 画面幅で表示方式を切替(モバイル=ModalBottomSheet / デスクトップ=右側2ペイン。PRD §3.2)。ブレークポイントは仕様の open_question で確定する。
- 詳細エディタの入力範囲・既定値・日時フォーマットのプリセット集合は**仕様(T1)の open_questions** で確定する。

## 決定事項

| 日付 | 論点(要旨) | 決定 | 決定者 |
|------|------------|------|--------|
| 2026-08-02 | 仕様レベル | Light(ルールモデルの編集UI。お金・権限・データ整合性・並行性なし。永続化は対象外) | Claude(判定) |
| 2026-08-02 | 区切りトークン | 自由テキスト(`LiteralToken`)と同一実体。UI でプリセット記号を提供 | 開発者(001 期決定の踏襲) |
| 2026-08-02 | プリセット保存/読込(名前付きルール) | 003 対象外。**別機能として実装**(開発者確定) | 開発者 |
| 2026-08-02 | 元名の大小変換 | 003 対象外(001 未対応。先に 001 拡張→再承認が必要)。**開発者確定** | 開発者 |
| 2026-08-02 | 前回ルールの復元(次回起動時) | **新規要求**(開発者)。永続化を伴うため**別機能として計画**(003 対象外)。RenameRule/Token のシリアライズは将来のプリセット機能と共有。discovery.md に記録 | 開発者 |
| 2026-08-02 | 仕様 open_questions の確定(T1 レビュー) | 連番 digits=2 / 区切りに全角スペース追加 / 自由テキスト空不可(エディタ確定無効) / 連番は正のみ(負・降順除外) / 日時はプリセット+自由入力(UIはT4検討) / 境界840dp / 空ルール許容。正本は spec.md | 開発者 |

## タスク一覧

| ID | タスク | 規模 | 依存 | 状態 | issue |
|----|--------|------|------|------|-------|
| T1 | 振る舞い仕様の作成(Light) | S | - | done | #26 |
| T2 | 状態層 `RuleController`(追加・削除・並び替え・差し替え・RenameRule 公開) | M | T1 | done | #27 |
| T3 | ウィジェット: トークン Chip 列 + 追加ボタン + 削除 + D&D 並び替え | M | T2 | done | #28 |
| T4 | ウィジェット: 各トークンの詳細エディタ(自由テキスト/区切り/連番/日時) | M | T2 | done | #29 |
| T5 | レスポンシブ外殻(モバイル=ボトムシート/デスクトップ=2ペイン)+ 002 setRule 連携 | M | T3, T4, 002-file-list.T3 | done | #30 |

<!-- 状態: pending / in_progress / done / blocked。Tn は不変。実行順は依存列と行順で表す -->

## タスク詳細

### T1: 振る舞い仕様の作成(Light)

- 変更対象: specs/003-rule-builder/spec.md
- 受け入れ条件:
  - [ ] トークンの追加(5種)・削除・並び替え(D&D)・詳細差し替え、`RenameRule` の組み上げと変更通知の REQ と検証観点(VER)が定義されている。
  - [ ] open_questions に「詳細エディタの入力範囲・既定値(連番 start/digits/increment、日時 source/format プリセット、自由テキスト空許容)」「区切りプリセットの集合」「レスポンシブのブレークポイント(モバイル/デスクトップ境界)」「空ルール・全削除時の扱い」を挙げる。
  - [ ] 反証ログに反証観点と検出・対処が記録されている(0件ならその旨)。
  - [ ] 仕様が draft でインデックス登録され、完了報告にレビュー依頼が含まれる(approved 化は人間。**後続タスクは仕様が approved まで実行不可**)。
- 参考: create-verifiable-spec skill、PRD §3.2、discovery.md(003)、001 の `token.dart`/`rename_rule.dart`、002 の spec.md(状態層の書き方)

### T2: 状態層 `RuleController`

- 変更対象: lib/ui/rule_builder/, test/spec_003_rule_builder/
- 受け入れ条件:
  - [ ] `RuleController`(ChangeNotifier 等)が、編集中トークン列の保持・追加・削除・並び替え(onReorderItem 規約)・指定位置のトークン差し替えを T1 の REQ どおり提供し、`RenameRule get rule` を公開する。
  - [ ] 該当 REQ/VER を覆う `test/spec_003_rule_builder/` の unit test が通る。`flutter analyze` 0 issue、`dart format` PASS。`Widget` 構築に非依存。
- 参考: T1 の spec.md、001 の `Token`/`RenameRule`、002 の `FileListController`(reorder 規約・identity 追従の実装)

### T3: ウィジェット: トークン Chip 列 + 追加/削除/並び替え

- 変更対象: lib/ui/rule_builder/, test/spec_003_rule_builder/
- 受け入れ条件:
  - [ ] トークンを Chip として横並び表示し、5種の追加ボタン・各 Chip の削除・D&D 並び替えが `RuleController` に反映される。色は `AppColors` を使用。
  - [ ] 該当 REQ/VER を覆う widget test が通り、`flutter analyze`/`dart format` PASS。
- 参考: T1、T2、002 の `file_list_view.dart`(ReorderableList/ドラッグの実装)、`AppColors`

### T4: ウィジェット: 各トークンの詳細エディタ

- 変更対象: lib/ui/rule_builder/, test/spec_003_rule_builder/
- 受け入れ条件:
  - [ ] Chip タップで種別ごとの詳細エディタを開き、自由テキスト(文字列)・区切り(プリセット選択)・連番(start/digits/increment)・日時(source/format)を編集すると、対応する新しい `Token` に差し替わる。元のファイル名は設定項目なし。
  - [ ] 該当 REQ/VER を覆う widget test が通り、`flutter analyze`/`dart format` PASS。
- 参考: T1、T2、001 の各 `Token` の引数、参考デザインの詳細ダイアログ

### T5: レスポンシブ外殻 + 002 連携

- 変更対象: lib/ui/rule_builder/, test/spec_003_rule_builder/
- 受け入れ条件:
  - [ ] 画面幅に応じてモバイル=ModalBottomSheet / デスクトップ=2ペインで T3/T4 を提示する(PRD §3.2)。境界は T1 で確定した値。
  - [ ] `RuleController` の変更が 002 の `FileListController.setRule` に渡り、プレビュー(変更後名)へ反映されることを widget test で確認する。
  - [ ] `flutter analyze`/`dart format` PASS。
- 参考: T1、002 の `FileListController.setRule`/`FileListView`、PRD §3.2

## 作業ログ

- 2026-08-02 / 計画承認 / 開発者承認(「承認します」)。状態 draft → approved。除外2件(プリセット保存=別機能 / 元名大小変換=001未対応で除外)を開発者確定。新要求「前回ルールの復元」は**別機能として計画**(開発者選択)。将来機能2件(前回ルール復元・プリセット保存)を discovery.md に記録。T1 実行は 003 plan.md の dev 到達(#25 マージ後にコミット→投影)を待つ。
- 2026-08-02 / 計画投影 / PR #25 マージで 003 の Issue projection(T1→#26 … T5→#30)。状態 → in_progress。
- 2026-08-02 / T1 / 着手 / 担当: shimmen3141(Issue #26 を assign)。ブランチ asdd/003-rule-builder/T1。
- 2026-08-02 / T1 / done / verifier PASS(試行1)。Light 仕様 spec.md 作成(RuleController の状態・操作 REQ-001〜007/VER-001〜002、反証ログ5観点、open_questions 5件に推奨デフォルト併記)。reorder は 002 と同じ onReorderItem 規約。**spec.md の approved(人間)待ち。後続 T2 は仕様承認まで実行不可**。
- 2026-08-02 / T1 / PR #31 作成(asdd/003-rule-builder/T1 → dev, Closes #26)。spec.md レビュー・承認待ちで停止。
- 2026-08-02 / T1 / spec.md approved / 開発者承認(「承認します」)。レビューでの指示・回答を open_questions に反映して確定: 連番 digits=2、区切りプリセットに全角スペース追加、自由テキストは空不可(エディタで未入力時は確定無効・T4/VER-002)、連番は正のみ(start≥0・digits≥1・increment≥1、負・降順は除外)、日時はプリセット+自由入力(自由入力欄のUIはT4で検討)、レスポンシブ境界840dp、空ルール許容。spec.md Status draft→approved。**後続 T2 は PR #31 の dev マージ後に /run-plan で実行可**。
- 2026-08-02 / T1 / PR #31 マージ済み(dev)。#26 close。マージ済みローカルブランチを整理。
- 2026-08-02 / T2 / 着手 / 担当: shimmen3141(Issue #27 を assign)。ブランチ asdd/003-rule-builder/T2。
- 2026-08-02 / T2 / done / verifier PASS(試行1)+レビューパス(P0/P1 なし)。`RuleController`(ChangeNotifier)を実装: addToken/removeAt/reorder(onReorderItem 規約・002 と一致)/replaceAt、`rule` はスナップショット公開。REQ-001〜007 を覆う rule_controller_test.dart 12件通過(全体107)、`flutter analyze` 0 issue、`dart format` PASS。Widget 非依存(foundation のみ)。
- 2026-08-02 / T2 / PR #32 作成(asdd/003-rule-builder/T2 → dev, Closes #27)。マージ待ちで停止。次は T3/T4(依存 T2。互いに独立=並列可)。
- 2026-08-02 / T2 / PR #32 マージ済み(dev)。#27 close。
- 2026-08-02 / T3 / 着手 / 担当: shimmen3141(Issue #28 を assign)。ブランチ asdd/003-rule-builder/T3。
- 2026-08-02 / T3 / done / verifier PASS(試行1)+レビューパス(P0/P1 なし)。`RuleBuilderView`(薄い描画層)+ `token_presets.dart`(既定トークン・区切り/日時プリセット・ラベルを集約)を追加。トークン Chip の横並び(横 ReorderableListView)・5種の追加ボタン・各 Chip 削除・D&D 並び替え(onReorderItem)を controller へ委譲。色は AppColors。REQ-002/003/004 を widget で被覆(rule_builder_view_test.dart 5件、spec_003 計17件)、`flutter analyze` 0 issue、`dart format` PASS。自由テキストの追加は暫定プレースホルダ(T4 でエディタ確定フローへ)。Chip タップ→編集(onEditToken)配線は T4。
- 2026-08-02 / T3 / PR #33 作成(asdd/003-rule-builder/T3 → dev, Closes #28)。マージ待ちで停止。次は T4(詳細エディタ。依存 T2。T3 とは独立だが同一ファイル rule_builder_view.dart に onEditToken 配線を足すため T3 マージ後が無難)。
- 2026-08-02 / T3 / PR #33 マージ済み(dev)。#28 close。
- 2026-08-02 / T4 / 着手 / 担当: shimmen3141(Issue #29 を assign)。ブランチ asdd/003-rule-builder/T4。
- 2026-08-02 / T4 / done / verifier PASS(試行1)+レビューパス(P0/P1 なし)。`token_editors.dart`(ボトムシートの詳細エディタ + `showTokenEditor`)を追加、`rule_builder_view.dart` の Chip タップを既定エディタ→`replaceAt` に配線(REQ-005)。自由テキスト/区切り=空不可ガード付き LiteralToken エディタ(区切りプリセット4種)、連番=ステッパー(start≥0/digits≥1/increment≥1、負を型で排除)、日時=基準選択+プリセット+自由入力、元名=設定なし。token_editors_test.dart 6件(spec_003 計23件)、`flutter analyze` 0 issue、`dart format` PASS。
- 2026-08-02 / T4 / PR #34 作成(asdd/003-rule-builder/T4 → dev, Closes #29)。マージ待ちで停止。最後の T5(レスポンシブ外殻 + 002 setRule 連携)は T3・T4 のマージ後に実行可。
- 2026-08-02 / T4 / PR #34 マージ済み(dev)。#29 close。
- 2026-08-02 / T5 / 着手 / 担当: shimmen3141(Issue #30 を assign)。ブランチ asdd/003-rule-builder/T5。
- 2026-08-02 / T5 / done / verifier PASS(試行1)+レビューパス(初期同期テストを非空ルールで強化)。`RuleBuilderWorkspace`(StatefulWidget)を追加: `RuleController` の変更を listener で `FileListController.setRule` へ同期(初期同期 + 変更同期、dispose/didUpdateWidget で解除)、幅 840dp を境にモバイル(リスト全面+ボトムシートでルール編集)/デスクトップ(左リスト+右ルールの2ペイン)を切替。rule_builder_workspace_test.dart 3件(spec_003 計26件)、`flutter analyze` 0 issue、`dart format` PASS。
- 2026-08-02 / T5 / 全体の受け入れ条件を最終検証: spec approved(Light)/ `test/spec_003_rule_builder/` 26件 PASS(全体121)/ analyze 0 / format PASS / RuleController は Widget 非依存 / 002 setRule 連携を widget test で確認。全条件クリア。全タスク done。計画状態 approved→done(PR #35 の dev マージで確定)。
- 2026-08-02 / T5 / PR #35 作成(asdd/003-rule-builder/T5 → dev, Closes #30)。マージ待ちで停止。マージで 003 完了(5/5)。

<!-- /run-plan が着手・完了を追記する。テンプレの書式に従う -->
