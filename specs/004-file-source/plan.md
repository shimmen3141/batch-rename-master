# 計画: ファイル読み込み(SAF / ピッカー)(file-source)

- 状態: in_progress <!-- draft → approved(人間が変更) → in_progress → done -->
- 作成日: 2026-08-03
- 元情報: `specs/discovery.md`(004)、`docs/proposals/001-PRD.md` §2/§5、`lib/core/file_entry.dart`、`lib/ui/file_list/file_list_controller.dart`
- 仕様: Light: spec.md(正しさの定義はそちらが正本)

## 背景・目的

実ファイルの読み込みを担う。抽象ポート `FileSource` を定義し、(a) フォルダを選んで権限を取得しフォルダ内のファイル+メタデータを返す、(b) 対象ファイルを個別選択して返す、の両経路を提供する。選択は**1回で差し替えず「作業セット(かご)」へ蓄積**し、フォルダ/ファイル選択を繰り返して**別フォルダのファイルも混在**させられる(開発者要望: 事前に1フォルダへ集約する手間を無くす)。読み込んだファイルは 002 の作業セットに**追加/除去**する形で供給する。各ファイルは**元の場所ハンドル(URI/パス)**を保持し、005 のリネーム書き戻し先を一意に特定できるようにする。純粋部分(ポート契約・マッピング・作業セットの蓄積/重複排除・in-memory fake・002 への結線)はサンドボックスで unit/widget test まで固め、実 SAF / 実ピッカーはホスト検証とする。

## スコープ外

- リネーム実行(実ファイルの書き込み)は 005。本機能は**読み取りのみ**(名前・メタデータの取得と選択集合の構成)。
- **画像の撮影日時(不変キー)と「すべて/アルバム」横断ギャラリー**(MediaStore/EXIF ベースの `DATE_TAKEN`/`DateTimeOriginal`)は**後続の専用機能**。004 は汎用のファイル/フォルダ選択に徹し、画像専用へはフォークしない。
- 命名エンジン(001)・リスト/選択/ソート/プレビュー UI(002)・ルール構築(003)は既存。004 は「実データを 002 に流す入口」と「作業セットの蓄積」を足す。
- Windows のエクスプローラからの D&D 追加は 006。004 は OS ピッカー経由の選択。
- サブフォルダの再帰探索は対象外(discovery スコープ境界)。

## 全体の受け入れ条件

- [ ] `spec.md` の Status が approved(Light)。
- [ ] T1 で定義される REQ/VER を覆う `test/spec_004_file_source/` が `flutter test` で通る(ポート契約・作業セット蓄積/重複排除・fake・002 結線)。
- [ ] `flutter analyze` 0 issue、`dart format --output=none --set-exit-if-changed .` PASS。
- [ ] `FileSource` ポート・fake・作業セット・結線ロジックは**実 IO なし**でサンドボックス検証できる。
- [ ] 実 SAF(Android)/ 実ピッカー(Windows)実装は、サンドボックスで analyze/test まで、実権限・実読み込み・複数フォルダ蓄積はホストで確認(手順は `docs/development/emulator-verification.md`)。
- [ ] 004 が触れる **001/002 の承認済み仕様の更新**(下記「決定事項」)は、実装前に該当仕様を更新し**人間の再承認**を得ている。

## 設計方針

