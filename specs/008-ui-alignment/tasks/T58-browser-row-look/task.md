# T58 app内browserの行を大きくし、2行目に更新日時と大きさを出して新しい順に並べる

## 目的

Android の app 内 browser で、**ファイルの中身と新しさが一目で分かる**行にする。

- preview を大きくし、1画面に並ぶ行を一般的なファイルアプリと同じくらい(約10行)にする。
- folder と、preview を出せないファイルを、preview と同じ大きさの四角で示す。
- 名前を少し大きくし、2行目に更新日時(ファイルなら大きさも)を出す。
- 更新日時の新しい順に並べる。

## 出所

開発者の要望(2026-10-07、原文の要約。全文は会話):

- 「ファイル選択画面の両方でプレビューの画像のサイズが小さいと思った。既存のファイルアプリを見てみたところ、画像が縦に10~11個程度並ぶぐらい(画像間の間隔も含めて)のサイズだった。」
- 「ファイルアプリでは画像と同じサイズの暗めのグレーの四角の上に現在のフォルダのアイコン(色は現状のものと同じぐらいなのでそこは変更しなくてよい)がのっているデザインでした。」「ドキュメントファイル等も同様にデザイン変更したいが、フォルダと区別するためにグレーの四角で画像の大きさ分を囲むだけでよいかも」
- 「ファイル・フォルダ名をやや大きくするとともに、2行目に薄いグレーで更新日時を書きたいです(ファイルならファイルサイズも)。また、更新日時の新しい順に自動的に並び替えるようにしてもよさそうです。」

Agent の推奨(preview 56dp・行 72dp、folder を先にしてそれぞれ新しい順)に、開発者は異を唱えずに進めると決めた(同日)。

**写真・動画の選択画面の格子(1マス最大 120dp、幅 412dp で横4列)は対象外**とする。Agent が「横3列にするか、4列のままか」を尋ねたが答えが無かったので、今のままにする。必要になれば別 task にする。

## 範囲

- **行の寸法**: ファイル行・folder 行とも preview 枠 56dp、行の高さ 72dp を目安にする。今はファイル行が preview 40dp・約 48dp(dense)、folder 行が約 56dp。
- **folder**: preview と同じ大きさの**暗い灰色で塗った四角**に、今の色(`textSecondary`)の folder アイコンを載せる。右端の `>` は残す。
- **preview を出せないファイル**(文書・書庫・読めなかったもの・まだ届かないもの): **灰色の線で囲んだ四角**(塗らない)に種別アイコン。folder と見分けられること。
  - この見た目は `RowPreviewView` が持つので、**リネーム画面の行の同じ場合も同じ見た目になる**(部品を分けない。揃うことを受け入れた)。
- **名前**: 今の `bodyLarge`(13)から一段大きくする(`title` 14 か `titleLarge` 15。端末で決める)。1行で省略。
- **2行目**: 薄い灰色(`textMuted`)で更新日時。ファイルなら大きさも(リネーム画面の行と同じ書式。`formatFileSize`)。folder は更新日時だけ。
- **並び順**: folder を先に置き、folder とファイルのそれぞれを**更新日時の新しい順**にする。同じ日時なら名前順。
- **データ**: `BrowserEntry` に更新日時と大きさを持たせ、`AndroidStorageBrowser.list` が各 entry を `stat` する。**読めない entry**(壊れた link、読む前に消えたものなど)は日時と大きさを空にし、**並びから外さず**それぞれの群の最後(名前順)に置き、2行目は出さない。004 REQ-017(絞り込まない)を守る。
- 触れない: header・現在地の帯・footer(`T38`/`T39`/`015`)、選択と範囲選択の意味(004 REQ-016・REQ-020。並びが変わっても**表示順**で動く)、保存場所の一覧の行、写真・動画の選択画面。

## 仕様との関係

004 は browser の並び順と行の見た目を決めていない(REQ-015〜020 は辿り方・選択・注記・権限)。**要求は変えない。** 「folder が先、名前順」は実装のコメント(`android_storage_browser.dart`)にだけあり、そこを書き換える。

## 確かめること

