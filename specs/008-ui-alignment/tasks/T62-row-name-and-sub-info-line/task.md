# T62 リネーム画面の行で、変更前の名前と矢印を白に近い色にし、補足情報の左に縦線を引く

## 目的

リネーム画面の各行で、**名前の2段(変更前・変更後)と補足情報(場所・日時・大きさ)を見た目で分ける**。今は変更前の名前(灰 `textSecondary`・11.5)と補足情報(濃い灰 `textMuted`・10.5)がどちらも灰色の小さい字で、区別がつきにくい。

## 出所

- 開発者の相談(2026-10-08、原文): 「変更前のファイル名を赤色にすると分かりやすいかと思った(補足情報とのメリハリもつけられる)のですが、リネームに問題がある際に変更前後のどちらも赤色になって分かりにくいでしょうか。」
- Agent の回答: このアプリで赤は「問題がある」だけに使っているので(警告がある行の変更後の名前、警告のマーク、`作成: 不明`)、変更前の名前を赤にすると、問題のない行まで警告に見え、「赤 → 緑」が「誤り → 正しい」と読め、警告がある行では前後とも赤になる。色相ではなく明るさで差を付ける案1(変更前の名前を本文の色にする)を推奨した。
- 開発者の決定(2026-10-08、原文): 「変更前と矢印を白に近い色にしてください。また、補足情報について、補足情報の左辺に太めの縦線を引く(notionの引用のような感じ)ことで、補足情報を強調せずにまとまりにできると思いました。」

## 範囲

- `lib/ui/file_list/file_list_view.dart` の行。
  - 変更前の名前と `→` を本文の色 `textPrimary`(`#EEF1F4`)にする。**大きさ(11.5)と太さ(通常)は変えない** — 変更後の名前(14・太字・緑/赤)より弱い段のまま。
  - 補足情報(`_DateSubInfo`)の左に縦線を引く。面は塗らない(`T59` の帯は不採用)。線は目立たない色にする。
- **`T10` の決定の一部を置き換える**: `T10`(2026-10-01 の要望「変更前の名前の文字の色を薄く」)で現在名を本文の白より暗くしていた。今回の開発者の指示で本文の色へ戻す。大きさの差(`T10`)は残す。
- 守ること(変えない):
  - 変更後の名前の色(正常は緑、警告は赤)、大きさ 14、太字(`T59`・2026-09-02 の要望7)。
  - 補足情報の中身(使っている日時だけ・見出し・`作成: 不明` の赤の強調。`T61`・`T50`)、場所は複数の場所のときだけ(`T22`)、日時の `Wrap` と下限(`T07`)、大きさは日時の後ろで削られない(`T48`)。
  - 補足情報を塗った面で包まない(`T59` の帯は不採用)。
  - 行の右端の警告(`T50`)、選ばれた行・掴んでいる行の面。
- 参考design `docs/design/Bulk Renamer.html` からは**離れる**(現在名は薄く、補足情報に線は無い)。理由は上の開発者の指示。
- **ファイルの大きさの書き方を有効数字3桁にする**(2026-10-08 の追加。下の attempt 1 の節)。`lib/ui/file_list/file_size_format.dart` の `formatFileSize` は app 内 browser の行の2行目(`T58`)でも使うので、**browser の大きさも同じ書き方になる**。`T48` の書き方(参考design の `fmtSize` に合わせた KB 整数・MB/GB 小数1桁)を置き換える。
- **線の太さ・色・線と文字の間は端末で見て詰める。** 初回は太さ 3dp・補足の文字と同じ灰・間 6dp で置き、エミュレータ確認で調整する。

## 受け入れ条件

- [ ] 補足情報が縦線ごと、名前の左端からわずかに字下げされる(attempt 1 の要望)。
  - 証拠: widget test。
- [ ] 大きさが有効数字3桁・1024 刻み・1000 に届いたら次の単位で書かれ、最長7文字。
  - 証拠: `row_file_size_test.dart` の単体 test。

- [ ] 変更前の名前と矢印が本文の色で、変更前の名前は変更後の名前より小さく太字でない。
  - 証拠: widget test(`row_name_hierarchy_test.dart` の色の主張を今回の決定へ更新)。
- [ ] 補足情報の左に縦線があり、補足情報の高さ全体にかかる。名前の2段にはかからない。面は塗らない。
  - 証拠: widget test。
