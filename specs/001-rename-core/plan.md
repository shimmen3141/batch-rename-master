# 計画: コア命名エンジン(rename-core)

- 状態: in_progress <!-- draft → approved(人間が変更) → in_progress → done -->
- 作成日: 2026-07-26
- 元情報: `specs/discovery.md`(機能横断ディスカバリ)、`docs/proposals/001-PRD.md`
- 仕様: Strict: contracts/behavior-contract.json(正しさの定義はそちらが正本)

## 背景・目的

一括リネームアプリの中核となる**純粋 Dart の命名エンジン**を、UI・ファイルIO・プラットフォーム固有処理から分離して先に作る。トークン列(元ファイル名 / 自由テキスト / 連番 / 日時)から新ファイル名を生成し、実行前のドライラン検証(重複・連番桁不足の検出)と自動解決((1)(2)付与・桁自動拡張)までを担う。ファイルを破壊しうる操作の正しさの核であり、`flutter test` で完全に検証できるため Strict 仕様で正しさを固定する。UI(002/003)や SAF/実行層(004/005)はこのエンジンを土台に後続で計画する。

## スコープ外

- Flutter ウィジェット・画面・状態管理(002/003 の担当)。このエンジンは Flutter widget に依存しない純粋 Dart として書く。
- 実ファイルの読み書き・SAF 権限取得・OS ファイルシステムアクセス(004/005 の担当)。ファイルメタデータ(名前・作成/更新日時・サイズ)は**入力として受け取る**。
- 正規表現置換・サブフォルダ再帰・undo 履歴・クラウド同期(ディスカバリで現時点スコープ外)。
- 正しさの境界(in/out・異常系の詳細)は仕様(T1)が正本。ここには進め方の線引きだけを書く。

## 全体の受け入れ条件

- [ ] `contracts/behavior-contract.json` が `status: approved`、`spec_lint.py --strict` が PASS。
- [ ] T1 で定義される REQ/INV/VER をすべて覆う `test/spec_001_rename_core/` が `flutter test` で通る。
- [ ] `flutter analyze` が 0 issue、`dart format --output=none --set-exit-if-changed .` が PASS。
- [ ] エンジンは `package:flutter/*` に依存しない(純粋 Dart / `dart:core` のみ想定)。

## 設計方針

- 配置: エンジン本体は `lib/core/`(純粋 Dart)。公開 API は `lib/core/rename_engine.dart` に集約。widget から使う型もここ経由で参照する。
- 層構成(下から): ドメインモデル(FileEntry・Token 階層・RenameRule)→ トークン評価(1ファイル→新ベース名)→ プレビュー生成(選択・並び順を反映した一覧)→ ドライラン検証(警告生成)→ 自動解決(強制実行時の名前確定)。純粋関数中心で副作用を持たせない(テスト容易性のため)。
- 連番の振り方・日時フォーマット・重複解決規則・ファイル名バリデーション・拡張子の扱いは**仕様の open_questions** として T1 で確定する(ここでは決めない)。

## 決定事項