- **一覧を開くまでの時間**: `stat` が entry ごとに増える。件数の多い folder(数百〜数千件)で開くまでの時間を、変更の前後で端末で比べて記録する。目立って遅くなるなら開発者へ報告する(全件読まないと並べられないので、読みながら出すことはできない)。
- 狭幅(320 / 360 / 411dp)× 文字倍率(1.0 / 1.3 / 2.0)で overflow しない。名前と2行目は省略する。
- 範囲選択(長押しdrag・自動scroll)の既存 test が、行の高さが変わっても PASS する。

## 受け入れ条件

- [ ] ファイル行と folder 行の preview 枠が同じ大きさ(56dp)で、行の高さが揃う。
  - 証拠: widget test(枠と行の寸法)。
- [ ] folder は塗った四角、preview を出せないファイルは線で囲んだ四角で、見分けられる。preview がある画像は今と同じく絵が出る。
  - 証拠: widget test(装飾の違い)、manual。
- [ ] 2行目に更新日時(ファイルは大きさも)が出る。読めなかった entry は2行目が無く、行は残る。
  - 証拠: widget test、`AndroidStorageBrowser` の test(一時 folder に日時の違うファイルを作る)。
- [ ] folder が先、それぞれ更新日時の新しい順、同時刻は名前順、読めない entry は群の最後。
  - 証拠: `AndroidStorageBrowser` の test。
- [ ] 狭幅 × 文字倍率で overflow しない。範囲選択・全選択・一括解除の既存 test が PASS。
  - 証拠: widget test。
- [ ] Android エミュレータで、1画面に並ぶ行の数・見た目・件数の多い folder を開く時間を確かめる。
  - 証拠: [manual-verification.md](manual-verification.md)。
- [ ] 独立review が PASS。

## machine検証範囲と引き受け先

- machine: 寸法、装飾、2行目の内容、並び順、読めない entry の扱い、overflow、既存の選択 test。
- 端末(この task の manual): 実際の字体での見え方、1画面の行数、開くまでの時間。

## 作業記録

- 2026-10-07 開発者の要望から登録した(`5c1449a`)。
- 2026-10-07 着手。`T57` と同じ branch・PR(`T57` の作業記録を参照)。

### checkpoint 1: 行の見た目・2行目・並び(`cb1fcb4`)

- **データ**: `BrowserEntry` に `modifiedAt`・`size`(どちらも省略可)を足した。`AndroidStorageBrowser.list` は列挙を `toList` してから **`Future.wait` でまとめて `stat`** する(1件ずつ待つと件数ぶん遅くなる)。`stat` が投げた・`notFound`(壊れた link、列挙の後に消えたもの)なら日時と大きさを `null` にし、**行は残す**(REQ-017)。folder の大きさは常に `null`。
- **並び**: `compareBrowserEntries` — folder が先、それぞれ更新日時の新しい順、同時刻は名前順(大小を区別しない)、日時を読めない entry は群の最後に名前順。
- **行**: folder 行・ファイル行とも `ListTile(minTileHeight: 72)`。ファイル行の `dense` を外した。preview 枠 56(`browserPreviewSize`)。名前は folder・ファイルとも `AppFontSize.titleLarge`(15)で1行省略 — **以前は ListTile の既定のままで、folder 16・ファイル 13(dense)と揃っていなかった**。2行目は `textMuted`・`bodySmall`(12)で `2026/10/1 09:05 · 2.4 MB`(folder は日時だけ)。日時の書式はリネーム画面の行と共通の `formatRowDateTime`(`row_date_format.dart`)へ出した。
- **四角**: テーマに `previewTile`(`#2A2F36`)を足した。folder はこの色で塗った四角 + 今の色(`textSecondary`)の folder アイコン。`RowPreviewView` の preview を出せないときの枠を、同じ色の**線**の四角にした(リネーム画面の行も同じ見た目になる)。
- `_previewEntryOf` は読めた日時と大きさを渡すようにした。`CachedFilePreview` のキーに更新日時が入るので、ファイルが変わったときに古い絵を出さず、リネーム画面の行とも同じキーになる。
- **写真・動画の選択画面の格子は変えていない**(登録時の決定)。
- test:
  - `android_storage_browser_test.dart`: 新しい順・folder が先、同時刻は名前順、ファイルは日時と大きさ・folder は日時だけ、壊れた link は外さず最後、`compareBrowserEntries` の群の境界。**既存の「folderが先、その中で名前順」は「集合は変えない」へ書き換え**(並びの主張は新しい test へ移した)、**「rootの列挙は既知の名前のfolderを1回だけ返す」は順序を問わない比較にした**(この test が見るのは二重に並ばないことで、並びではない)。
  - `browser_row_look_test.dart`(新規): 行 72・枠 56、塗りと線の違い・絵があれば線が無い、2行目の内容と色、名前の大きさ、画面で並べ替えない、320/360/411dp × 文字倍率 1.0/1.3/2.0 で溢れない。
  - 既存の browser の test(範囲選択・自動スクロール・全選択・一括解除を含む)は変更なしで PASS。
