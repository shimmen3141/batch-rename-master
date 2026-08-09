# 手動検証: target platformでファイル選択を受け入れ確認する

## 共通前提

- 起動、device接続、branch/commit確認は`docs/development/emulator-verification.md`に従う。
- 消失してよい専用fixtureを2folderへ用意する。
- commit、build、OS/device、各結果、必要なscreenshotまたはcommand出力をlive IssueまたはPRへ記録する。このfileへstatusを書かない。

## Android SAF

1. 「ファイルを選ぶ」で種類sheetが出る。
2. 「画像」「動画」は読み込みを始めず、写真機能で対応予定であることを示す。
3. 「すべて」から複数fileを選ぶと一覧が選択結果へ置き換わり、各行に場所が表示される。
4. 別の選択を行うと前回分を蓄積せず置き換える。
5. pickerをcancelすると一覧と通知が変化しない。
6. 「文書」では文書系fileを選ぶpickerが開く。
7. 2folderのfileを一度に選ぶと読み込みは成功し、folderを跨ぐwarningが出る。
8. 作成日時が不明なfileを作成日時順にすると代替warningと行の強調が出る。別sortでは不明表示を残し、強調を外す。
9. 追加の全file access権限を要求しない。

記録する証拠: 対象commit/build/device、置換前後、cancel前後、種類別入口、跨ぎwarning、日時warning。

## desktop

1. Windows、Linux、またはmacOSの対象buildでfile pickerを開く。
2. 複数fileを選ぶと一覧が置き換わり、場所が表示される。
3. 選び直しとcancelがAndroidと同じ契約になる。
4. 実装が扱うhandleが選択fileのabsolute pathであり、同名の別pathを別fileとして扱える。

記録する証拠: 対象commit/build/OS、選択・置換・cancel後の一覧、選択元path。
