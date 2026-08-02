# 計画: ファイル選択・リストUI(file-list)

- 状態: in_progress <!-- draft → approved(人間が変更) → in_progress → done -->
- 作成日: 2026-07-27
- 元情報: `specs/discovery.md`(002)、`docs/proposals/001-PRD.md` §3.1/§4.1
- 仕様: Light: spec.md(正しさの定義はそちらが正本)

## 背景・目的

メインのワークスペース画面。読み込んだファイルを一覧表示し、左に現在名・右に変更後名(001 のプレビュー)を並べる。チェックボックスで対象を絞り、名前/作成日時/サイズでソートでき、行をドラッグすると自動で「カスタム順」へ切り替わる。選択・並び順・ルールの変更が即座にプレビューへ反映される(001 の `generatePreview` を使用)。サンドボックスでは視覚検証ができないため、選択・ソート・カスタム順・プレビュー連携を**ウィジェットから分離したプレゼンテーション状態層(コントローラ)**として先に作り unit test で固定し、その上に薄いウィジェット層を載せて widget test で検証する。

## スコープ外

- ルール構築UI(トークンの追加・並び替え・詳細設定)は 003。002 は `RenameRule` を**外部注入**で受け取り、既定は元名トークンのみで動く。
- 実ファイルの読み込み(SAF)は 004、リネーム実行は 005、エクスプローラからの D&D 追加は 006。002 は `List<FileEntry>` を入力として受け取る。
- 視覚デザインの確定。後日の参考デザイン(claude design)到着時にすり合わせるため、本計画・仕様は**振る舞い中心**とし、レイアウト・配色・余白などの視覚は固定しない。
- 正しさの境界・異常系の詳細は仕様(T1, Light)が正本。ここには進め方の線引きだけを書く。

## 全体の受け入れ条件

- [x] `spec.md` の Status が approved(Light)。
- [x] T1 で定義される REQ/VER を覆う `test/spec_002_file_list/` が `flutter test` で通る(コントローラの unit test 27件 + ウィジェットの widget test 8件 = 35件)。
- [x] `flutter analyze` 0 issue、`dart format --output=none --set-exit-if-changed .` PASS。
- [x] コントローラ層はウィジェット(`Widget` の構築)に依存せず、ロジックが unit test 単体で検証できる(`foundation.dart` のみ依存)。

## 設計方針

- 配置: `lib/ui/file_list/`。プレゼンテーション状態層 = `FileListController`(選択・ソート種別・カスタム順・現在ルールを保持し、001 の `generatePreview` で行データを算出)。ウィジェット層はこのコントローラを描画するだけの薄い層。
- 依存: 001-rename-core の公開 API(`FileEntry` / `RenameRule` / `generatePreview`。done)。行データ = 現在名(`FileEntry.name`)+ 変更後名(選択行はプレビュー結果、未選択行の扱いは仕様で定義)。
- ソートは安定ソートで種別ごとの comparator を用意。ドラッグでの並び替えが起きた瞬間に種別を「カスタム」へ切り替える(PRD §3.1)。
- 名前ソートの順序・既定選択状態・ソート方向・未チェック行の変更後名表示は**仕様の open_questions** として T1 で確定する。

## 決定事項

| 日付 | 論点(要旨) | 決定 | 決定者 |
|------|------------|------|--------|
| 2026-07-27 | 002 のスライス | 状態コントローラ層を分離して先に作り unit test で検証、薄いウィジェット層を widget test で検証。視覚はホスト側で確認 | 開発者 |
| 2026-07-27 | 仕様レベル | Light(表示・選択・ソートのUI機能。お金・データ整合性・並行性なし) | Claude(判定) |
| 2026-07-27 | ルールの供給 | 002 は `RenameRule` を外部注入で受け取り、既定は元名トークンのみ。ルール構築は 003 | Claude(設計) |
| 2026-07-27 | 参考デザイン | 後日 claude design の参考デザイン到着時に UI 視覚をすり合わせる。計画・仕様は振る舞い中心・視覚非固定 | 開発者 |
| 2026-08-02 | UI 視覚方針 | ウィジェット層(T4/T5)は `docs/design/Bulk Renamer.html` に全面準拠。色はセマンティック名で `ThemeExtension`(`AppColors`)に定義し再利用(直接指定しない)。色・細部は後日別途調整あり。※仕様は振る舞い中心で視覚非規範のため spec 変更なし | 開発者 |

