# 手動確認: footer 左下の「キャンセル」(Androidエミュレータ)

`015:T03` で、browser(「すべて」)と写真・動画の選択画面の footer 左下を「← リネーム画面へ」から**矢印の無い「キャンセル」**にした。置き場所・形(暗い地にシアンの枠と文字)・押したときの意味(選んだものを捨ててリネーム画面へ戻る)は変えていない。

**対象buildは、`lib/`・`android/` の内容が task.md の「Evidence revision」に書いた commit と同一のもの**である。branch `asdd/015-screen-switch-placement/T03-footer-cancel-label` の HEAD から build すればこれを満たす。Kotlin は変えていない。**code・dependency・build設定が変わったら、この結果は再利用しない。**

## 準備

- 起動と`flutter run`は`/workspace/docs/development/emulator-verification.md`のとおり。**普段の作業ツリーは branch の移動が不要**(Agent がこの branch にしてある)。hot reload ではなく起動し直す。
- これまでの確認で作った写真・動画をそのまま使う。

## 手順と期待結果

1. 「すべて」でファイルのあるフォルダ(例: `DCIM/Camera`)を開く。
   - footer は左に「キャンセル」(矢印なし、枠付き)、右に「確定」。**2つは同じ幅で横いっぱいに並び、間に不自然な隙間が無い**(attempt 1 の指摘)。いちばん上に帯は無く、header は今までどおり。
2. 1つ選んでから「キャンセル」を押す。
   - リネーム画面へ戻り、一覧は開く前のまま(選んだものは入らない)。
3. 「写真・動画」を開き、1・2と同じことを行う。
   - footer の見た目と戻り方が browser と同じ。
4. 気になる点(文言、ボタンの大きさなど)があれば伝える。

## 後片付け

なし
