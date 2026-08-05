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

- [x] `spec.md` の Status が approved(Light)。
- [x] T1 で定義される REQ/VER を覆う `test/spec_004_file_source/` が `flutter test` で通る(ポート契約・作業セット蓄積/重複排除・fake・002 結線)。
- [x] `flutter analyze` 0 issue、`dart format --output=none --set-exit-if-changed .` PASS(257 tests PASS)。
- [x] `FileSource` ポート・fake・作業セット・結線ロジックは**実 IO なし**でサンドボックス検証できる。
- [ ] 実 SAF(Android)/ 実ピッカー(Windows)実装は、サンドボックスで analyze/test まで、実権限・実読み込み・複数フォルダ蓄積はホストで確認(手順は `docs/development/emulator-verification.md`)。**← ホスト側の確認が残っているため計画は in_progress のまま**
- [x] 004 が触れる **001/002 の承認済み仕様の更新**(下記「決定事項」)は、実装前に該当仕様を更新し**人間の再承認**を得ている。

## 設計方針

- 配置: ポート/fake/実装 = `lib/data/file_source/`(007 の `rule_store` と同じ層構成)。結線 = デモ/本番入口(`lib/main.dart`)。
- ポート `FileSource`: `Future<List<FileEntry>> pickFolder()` と `Future<List<FileEntry>> pickFiles()`(キャンセルは空リスト)。プラットフォーム権限・URI 保持は実装の内側に隠す。
- **元場所ハンドル**: 各 `FileEntry` に、リネーム書き戻し先を一意に特定できる**不透明なハンドル(SAF URI / ファイルパスの文字列)**を持たせる。作業セットの重複排除もこのハンドルで行う(同名でも別フォルダなら別物)。core を純粋に保つため型は文字列。フィールドを `FileEntry` に足すか data 層のラッパにするかは T1/T2 の設計判断。
- **作業セット(かご)**: UI は選択のたびに結果を**追加**する(差し替えない)。除去・全消去も可能。キャンセル=空リストは何も足さない。002 のコントローラに**追加/除去 API**を設ける(既定は追加分も選択状態)。
- **メタデータの可用性**: `modifiedAt`・サイズ・名前は SAF/ピッカーで確実に取得。**`createdAt` は SAF の列としては取得不能**(規格に無い)。ただし作成日時は他経路(EXIF・コンテナメタデータ・MediaStore・NTFS)で取得しうるため、**取得できたときだけ設定し、できなければ「不明」として扱う**(`modifiedAt` を暗黙代入して偽らない)。時系列ソートは**作成日時・更新日時の2種**を提供し、作成日時ソートでは**不明な item を更新日時で代替して並べ**、**その件数と代替した旨を警告**する(判定はファイル種別ではなく取得可否。T5/T6・決定事項参照)。代替は 002 の並べ替え・表示に閉じ、データ(REQ-003)と命名(001 INV-006)では代替しない。
- 002 連携: 読み込んだ一覧を作業セットへ足す。ファイル先行選択もフォルダ読み込みも、同じ `List<FileEntry>` として 002 に渡る。混在(画像+文書)を許し、**同種は前提にしない**。時刻の次元は、**取得できた作成日時があればそれを、無ければ更新日時を代替キー**として扱い、不明であることは行と警告で見えるようにする。

## 決定事項

