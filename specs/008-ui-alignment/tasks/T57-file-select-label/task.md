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

- [ ] 読み込む前も後も、帯のbuttonが「ファイル選択」と読める。押すと今と同じ種類選択が開く。
  - 証拠: widget test(`load_affordance_test.dart` の文言の主張を更新。読み込み前後の両方)。
- [ ] 帯の幅が狭い端末(320dp)と文字倍率 2.0 で、folder 名とbuttonが今と同じく収まる。
  - 証拠: 既存の帯の overflow test が PASS。
- [ ] Android エミュレータで見え方を確かめる。
  - 証拠: [manual-verification.md](manual-verification.md)。`T58`・`T59` と同じ build で確かめてよい。
- [ ] 独立review が PASS。

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

## Current state / handoff

- Last checkpoint: `de47cae`(文言と仕様の言い換え)
- Blocker category: なし
- Evidence revision: `a2b8516`(全件 test・mutation)
- Next Agent action: `T59` まで実装したら、PR の範囲で独立review(gpt-6-luna)を起動する。manual-verification.md の対象 commit を埋める
