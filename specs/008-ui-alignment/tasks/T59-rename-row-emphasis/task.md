# T59 リネーム画面の行で、名前と補足情報にメリハリを付ける

## 目的

リネーム画面の各行で、**読むべき名前(変更前・変更後)と、確かめるための補足情報(場所・日時・大きさ)が見た目で分かれる**ようにする。今は文字の大きさと色だけで分けており、間隔や囲みが無い。

## 出所

開発者の要望(2026-10-07、原文): 「リネーム画面で並んでいるファイルの情報について、リネーム前後の名前と補足情報では重要度が異なるが、ほぼ文字の色でしか区別されていない。補足情報を枠に入れるなど、情報にメリハリをつけたい。メリハリの付け方(逆にリネーム前後の名前を強調すべきか、「変更前: 」「変更後: 」のようなキャプションを入れるべきかなど)は考える余地がありそう。」

Agent が3案を示した。**開発者は案Aを選んだ**(「2 のメリハリは、推奨の案Aで進めてください。」)。

| 案 | 内容 | 扱い |
|---|---|---|
| **A** | 名前の2段と補足情報の間を空け、補足情報を薄い面(角丸の帯)に入れる。変更後の名前を少し大きくする | **採用**。ただし**帯は 2026-10-07 のエミュレータ確認 attempt 2 で消した**(「あまりわかりやすくなりませんでした」)。変更後の名前の大きさだけ残す |
| B | 「変更前:」「変更後:」の見出しを付ける | 不採用。見出しが横幅を 3〜4 文字分取り、狭幅・大きい文字倍率で名前の省略が増える。矢印で読み方は伝わっている |
| C | 補足情報を「作成日時:」の文字からアイコンへ変えて短くする | 不採用。赤で出す「作成日時: 不明」(`T50`)が文字で読めなくなる |

## 範囲

- `lib/ui/file_list/file_list_view.dart` の行(`_DateSubInfo` と名前の2段)。
- 補足情報(場所・作成日時・更新日時・大きさ)を、行の背景より一段明るい面の角丸の帯に入れる。名前の2段との間を空ける。
- 変更後の名前を少し大きくする(今の大きさから一段)。変更前の名前は今のまま小さく薄く(`T10` の要望)。
- **面・余白・大きさの値は端末で見て詰める。** 初回の build で開発者に見てもらい、調整を同じ task で行う。
- 守ること(変えない):
  - `作成日時: 不明` の赤の強調と警告アイコン(`T50`・002 REQ-013)、場所は複数の場所が混ざるときだけ(`T22`)、日時は `Wrap` で落ちて作成日時を削らない(`T07`)、大きさは日時の後ろ(`T48`)。
  - 行の右端の警告(`T50`)、つまみ・checkbox の枠(`T28`/`T32`)、長押しの範囲(preview と名前の範囲)。
  - 選ばれた行・掴んでいる行の面の色が、補足情報の帯と見分けられること。
- 参考design `docs/design/Bulk Renamer.html` からは**離れる**(参考designは補足情報を枠に入れていない)。理由は上の開発者の要望。

## 確かめること

- **行の高さと1画面の行数**: 変更の前後で行の高さを測って記録する(帯の余白で 4〜6dp ほど高くなる見込み)。開発者は「リネーム画面は悪くない大きさだと思うが、実際に何個程度並ぶか測ってから判断したい」と言っているので、**manual で1画面に並ぶ行の数を数えてもらう**。
- 狭幅(320 / 360 / 411dp)× 文字倍率(1.0 / 1.3 / 2.0)で overflow しない。
- 2ペイン(幅 840 以上)でも同じ見え方で崩れない。

## 受け入れ条件

- [x] ~~補足情報が名前の2段と分かれた帯に入り、~~変更後の名前が一段大きい。**帯は不採用**(attempt 2 で消した)。補足情報は帯の前と同じ見え方。
  - 証拠: widget test(名前の大きさ・補足情報を塗った面で包まない)。
- [x] 上の「守ること」が成り立つ(既存の test が変更なしで PASS。変えた値を主張する test だけ更新する)。 **例外1件**: `removal_selection_mode_test.dart` の刻む回数(260 → 600)。主張は変えていない(checkpoint 1)。
  - 証拠: widget test。
- [x] 狭幅 × 文字倍率と 2ペインで overflow しない。
  - 証拠: widget test。
- [x] 開発者が Android エミュレータで見て、メリハリと1画面の行数を確かめている。 帯は attempt 2 で不採用となり、行の高さは帯の前とほぼ同じ(変更後の名前 +1)に戻ったので、**行数の数値は受け取っていない**。attempt 3 は「問題ありませんでした」。
  - 証拠: [manual-verification.md](manual-verification.md)。