| 日付 | 論点(要旨) | 決定 | 決定者 |
|------|------------|------|--------|
| 2026-08-03 | 読み込み経路 | フォルダ選択(権限取得)と**ファイル個別選択**の両方を提供 | 開発者 |
| 2026-08-03 | アプリの形 | **汎用1アプリのまま**。画像の撮影日時と横断ギャラリーは MediaStore/EXIF ベースの専用後続機能へ。画像専用へフォークしない | 開発者 |
| 2026-08-03 | 複数フォルダ選択 | 004 で**作業セット(かご)方式**を採用。選択を蓄積し別フォルダも混在。各 `FileEntry` に**元場所ハンドル**を保持。002 に**追加/除去 API**を足す | 開発者 |
| 2026-08-03 | 同種前提 | 一括リネームは**同種を前提にしない**(混在可)。時刻次元だけ種別ごとに最善値 | 開発者 |
| 2026-08-03 | ~~時刻ラベルの正直化~~(2026-08-04 に下記3行で置換) | ~~`createdAt` は SAF で取れないため、時系列ソート/ラベルを「更新日時(modifiedAt)」に置換~~ → **作成日時ソートは残し、更新日時と2種提供+取得可否で警告**へ変更。`FileEntry` へのハンドル/場所追加の再承認(2026-08-04 実施済み)は有効 | 開発者/Claude |
| 2026-08-03 | Android 権限 | `MANAGE_EXTERNAL_STORAGE` を使わず SAF のフォルダ単位 URI 権限/`OPEN_DOCUMENT`(複数)。プラグイン選定は実装制約として ADR | 開発者(PRD §5) |
| 2026-08-03 | スコープ | 読み取りのみ(書き込み=リネームは 005)。サブフォルダ再帰は対象外 | Claude(スコープ) |
| 2026-08-03 | 仕様レベル | Light(読み取り専用で低リスク。権限・実 IO はプラットフォーム=ホスト検証) | Claude(判定) |
| 2026-08-04 | キャンセル/エラー(spec D-1) | 区別する。結果型 `PickResult`=`Picked`/`Cancelled`/`Failed`。`Failed`(権限拒否・IO)は無変化のまま**ユーザーに通知**。005 の命名警告とは別チャネル | 開発者 |
| 2026-08-04 | 隠し/システムファイル(spec D-2) | フィルタしない(002 で選択解除)。クロスプラットフォームで確実な判別手段が無いため。将来トグルは後続 | 開発者 |
| 2026-08-04 | 返り順(spec D-3) | 追加順。初期ソートは 002 の `custom`(=追加順)。以後ソートで並び替え | 開発者 |
| 2026-08-04 | 場所の表示(spec D-4) | 同名か否かに関わらず、各行に**場所(フォルダ)をサブ情報として常時表示**。`FileEntry` に表示用の場所、002 `RowView` に副題を追加(001/002 波及) | 開発者 |
| 2026-08-04 | 時系列ソートの構成 | **作成日時ソートを残す**(画像ではリネーム順にとって撮影時刻が本質的で、更新日時はリネームで書き換わる)。**更新日時ソートと両方**提供し、作成日時ソート選択時に危険なら警告。旧決定「時刻ラベルの正直化(更新日時へ置換)」を**置き換える** | 開発者 |
| 2026-08-04 | 警告の判定条件 | **ファイル種別ではなく「作成日時を取得できたか」で判定**(取得できなかった件数を警告)。スクショのような「画像だが EXIF 撮影日時が無い」ケースを種別判定は誤検出するため。取得可否を表現するため `FileEntry.createdAt` を**取得不可を表せる形**にする | 開発者 |
| 2026-08-04 | 不明な作成日時の並べ替え | **更新日時をソートキーに代替**し、警告に「更新日時で代替して並べている」と明記する(未変更ファイルでは作成日時=更新日時のことが多く、末尾へ隔離するより有用)。当初の「不明は末尾・相対順保持」を置換。**代替は 002 の並べ替え・表示に閉じ**、004 のデータ(REQ-003)と 001 の命名(INV-006)では代替しない — 名前は後から直せないため | 開発者 |
| 2026-08-04 | 不明な行の識別 | 各行が**作成日時(不明ならその旨)と更新日時の双方 + 不明フラグ**を供給し、UI が識別できるようにする(002 REQ-013)。例「作成日時: 不明 / 更新日時: 2026/8/4 16:00」の強調表示・警告マーク。**見た目は非規範**で `AppColors` のセマンティック色を用いる | 開発者 |
| 2026-08-04 | 作成日時の取得経路 | 単一手段に限定せず**優先順位付きチェーン**: ① コンテンツ由来(EXIF `DateTimeOriginal` / 動画 `mvhd` / PDF `CreationDate` / Office `dcterms:created` / XMP) → ② プラットフォーム由来(Windows NTFS `CreationTime` は FFI で取得可・**コピーで更新される点に注意** / Android MediaStore `DATE_TAKEN`・`DATE_ADDED`) → ③ 取得不可(null)。**SAF には作成日時カラムが無く、`stat()` の ctime は作成時刻ではない**。判定を取得可否に置いたため、経路の追加は仕様を変えずに拡張できる | 開発者/Claude |

## タスク一覧

