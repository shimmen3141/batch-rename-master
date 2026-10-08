# T63 リネーム画面の行で、変更前後をつなぐ矢印を軸が長く矢じりが小さい形にする

## 目的

リネーム画面の行で、変更前の名前と変更後の名前をつなぐ `→` を、**軸が長く矢じりが小さい**形にする。

## 出所

- 開発者の要望(2026-10-08、原文): 「リネーム前後をつなぐ矢印が短く見える(逆に矢の部分が大きい)のですが、改善できますか。」
- 原因: 今は Material の `Icons.arrow_forward` を 12dp で出している。この glyph は正方形の中に大きな矢じりと短い軸を描く形である。
- Agent の案: 軸が長く矢じりが小さい Material の `Icons.arrow_right_alt` に替え、線が細くなる分だけ大きさを上げる。端末で見て、合わなければ自前で描く(`CustomPaint`)案へ移る。

## 範囲

- `lib/ui/file_list/file_list_view.dart` の `→`(`rowNameArrowKey`)。glyph を `Icons.arrow_right_alt` にし、大きさ 12 → 18。glyph の左右に余白(24 のうち 4 ずつ)があるので、変更後の名前との間 `right: 4` → `2`。
- 守ること(変えない): 色(本文の色。`T62`)、変更後の名前の大きさ・太さ・色、補足情報の字下げの基準(`→` の左端。`T62`)、狭幅 × 文字倍率で溢れない。
- **大きさと間は端末で見て詰める。**

## 受け入れ条件

- [ ] `→` が `Icons.arrow_right_alt`・本文の色で、取る場所 18・描く大きさ 22 相当(行の高さを変えない。attempt 1 の要望)。
  - 証拠: widget test(`row_name_hierarchy_test.dart`)。
- [ ] 既存の行の保証が成り立つ(既存の test が変更なしで PASS。glyph を主張する test だけ更新する)。
  - 証拠: `flutter test`。
- [ ] 開発者が Android エミュレータで矢印の見え方を確かめている。
  - 証拠: [manual-verification.md](manual-verification.md)。
- [ ] 独立review が PASS。

## machine検証範囲と引き受け先

- machine: glyph・大きさ・色・溢れ。
- 端末(この task の manual): 実際の見え方(軸と矢じりの釣り合い)。

## 作業記録

- 2026-10-08 登録・着手。branch `asdd/008-ui-alignment/T63-row-name-arrow`(起点 `dev`@`21f9d93`)。

### checkpoint 1: 実装(`2ec1184`。登録は `6afbe3c`)

- `→` を `Icons.arrow_right_alt`・大きさ `rowNameArrowSize = 18`・間 `right: 2` にした。色は `T62` のまま。
- test: `row_name_hierarchy_test.dart` の `→` の test で、glyph の主張を `arrow_forward` → `arrow_right_alt` に更新し、大きさ(18)を足した。他の test は変更なしで PASS(狭幅 × 文字倍率の溢れ、`T62` の字下げの基準を含む)。
- mutation: M833 の `find` を追随させ(大きさを定数にした)、M841(glyph を戻す)・M842(大きさを 12 に戻す)を足した。範囲付き(`flutter test test/spec_002_file_list test/spec_005_rename_exec test/widget_test.dart`、対象 `2ec1184`、4件):

```text
M833 | KILLED | M839 | KILLED | M841 | KILLED | M842 | KILLED
4 mutations: 4 KILLED, 0 SURVIVED, 0 SKIPPED
```

- `flutter test`(全件)@`2ec1184`: `01:07 +1435: All tests passed!`。`flutter analyze` No issues、`dart format` PASS、`check_mutation_finds.py` PASS(762)。

### 独立review attempt 1

