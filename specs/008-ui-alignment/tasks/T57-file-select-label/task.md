# T57 リネーム画面の読み込みbuttonの文言を「ファイル選択」にする

## 目的

リネーム画面の帯にある読み込みbuttonの文言を、**読み込む前も後も「ファイル選択」**にする。今は読み込む前が「ファイルを選ぶ」、読み込んだ後が「別フォルダへ」である。

## 出所

開発者の要望(2026-10-07、原文): 「「別フォルダへ」ボタンの文言は「ファイル選択」に変更する。」

Agent が「読み込む前の「ファイルを選ぶ」も「ファイル選択」に揃える」を推奨し、開発者は異を唱えずに進めると決めた(同日、案Aの回答と同じ返答)。「別フォルダへ」は「選び直す」を表すための言い分けだったが、「ファイル選択」はどちらの状態でも意味が通る。

## 範囲

- `lib/ui/file_source/file_source_bar.dart` の文言(`controller.items.isEmpty ? 'ファイルを選ぶ' : '別フォルダへ'`)と、それを主張する test。
- 004 `spec.md` の代表例 43・66 にある「別フォルダへ」を「ファイル選択」へ言い換える。**要求(must)は変えない**ので再承認は求めず、Status 行へ記録を足す(2026-08-22 以来の扱い)。日付の付いた「由来の更新」節と 002 の更新記録は当時の記録なので書き換えない。
- 触れない: buttonの位置・形・押したときの動き(種類選択のsheet)、選択モード中に隠すこと(`T29`)、同じ folder を開き直す入口(`T56`)。

## 受け入れ条件

- [x] 読み込む前も後も、帯のbuttonが「ファイル選択」と読める。押すと今と同じ種類選択が開く。
  - 証拠: widget test(`load_affordance_test.dart` の文言の主張を更新。読み込み前後の両方)。
- [x] 帯の幅が狭い端末(320dp)と文字倍率 2.0 で、folder 名とbuttonが今と同じく収まる。
  - 証拠: 既存の帯の overflow test が PASS。
- [x] Android エミュレータで見え方を確かめる。
  - 証拠: [manual-verification.md](manual-verification.md)。`T58`・`T59` と同じ build で確かめてよい。
- [x] 独立review が PASS。

## machine検証範囲と引き受け先

- machine: 文言、押したときに開くもの、狭幅と文字倍率での収まり。
- 端末(この task の manual): 見え方だけ。

## 作業記録

- 2026-10-07 開発者の要望から登録した(`5c1449a`)。
- 2026-10-07 着手。branch `asdd/008-ui-alignment/T57-file-select-label`(起点 `dev`@`73006f1`)。**`T58`・`T59` も同じ branch・同じ PR に載せる** — 同じ要望から出た隣接する見た目の変更で、エミュレータの確認を1回で済ませるため(`015` の `T03`・`T04` と同じ扱い)。

### checkpoint 1: 文言(`a2b8516`)

- `FileSourceBar.pickLabelOf(controller)`(一覧が空かで言い分け)を定数 `FileSourceBar.pickLabel = 'ファイル選択'` にした。現在の状態を説明するコメント(`main.dart`・`file_list_view.dart`・`removal_selection.dart`・`file_source_bar.dart`・`storage_browser_view.dart`)の「別フォルダへ」も言い換えた。`test/widget_test.dart` の要望の原文の引用は当時の言葉なので残した。
- **browser の見出し「ファイルを選ぶ」(保存場所の一覧のときの題名)は変えていない。** 帯の button ではなく、要望の対象外。
- test: `load_affordance_test.dart` の文言の主張を「ファイル選択」にし、**以前の言い分けへ戻していないこと**(読み込む前に「ファイルを選ぶ」、読み込んだ後に「別フォルダへ」が出ない)を足した。
- mutation: 言い分けを守っていた M268・M269・M274 は**守る対象が無くなったので外した**。代わりに M803(読み込んだ後だけ「別フォルダへ」へ戻す)・M804(定数を「ファイルを選ぶ」にする)を足した。M614(button にアイコンを戻す)は `find` を追随させた。
- 範囲付き mutation(`flutter test test/spec_004_file_source test/spec_002_file_list test/widget_test.dart`、対象 `a2b8516`、3件):