- [ ] 上の「守ること」が成り立つ(既存の test が変更なしで PASS。変えた値を主張する test だけ更新する)。
  - 証拠: widget test。
- [ ] 狭幅(320 / 360 / 411dp)× 文字倍率(1.0 / 1.3 / 2.0)と 2ペインで溢れない。大きさが削られない(`T48`)。
  - 証拠: widget test。
- [ ] 開発者が Android エミュレータで見え方を確かめている。
  - 証拠: [manual-verification.md](manual-verification.md)。
- [ ] 独立review が PASS。

## machine検証範囲と引き受け先

- machine: 色・線の有無と範囲・既存の行の保証・overflow。
- 端末(この task の manual): 実際の字体での見え方、メリハリの度合い、線の太さと色。

## 作業記録

- 2026-10-08 登録・着手。branch `asdd/008-ui-alignment/T62-row-name-and-sub-info-line`(起点 `dev`@`406f8e3`)。

### checkpoint 1: 実装(`ef4dacb`。登録は `9ed134f`)

- `rowCurrentNameColorOf` を `textPrimary` にし、`→` も同じ関数の色にした(`rowNameArrowKey` を足した)。大きさ 11.5・太さ通常はそのまま。
- `_DateSubInfo` の `Column` を `Container(key: rowSubInfoLineKey)` で包み、`BoxDecoration` の `border` で**左だけ**に線を引いた(太さ `rowSubInfoLineWidth = 3`、色 `rowSubInfoLineColorOf` = `textMuted`(補足の文字と同じ灰)、線と文字の間 `rowSubInfoLineGap = 6`)。面の色は付けない。
- 横幅が 9dp 減るが、`row_file_size_test.dart` の 320dp × 文字倍率 2.0 で大きさが削られない(`T48`)は**変更なしで PASS**。
- test:
  - `row_name_hierarchy_test.dart`: 色の主張を `T10`(本文の白より暗く、`textMuted` より明るく)から今回の決定(本文の色。赤ではない)へ**更新した**。大きさ・太さの主張はそのまま。`→` の色の test を足した。
  - `row_sub_info_line_test.dart`(新規): 線が左だけ・太さ・色・面を塗らない。場所・作成日時・大きさが線の箱の中で、線の高さの内側、線の右から始まる。現在名・変更後名・`→` は線の外で、線より上。
  - 補足情報を塗った面で包まないこと(`row_emphasis_test.dart`)・溢れないこと・強調の条件の既存 test は変更なしで PASS。
- mutation: 字下げが深くなった M163・M164・M281・M616・M620 の `find` を追随させ、M825(帯が戻る)を縦線の装飾へ面の色を足す形へ追随させた。M609・M610 は `T10` の向きから今回の向きへ置き換えた(灰へ戻す・赤にする)。M833〜M837 を足した。範囲付き(`flutter test test/spec_002_file_list test/spec_005_rename_exec test/widget_test.dart`、対象 `ef4dacb`、13件):

```text
M163 | KILLED | M164 | KILLED | M281 | KILLED | M609 | KILLED | M610 | KILLED
M616 | KILLED | M620 | KILLED | M825 | KILLED | M833 | KILLED | M834 | KILLED
M835 | KILLED | M836 | KILLED | M837 | KILLED
13 mutations: 13 KILLED, 0 SURVIVED, 0 SKIPPED
```

- `flutter test`(全件)@`ef4dacb` 相当の作業木: `01:18 +1433: All tests passed!`。`flutter analyze` No issues、`dart format` PASS、`check_mutation_finds.py` PASS(757)。

### 独立review attempt 1

- range `406f8e3..af2eb6d`(全範囲)。reviewer: Codex **gpt-6-luna**(開発者の指定。実装は Claude Opus 5.5)。
- 判定: **PASS**。指摘なし(成果物の欠陥・安全網の穴とも)。開発者の決定どおりで、変更後の名前・警告・補足情報の中身と条件・日時の `Wrap`・大きさ・選択行の面を変えていないこと、`row_name_hierarchy_test.dart` の書き換えが決定による色の主張の置き換えに限られること、新しい test と mutation の追随・置き換え・追加が妥当であることを確かめた。reviewer の実行結果: `flutter test` `01:25 +1433: All tests passed!`、`flutter analyze` No issues、`dart format` PASS、`workspace.py check` PASS。範囲付き mutation 13件(M163・M164・M281・M609・M610・M616・M620・M825・M833〜M837): `13 mutations: 13 KILLED, 0 SURVIVED, 0 SKIPPED`。