- 配置: ポート/fake/実装 = `lib/data/file_source/`(007 の `rule_store` と同じ層構成)。結線 = デモ/本番入口(`lib/main.dart`)。
- ポート `FileSource`: `Future<List<FileEntry>> pickFolder()` と `Future<List<FileEntry>> pickFiles()`(キャンセルは空リスト)。プラットフォーム権限・URI 保持は実装の内側に隠す。
- **元場所ハンドル**: 各 `FileEntry` に、リネーム書き戻し先を一意に特定できる**不透明なハンドル(SAF URI / ファイルパスの文字列)**を持たせる。作業セットの重複排除もこのハンドルで行う(同名でも別フォルダなら別物)。core を純粋に保つため型は文字列。フィールドを `FileEntry` に足すか data 層のラッパにするかは T1/T2 の設計判断。
- **作業セット(かご)**: UI は選択のたびに結果を**追加**する(差し替えない)。除去・全消去も可能。キャンセル=空リストは何も足さない。002 のコントローラに**追加/除去 API**を設ける(既定は追加分も選択状態)。
- **メタデータの可用性**: `modifiedAt`・サイズ・名前は SAF/ピッカーで確実に取得。**`createdAt` は SAF では取得不能**(誕生時刻の API が無い)。よって 004 では `createdAt` を埋めず、時系列ソート/ラベルは暫定的に**「更新日時(modifiedAt)」に正直化**する(「作成日時」と偽らない)。**撮影日時(不変キー)は後続の写真機能で正直な選択肢として追加**する。
- 002 連携: 読み込んだ一覧を作業セットへ足す。ファイル先行選択もフォルダ読み込みも、同じ `List<FileEntry>` として 002 に渡る。混在(画像+文書)を許し、**同種は前提にしない**。時刻の次元だけ種別ごとに最善値(画像の撮影日時は後続機能、それ以外は更新日時)。

## 決定事項

| 日付 | 論点(要旨) | 決定 | 決定者 |
|------|------------|------|--------|
| 2026-08-03 | 読み込み経路 | フォルダ選択(権限取得)と**ファイル個別選択**の両方を提供 | 開発者 |
| 2026-08-03 | アプリの形 | **汎用1アプリのまま**。画像の撮影日時と横断ギャラリーは MediaStore/EXIF ベースの専用後続機能へ。画像専用へフォークしない | 開発者 |
| 2026-08-03 | 複数フォルダ選択 | 004 で**作業セット(かご)方式**を採用。選択を蓄積し別フォルダも混在。各 `FileEntry` に**元場所ハンドル**を保持。002 に**追加/除去 API**を足す | 開発者 |
| 2026-08-03 | 同種前提 | 一括リネームは**同種を前提にしない**(混在可)。時刻次元だけ種別ごとに最善値 | 開発者 |
| 2026-08-03 | 時刻ラベルの正直化 | `createdAt` は SAF で取れないため、暫定の時系列ソート/ラベルを「**更新日時(modifiedAt)**」に。撮影日時は後続機能で追加。**001/002 の該当仕様は 004 の一部として更新→人間の再承認** | 開発者/Claude |
| 2026-08-03 | Android 権限 | `MANAGE_EXTERNAL_STORAGE` を使わず SAF のフォルダ単位 URI 権限/`OPEN_DOCUMENT`(複数)。プラグイン選定は実装制約として ADR | 開発者(PRD §5) |
| 2026-08-03 | スコープ | 読み取りのみ(書き込み=リネームは 005)。サブフォルダ再帰は対象外 | Claude(スコープ) |
| 2026-08-03 | 仕様レベル | Light(読み取り専用で低リスク。権限・実 IO はプラットフォーム=ホスト検証) | Claude(判定) |
| 2026-08-04 | キャンセル/エラー(spec D-1) | 区別する。結果型 `PickResult`=`Picked`/`Cancelled`/`Failed`。`Failed`(権限拒否・IO)は無変化のまま**ユーザーに通知**。005 の命名警告とは別チャネル | 開発者 |
| 2026-08-04 | 隠し/システムファイル(spec D-2) | フィルタしない(002 で選択解除)。クロスプラットフォームで確実な判別手段が無いため。将来トグルは後続 | 開発者 |
| 2026-08-04 | 返り順(spec D-3) | 追加順。初期ソートは 002 の `custom`(=追加順)。以後ソートで並び替え | 開発者 |
| 2026-08-04 | 場所の表示(spec D-4) | 同名か否かに関わらず、各行に**場所(フォルダ)をサブ情報として常時表示**。`FileEntry` に表示用の場所、002 `RowView` に副題を追加(001/002 波及) | 開発者 |