- [x] 独立review が PASS。

## machine検証範囲と引き受け先

- machine: 帯の有無と範囲、名前の大きさ、既存の行の保証、overflow。
- 端末(この task の manual): 実際の字体での見え方、メリハリの度合い、1画面の行数。

## 作業記録

- 2026-10-07 開発者の決定(案A)から登録した(`5c1449a`)。
- 2026-10-07 着手。`T57` と同じ branch・PR(`T57` の作業記録を参照)。

### checkpoint 1: 帯と名前の大きさ(`2a19665`、test の修正 `bc98865`)

- `_DateSubInfo` を `Container(key: rowSubInfoKey)` にし、**行幅いっぱい**(`width: double.infinity`)・上に間 4(`rowSubInfoGap`)・内側の余白 左右 4 / 上下 3・角丸 4・面の色 `rowSubInfoSurface` にした。
  - 面の色はテーマに足した `rowSubInfoSurface`(`0x0FFFFFFF` = 白を 6% 重ねる)。**不透明な色にしなかった**のは、選ばれた行(`selectedSurface`)・掴んでいる行(`surface`)の面の上でも一段明るく見せるため。
  - **左右の余白は最初 6 で、`row_file_size_test.dart` の「320dp × 文字倍率 2.0 で大きさが削られない」(`T48` の保証)が落ちた**ので 4 にした。test は緩めていない。M819 がこの対照。
- 変更後の名前を `rowNewNameFontSize = AppFontSize.title`(14。以前は 13)にした。「変更なし」と未選択の `—` も同じ大きさ(同じ位置の文字が行で揃うように)。変更前の名前は 11.5 のまま。
- 中身(場所は複数の場所のときだけ・日時の `Wrap`・`作成日時: 不明` の赤・大きさ)は変えていない。
- **行の高さ(測定)**: 一時 test(commit していない)で、2件の一覧の1行目と2行目の現在名の `top` の差を測った。test の字体 Ahem(1文字 = 1em)なので実際の字体より日時が多く折り返す:

```text
変更前(cb1fcb4): w=360.0 rowPitch=95.0 / w=411.0 rowPitch=95.0 / w=1200.0 rowPitch=65.0
変更後(2a19665): w=360.0 rowPitch=104.0 / w=411.0 rowPitch=104.0 / w=1200.0 rowPitch=74.0
```

  増えた 9 = 間 +2(以前の `top: 2` → 4)、帯の上下の余白 +6、変更後の名前 +1。**1画面の行数は manual で数える**(開発者の要望)。
- test: `row_emphasis_test.dart`(新規): 帯に入るのは補足情報だけ、帯の色・角丸・行幅いっぱい・**塗った面**と変更後の名前の間、変更後の名前と「変更なし」の大きさ、`作成日時: 不明` の赤が帯の中で保たれる、320/360/411/1200dp × 文字倍率 1.0/1.3/2.0 で溢れない。
- **既存 test の変更 1件**: `removal_selection_mode_test.dart` の「端の保持で実在する行だけを連続して選びながらスクロールする」で、刻む回数を 260 → 600 にした。**主張は変えていない。** 行が高くなって一覧が長くなり、260 回(約4.2秒)では末尾の行に届かなかった。一時的に刻むごとに見て、**269 回目に末尾の行(`h:11`)が選ばれる**ことを確かめた(止まっていたのではない)。届いた後も刻み続けるので、末尾で止まることも長く見る。
- mutation: M815〜M820 を足した。範囲付き(`flutter test test/spec_002_file_list test/spec_005_rename_exec test/widget_test.dart`、対象 `2a19665`、7件):

```text
M163 | KILLED   | lib/ui/file_list/file_list_view.dart
M815 | KILLED   | lib/ui/file_list/file_list_view.dart
M816 | SURVIVED | lib/ui/file_list/file_list_view.dart
M817 | KILLED   | lib/ui/file_list/file_list_view.dart
M818 | KILLED   | lib/ui/file_list/file_list_view.dart
M819 | KILLED   | lib/ui/file_list/file_list_view.dart
M820 | KILLED   | lib/ui/file_list/file_list_view.dart
7 mutations: 6 KILLED, 1 SURVIVED, 0 SKIPPED
```

  **M816(帯と名前の間を空けない)が SURVIVED。** test が間を「`Container` の矩形の上端 + 4」で計算しており、`margin` を消しても同じ値になっていた。塗った面(`DecoratedBox`)の上端を測る形に直し(`bc98865`)、M816 だけ回し直した:

```text
M816 | KILLED | lib/ui/file_list/file_list_view.dart
1 mutations: 1 KILLED, 0 SURVIVED, 0 SKIPPED
```

- `flutter test`(全件)@`2a19665`: `01:19 +1421: All tests passed!`。`bc98865` は test 1件の修正だけで、その file は PASS。

- 独立review attempt 1: **PASS**(`73006f1..649d8e1`、gpt-6-luna)。記録は `T57` の task.md。

### checkpoint 2: エミュレータ確認 attempt 1 の直し(`45883d9`)

- 帯の面を、白を 6% 重ねた色から**紫がかった灰色 `#221F2B`(不透明)**にした。開発者の要望「グレーか紫がかったグレー」「文字が白よりのグレーなので同化しないように注意」。header・footer の `bar`(`#2E2B38`)と同じ系統で、補足の文字(`textMuted` `#5B636C`)と離すため**ずっと暗く**置いた(明るさの比は約 2.6:1。背景 `#0A0B0D` の上では約 3.1:1)。不透明にしたが、選ばれた行(`#1A333B`、シアン系)・掴んでいる行(`#15181D`)とも色が違うので帯は見分けられる。
- test: `row_emphasis_test.dart` で色の値を固定した。M815(帯を塗らない)は KILLED のまま(`T58` の記録の出力)。
- `flutter test`(全件)@`45883d9`: `01:17 +1422: All tests passed!`
- 差分review attempt 2: **PASS**(`649d8e1..cddcd30`、Sonnet。luna が利用上限のため)。P3 ×1 と M823 の取り込みは SELF-CHECK 済み。記録は `T57` の task.md。

### checkpoint 3: 帯を消す(`2960b35`、test の修正 `e293662`)

- エミュレータ確認 attempt 2 の開発者の判断「補足情報を枠に収めてみるアプローチでは、あまりわかりやすくなりませんでした。枠は消し、別のアプローチを考えます」により、`_DateSubInfo` を帯の前の形(`Padding(top: 2)`)に戻し、`rowSubInfoKey`・`rowSubInfoGap`・テーマの `rowSubInfoSurface` を消した。**変更後の名前の大きさ 14 は残した**(指摘の対象外で、開発者が挙げた「変更前後の名前の方を強調する」方向と合う)。
- **別の見せ方は、開発者が挙げた案(補足情報をソートやルールのチップに合わせて減らす、名前を強調する)を相談してから別 task にする。** この task では扱わない。
- mutation: 帯を守っていた M815・M816・M818・M819・M823 は**守る対象が無くなったので外した**。帯が戻ることを捕まえる M825 を足した。`removal_selection_mode_test.dart` の刻む回数 600 は、行の高さに左右されない余裕として残した(コメントを直した)。
- test: `row_emphasis_test.dart` の帯の test を「補足情報を塗った面で包まない」に置き換えた。最初は `DecoratedBox` だけを見ていて **M825(`Container(color:)` = `ColoredBox`)が SURVIVED** したので、`ColoredBox` も見るように直した(`e293662`)。範囲付き(`flutter test test/spec_004_file_source test/spec_002_file_list test/widget_test.dart`、対象 `2960b35`):

```text
M163 | KILLED   | lib/ui/file_list/file_list_view.dart
M817 | KILLED   | lib/ui/file_list/file_list_view.dart
M820 | KILLED   | lib/ui/file_list/file_list_view.dart
M824 | KILLED   | lib/ui/file_source/storage_browser_view.dart
M825 | SURVIVED | lib/ui/file_list/file_list_view.dart
5 mutations: 4 KILLED, 1 SURVIVED, 0 SKIPPED
```

  `e293662` の後に M825 を回し直した:

```text
M825 | KILLED | lib/ui/file_list/file_list_view.dart
1 mutations: 1 KILLED, 0 SURVIVED, 0 SKIPPED
```

- `flutter test`(全件)@`2960b35`: `01:18 +1421: All tests passed!`。`e293662` は test 1件の修正で、その file は PASS。

- エミュレータ確認 attempt 3(`2960b35`): **PASS**(開発者「問題ありませんでした。」)。記録は `T57` の task.md。

## Current state / handoff

- Last checkpoint: エミュレータ確認 attempt 3 PASS(`2960b35`)。PR #232
- Blocker category: なし
- Evidence revision: `2960b35`
- Next Agent action: なし(done)。補足情報の別の見せ方(案A)は新しい task で扱う
