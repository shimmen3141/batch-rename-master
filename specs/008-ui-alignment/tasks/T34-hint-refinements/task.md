# T34 吹き出しの位置・文言・配色・時間を詰める

## 目的

`T30` で入れた「外すアイコンへ重ねる補足」を、2回目の実機確認で受領した5点で詰める。
**`T30` の欠陥ではない** — 手順1〜5の確認事項はすべて成立した上での調整である。

## 受領した要望(2026-09-19、原文)

> 吹き出しは、ツノがアイコンの中央からすこしだけ右にずれているので、やや左にずらしたい。吹き出し自体ももう少し下にずらせる。また、文言を「押すとファイルをリネームリストから外します。削除はされません。」(改行なし)にしたほうがわかりやすそうです。また、フェードまでの時間を5秒に延長し、色の主張が強すぎるので枠だけシアンで中は黒にしたいです(ツノと長方形の境界線が見えないように)。

## 変更範囲

すべて [`lib/ui/file_list/removal_hint.dart`](../../../../lib/ui/file_list/removal_hint.dart) の中で閉じる。

1. **ツノを少し左へ。** いまは `removalHintTailInsetFromRight`(= `headerMenuExtent` +
   `headerIconExtent` / 2)で**アイコンの中心に一致させている**(widget test が実測で固定)。
   実機では少し右に見えるとのことなので、**見た目の中心とアイコンの中心がずれている**
   ことになる。原因を確かめてから動かす(`Icons.playlist_remove` の字面が枠の中で
   左寄りである可能性が高い)。**test の期待値も一緒に動かす**(いまは「ツノの中心 ==
   アイコンの中心」を厳密に見ているので、ずらすなら意図した差として書く)。
2. **吹き出し全体をもう少し下へ。** `_build` の `offset` の `dy`(いまは `-2`)。
3. **文言を1行へ。** `押すとファイルをリネームリストから外します。削除はされません。`
   (改行なし)。**「削除はされません」は落とさない**(005 / 013 の境界。対照 `M353`)。
   **1行にすると横に長くなる**ので、`removalHintMaxWidth`(いま232)と
   「画面に収まるか」の判定(`_showIfItFits`)への影響を測り直す。
4. **`removalHintLifetime` を 3 秒 → 5 秒へ。**
5. **配色を「枠だけシアン・中は黒」へ。** いまは面も枠もツノも `primary` 一色。
   **ツノと箱の継ぎ目に線を出さない**という要求は変わらない(対照 `M367`)ので、
   ツノにも同じ塗り(`background` 相当)と**外側の2辺だけに枠線**が要る。
   箱の下辺のうちツノが接する部分は枠線を描かない、という描き方になる
   (`CustomPainter` で箱ごと描くのが素直かもしれない)。

## 気をつけること

- **`T30` が閉じた保証を戻さない。** 収まらないときは出さない / 出ているときは画面の中に
  ある / 閉じる操作が押せる / 飾りは pointer を取らない / 読み上げから文言が消えない。
  **文言を1行にすると箱の形が変わる**ので、`test/spec_002_file_list/removal_hint_test.dart`
  の格子を回し直す。
- **画面サイズを変える test は `tester.view.physicalSize` を使う**
  (`tester.binding.setSurfaceSize` は `MediaQuery.size` を動かさない。
  [finding](../../../../development-findings/2026-09-19-set-surface-size-does-not-move-media-query.md))。
- 対照 `M352`(ツノの位置)・`M353`(文言)・`M367`(枠線)・`M363`(幅)は**動かす対象なので
  再アンカーが要る**。

## 受け入れ証拠

- ツノの位置・文言・時間・配色が要望どおりであることを widget test で固定する。
- `T30` の格子(幅 × 文字倍率)を回し直して、**出る/出ないの境目**を記録し直す。
- `flutter test` / `flutter analyze` / `dart format` / `mutation_check.py` が PASS。
- Android実機での manual 確認(`manual-verification.md` を作る)。**`T32` の確認は要らない**
  (触らないため)。

## Current state / handoff

- Last checkpoint: `T30` の2回目の実機確認で受領した5点をtask化した(2026-09-19)
- Blocker category: none(`T30` は merge 済み。着手可能)
- Waiting for: なし
- Requested action: なし
- Touches: `lib/ui/file_list/removal_hint.dart`(必要なら `header_metrics.dart`)、
  `test/spec_002_file_list/removal_hint_test.dart`、`tool/mutations.json`(M352/M353/M363/M367 の再アンカー)
- 並行: **`T31` とは別file**(あちらは `file_list_view.dart`)なので同時に進められる。
  `header_metrics.dart` だけは `file_list_view.dart` と共有している定数なので、
  **そこを動かすなら `T31` と順番を決める**
- Evidence revision: 未着手
- Next Agent action: 着手してよい。まず「ツノが右にずれて見える」原因を実測で確かめる
  (アイコンの字面が枠の中で左寄りなのか、ツノの位置そのものか)。**`T31` と同じ file を
  触る**ので、どちらかを先に終える
