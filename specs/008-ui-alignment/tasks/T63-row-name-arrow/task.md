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

- [ ] `→` が `Icons.arrow_right_alt`・大きさ 18・本文の色。
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

## Current state / handoff

- Last checkpoint: `2ec1184`。Draft PR #235
- Blocker category: なし
- Evidence revision: `2ec1184`
- Next Agent action: 独立review attempt 1(gpt-6-luna)、その後エミュレータ確認