### エミュレータ確認 attempt 1(2026-10-08、対象 `ef4dacb`)

- 開発者: 「悪くないですが、補足情報を縦線も含めてわずかにインデントしてほしいです。」
- 字下げ 4dp を入れると、`row_file_size_test.dart` の「320dp × 文字倍率 2.0 で大きさが削られない」(`T48` の保証)が落ちた。この条件(Ahem)で使える幅は 1dp だけだった(字下げ 1 は PASS、2・3・4 は FAIL)。test は緩めず、開発者へ選択肢(狭いときだけ字下げをやめる / 線と文字の間を詰める / 保証を緩める)を示した。
- 開発者の問い「1023.0 MB のような記述は 1 GB や 1.02 GB にはならないのですか」に、今の書き方(1024 に届くまで同じ単位、小数1桁)を説明し、**有効数字3桁・1000 に届いたら次の単位**(最長7文字)を推奨した。開発者の決定(原文): 「有効数字を 3 桁にし、インデントしてください。」

### checkpoint 2: 字下げと大きさの書き方(`afc1137`)

- `_DateSubInfo` の外側の `Padding` に `left: rowSubInfoIndent`(4)を足した。線と文字の間 6・線の太さ 3 は変えていない。
- `formatFileSize`: 1000 未満は `B`(丸めない)。それ以上は 1024 刻みで、有効数字3桁(1未満・10未満は小数2桁、100未満は1桁、それ以上は整数)。**丸めた値が 1000 に届いたら次の単位**(`999.6 KB` → `0.98 MB`、`1023 KB` → `1.00 MB`、`1023 MB` → `1.00 GB`)。丸めで桁が上がったら小数を減らす(`9.995 KB` → `10.0 KB`)。GB より上は持たない(`1500 GB`)。
- 大きさが2文字短くなったので(`1023.0 MB` 9文字 → 最長7文字)、**字下げ 4・間 6 のままで `T48` の test が変更なしで PASS**(320/360/411dp × 1.0/1.3/2.0)。その test の「いちばん長い書き方」は `0.98 GB`(1000 MB)へ変えた(以前の最長 `1023.0 MB` は `1.00 GB` になり、最長ではなくなった)。
- test:
  - `row_file_size_test.dart`: 書き方の単体 test を新しい規則へ書き直した(境界・繰り上げ・桁の調整・GB より上・**1500 GB までの最長が7文字以下**)。行の test の期待値 `2.4 MB` → `2.40 MB`。
  - `browser_row_look_test.dart`: 2行目の期待値 `2.4 MB` → `2.40 MB`、`2 KB` → `2.00 KB`(書き方の変更だけ)。
  - `row_sub_info_line_test.dart`: 線の箱の左端が `→` の左端 + `rowSubInfoIndent` であることを足した。
- mutation: 以前の書き方を守っていた M617〜M619 は守る対象が無くなったので、新しい書き方の対照へ置き換えた(B を 1023 まで残す / 丸めで 1000 に届いたものを上げない / 桁が上がったときに小数を減らさない)。M838(以前の小数1桁へ戻す)・M839(字下げしない)を足した。範囲付き(`flutter test test/spec_002_file_list test/spec_004_file_source test/spec_005_rename_exec test/widget_test.dart`、対象 `afc1137`、10件):

```text
M616 | KILLED | M617 | KILLED | M618 | KILLED | M619 | KILLED | M620 | KILLED
M825 | KILLED | M834 | KILLED | M836 | KILLED | M838 | KILLED | M839 | KILLED
10 mutations: 10 KILLED, 0 SURVIVED, 0 SKIPPED
```

- `flutter test`(全件)@`afc1137`: `00:54 +1435: All tests passed!`。`flutter analyze` No issues、`dart format` PASS、`check_mutation_finds.py` PASS(759)。

## Current state / handoff

- Last checkpoint: `afc1137`。Draft PR #234
- Blocker category: なし
- Evidence revision: `afc1137`
- Next Agent action: 差分review attempt 2(`e721139..head`。`lib/`・`test/`・`tool/` に差分があるので full regression)、その後エミュレータ確認 attempt 2
