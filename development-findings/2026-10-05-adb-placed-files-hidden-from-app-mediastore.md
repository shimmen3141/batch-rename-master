# adb で置いた file は、全ファイルアクセス権限の app の MediaStore 照会から見えない

## 観測

2026-10-05、`010:T03` の manual attempt 1 で、`adb shell 'echo x > …/download.txt'` で置いた file の作成日時が `不明` になった
(期待は MediaStore の `DATE_ADDED`)。

- `adb shell content query` では、その file の行に `date_added` がある(置いた時刻)。
- app の照会(`MediaStore.Files`、`VOLUME_EXTERNAL`)は例外なく **0 行**。`_data =`・`_display_name =`・親 folder の `LIKE` のどれも 0 行。
  条件なしなら 345 行見える。端末は `sdk=37`、app の `targetSdk=36`、`Environment.isExternalStorageManager()` は `true`。
- 同じ build で、エミュレータで撮ったスクリーンショットは MediaStore から値が入った(`1 paths, 1 found`)。

→ shell(adb)が置いた file の行は、全ファイルアクセス権限があっても app から見えない。普通の app・system が作った file は見える。
(`adb push` で置いた JPEG・MP4 の行も、親 folder の `LIKE` で見えなかった。)

## なぜ手戻りになったか

`010:T04` は「app が path で作った file は MediaStore に載らない」「shell が置いた file は載る」を `adb shell content query`(shell の権限)で
確かめた。**app から見えるか**は確かめず、T03 の manual は「載る」を「app が引ける」とみなして adb で fixture を置いた。
実装の誤りではなかったが、build と原因の切り分けに4往復かかった(古い APK か / 例外か / 0 行か / 見えないのか)。

## 改善

- T03 の manual は、③の fixture をエミュレータの Chrome で本当にダウンロードした file に替えた。
- MediaStore の可視性に依存する確認は、**app と同じ identity で見えるか**を確かめる(shell の `content query` は上位の権限で見ている)。
- 失敗を黙って「値が無い」にする経路には、logcat への出力を残した(画面に出ない失敗の切り分けに要る)。