## タスク一覧

| ID | タスク | 規模 | 依存 | 状態 | issue |
|----|--------|------|------|------|-------|
| T1 | 振る舞い仕様の作成(Light)+ 001/002 仕様更新の洗い出し | M | - | done | #51 |
| T2 | `FileSource` ポート + 元場所ハンドル + 作業セット + fake + 002 結線 | M | T1 | pending | #52 |
| T3 | UI 入口: フォルダを開く / ファイルを選ぶ(追加・除去、fake で結線・widget test) | M | T2, 002-file-list.T2 | pending | #53 |
| T4 | 実 `FileSource`(Android SAF + Windows ピッカー)+ 実データ入口配線(ホスト検証) | L | T3 | pending | #54 |

<!-- 状態: pending / in_progress / done / blocked。Tn は不変。実行順は依存列と行順で表す -->

## タスク詳細

### T1: 振る舞い仕様の作成(Light)

- 変更対象: specs/004-file-source/spec.md
- 受け入れ条件:
  - [ ] `FileSource` の契約(pickFolder / pickFiles の入出力、キャンセル=空、エラー時の扱い)、`FileEntry` へのマッピング、**元場所ハンドル**の意味、**作業セットへの追加/除去/重複排除**(ハンドル同一で重複、既定選択)、002 への結線の REQ と VER が定義されている。
  - [ ] 時刻の扱い(`modifiedAt` 常時・`createdAt` は SAF で取得不能→暫定「更新日時」ラベル・撮影日時は後続機能)が REQ として明記されている。
  - [ ] **004 が触れる 001/002 の承認済み仕様の更新点**(002: 追加/除去 API と時系列ソートのラベル「作成日時」→「更新日時」、001: 日時トークンの「作成」表記、`FileEntry` への元場所ハンドル追加)を洗い出し、それぞれ**人間の再承認が要る**旨を明記する。
  - [ ] open_questions に「重複名・隠しファイルの扱い」「キャンセルとエラー(権限拒否)の区別」「返す順序(名前順/未定義)」「複数フォルダ混在時の表示(フォルダ名の副題等)」を挙げる。
  - [ ] 反証ログに反証観点と検出・対処が記録されている(0件ならその旨)。
  - [ ] 仕様が draft でインデックス登録され、完了報告にレビュー依頼が含まれる(approved 化は人間。**後続タスクは仕様が approved まで実行不可**)。
- 参考: create-verifiable-spec skill、PRD §2/§5、discovery.md(004)、001 の `file_entry.dart`、002 の `file_list_controller.dart`、007 の `rule_store`(ポート/fake の書き方)

### T2: `FileSource` ポート + 元場所ハンドル + 作業セット + fake + 結線

- 変更対象: lib/data/file_source/, lib/core/file_entry.dart(元場所ハンドル), lib/ui/file_list/file_list_controller.dart(追加/除去 API), test/spec_004_file_source/
- 受け入れ条件:
  - [ ] `FileSource` ポートと in-memory fake(与えた `FileEntry` 群を返す)を定義。各 `FileEntry` が元場所ハンドルを持つ。
  - [ ] 作業セットのロジック(追加・除去・ハンドルによる重複排除・既定選択)と、fake の pickFolder/pickFiles 結果を 002 の作業セットへ**追加**する結線が T1 の REQ どおり動く(キャンセル=空は無変化)。
  - [ ] 002 コントローラに追加/除去 API を足し、既存の 002 テストが緑のまま(退行なし)。
  - [ ] 該当 REQ/VER を覆う unit test が fake で通り、`flutter analyze`/`dart format` PASS。実 IO 不要。
  - [ ] 001/002 の該当仕様が**先に更新・再承認**されていること(未承認ならブロック報告)。