```text
M614 | KILLED | lib/ui/file_source/file_source_bar.dart
M803 | KILLED | lib/ui/file_source/file_source_bar.dart
M804 | KILLED | lib/ui/file_source/file_source_bar.dart
3 mutations: 3 KILLED, 0 SURVIVED, 0 SKIPPED
```

- `flutter test`(全件)@`a2b8516`: `01:16 +1385: All tests passed!`。`flutter analyze`: No issues found。

### checkpoint 2: 004 の代表例(`de47cae`)

- 004 `spec.md` の代表例 43・66 の「別フォルダへ」を「ファイル選択」へ言い換え、Status 行に記録を足した。要求(must)と結果は変えていないので再承認は求めていない。日付の付いた「由来の更新」節(425〜441 行あたり)と 002 の更新記録は当時の記録なので残した。

### 独立review attempt 1

- range `73006f1..649d8e1`(全範囲。`T57`・`T58`・`T59` と登録 `5c1449a` をまとめて)。reviewer: Codex **gpt-6-luna**(2026-10-07 の開発者の指定。実装は Claude Opus 5.5)。
- 判定: **PASS**。P0〜P3 の指摘なし。
- 確かめた点(要約): 文言と 004 代表例の言い換えは要求を変えていない。`stat` の失敗は entry 単位で空にして行を残し(REQ-017)、例外は結果型へ変わる(REQ-001)。並びと読めない entry の位置。帯と名前の強調は範囲内で、`作成日時: 不明` の赤・日時と大きさの順・警告・選択とつまみの枠を保つ。`T48` の大きさの test は変えていない。既存 test の変更3件は主張を緩めていない。mutation の削除・追加・`find` の追随は妥当。
- reviewer の実行結果: `flutter analyze` No issues found、`dart format` PASS、`flutter test test/spec_004_file_source test/spec_002_file_list test/widget_test.dart test/spec_005_rename_exec` 996 PASS、`workspace.py check specs` PASS。reviewer が回した mutation(範囲付き):

```text
M115 | KILLED | M805 | KILLED | M806 | KILLED | M808 | KILLED
M813 | KILLED | M816 | KILLED | M819 | KILLED
7 mutations: 7 KILLED, 0 SURVIVED, 0 SKIPPED
```

- reviewer が足した mutation は無い。

### エミュレータ確認 attempt 1(build `bc98865`)

- 開発者の結果(2026-10-07、原文): 「動作は問題ありませんでしたが、UIについて改善点があります。」
  - 「ファイル選択の「すべて」で、最初の内部共有ストレージ・SDCARDも同様に画像と同じ大きさの四角形、文字の大きさにしたい。四角形はsdcardのマークに使われているシアンと同じ色で、塗りつぶさずに枠だけでよい。」→ `T58`
  - 「リネーム画面の補足情報の枠の色はグレーか紫がかったグレーにしたい(文字が白よりのグレーなので同化しないように注意)。」→ `T59`
- 動作は PASS。見た目の2点を直す(`45883d9`)。1画面の行数・開くまでの時間の数値は受け取っていない(動作に問題なしとの報告)。

### 差分review attempt 2

- range `649d8e1..cddcd30`(attempt 1 の直し)。**reviewer: Sonnet(Claude Code の subagent)** — 既定の Codex gpt-6-luna が利用上限に達して起動できなかったため(`ERROR: You've hit your usage limit ... try again at 8:08 PM`)。開発者の指定(luna)と食い違うので記録する。
- 判定: **PASS**。full regression `01:19 +1422: All tests passed!`、`flutter analyze` No issues、`dart format` PASS、`workspace.py check` PASS。帯の色と `textMuted` の明るさの比を計算し(約 2.65:1、白 6% の重ねを選ばれた行に載せたときの 1.82〜2.34 より高い)、記録の値と一致すると確かめた。選ばれた行・掴んでいる行との見分けは数値で示せないので manual に回していることも確かめた。
- reviewer が回した mutation:

```text
M821 | KILLED | lib/ui/file_source/storage_browser_view.dart
M822 | KILLED | lib/ui/file_source/storage_browser_view.dart
MR01 | KILLED | lib/ui/theme/app_colors.dart | reviewer control: revert band color to old 6% white overlay
3 mutations: 3 KILLED, 0 SURVIVED, 0 SKIPPED
```

- 指摘 P3 ×1(成果物の欠陥・記録): manual-verification.md の「調整できる値」に帯の古い色(白 6%)が残っていた。

### SELF-CHECK(attempt 2 の後)