| ID | タスク | 規模 | 依存 | 状態 | issue |
|----|--------|------|------|------|-------|
| T1 | 振る舞い仕様の作成(Light)+ 001/002 仕様更新の洗い出し | M | - | done | #51 |
| T2 | `FileSource` ポート + 元場所ハンドル + 作業セット + fake + 002 結線 | M | T1 | done | #52 |
| T3 | UI 入口: フォルダを開く / ファイルを選ぶ(追加・除去、fake で結線・widget test) | M | T2, 002-file-list.T2 | done | #53 |
| T4 | 実 `FileSource`(Android SAF + Windows ピッカー)+ 実データ入口配線(ホスト検証) | L | T3 | done | #54 |
| T5 | 時系列ソート2種+警告の**仕様更新**(001 Strict / 002 / 004)→ 再承認依頼 | M | T2 | done | #63 |
| T6 | 時系列ソート2種+警告の**実装**(取得可否・ソート・警告表示) | M | T5 | done | #64 |

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

- 変更対象: lib/ui/ または lib/main.dart, test/spec_002_file_list/, test/spec_004_file_source/
- 受け入れ条件:
  - [ ] 「フォルダを開く」「ファイルを選ぶ」の導線から `FileSource` を呼び、結果が 002 の作業セットに**追加**される(複数回で別フォルダ分も蓄積)。選択の除去・全消去導線がある。空(キャンセル)時は無変化(fake を注入した widget test で検証)。
  - [ ] `Failed` のとき作業セットを変えずに**エラー(理由)をユーザーへ通知**する(004 REQ-008。`Cancelled` では通知しない)。
  - [ ] **各行に場所(元フォルダ)がサブ情報として表示される**(002 REQ-010。T6 で作った行サブ情報に並べる。同名・非同名に関わらず常時表示。色は `AppColors`)。REQ-010 は T2 でデータ供給まで実装済みで**表示が未実装**のため、ここで回収する。
  - [ ] 該当 REQ/VER を覆う widget test が通り、既存テストが緑のまま(退行なし)。`flutter analyze`/`dart format` PASS。色は `AppColors`。
- 参考: T1、T2、002 の `FileListView` と T6 の `_DateSubInfo`、`AppColors`

### T4: 実 `FileSource`(Android SAF / Windows)+ 実データ配線(ホスト検証)

- 変更対象: pubspec.yaml, lib/data/file_source/, lib/main.dart, lib/ui/file_source/file_source_bar.dart, android/・windows/ 設定(および `flutter pub get` が生成する各プラットフォームの plugin registrant), test/spec_004_file_source/, specs/004-file-source/decisions/, docs/development/emulator-verification.md
- 受け入れ条件:
  - [ ] Android(SAF フォルダ URI 権限 + `OPEN_DOCUMENT` 複数選択、必要な永続化権限)/ Windows(ピッカー)の `FileSource` 実装を追加(プラグイン選定は実装制約として ADR)。可能な範囲でモック/ユニット test を置く。
  - [ ] **返す全エントリに `sourceHandle` を必ず設定する**(実 URI/パス)。null は作業セットのハンドル重複排除の対象外になり、同一ファイルが多重に積まれるため(T2 の申し送り)。
  - [ ] アプリ入口で実 `FileSource` を注入し、実ファイルを 002 の作業セットに流す。`flutter analyze`/`dart format`/`flutter test` PASS。
  - [ ] 003 T6 の修正を受けて、読み込み入口のバーが作業セットを購読し直し、**空のときは「すべて外す」を無効表示**にする。あわせて T6 で不正確になったコメントを実態に合わせる(2026-08-04 開発者指示で T4 に含める)。
  - [ ] **実権限・実読み込み・複数フォルダ蓄積(別フォルダの選択を重ねて1リストになる)の実機/エミュレータ確認はホスト側**(手順は emulator-verification.md。T4 の実装に合わせて手順を更新する)。`.github/workflows` 変更が要る場合は人間に依頼。
- 参考: T1、T3、PRD §5、`docs/development/emulator-verification.md`

### T5: 時系列ソート2種+警告の仕様更新(001 Strict / 002 / 004)

