# `setSurfaceSize` は layout には効くが `MediaQuery.size` には効かない

## 観測したこと(2026-09-19)

`008:T30` の吹き出しは「**画面に収まらなければ出さない**」を `MediaQuery.of(context).size` で
判定する。その検査を `tester.binding.setSurfaceSize(Size(320, 800))` の格子で書いたところ、
**幅を一度も動かせていなかった**(独立review attempt 5 の P1)。最小再現:

```dart
await tester.binding.setSurfaceSize(const Size(360, 800));
// MediaQuery.of(context).size = Size(800.0, 600.0)   ← 既定のまま
// LayoutBuilder の制約       = Size(360.0, 800.0)   ← こちらは変わる
```

`tester.view.physicalSize = size; tester.view.devicePixelRatio = 1.0;` なら
`MediaQuery.of(context).size` も動く。Flutter SDK 自身が `setSurfaceSize` に
`TODO(pdblasi-google): Deprecate this.` を書いている(multi-view 化以降の制限)。

**危ないのは「半分効く」ことである。** 帯の幅や button の位置のような**layout の検査は
本当に動いている**ので、同じ書き方が通用すると思い込む。`MediaQuery` を読む実装だけが
黙って素通りし、**格子を回しているのに一度も条件を変えていない** test になる。
独立reviewが `M386`(横方向の判定だけを無効化する対照)で見つけた。

## なぜ起きたか

- projectの既存testが `setSurfaceSize` を広く使っており(`008:T16` / `T18` 由来の
  `row_presentation_test.dart`・`location_view_test.dart` ほか)、**そのまま踏襲した**。
  既存の用途は layout の検査なので、それらは壊れていない。
- 「狭幅 × 文字倍率の格子を回した」という記録を、**格子が本当に動いたかを確かめずに**書いた。
  文字倍率(`MediaQuery.copyWith(textScaler:)`)は効いていたので、結果が変化して見えた。

## 変更先と検証

- `008:T30` の `test/spec_002_file_list/removal_hint_test.dart` に `_setScreen` を置き、
  `tester.view.physicalSize` / `devicePixelRatio` / `padding` で画面を変える形へ直した。
  格子を回し直して `task.md` の表を実測値へ更新した。
- 横方向の判定を閉じる test(幅200dp)と、上の inset を数える test を足した
  (対照 `M385` / `M386`)。
- 未適用: **`MediaQuery` を読む実装を検査するときは `tester.view` で画面を変える**という
  規律。既存の `setSurfaceSize` 利用箇所は layout の検査なので直していないが、
  そこへ `MediaQuery` 依存の検査を足すと同じ穴が開く。forward-test は次に
  画面サイズへ依存する実装を書く task で行う。