- P3 を閉じた: manual-verification.md の該当行を新しい色に直した(`specs/` だけ)。
- reviewer の対照 MR01 を **M823** として `tool/mutations.json` へ取り込んだ(`edf1418`。AGENTS.md「独立reviewが足したmutationは取り込む」)。`find` の一致 PASS(748)、`flutter test test/tooling` PASS、M823 を範囲付き(`flutter test test/spec_002_file_list`)で回した:

```text
M823 | KILLED | lib/ui/theme/app_colors.dart
1 mutations: 1 KILLED, 0 SURVIVED, 0 SKIPPED
```

  `lib/`・`test/` は変えておらず、表へ reviewer 自身が確かめた対照を足しただけなので、再reviewは起動しない。
- review の連鎖: `73006f1..649d8e1` PASS(luna)→ `649d8e1..cddcd30` PASS(Sonnet)→ `cddcd30..` SELF-CHECK。

### エミュレータ確認 attempt 2(build `45883d9`)

- 開発者の結果(2026-10-07、原文): 「いくつか修正点があります。lunaが2分後には使えるので、レビューはsonnetから切り替えてください。」
  - 「ファイル選択画面のフォルダのマークやsdcardのマークが四角に対して大きすぎると不格好に見えるので、少しだけ一回り小さくしてください。」→ `T58`(アイコンを四角の 55% → 45%)
  - 「補足情報を枠に収めてみるアプローチでは、あまりわかりやすくなりませんでした。枠は消し、別のアプローチを考えます。補足情報自体の情報量を減らす(ソートやリネームのチップによって表示するものを変える)ことや、変更前後の名前の方を強調するなどが考えられそうです。」→ `T59`(帯を消す。別の見せ方は相談して別 task にする)
- 直し `2960b35`(test の修正 `e293662`)。review は gpt-6-luna に戻す。

### 差分review attempt 3

- range `75c4bf1..8f973cf`(attempt 2 の直し)。reviewer: Codex **gpt-6-luna**(開発者の指示で Sonnet から戻した)。
- 判定: **PASS**。P0/P1 なし。`flutter test` `01:08 +1421: All tests passed!`、`flutter analyze` No issues、`dart format` PASS、`workspace.py check` PASS。`_DateSubInfo` が `73006f1` と同じ形に戻り、帯の残骸が無いこと、M815・M816・M818・M819・M823 の削除と M824・M825 の追加が妥当なことを確かめた。reviewer が回した mutation(範囲付き):

```text
M163 | KILLED | M824 | KILLED | M825 | KILLED
3 mutations: 3 KILLED, 0 SURVIVED, 0 SKIPPED
```

- 指摘 P2 ×1(成果物の欠陥・記録): manual-verification.md の結果欄 attempt 2 の `45883d9` が、直しの commit(`2960b35`)と食い違って読める。

### SELF-CHECK(attempt 3 の後)

- P2 を閉じた: `45883d9` は attempt 2 で**確認した build**で誤りではないが、結果欄を「確認した build」と「直しの commit」に書き分け、対象 commit の行を attempt 3(`2960b35` 以後)に直した(`specs/` だけ。再reviewは起動しない)。
- review の連鎖: `73006f1..649d8e1` PASS(luna)→ `649d8e1..cddcd30` PASS(Sonnet)→ `cddcd30..75c4bf1` SELF-CHECK → `75c4bf1..8f973cf` PASS(luna)→ `8f973cf..` SELF-CHECK。

### エミュレータ確認 attempt 3(build `2960b35`)

- 開発者の結果(2026-10-07、原文): 「問題ありませんでした。」→ **PASS**。`2960b35` の後の commit は test 1件(`e293662`)と `specs/` の記録だけで、code・依存・build 設定は変わっていない。
- 同じ返答で、補足情報の別の見せ方は**案A**(並び順やルールで使う日時だけを出す)を選び、「作成日時:」「更新日時:」を「作成:」「更新:」に短くする案と、作成と更新が一致するときは「作成・更新:」とまとめる案を挙げた。→ 別 task で扱う(この PR では扱わない)。

## Current state / handoff

- Last checkpoint: エミュレータ確認 attempt 3 PASS(`2960b35`)。review の連鎖 `73006f1..8f973cf` は PASS と SELF-CHECK で途切れず覆う。PR #232
- Blocker category: なし
- Evidence revision: `2960b35`
- Next Agent action: なし(done)。補足情報の案A は新しい task で扱う
