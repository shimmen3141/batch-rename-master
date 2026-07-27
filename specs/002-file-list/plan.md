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

- [ ] `spec.md` の Status が approved(Light)。
- [ ] T1 で定義される REQ/VER を覆う `test/spec_002_file_list/` が `flutter test` で通る(コントローラの unit test + ウィジェットの widget test)。
- [ ] `flutter analyze` 0 issue、`dart format --output=none --set-exit-if-changed .` PASS。
- [ ] コントローラ層はウィジェット(`Widget` の構築)に依存せず、ロジックが unit test 単体で検証できる。

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

## タスク一覧

| ID | タスク | 規模 | 依存 | 状態 | issue |
|----|--------|------|------|------|-------|
| T1 | 振る舞い仕様の作成(Light) | S | - | done | |
| T2 | 状態コントローラ(選択・ソート・カスタム順) | M | T1 | pending | |
| T3 | プレビュー連携(001 の generatePreview で行データ供給) | S | T2, 001-rename-core.T4 | pending | |
| T4 | ウィジェット: 2カラムリスト + チェックボックス + ソート切替 | M | T3 | pending | |
| T5 | ウィジェット: ドラッグ並び替え + カスタム順への自動切替 | M | T4 | pending | |

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

<!-- /run-plan が追記する。着手/完了の記録はそちらの管轄 -->
