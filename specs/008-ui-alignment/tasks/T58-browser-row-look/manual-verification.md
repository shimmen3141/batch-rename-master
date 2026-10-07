# 008 / T58 manual確認: app内browserの行

対象 commit・build は実装後に書く。共通の起動手順は [`docs/development/emulator-verification.md`](../../../../docs/development/emulator-verification.md)。

## 手順と期待結果(実装後に具体化する)

1. 変更前(`dev`)の browser で、画像・文書・folder が混ざった folder を開き、スクリーンショットを撮る。件数の多い folder を開くまでの時間を測る。
2. この task の build で同じ folder を開く。
   - preview が大きくなり、1画面に約10行並ぶ。
   - folder は暗い灰色の四角に folder アイコン、文書などは灰色の線の四角で、見分けられる。
   - 名前が少し大きく、2行目に薄い灰色で更新日時(ファイルは大きさも)が出る。
   - folder が先、それぞれ更新日時の新しい順に並ぶ。
3. 件数の多い folder を開くまでの時間を測り、1 と比べる。
4. 長押しdragの範囲選択・全選択・一括解除が今と同じく動く。
5. リネーム画面の行で preview を出せないファイル(文書など)が、線の四角になっている。

## 結果

未実施。