| 日付 | 論点(要旨) | 決定 | 決定者 |
|------|------------|------|--------|
| 2026-07-25 | 最初のスライス | コアロジック層(命名エンジン)を UI/ファイルIOから分離して先に作る。ビルド確認はホスト側 | 開発者 |
| 2026-07-25 | コアの範囲 | 4トークン全部 + ドライラン検証 + 自動解決をすべて 001 に含める | 開発者 |
| 2026-07-25 | 001 のファイルIO | 持たない。ファイルメタデータは入力として受け取る | 開発者 |
| 2026-07-25 | 仕様レベル | Strict(データ整合性が核) | 開発者 |
| 2026-07-26 | 仕様由来テストの配置 | ASDD 規約の `tests/spec_<NNN>_...` を Flutter 慣習に合わせ `test/spec_001_rename_core/` に読み替え(`flutter test` が `test/` 配下を走査するため) | Claude(規約適応) |
| 2026-07-26 | 区切り記号(ハイフン/アンダーバー/スペース)の扱い | 独立トークンにせず、自由テキストと同一実体(リテラル文字列トークン)として評価。コアのトークン種別は4つのまま。UI(003)でワンタップ挿入できるプリセットチップとして見せる | 開発者 |
| 2026-07-26 | トークンの追加・削除・並び替え | 主に UI(003)の担当だが、コア(001)の RenameRule は任意順・同一種別の重複可のトークン順序付きリストとしてこれを支える(モデルが並びを制約しない) | 開発者 |
| 2026-07-26 | 連番の振り順(選択順/表示順) | PRD §3.1「連番もチェックされたファイルの上から順に振られる」より、チェック済みファイルのリスト表示順・上から1始まり(REQ-006)。質問せず PRD で確定 | Claude(PRD 引用) |
| 2026-07-26 | 重複検出のスコープ | チェック済みの生成後名同士 + フォルダ内の未チェック既存ファイルの現在名との衝突も検出(最終名集合ベース、REQ-007)。既存ファイルの上書き防止 | 開発者 |
| 2026-07-26 | 日時フォーマット記号集合 | YYYY/YY/MM/DD/HH/mm/ss(ゼロ埋め・最長一致・大小区別、非該当文字はリテラル、REQ-004) | 開発者 |
| 2026-07-26 | 001 のファイル名バリデーション範囲 | 空名検出のみ(REQ-009)。OS 別禁止文字・最大長は 004/005 に後回し(scope.out) | 開発者 |
| 2026-07-26 | 自動解決の重複回避接尾辞の書式 | ` (n)`(半角スペース + 半角括弧 + 1始まり整数)で確定(REQ-010)。契約 open_question を解消 | 開発者 |
| 2026-07-26 | 仕様(Strict 契約)の承認 | behavior-contract.json を `approved` に(開発者承認)。後続 T2〜T6 が実行可能に | 開発者 |

## タスク一覧

| ID | タスク | 規模 | 依存 | 状態 | issue |
|----|--------|------|------|------|-------|
| T1 | 振る舞い仕様の作成(Strict) | M | - | done | #2 |
| T2 | ドメインモデル + 単純トークン評価(元名・自由テキスト) | M | T1 | pending | #3 |
| T3 | 連番・日時トークンの評価 | M | T2 | pending | #4 |
| T4 | プレビュー生成(選択・並び順反映、連番の割り当て) | M | T3 | pending | #5 |
| T5 | ドライラン検証(重複・桁不足の警告生成) | M | T4 | pending | #6 |
| T6 | 自動解決(強制実行時の名前確定) | M | T5 | pending | #7 |

<!-- 状態: pending / in_progress / done / blocked。Tn は不変(順序ではなく identity)。実行順は依存列と行順で表す -->

## タスク詳細

### T1: 振る舞い仕様の作成(Strict)

- 変更対象: specs/001-rename-core/spec.md, specs/001-rename-core/contracts/behavior-contract.json, specs/001-rename-core/decisions/
- 受け入れ条件:
  - [ ] 4トークン(元名/自由テキスト/連番/日時)の評価、プレビュー生成、ドライラン検証(重複・桁不足)、自動解決の REQ/INV/OP と検証観点(VER)が定義されている。区切り記号は独立トークンにせず自由テキストと同一のリテラル文字列トークンとして扱う(決定事項参照)。
  - [ ] RenameRule のモデルが「任意順・同一種別の重複可」のトークン順序付きリストであることを INV として明示(UI 側の追加・削除・並び替えを土台として支える)。
  - [ ] open_questions に「連番の振り方(選択順/表示順)」「日時フォーマット記号集合と基準(作成/更新/現在)」「重複解決の順序・既存名との衝突・拡張子の扱い」「OS別ファイル名バリデーション」を挙げ、決着した回答は決定事項へ反映する。
  - [ ] spec.md の「反証ログ」に反証観点と検出・対処が記録されている(0件ならその旨)。
  - [ ] `spec_lint.py --strict` が PASS(出力を作業ログに添付)。
  - [ ] 仕様が `draft` でインデックス登録され、完了報告にレビュー依頼が含まれる(approved 化は人間。**後続タスクは仕様が approved まで実行不可**)。
- 参考: create-verifiable-spec skill、`docs/proposals/001-PRD.md` §3.1/§4

### T2: ドメインモデル + 単純トークン評価(元名・自由テキスト)