## タスク一覧

| ID | タスク | 規模 | 依存 | 状態 | issue |
|----|--------|------|------|------|-------|
| T1 | 振る舞い仕様の作成(Light) | S | - | done | #15 |
| T2 | 状態コントローラ(選択・ソート・カスタム順) | M | T1 | done | #16 |
| T3 | プレビュー連携(001 の generatePreview で行データ供給) | S | T2, 001-rename-core.T4 | done | #17 |
| T4 | ウィジェット: 2カラムリスト + チェックボックス + ソート切替 | M | T3 | done | #18 |
| T5 | ウィジェット: ドラッグ並び替え + カスタム順への自動切替 | M | T4 | done | #19 |

<!-- 状態: pending / in_progress / done / blocked。Tn は不変。実行順は依存列と行順で表す -->

## タスク詳細

### T1: 振る舞い仕様の作成(Light)

- 変更対象: specs/002-file-list/spec.md
- 受け入れ条件:
  - [ ] 選択(既定状態・トグル・全選択/全解除)、ソート(名前/作成日時/サイズ/カスタム)、ドラッグでのカスタム順自動切替、プレビュー連携(選択・並び順・ルールから各行の現在名/変更後名を供給)の REQ と検証観点(VER)が定義されている。
  - [ ] open_questions に「既定の選択状態(全選択/全解除)」「名前ソートの順序(自然順/辞書順・大小・ロケール)」「ソート方向(昇順固定/昇降トグル)」「未チェック行の変更後名の表示」「同値時のソート安定性」を挙げる。
  - [ ] spec.md の「反証ログ」に反証観点と検出・対処が記録されている(0件ならその旨)。
  - [ ] 仕様が draft でインデックス登録され、完了報告にレビュー依頼が含まれる(approved 化は人間。**後続タスクは仕様が approved まで実行不可**)。
- 参考: create-verifiable-spec skill、`docs/proposals/001-PRD.md` §3.1/§4.1、discovery.md(002)

### T2: 状態コントローラ(選択・ソート・カスタム順)

- 変更対象: lib/ui/file_list/(controller・sort), test/spec_002_file_list/
- 受け入れ条件:
  - [ ] `FileListController` が、`List<FileEntry>` の保持・選択トグル・全選択/全解除・ソート種別切替(名前/作成日時/サイズ)・カスタム順(reorder)を、T1 の REQ どおりに提供する。ソートは安定。
  - [ ] 該当 REQ/VER を覆う `test/spec_002_file_list/` の unit test が `flutter test` で通る。
  - [ ] `flutter analyze` 0 issue、`dart format` PASS。コントローラは `Widget` 構築に依存しない。
- 参考: T1 の spec.md、001-rename-core の `FileEntry`

### T3: プレビュー連携(001 の generatePreview で行データ供給)

- 変更対象: lib/ui/file_list/, test/spec_002_file_list/
- 受け入れ条件:
  - [ ] コントローラが、現在の並び順・選択・注入された `RenameRule` から 001 の `generatePreview` を呼び、各行の (現在名, 変更後名 or 未選択時の表示) を供給する。選択・並び順・ルールの変更が行データに反映される。
  - [ ] 該当 REQ/VER を覆う unit test が通り、`flutter analyze`/`dart format` PASS。
- 参考: T1、001-rename-core.T4(`generatePreview`)、PRD §4.1

### T4: ウィジェット: 2カラムリスト + チェックボックス + ソート切替

- 変更対象: lib/ui/file_list/(widgets), test/spec_002_file_list/
- 受け入れ条件:
  - [ ] コントローラを描画する薄いウィジェット。各行に現在名/変更後名の2カラムとチェックボックス、上部にソート切替を表示。操作がコントローラに反映されプレビューが更新される。
  - [ ] 該当 REQ/VER を覆う widget test が `flutter test`(ヘッドレス)で通り、`flutter analyze`/`dart format` PASS。
- 参考: T1、PRD §3.1

### T5: ウィジェット: ドラッグ並び替え + カスタム順への自動切替

