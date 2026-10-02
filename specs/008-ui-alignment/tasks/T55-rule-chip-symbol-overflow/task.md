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

- 2026-10-03 / 実装(`80a9754`)。検証: `flutter analyze` No issues、`dart format` 0 changed、`flutter test` 1199 PASS、
  `check_mutation_finds.py` PASS(612件)。mutation(`flutter test test/spec_005_rename_exec/bottom_bar_presentation_test.dart`、3件):

```text
M666 | KILLED | lib/ui/rule_builder/rule_chip_strip.dart | 008:T55 値の行の高さを固定しない ... | exit 1
M667 | KILLED | lib/ui/rule_builder/rule_chip_strip.dart | 008:T55 値の Text に strut を付けない ... | exit 1
M668 | SURVIVED | lib/ui/rule_builder/rule_chip_strip.dart | 008:T55 列の高さを strut 無しで測る ... | exit 0: the tests passed with the mutation applied
3 mutations: 2 KILLED, 1 SURVIVED, 0 SKIPPED
```

  - **M668 の SURVIVED を受容する(安全網の穴)**: 列の高さを strut 無しで測っても、test のフォントは字形ごとの差が無く、
    strut の有無で行の高さが変わらないので区別できない。失敗は見た目(1px のはみ出しか隙間)で、データ損失・無断置換・
    偽の成功・権限・互換性のいずれにも当たらない。引き受け先: 008:T55 の実機確認。

## Current state / handoff

- Last checkpoint: 実装と自動検証(`80a9754`)。独立reviewを依頼する
- Blocker category: none
- Evidence revision: `80a9754`
- Next Agent action: 独立review(Sonnet、`520d072..HEAD`)を起動し、PASS なら実機確認を依頼する
