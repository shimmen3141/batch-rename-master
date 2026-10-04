# 手動確認: 電話では縦に固定される(Androidエミュレータ)

`008:T35` で、`AndroidManifest.xml` の `MainActivity` を縦に固定した(`android:screenOrientation="portrait"`)。

**対象buildは、`lib/`・`android/` の内容が task.md の「Evidence revision」に書いた commit と同一のもの**である。
branch `asdd/008-ui-alignment/T35-define-orientation-scope` の HEAD から build すればこれを満たす。
**manifest は再 build しないと反映されない**(hot reload / hot restart では変わらない)。`flutter run` をやり直す。

## 使う端末と準備

- 起動と`flutter run`は`/workspace/docs/development/emulator-verification.md`のとおり。branchの移動は不要。
- いつもの電話のエミュレータ(短辺 600dp 未満)。**端末の「自動回転」を ON にしておく。**

## 1. 回転しない

1. アプリを縦で開く。
2. エミュレータを横へ回す(ツールバーの回転ボタン)。

**こうなってほしい**: 画面は**縦のまま**で、アプリが横向きに描き直されない。

## 2. 他の画面でも回転しない

1. 「ファイルを選ぶ」→「すべて」で選択画面を開き、エミュレータを横へ回す → 縦のまま。
2. ルール設定(下部のボタン)を開いて横へ回す → 縦のまま。

## 3. 文字サイズ最大でも縞模様が出ない(縦)

1. 端末の文字サイズを最大にして、メイン画面を見る → 縞模様(黄と黒の帯)が出ない。

## 報告

結果は会話で自由に書いてほしい(項目番号ごとに OK / 気になった点)。