- range `21f9d93..5395214`(全範囲)。reviewer: Codex **gpt-6-luna**(開発者の指定。実装は Claude Opus 5.5)。
- 判定: **PASS**。指摘なし。glyph・大きさ・間の変更が要望どおりで、色・変更後の名前・補足情報の字下げの基準・溢れを変えていないこと、test の更新が glyph の置き換えと大きさの追加に限られること、M833 の追随と M841・M842 が妥当なこと、記録が差分と食い違わないことを確かめた。reviewer の実行結果: `flutter test` `01:00 +1435: All tests passed!`、analyze・format・`workspace.py check` PASS。範囲付き mutation(M833・M839・M841・M842)は `4 mutations: 4 KILLED, 0 SURVIVED, 0 SKIPPED`。
- **reviewer の log では、M842 が1回 `SURVIVED` と出た**(`4 mutations: 3 KILLED, 1 SURVIVED`)。log を読むと、reviewer が**同じ worktree で mutation_check を2本同時に走らせていた**(227秒と241秒でほぼ同時に終わった)。一方が file を元に戻した後で、もう一方の test が走ったためと見られる。reviewer が M842 だけを回し直すと `1 mutations: 1 KILLED`、test file を絞っても KILLED だった。M842 を捕まえるのは `row_name_hierarchy_test.dart` の `getSize(...).width == 18`(値を直に書いた主張)。**`arrow.size == rowNameArrowSize` は定数どうしを比べるだけで、M842 を捕まえない**。所有側の実行(checkpoint 1)でも KILLED だった。

### エミュレータ確認 attempt 1(2026-10-08、対象 `2ec1184`)

- 開発者: 「矢尻が目立たなくなってしまったので、もう一回り大きくしたいです。」

### checkpoint 2: 矢印を一回り大きく描く(`d6656a5`)

- `arrow_right_alt` は矢じりだけを大きくできないので、全体を一回り(18 → 22dp 相当)大きくした。
- **大きさそのもの(`size`)を 22 にすると、名前の行が 2dp 高くなる**(一時 test で測った行の間隔: 18 → 66、22 → 68)。行の数が減らないよう、**場所は 18 のまま取り、`Transform.scale`(`rowNameArrowScale = 22 / 18`)で描くときだけ拡大した**。行の間隔は 66 のまま。
- 拡大した分が右へはみ出すので、変更後名との間を `right: 2` → `4` に戻した。
- test:
  - `row_name_hierarchy_test.dart`: 取る場所 18×18、描く幅 22、中心が場所の中心、描いた矢印と変更後名の間が 2 以上、場所の高さが変更後名の文字の高さ以下(行を高くしない)を足した。glyph と色の test から大きさの主張を外した(新しい test へ移した)。
  - `row_sub_info_line_test.dart`(`T62`): 字下げの基準を `→` の**描いた**左端から**取る場所**(`rowNameArrowScaleKey`)の左端へ変えた。拡大で描いた左端が 2 左へずれるが、字下げの意味(名前の左端から)は変えていない。
- mutation: M833 の `find` を追随させ(字下げが深くなった)、M843(拡大しない)・M844(間を 2 に戻す)・M845(拡大ではなく大きさを 22 にする = 行が高くなる)を足した。範囲付き(`flutter test test/spec_002_file_list test/spec_005_rename_exec test/widget_test.dart`、対象 `d6656a5`、7件。**1本ずつ**):

```text
M833 | KILLED | M839 | KILLED | M841 | KILLED | M842 | KILLED
M843 | KILLED | M844 | KILLED | M845 | KILLED
7 mutations: 7 KILLED, 0 SURVIVED, 0 SKIPPED
```

- `flutter test`(全件)@`d6656a5`: `01:10 +1436: All tests passed!`。`flutter analyze` No issues、`dart format` PASS、`check_mutation_finds.py` PASS(765)。

### 独立review attempt 2(差分review)

- range `3678ebd..37057ba`。reviewer: Codex **gpt-6-luna**。
- 判定: **PASS**。指摘なし。描画だけ 22 相当で場所は 18 のまま、行の高さ・色・変更後名・間を test が検査していること、`T62` の字下げの test の基準の変更が主張を緩めていないこと、M833 の追随と M843〜M845 が妥当なことを確かめた。reviewer の実行結果: `flutter test` `00:51 +1436: All tests passed!`、analyze・format・`workspace.py check` PASS。範囲付き mutation(M833・M843・M844・M845、1本ずつ)は `4 mutations: 4 KILLED, 0 SURVIVED, 0 SKIPPED`。
- review の連鎖: `21f9d93..5395214` PASS → `5395214..3678ebd` 記録だけ → `3678ebd..37057ba` PASS。

## Current state / handoff

- Last checkpoint: 独立review attempt 2 PASS(`3678ebd..37057ba`)。Draft PR #235
- Blocker category: manual-evidence
- Evidence revision: `d6656a5`(code の最後の commit)
- Waiting for: 開発者(Android エミュレータの確認 attempt 2)
- Requested action: [manual-verification.md](manual-verification.md) の手順を行い、結果を会話で伝える
- Next Agent action: 結果を記録する。PASS なら `T63` を done にし、PR #235 を ready にして merge する