- 変更対象: lib/core/(model・rename_engine.dart), test/spec_001_rename_core/
- 受け入れ条件:
  - [ ] FileEntry(名前・ベース名・拡張子・作成/更新日時・サイズ)、Token 階層、RenameRule を定義。
  - [ ] 「元ファイル名」「自由テキスト」トークンの評価に対応する REQ を覆う `test/spec_001_rename_core/` が `flutter test` で通る。
  - [ ] `flutter analyze` 0 issue、`dart format` PASS、エンジンは Flutter に非依存。
- 参考: T1 の spec.md / behavior-contract.json

### T3: 連番・日時トークンの評価

- 変更対象: lib/core/, test/spec_001_rename_core/
- 受け入れ条件:
  - [ ] 連番トークン(開始番号・桁数ゼロ埋め・増分)と日時トークン(基準・フォーマット)の評価が、T1 で確定した REQ どおりに動く。
  - [ ] 該当 REQ/VER を覆う `test/spec_001_rename_core/` が通り、`flutter analyze`/`dart format` が PASS。
- 参考: T1、PRD §3.2

### T4: プレビュー生成(選択・並び順反映、連番の割り当て)

- 変更対象: lib/core/, test/spec_001_rename_core/
- 受け入れ条件:
  - [ ] 順序付き+選択状態のファイル一覧にルールを適用し、各ファイルの新名(プレビュー)を返す。連番は T1 で確定した単位(選択順/表示順)で割り当てる。
  - [ ] 該当 REQ/INV を覆う `test/spec_001_rename_core/` が通り、`flutter analyze`/`dart format` が PASS。
- 参考: T1、PRD §4.1

### T5: ドライラン検証(重複・桁不足の警告生成)

- 変更対象: lib/core/, test/spec_001_rename_core/
- 受け入れ条件:
  - [ ] プレビュー結果に対し、重複する新名・連番桁不足の箇所を警告として列挙する(実行はしない)。
  - [ ] 該当 REQ/VER(異常系含む)を覆う `test/spec_001_rename_core/` が通り、`flutter analyze`/`dart format` が PASS。
- 参考: T1、PRD §4.2

### T6: 自動解決(強制実行時の名前確定)

- 変更対象: lib/core/, test/spec_001_rename_core/
- 受け入れ条件:
  - [ ] 警告がある状態で強制実行相当を要求すると、重複には `(1)(2)…` を付与、桁不足は桁を自動拡張して、衝突のない最終名一覧を返す。
  - [ ] 該当 REQ/INV(自動解決後は重複ゼロ)を覆う `test/spec_001_rename_core/` が通り、`flutter analyze`/`dart format` が PASS。
- 参考: T1、PRD §4.2 選択肢B

## 作業ログ

- 2026-07-26 / 計画承認 / 開発者承認(「承認します」)。状態 draft → approved。レビュー判断ポイント1〜4に個別の異議なし、包括承認として記録。
- 2026-07-26 / 指示反映 / 開発者確認済み: トークンの自由な追加・削除・並び替えと、区切り記号の扱いを確認。区切り記号=自由テキストと同一実体(リテラル文字列トークン)、UI プリセットとして提供(決定事項に2行追加、T1 受け入れ条件を補足)。plan テキスト変更につき事前確認済み。
- 2026-07-26 / T1 / 着手 / 担当: shimmen3141(暫定 claim)。issue運用は mode B 自動同期が Workflow permissions のユーザー導入対応待ちで Issue 未投影のため、claim を plan.md 側に置く(Issue 投影後に整合させる)。
- 2026-07-26 / T1 / done / verifier PASS(試行1) / Strict 契約・spec.md・ADR-001 作成、spec_lint --strict PASS(errors=0/warnings=0)。仕様は draft。**仕様の approved(人間)待ち。後続 T2 は仕様承認まで実行不可**。契約 open_questions 1件(接尾辞書式の確認)は承認時に解消。
- 2026-07-26 / 仕様承認 / 開発者承認(「behavior-contract.json は承認します」「接尾辞書式はあなたの提案で確定」)。contract status draft → approved、open_questions 解消(空)、spec.md Status approved。lint --strict PASS 継続。**T2 が実行可能に**。
- 2026-07-26 / T1 / PR #1 作成(asdd/001-rename-core/T1 → main)。PR運用のためマージ待ちで停止。T2 は T1 の PR マージ後に着手可(依存の完了判定 = done かつ PR マージ済み)。

<!-- /run-plan が追記する。着手/完了の記録はそちらの管轄 -->