- 参考: T1、001 `FileEntry`、002 `FileListController`、007 の `rule_persistence`(結線の書き方)

### T3: UI 入口(フォルダを開く / ファイルを選ぶ・追加/除去)

- 変更対象: lib/ui/ または lib/main.dart, test/spec_004_file_source/
- 受け入れ条件:
  - [ ] 「フォルダを開く」「ファイルを選ぶ」の導線から `FileSource` を呼び、結果が 002 の作業セットに**追加**される(複数回で別フォルダ分も蓄積)。選択の除去・全消去導線がある。空(キャンセル)時は無変化(fake を注入した widget test で検証)。
  - [ ] 該当 REQ/VER を覆う widget test が通り、`flutter analyze`/`dart format` PASS。色は `AppColors`。
- 参考: T1、T2、002 の `FileListView`、`AppColors`

### T4: 実 `FileSource`(Android SAF / Windows)+ 実データ配線(ホスト検証)

- 変更対象: pubspec.yaml, lib/data/file_source/, lib/main.dart, android/・windows/ 設定, test/spec_004_file_source/
- 受け入れ条件:
  - [ ] Android(SAF フォルダ URI 権限 + `OPEN_DOCUMENT` 複数選択、必要な永続化権限)/ Windows(ピッカー)の `FileSource` 実装を追加(プラグイン選定は実装制約として ADR)。各ファイルの元場所ハンドルを実 URI/パスで満たす。可能な範囲でモック/ユニット test を置く。
  - [ ] アプリ入口で実 `FileSource` を注入し、実ファイルを 002 の作業セットに流す。`flutter analyze`/`dart format`/`flutter test` PASS。
  - [ ] **実権限・実読み込み・複数フォルダ蓄積(別フォルダの選択を重ねて1リストになる)の実機/エミュレータ確認はホスト側**(手順は emulator-verification.md)。`.github/workflows` 変更が要る場合は人間に依頼。
- 参考: T1、T3、PRD §5、`docs/development/emulator-verification.md`

## 作業ログ

<!-- /run-plan が着手・完了を追記する。テンプレの書式に従う -->

- 2026-08-03 / 承認 / 計画を draft→approved。開発者承認(「改訂版は承認します」)。決定事項に「アプリの形(汎用1アプリ・写真機能は後続)」「複数フォルダ=作業セット方式」「同種前提にしない」「時刻ラベルの正直化(更新日時)」を記録。リネーム時刻ずらし案は 005 候補として discovery へ記録(004 対象外)。
- 2026-08-04 / T1 着手 / shimmen3141。Issue #51 を assign(claim)、ブランチ asdd/004-file-source/T1。計画全体を in_progress に。create-verifiable-spec で Light 仕様を作成する。
- 2026-08-04 / T1 完了 / spec.md(Light・draft)作成: REQ-001〜008 / VER-001〜003 / 「波及: 001・002 の再承認が要る更新点」/ 反証ログ5観点 / open_questions OQ-1〜4。verifier PASS(試行1回・6条件すべて充足)。**spec は draft。approved 化は人間。後続 T2 以降は spec approved まで実行不可。**
- 2026-08-04 / T1 / PR #56 作成(Closes #51)。マージ待ちで停止。
- 2026-08-04 / T1 / open_questions を開発者回答で解消(D-1〜D-4)。spec を更新: `PickResult`(Picked/Cancelled/Failed)+ Failed 通知(REQ-001/008)、場所のサブ情報表示(REQ-009)、隠しファイル非フィルタ(対象外)、追加順(REQ-007)。REQ-009 追加に伴い波及に「002 RowView 場所副題」「001 FileEntry 表示用の場所」を追記。PR #56 を更新。spec は引き続き draft(approved 化は人間)。
- 2026-08-04 / T1 / PR #56 マージ。**spec.md を approved に(開発者承認: 「承認します」)。** open_questions ゼロ・全 REQ 確定。次ゲートは T2 前の 001/002 仕様更新→再承認。
