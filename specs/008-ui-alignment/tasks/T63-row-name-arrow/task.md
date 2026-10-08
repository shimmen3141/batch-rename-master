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

## Current state / handoff

- Last checkpoint: 登録
- Blocker category: なし
- Evidence revision: なし
- Next Agent action: 実装