- 変更対象: specs/001-rename-core/contracts/behavior-contract.json, specs/001-rename-core/spec.md, specs/002-file-list/spec.md, specs/004-file-source/spec.md
- 受け入れ条件:
  - [ ] `FileEntry.createdAt` が**「取得できなかった」を表現できる**形(nullable 等)に更新され、001 契約の用語と、**日時トークン `source: created` が取得不可のときの出力**(REQ-004)が規定されている。
  - [ ] 002: 時系列ソートは**作成日時・更新日時の2種**を提供する(旧「createdAt→modifiedAt 置換」の決定を上書き)。作成日時ソート選択時に**作成日時を取得できなかった件数**を警告として供給する REQ が定義され、取得不可の並び順(末尾等)も規定されている。
  - [ ] 004: `FileSource` が作成日時を**取得できた場合のみ**設定し、取得不可は「不明」として扱う(捏造しない)ことが REQ として明記されている(現 REQ-003 の更新)。取得経路は「決定事項」の優先順位付きチェーンに従い、**具体的な経路の実装範囲は自由とする点**に置く(経路追加で仕様が変わらないこと)。
  - [ ] `spec_lint.py --strict`(001)が PASS し、3仕様が draft でインデックス登録され、完了報告にレビュー依頼が含まれる(**approved 化は人間。T6 は再承認まで実行不可**)。
- 参考: create-verifiable-spec skill、004 spec の「波及」節、決定事項の「時系列ソートの構成」「警告の判定条件」「作成日時の取得経路」

### T6: 時系列ソート2種+警告の実装

- 変更対象: lib/core/file_entry.dart, lib/core/rename_engine.dart(日時トークンの取得不可時), lib/ui/file_list/file_sort.dart, lib/ui/file_list/file_list_controller.dart, lib/ui/file_list/file_list_view.dart, lib/data/file_source/, test/spec_001_rename_core/, test/spec_002_file_list/, test/spec_004_file_source/
- 受け入れ条件:
  - [ ] T5 の仕様が **approved**(未承認なら着手せずブロック報告)。
  - [ ] `FileEntry` の作成日時が**「不明」を表現できる**形になり(001 用語 FileEntry)、既存の呼び出し・テストが退行なく追随している。
  - [ ] 作成日時・更新日時の**両ソート**が動き、作成日時ソートでは**不明な item を当該 item の更新日時をキーに代替**して並ぶ(002 REQ-002)。
  - [ ] 作成日時ソート選択時に、**不明の件数と「更新日時で代替して並べている」旨の警告**が表示される(取得可否での判定。ファイル種別では判定しない。0 件なら出さない・作成日時以外では出さない。002 REQ-011)。
  - [ ] **各行が作成日時(不明ならその旨)と更新日時の双方 + 作成日時が不明かを供給**し、行 UI がそれを識別表示する(002 REQ-013。色は `AppColors` のセマンティック色で、直書きしない)。
  - [ ] **`validate` が基準日時不明を警告する**(001 REQ-014)。基準日時が取得不能な日時トークンは**空文字列**を出力し(001 REQ-004)、更新日時・now で代替しない(001 INV-006)。
  - [ ] 取得不可を捏造しない(データと命名で `modifiedAt` の暗黙代入をしない)ことがテストで示される。代替はソートキーと表示に閉じる。
  - [ ] 該当 REQ/VER を覆うテストが通り、既存の 001/002/003/004/007 テストが緑のまま(退行なし)。`flutter analyze`/`dart format` PASS。色は `AppColors`。
- 参考: T5、002 `file_sort.dart`/`FileListView`/`RowView`、001 の日時トークンと `validate`、`AppColors`

## 作業ログ

<!-- /run-plan が着手・完了を追記する。テンプレの書式に従う -->