- 変更対象: lib/ui/file_list/, test/spec_002_file_list/
- 受け入れ条件:
  - [ ] 行のドラッグ&ドロップで並び替えでき、並び替えが起きた瞬間にソート種別が「カスタム」へ切り替わる(PRD §3.1)。並び順の変更が連番・プレビューに反映される。
  - [ ] 該当 REQ/VER を覆う widget test が通り、`flutter analyze`/`dart format` PASS。
- 参考: T1、PRD §3.1

## 作業ログ

- 2026-07-27 / 計画承認 / 開発者承認(「承認します。T1から実行してください」)。状態 draft → approved。レビュー判断ポイント1〜4に個別異議なし、包括承認として記録。
- 2026-07-27 / T1 / 着手 / 担当: shimmen3141(暫定 claim)。002 plan.md が dev/main 未到達で Issue 未投影のため claim を plan.md 側に置く(T1 PR の dev マージで projection が 002 Issue を作成)。状態 → in_progress。
- 2026-07-27 / T1 / done / verifier PASS(試行1) / Light 仕様 spec.md 作成(選択・ソート4種・カスタム順自動切替・001 generatePreview 連携の REQ-001〜007/VER-001〜002、反証ログ、open_questions 6件に推奨デフォルト併記)。**spec.md の approved(人間)待ち。後続 T2 は仕様承認まで実行不可**。
- 2026-07-27 / T1 / PR #14 作成(asdd/002-file-list/T1 → dev)。spec.md レビュー・承認待ちで停止。マージで 002 の Issue が projection される。
- 2026-08-01 / 参考デザイン反映 / claude design(`docs/design/Bulk Renamer.html`)到着。3点をレビューし機能ごとに仕分け(開発者確認済み): ①ファイル先行選択=004 の追加要求(矛盾なし)、②リネーム後 undo=005(セッション内・単一ステップ・時限トースト。discovery の「永続 undo スタック除外」とは別物として 005 へ)、③a base トークン大小変換=approved 001 の将来拡張(今は 001 を触らない)、③b レイアウト3案/プリセット保存=視覚(002範囲外)/003。**いずれも 002 の draft 仕様・計画に変更不要**(002 は `List<FileEntry>`+`RenameRule` 注入で構造的に隔離)。①②③の将来スコープは discovery.md に記録。
- 2026-08-01 / T1 / spec.md approved / 開発者承認(未解決事項への個別回答: 初期ソートを「入力順(custom)のまま」で確定=現行 spec の ASSUMED と一致)。設計が既定選択・ソート4種・自動カスタム順・ライブプレビューを追認。spec.md の Status draft→approved、未解決事項6件を確定値へ。**後続 T2 は PR #14 の dev マージ(002 Issue projection)後に /run-plan で実行可**。
- 2026-08-01 / T1 / PR #14 マージ済み(dev)。002 Issue が projection(T1→#15 … T5→#19)。
- 2026-08-01 / T2 / 着手 / 担当: shimmen3141(Issue #16 を assign)。ブランチ asdd/002-file-list/T2。
- 2026-08-01 / T2 / done / verifier PASS(試行1)+レビューパス(P0/P1 なし)。`FileListController`(選択 identity Set・ソート4種・reorder→custom 自動切替・setRule)と `file_sort.dart`(自然順・大小無視・安定ソート)を実装。REQ-001〜005 を覆う controller_test.dart 17件通過、`flutter analyze` 0 issue、`dart format` PASS。プレビュー行データ(REQ-006/007)は T3。
- 2026-08-01 / T2 / PR #21 作成(asdd/002-file-list/T2 → dev, Closes #16)。マージ待ちで停止。次の T3 は T2 のマージ後に実行可(依存 = done ∧ PR マージ済み)。
- 2026-08-01 / T2 / PR #21 マージ済み(dev)。#16 close。参考デザイン PR #20 もマージ済み。
- 2026-08-01 / T3 / 着手 / 担当: shimmen3141(Issue #17 を assign)。ブランチ asdd/002-file-list/T3。
- 2026-08-01 / T3 / done / verifier PASS(試行1)。`RowView`(row_view.dart)と `FileListController.rows` ゲッターを追加。001 の `generatePreview` に委譲(連番は再実装せず)し、選択状態を FileEntry.selected へ写した複製を表示順で渡す。未選択行は newName=null(REQ-007)。日時「現在」用に clock 注入で決定性確保。REQ-005/006/007 を覆う preview_rows_test.dart 10件通過(spec_002 計27件)、`flutter analyze` 0 issue、`dart format` PASS。verifier 指摘の doc コメント重複を整理。
- 2026-08-01 / T3 / PR #22 作成(asdd/002-file-list/T3 → dev, Closes #17)。マージ待ちで停止。次の T4(ウィジェット層)は T3 のマージ後に実行可。
- 2026-08-02 / T3 / PR #22 マージ済み(dev)。#17 close。
- 2026-08-02 / 開発者指示 / ウィジェット層を docs/design に全面準拠、色はセマンティック名(AppColors ThemeExtension)で再利用可能に定義。上の決定事項表に記録。視覚は仕様非規範のため spec 変更なし。
- 2026-08-02 / T4 / 着手 / 担当: shimmen3141(Issue #18 を assign)。ブランチ asdd/002-file-list/T4。
- 2026-08-02 / T4 / done / verifier PASS(試行1)+レビューパス(効率P2を1件修正: rows ゲッターの行ごと再計算を builder で1回に集約)。`FileListView`(ListenableBuilder で購読する薄い描画層)+ セマンティックカラー基盤 `AppColors`(ThemeExtension)/`appDarkTheme` を追加。ヘッダ(全選択トグル+件数)・ソートチップ4種・2カラム行(チェックボックス+現在名/変更後名)。VER-002 の file_list_view_test.dart 5件通過(spec_002 計32件)、`flutter analyze` 0 issue、`dart format` PASS。色は生値を app_colors.dart に集約し直書きなし(grep 確認)。REQ-002/004/006/007 を widget で被覆(REQ-003 ドラッグは T5)。
- 2026-08-02 / T4 / スコープ観察(実装せず報告): 参考デザインの「⚠N件の問題」warn 表示(PRD §4.2 のリアルタイム警告 = 001 validate 由来)は approved の 002 spec の REQ に含まれないため T4 では出していない。002 spec への追加(→再承認)か後続機能で扱うかを要判断。
- 2026-08-02 / T4 / PR #23 作成(asdd/002-file-list/T4 → dev, Closes #18)。マージ待ちで停止。最後の T5(ドラッグ並び替え)は T4 のマージ後に実行可。
- 2026-08-02 / T4 / PR #23 マージ済み(dev)。#18 close。
- 2026-08-02 / 開発者決定 / 警告表示(PRD §4.2 のリアルタイム警告)は 005 で扱う。002 では持たない。discovery.md の 005 と FINDINGS に記録。
- 2026-08-02 / T5 / 着手 / 担当: shimmen3141(Issue #19 を assign)。ブランチ asdd/002-file-list/T5。
- 2026-08-02 / T5 / done / verifier PASS(試行1)+レビューパス(P0/P1 なし)。`FileListView` を `ReorderableListView.builder` 化し、行末尾に `ReorderableDragStartListener` のドラッグハンドルを追加。並び替えで `sortMode` が custom へ自動切替し連番・プレビューへ反映(REQ-003)。Flutter 3.44 で `onReorder` が非推奨のため `onReorderItem`(newIndex=削除後の挿入先)を採用し、`controller.reorder` を同規約(removeAt→insert)へ整理。既存 T2 の reorder テスト3件を新規約に追随(結果の並びは不変、index 引数のみ調整)。reorder_view_test.dart 新規3件(直接コールバック駆動 + 実ジェスチャドラッグ + ハンドル表示)。spec_002 計35件通過、`flutter analyze` 0 issue、`dart format` PASS。
- 2026-08-02 / T5 / 全体の受け入れ条件を最終検証: spec.md approved(Light)/ `test/spec_002_file_list/` 35件 PASS / `flutter analyze` 0 issue / `dart format --set-exit-if-changed .` PASS / コントローラ層は Widget 構築に非依存(`foundation.dart` のみ)。全条件クリア。計画は PR #24 の dev マージで done(5/5)。
- 2026-08-02 / T5 / PR #24 作成(asdd/002-file-list/T5 → dev, Closes #19)。マージ待ちで停止。マージで 002 全タスク完了(5/5)→ 計画 done へ。
