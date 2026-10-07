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

- 2026-10-07 開発者の要望から登録した。

## Current state / handoff

- Last checkpoint: 未着手
- Blocker category: なし
- Evidence revision: なし
- Next Agent action: 着手時に `in_progress` へ変え、branch を作る。manual-verification.md を作る
