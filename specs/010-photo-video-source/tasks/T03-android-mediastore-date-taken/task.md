# T03 Android で MediaStore の撮影日時と追加日時を補う

## 目的

Android で、中身から日時を取れなかったファイルについて、MediaStore の `DATE_TAKEN`(004 REQ-010 の②)、それも無ければ `DATE_ADDED`(③)を引いて
作成日時に入れる。どちらも UTC なので端末の時刻帯へ直す。
あわせて、T02 と合わせた全体を Android エミュレータで確かめる。

## 入力と依存

- T01 の差分(順位・時刻帯)、T02 の実装。
- [R-001](../../decisions/R-001-mediastore-date-taken-source.md)。
- [`T04`](../T04-verify-creation-time-stability/task.md) の結論(`DATE_ADDED` は改名で変わらない。この app が path で作った file は MediaStore に載らない)。
- 既存の platform channel(`MainActivity.kt`)と、channel 名を突き合わせる test(`test/tooling/platform_channel_names_test.dart`)。

## 変更範囲

- Kotlin 側で path から `DATE_TAKEN` と `DATE_ADDED` を引く処理と、Dart 側の呼び出し。
- 触れない: desktop の経路、改名の実行。

## 受け入れ条件

- [ ] 中身に撮影日時が無く `DATE_TAKEN` を持つファイルで、その値が入る。中身から取れたファイルは中身の値のまま(代表例 47・48)。
- [ ] ①②が無く `DATE_ADDED` を持つファイル(ダウンロード・スクリーンショットなど)で、その値が入る(代表例 11・49・51)。この app で改名した後に読み込み直しても変わらない(代表例 50)。
  - 証拠: Dart 側の test(channel を差し替える)、Android エミュレータの manual。
  - 証拠: Dart 側の test(channel を差し替える)、channel 名の突き合わせ test、Android エミュレータの manual。
- [ ] MediaStore に無いファイル・引けないときは「不明」のままで、読み込みは失敗しない。
  - 証拠: test、manual。
- [ ] エミュレータで、カメラで撮った写真・動画が撮影日時の順に並び、日時トークンで撮影日が名前に入る。ダウンロードしたファイル・スクリーンショットにも作成日時が入る。
  - 証拠: [manual-verification.md](manual-verification.md)。

## 作業記録

## Current state / handoff

- Last checkpoint: 未着手
- Blocker category: none
- Evidence revision: none
- Next Agent action: T02 の完了を待ち、Kotlin の MediaStore 照会を足す