- mutation: 足した M805〜M814。`find` を追随させた M115(隠しファイルを絞り込む対照)・M163(作成日時の下限)・M431(preview の枠を外す)・M434(読めないファイルを出せないファイルと同じアイコンにする対照)。範囲付き(`flutter test test/spec_004_file_source test/spec_002_file_list test/widget_test.dart`、対象 `cb1fcb4`、14件):

```text
M115 | KILLED | lib/data/file_source/android_storage_browser.dart
M163 | KILLED | lib/ui/file_list/file_list_view.dart
M431 | KILLED | lib/ui/file_source/storage_browser_view.dart
M434 | KILLED | lib/ui/file_list/row_preview_view.dart
M805 | KILLED | lib/data/file_source/android_storage_browser.dart
M806 | KILLED | lib/data/file_source/android_storage_browser.dart
M807 | KILLED | lib/data/file_source/android_storage_browser.dart
M808 | KILLED | lib/data/file_source/android_storage_browser.dart
M809 | KILLED | lib/data/file_source/android_storage_browser.dart
M810 | KILLED | lib/ui/file_source/storage_browser_view.dart
M811 | KILLED | lib/ui/file_source/storage_browser_view.dart
M812 | KILLED | lib/ui/file_list/row_preview_view.dart
M813 | KILLED | lib/ui/file_source/storage_browser_view.dart
M814 | KILLED | lib/ui/file_source/storage_browser_view.dart
14 mutations: 14 KILLED, 0 SURVIVED, 0 SKIPPED
```

- **開くまでの時間は未計測**(端末が要る)。manual 手順 3 で比べる。

- 独立review attempt 1: **PASS**(`73006f1..649d8e1`、gpt-6-luna)。記録は `T57` の task.md。

### checkpoint 2: エミュレータ確認 attempt 1 の直し(`45883d9`)

- 保存場所の一覧(「すべて」で保存場所が2つ以上あるときの最初の画面)の行も、folder・ファイルの行と同じにした: 行 72、56 の四角(**シアン `primary` の線だけ、塗らない**)に今の `sd_storage` アイコン(シアン)、名前 15 で1行省略。開発者の要望(`T57` の記録)。
- test: `browser_row_look_test.dart` に保存場所の一覧の行を足した。mutation M821(四角を塗る)・M822(行の高さを戻す)。範囲付き(`flutter test test/spec_004_file_source test/spec_002_file_list test/widget_test.dart`、対象 `45883d9`):

```text
M815 | KILLED | lib/ui/file_list/file_list_view.dart
M821 | KILLED | lib/ui/file_source/storage_browser_view.dart
M822 | KILLED | lib/ui/file_source/storage_browser_view.dart
3 mutations: 3 KILLED, 0 SURVIVED, 0 SKIPPED
```

- `flutter test`(全件)@`45883d9`: `01:17 +1422: All tests passed!`

## Current state / handoff

- Last checkpoint: エミュレータ確認 attempt 1 の直し(`45883d9`)。独立review attempt 1 PASS(`73006f1..649d8e1`)、Draft PR #232
- Blocker category: manual-evidence
- Evidence revision: `45883d9`(code の最後の commit)
- Waiting for: 開発者(Android エミュレータの再確認 attempt 2。差分review `649d8e1..` の後)
- Requested action: [`T57` の manual-verification.md](../T57-file-select-label/manual-verification.md) の手順を行い、結果を会話で伝える
- Next Agent action: 結果を task.md へ記録する。PASS なら PR #232 を ready にし、CI と merge 条件を確かめて merge する。値の調整を頼まれたら直し、差分review(`649d8e1..`)の後に再確認を頼む
