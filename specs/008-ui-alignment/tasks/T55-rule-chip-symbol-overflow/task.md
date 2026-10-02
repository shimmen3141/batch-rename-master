# T55 ルール設定buttonのチップで、空白の「␣」を含む値が列の高さからはみ出さないようにする

## 目的

ルール設定buttonに並ぶルールのチップ(`008:T47`)で、自由テキストの値に空白を含めると、チップが
「BOTTOM OVERFLOWED BY 1.00 PIXELS」になる。値の行の高さを描く文字によらず一定にして、はみ出さないようにする。

## 受領した報告(2026-10-03 JST)

`T54` の実機確認の途中で、開発者が無関係な問題として報告した(原文)。

> 自由テキストチップに「same 」(最後にスペースを入れる)を入力すると、ルール設定ボタン上に表示される
> 自由テキストチップに「BOTTOM OVERFLOWED BY 1.00 PIXELS」と表示されました。

## 原因

- チップの値は空白を `␣` に置き換えて見せる(`tokenChipValue`)。
- チップの列の高さは1つ分に**固定**している(`RuleChipStrip` の `_chipHeight`。`T47`)。値の行の高さは `あ` で測る。
- `␣` は等幅のフォント(`monospace`)に無い字形で、端末では別のフォントで描かれ、その行が `あ` の行より 1px 高くなる。
  固定した高さを超えるのではみ出す。**test のフォントは字形ごとの差が無いので test では再現しない。**

## 変更範囲

- `lib/ui/rule_builder/rule_chip_strip.dart`: 値の `Text` に `StrutStyle(forceStrutHeight: true)`(値の文字の style から作る)を
  付け、行の高さを描く文字によらず一定にする。`_chipHeight` も同じ strut で測る。
- 見た目(余白・字体・色・並べ方)と `T47` の決定(2段のチップ、フェード)は変えない。
- 設定画面のチップ(`TokenChip`)は高さを固定していないので対象外(はみ出さない。必要なら行が伸びる)。

## 受け入れ証拠

- widget test: 値の行の `Text` が `forceStrutHeight` の strut を持ち、strut の字体・大きさが値の style と同じ。チップの高さが
  列の高さと一致する(`same` / `same ` / 全角空白 / `あ`)。
- `flutter test` / `flutter analyze` / `dart format` が PASS。mutation で KILLED を確かめる。
- 実機: `same ` のチップではみ出しの表示が出ない([manual-verification.md](manual-verification.md))。
- 独立review(開発者の指定で当面は Sonnet)。

## 作業記録

日付は JST。

- 2026-10-03 / 起票と実装。test 用のフォントで `same` / `same ` などを描いて再現しないことを確かめ(字形ごとの差が無い)、
  原因を上のとおり特定した。

## Current state / handoff

- Last checkpoint: 実装(未commit)
- Blocker category: none
- Evidence revision: 未定
- Next Agent action: 検証して commit し、mutation と独立reviewへ進む
