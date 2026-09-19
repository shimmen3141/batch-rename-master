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

## 実装と機械検証(2026-09-19)

- ツノは、40dpのアイコン枠の幾何学的中心から字面に合わせて3dp左へ補正した。吹き出しは
  4dp下へ寄せ、文言を改行なしの`押すとファイルをリネームリストから外します。削除はされません。`
  へ替えた。5秒表示、黒地、シアンの連続外枠は一つの`CustomPainter`で描く。
- `flutter test test/spec_002_file_list/removal_hint_test.dart` — PASS (13 tests)
- `flutter test test/spec_002_file_list test/spec_004_file_source` — PASS (333 tests)
- `dart format --output=none --set-exit-if-changed .` — PASS (131 files)
- `flutter analyze` — PASS (`No issues found`)
- 全回帰の`flutter test`は、この対話環境で親プロセスが出力上限により切れ、完走結果を取得
  できなかった。関連回帰は上記333件で閉じている。Android SDKが無いため、buildと実機確認は
  machineでは未実施。

### mutation の生出力

`mutation_check.py`を、対応するtest名だけへ絞った作業用表で実行した。

```text
M351 | KILLED | ツノをケバブの下へずらす | exit 1
M352 | KILLED | ツノの中心計算から幅の半分を外す | exit 1
M353 | KILLED | 「削除はされません」を落とす | exit 1
M363 | KILLED | 吹き出し幅の上限を2倍にする | exit 1
M364 | KILLED | 閉じる操作を無効にする | exit 1
M365 | KILLED | 5秒後に消えないようにする | exit 1
M366 | KILLED | モード終了時もフェードを待つ | exit 1
M367 | KILLED | シアンの一体枠を黒へ替える | exit 1
8 mutations: 8 KILLED, 0 SURVIVED, 0 SKIPPED
```

### review

- `SELF-REVIEW ONLY`: `8b0279f..e46bc84` の実装・test・mutation・task正本を照合した。
  成果物の欠陥は見つからなかった。実機の色、相対位置、5秒の体感は手動確認で判定する。

## Current state / handoff

- Last checkpoint: 実装、関連widget回帰333件、format、analyze、対象mutationを完了し、Android manual確認を渡せる状態にした(2026-09-19)
- Blocker category: manual verification
- Waiting for: Android実機またはemulatorを操作する人間
- Requested action: `manual-verification.md`の手順1〜3を対象revisionで確認し、結果を会話で返す。
- Touches: `lib/ui/file_list/removal_hint.dart`(必要なら `header_metrics.dart`)、
  `test/spec_002_file_list/removal_hint_test.dart`、`tool/mutations.json`(M352/M353/M363/M367 の再アンカー)
- 並行: **`T31` とは別file**(あちらは `file_list_view.dart`)なので同時に進められる。
  `header_metrics.dart` だけは `file_list_view.dart` と共有している定数なので、
  **そこを動かすなら `T31` と順番を決める**
- Evidence revision: e46bc844a406f7038d1a44b555c74c03b06793e6
- Machine verification scope: widget testでツノの意図した視覚補正、1行の文言、5秒の表示、黒地とシアン枠、画面内への収まり、閉じる操作、pointer透過を検証する。Android実機の見た目と操作感はmachineで閉じられないため、このtaskのmanual確認で受ける。
- Next Agent action: manual結果をtaskへ記録し、証拠identityを確認してfinal-evidence reviewを行う。