- 2026-08-03 / 承認 / 計画を draft→approved。開発者承認(「改訂版は承認します」)。決定事項に「アプリの形(汎用1アプリ・写真機能は後続)」「複数フォルダ=作業セット方式」「同種前提にしない」「時刻ラベルの正直化(更新日時)」を記録。リネーム時刻ずらし案は 005 候補として discovery へ記録(004 対象外)。
- 2026-08-04 / T1 着手 / shimmen3141。Issue #51 を assign(claim)、ブランチ asdd/004-file-source/T1。計画全体を in_progress に。create-verifiable-spec で Light 仕様を作成する。
- 2026-08-04 / T1 完了 / spec.md(Light・draft)作成: REQ-001〜008 / VER-001〜003 / 「波及: 001・002 の再承認が要る更新点」/ 反証ログ5観点 / open_questions OQ-1〜4。verifier PASS(試行1回・6条件すべて充足)。**spec は draft。approved 化は人間。後続 T2 以降は spec approved まで実行不可。**
- 2026-08-04 / T1 / PR #56 作成(Closes #51)。マージ待ちで停止。
- 2026-08-04 / T1 / open_questions を開発者回答で解消(D-1〜D-4)。spec を更新: `PickResult`(Picked/Cancelled/Failed)+ Failed 通知(REQ-001/008)、場所のサブ情報表示(REQ-009)、隠しファイル非フィルタ(対象外)、追加順(REQ-007)。REQ-009 追加に伴い波及に「002 RowView 場所副題」「001 FileEntry 表示用の場所」を追記。PR #56 を更新。spec は引き続き draft(approved 化は人間)。
- 2026-08-04 / T1 / PR #56 マージ。**spec.md を approved に(開発者承認: 「承認します」)。** open_questions ゼロ・全 REQ 確定。次ゲートは T2 前の 001/002 仕様更新→再承認。
- 2026-08-04 / 波及 / ハンドル・場所の置き場を **core `FileEntry` の任意フィールド**に決定(開発者選択)。001(Strict): `sourceHandle`/`sourceLocation` + INV-005 を追加、`spec_lint --strict` PASS(errors=0, warnings=0)。002(Light): `addFiles`/`removeFile`/`clearFiles`(REQ-008/009)・時系列ソート `createdAt`→`modifiedAt`(REQ-002)・場所サブ情報(REQ-010)。PR #58 で **開発者再承認**(「#58は承認します」)→ 両仕様を approved に復帰し index 再生成。**T2 のゲート解除。**
- 2026-08-04 / T2 着手 / shimmen3141。Issue #52 を assign(claim)、ブランチ asdd/004-file-source/T2。
- 2026-08-04 / T2 完了 / `FileSource` ポート + `PickResult`(Picked/Cancelled/Failed)+ `FakeFileSource`(lib/data/file_source/file_source.dart)、結線 `applyPick`/`loadFolderInto`/`loadFilesInto`(file_loading.dart、data→ui 依存を避けるため受け口は `AddFiles` コールバック)、`FileEntry` に `sourceHandle`/`sourceLocation` を追加、002 に `addFiles`/`removeFile`/`clearFiles`。テスト28件(VER-001/002/003)。verifier PASS(試行1回・5条件充足)。レビューパスの指摘で **INV-005 の回帰検出を determinism_test.dart に追加**(P1: VER-005 が宣言していたが実体が無かった)。全 187 tests PASS / analyze 0 issue / format PASS。
- 2026-08-04 / T2 / スコープ外の申し送り(未実施・plan の判断待ち): (1) **002 REQ-002 の時系列ソート `createdAt`→`modifiedAt` が未実装**(`lib/ui/file_list/file_sort.dart` は `FileSortMode.createdAt` のまま)。T2 の変更対象外のため触らず。T3 に含めるか別タスク化するか要判断。(2) T4 の実 `FileSource` は全エントリに `sourceHandle` を必ず設定すること(null はハンドル重複排除の対象外のため)。
- 2026-08-04 / T2 / PR #61 作成(Closes #52)。マージ待ちで停止。
- 2026-08-04 / T2 / PR #61 マージ。
- 2026-08-04 / 計画変更 / **T5・T6 を追加**(開発者承認: 「新タスク T5」を選択。仕様更新と実装の間に人間の再承認ゲートが入るため、T1/T2 と同じ形で2タスクに分割)。決定事項に「時系列ソートの構成(作成日時を残し2種提供)」「警告の判定条件(種別ではなく取得可否)」「作成日時の取得経路(優先順位付きチェーン)」を追加し、2026-08-03 の「時刻ラベルの正直化」決定を置換。設計方針の該当箇所も更新。T2 の申し送り(1)はこの T5/T6 で回収する。
- 2026-08-04 / 計画変更 / T4 の受け入れ条件に「返す全エントリに `sourceHandle` を必ず設定する」を追加(T2 の申し送り(2)。承認済み 004 REQ-002 の詳細化であり矛盾のない追加)。
- 2026-08-04 / FINDINGS / asdd-suite への気づきを specs/FINDINGS.md に5件追記(波及のタスク化漏れ・宣言だけの検証 ID・規約と verifier の食い違い・read-only マウントの git 事故・gitconfig 非永続とホスト生成物)。
- 2026-08-04 / T5 着手 / shimmen3141。Issue #63 を assign(claim)、ブランチ asdd/004-file-source/T5。
- 2026-08-04 / T5 完了 / 3仕様を更新(いずれも draft = 再承認待ち)。**001(Strict)**: 用語 FileEntry に「作成日時は不明を取りうる・代替禁止」、用語「基準日時」追加、REQ-004 更新(基準日時が取得不能なら空文字列)、**REQ-014 追加**(validate が基準日時不明を警告)、**INV-006 追加**(不明を更新日時/now で代替しない)、OP-003・scope.in・VER-001/003 の被覆を更新。`spec_lint --strict` PASS(errors=0, warnings=0)。**002**: REQ-002 を作成日時・更新日時の2種に(不明は末尾・相対順保持)、**REQ-011**(作成日時ソート時に不明件数を警告・0件なら供給しない・種別ではなく取得可否で判定)、**REQ-012**(不明を含んでも失敗しない)、代表例5件と VER 被覆を追加。**004**: REQ-003 更新(取得できたときだけ設定・代替して埋めない)、**REQ-010 追加**(取得は優先順位付きチェーン、経路の実装範囲は自由)、代表例3件。verifier PASS(試行1回・条件1〜3/4-a/4-b 充足)。
- 2026-08-04 / T5 / 申し送り(plan は T5 の変更対象外のため未変更・人間の判断待ち): (1) **T6 の受け入れ条件に 001 REQ-014(validate の基準日時不明警告)が入っていない** — 再承認後に T6 へ追記しないと「承認したのに実装されない要件」(FINDINGS 参照)が再発する。(2) 設計方針の「002 連携」末尾「それ以外は更新日時」と `specs/discovery.md` の「004 は暫定『更新日時』まで」が旧方針の名残り。(3) 004 REQ-010 の経路優先順位は fake では検証できず、実経路の確認は T4 のホスト検証に委ねる。
- 2026-08-04 / T5 / PR #65 作成(Closes #63)。マージ+再承認待ちで停止。
- 2026-08-04 / T5 / 開発者フィードバックで 002 の仕様を改訂(PR #65 を更新): 作成日時が不明な item は**更新日時をソートキーに代替**(旧「末尾・相対順保持」を置換)、警告に代替した旨を明記(REQ-011)、**REQ-013 追加**(各行が両日時+不明フラグを供給。見た目は非規範)。代替は 002 の並べ替え・表示に閉じ、004 REQ-003(データ)と 001 INV-006(命名)は不変。代表例を 12→13 件に更新し反証ログも同期。決定事項に2行追加。
- 2026-08-04 / T5 / **開発者再承認**(「承認します」)。3仕様を approved に戻し(001 契約 status / 001・002・004 の spec.md Status と各更新セクションの見出し)、004 spec の波及節を最新の決定(更新日時で代替・REQ-013)に同期。index 再生成。
- 2026-08-04 / 計画変更 / **T6 の受け入れ条件に4項目を追記**(開発者指示「T6の受け入れ条件に追記してください」): 作成日時の「不明」表現への追随 / 作成日時ソートの代替キー(002 REQ-002) / 警告に代替した旨を含める(002 REQ-011) / 各行の両日時+不明フラグの供給と識別表示(002 REQ-013) / validate の基準日時不明警告(001 REQ-014)。あわせて参考欄に RowView・validate を追加。非規範の `specs/discovery.md` に残っていた旧方針(「004 は暫定『更新日時』まで」)も承認済み仕様に合わせて更新。
- 2026-08-04 / T6 着手 / shimmen3141。Issue #64 を assign(claim)、ブランチ asdd/004-file-source/T6。
- 2026-08-04 / T6 完了 / **core**: `FileEntry.createdAt` を `DateTime?`(不明を表現)、`DateTimeToken.baseDateOf` を追加し基準日時が取得不能なら空文字列(001 REQ-004 / INV-006)、`MissingSourceDateWarning` を追加し `validate` が選択ファイル×トークンごとに発行(001 REQ-014)。**002**: `FileSortMode.modifiedAt` 追加、`createdAtSortKey`(判明→その値 / 不明→当該 item の更新日時)で作成日時ソートを代替、`unknownCreatedAtCount` と `createdAtSortWarning`(0件・他ソートでは供給しない)、UI に「更新日時順」チップ・警告バナー・行の日時サブ情報(不明は `AppColors.danger` + 警告アイコン)。テスト +34(合計 221)。**221 tests PASS / analyze 0 issue / format PASS / spec_lint --strict PASS**。verifier PASS(試行1回・8条件充足)。検証ループ中の修正2件: 狭幅で行サブ情報が overflow → `Text.rich` 1行化、widget test の RichText 特定が別テキストを拾う → プレーンテキストで絞り込み。
- 2026-08-04 / T6 / 申し送り(いずれも T6 の変更対象外・人間の判断待ち): (1) **002 spec の VER 表の成果物パスが実体と食い違う** — REQ-011/012/013 の実テストは新規の `test/spec_002_file_list/created_at_sort_test.dart` / `created_at_sort_view_test.dart` にあるが、VER-001/002 は `controller_test.dart` / `file_list_view_test.dart` を指したまま(approved 済みのため更新には再承認が必要)。(2) `lib/main.dart` のデモデータは全件 `createdAt` を持つため、デモでは警告バナー・「作成日時: 不明」行が出ない(T3/T4 で実データが入る際に手動確認)。(3) **002 REQ-010(場所サブ情報)は未実装のまま**で VER-002 の宣言と食い違う — T3 で回収されるか計画側の確認が要る。
- 2026-08-04 / T6 / PR #67 作成(Closes #64)。マージ待ちで停止。
- 2026-08-04 / 計画変更 / **T3 の受け入れ条件に2項目を追記**(開発者指示「1についてはT3の受け入れ状態に含めてください」): (a) **002 REQ-010 の場所サブ情報表示**(T2 でデータ供給まで実装済み・表示が未実装だった分の回収。T6 の `_DateSubInfo` に並べる)、(b) 004 REQ-008 の `Failed` 時のエラー通知(spec にはあったが T3 の条件に明示されていなかったため詳細化)。変更対象に `test/spec_002_file_list/` を追加。
- 2026-08-04 / 仕様更新 / **002 の VER 表を実体に合わせ、ディレクトリ+種別の指定に変更**(開発者指示「2については早めにやりたい」)。単一ファイル固定だったため T6 で分割した `created_at_sort_test.dart` / `created_at_sort_view_test.dart` と食い違っていた(FINDINGS 記録済み)。**規範要件(REQ)の変更は無く、検証の成果物指定のみ**。002 spec を draft にし再承認を依頼する。
- 2026-08-04 / デモデータ / `lib/main.dart` のサンプルに **`createdAt` が不明な1件(`Screenshot_20260304.png`)を追加**(開発者指示「3についてはデモデータに1件不明を混ぜてください」)。作成日時順ソートで警告帯と「作成日時: 不明」行をエミュレータで目視確認できるようにするため。221 tests PASS のまま(退行なし)。
- 2026-08-04 / 仕様 / 002 spec を **approved に復帰**(開発者承認「002を承認します」)。VER 成果物指定のディレクトリ化のみで規範要件の変更なし。
- 2026-08-04 / T3 着手 / shimmen3141。Issue #53 を assign(claim)、ブランチ asdd/004-file-source/T3。
- 2026-08-04 / T3 完了 / `FileSourceBar`(lib/ui/file_source/)を追加: 「フォルダを開く」「ファイルを選ぶ」で `loadFolderInto`/`loadFilesInto` を呼び作業セットへ追加、「すべて外す」で全消去、`Failed` は SnackBar で理由通知(`Cancelled`・成功は通知なし)。`FileListView` の各行に **× で個別除去**(元場所ハンドルを持つ行のみ)と、サブ情報の先頭に**場所(元フォルダ)を常時表示**(002 REQ-010 の回収)。`lib/main.dart` にバーを配線(デモ用 `FakeFileSource`。**T4 で実 `FileSource` に差し替える**)。テスト +16(合計 237: ui_entry_test 12 / location_view_test 4)。**237 tests PASS / analyze 0 issue / format PASS**。verifier PASS(試行1回・4条件充足)。
- 2026-08-04 / T3 / 設計判断 / バーは `FileListController` を**購読しない**設計にした。購読すると、003 の `RuleBuilderWorkspace` が `initState` でビルド中に `setRule`(= `notifyListeners`)を呼ぶため「ビルド中の setState」エラーになる。**003 は T3 の変更対象外**のため触らず、表示が作業セットに依存しないバー側で依存を持たない形に。機能欠落なし(空での「すべて外す」は無変化・無通知)。**003 の潜在バグは未解消**(同コントローラを購読する兄弟ウィジェットを近傍に置くと再発)。FINDINGS に記録。
- 2026-08-04 / T3 / 申し送り(T3 の変更対象外・人間の判断待ち): (1) **004 VER-003 の成果物パスが実体と食い違う** — T3 の widget テストは `test/spec_004_file_source/ui_entry_test.dart` だが VER-003 は `wiring_test.dart` を指したまま。002 で実施した「ディレクトリ + 種別」指定への変更を 004 spec にも適用すると再発を防げる(approved 済みのため再承認が必要)。002 VER-002 の「現在:」列挙にも `location_view_test.dart` が未記載。(2) 003 の潜在バグ(上記)の回収。(3) 行の × は `sourceHandle` を持つ行にのみ出る — T4 で全エントリにハンドルを付ける前提(T2 申し送り)が守られることの確認が必要。
- 2026-08-04 / T3 / PR #71 作成(Closes #53)。マージ待ちで停止。
- 2026-08-04 / T3 / PR #71 マージ。
- 2026-08-04 / 仕様更新 / **004 spec の VER 表を「ディレクトリ + 種別」指定へ変更**(開発者指示「2についてもあなたの推奨通りに」)。T3 の `ui_entry_test.dart` と VER-003 のパスが食い違っていた分の解消で、002 spec と同じ形に揃えた。**規範要件(REQ)の変更は無し**。004 spec を draft にし再承認を依頼する。あわせて 002 spec の VER-002 の内訳(非規範)に `location_view_test.dart` を追記(内訳は非規範のため 002 の Status は approved のまま)。
- 2026-08-04 / 申し送りの回収 / 003 の潜在バグは **003 計画に T6 を追加**して回収(開発者指示)。
- 2026-08-04 / 仕様 / 004 spec を **approved に復帰**(開発者承認「承認します」)。VER 成果物指定のディレクトリ化のみで規範要件の変更なし。
- 2026-08-04 / 計画変更 / T4 の**変更対象と受け入れ条件を更新**(開発者確認済み: 「T4に含めるのが自然だとあなたが判断したら含めてください」)。読み込み入口バーの購読復活(空なら「すべて外す」を無効表示)+ T6 で不正確になったコメント修正を T4 に含め、変更対象に `lib/ui/file_source/file_source_bar.dart` / `specs/004-file-source/decisions/` / `docs/development/emulator-verification.md` /(`flutter pub get` が生成する plugin registrant)を追記。**実装前に書くべき手続きが遅れたため verifier に逸脱として指摘され、その場で文書化した**(FINDINGS 記録済み)。
- 2026-08-04 / T4 着手 / shimmen3141。Issue #54 を assign(claim)、ブランチ asdd/004-file-source/T4。
- 2026-08-04 / T4 完了 / **Android = `saf_util`**(`SafFileSource`: `pickDirectory` で永続化可能な書き込み権限を取得 → `list`、`pickFiles` で複数選択。ハンドル= SAF document URI)、**デスクトップ = `file_selector`**(`DesktopFileSource`: `getDirectoryPath`/`openFiles` + `dart:io` の `FileStat`。ハンドル=絶対パス)、`createPlatformFileSource()` で選択し未対応 PF は `UnsupportedFileSource` が `Failed` を返す。`lib/main.dart` を fake から実 `FileSource` へ差し替え。**作成日時は両実装とも常に不明**(代替しない)。ADR-001 にプラグイン選定(決め手は **rename の有無** — 最人気の `saf` は rename が無く 005 で行き詰まる)を記録。テスト +18(合計 257)。**257 tests PASS / analyze 0 issue / format PASS**。verifier PASS(2回目。1回目の指摘4件—スコープ文書化漏れ・ADR の minSdk 誤り(21→**24**)・コメントと実装の不一致・ホスト検証手順の誤認リスク—を修正し、追加テストはミューテーションで捕捉力を実証)。
- 2026-08-04 / T4 / 申し送り: (1) **Android の個別ファイル選択のみ `sourceLocation` が null**(親フォルダが分からないため)。デスクトップは親フォルダ名が入るのでプラットフォーム間で非対称。REQ-009 は should かつ「場所文字列の形は自由」のため違反ではないが、ホスト検証で不具合と誤認されないよう手順書にも明記した。(2) 起動直後のサンプル9件は `sourceHandle` を持たないため行の × が出ない(全消去のみ)。実データ入口が本番化したので、サンプルを残すかは製品判断。(3) **実権限・実読み込み・複数フォルダ蓄積の確認はホスト側**(手順は emulator-verification.md を T4 の実装に合わせて更新済み)。
- 2026-08-04 / T4 / PR #76 作成(Closes #54)。マージ+ホスト検証待ちで停止。
