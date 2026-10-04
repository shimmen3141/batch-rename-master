# 手動確認: 写真・動画・ダウンロードの作成日時(Androidエミュレータ)

`010:T02`・`T03` で、読み込んだファイルの**作成日時**を、次の順に最初に取れた値で埋めるようにした(004 REQ-010)。

1. ファイルの中身の日時(写真の EXIF の撮影日時、動画に記録された日時)
2. MediaStore の `DATE_TAKEN`
3. MediaStore の `DATE_ADDED`(この端末にファイルが作られた時刻)

**対象buildは、`lib/`・`android/` の内容が task.md の「Evidence revision」に書いた commit と同一のもの**である。
branch `asdd/010-photo-video-source/T03-android-mediastore-date-taken` の HEAD から build すればこれを満たす。
**Kotlin(`MainActivity.kt`)を変えたので、hot reload / hot restart ではなく `flutter run` をやり直す。**
**code・dependency・build設定が変わったら、この結果は再利用しない。**

## 使う端末と準備

- 起動と`flutter run`は`/workspace/docs/development/emulator-verification.md`のとおり。branchの移動は不要。
- **`flutter run` が build に失敗したら、そこで止めてエラーをそのまま貼ってほしい**(Kotlin は container で build できず、ここが最初の build になる)。
- PowerShell で、先に次を実行しておく。

```powershell
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
$dir = "$env:TEMP\brm-010-t03"
New-Item -ItemType Directory -Force $dir | Out-Null
Invoke-WebRequest https://raw.githubusercontent.com/ianare/exif-samples/master/jpg/Canon_40D.jpg -OutFile "$dir\canon_2008.jpg"
Invoke-WebRequest https://raw.githubusercontent.com/web-platform-tests/wpt/master/media/movie_5.mp4 -OutFile "$dir\movie_2010.mp4"
& $adb shell mkdir -p /storage/emulated/0/Download/brm-010-t03
& $adb push "$dir\canon_2008.jpg" "$dir\movie_2010.mp4" /storage/emulated/0/Download/brm-010-t03/
& $adb shell 'echo x > /storage/emulated/0/Download/brm-010-t03/download.txt'
& $adb shell date
```

- 置いたもの(どれも `Download/brm-010-t03/`):
  - `canon_2008.jpg`: EXIF の撮影日時が **2008/5/30 15:56**(中身の日時)。
  - `movie_2010.mp4`: 動画に記録された日時が **UTC で 2010/6/1 16:08**(日本時間の端末なら **2010/6/2 01:08**)。
  - `download.txt`: 中身に日時が無い。**置いた時刻**(最後の `date` の時刻)が `DATE_ADDED` になる。ダウンロードしたファイルの代わり。
- 最後の `adb shell date` の出力(端末の今の時刻と時刻帯)を控えておく。

## 1. 中身の日時が入る(代表例 10・44・46)

1. アプリで「ファイルを選ぶ」→「すべて」→ `Download/brm-010-t03` を開き、3つとも選んで確定する。
2. 各行の `作成日時:` を見る。

**こうなってほしい**

- `canon_2008.jpg` … `作成日時: 2008/5/30 15:56`(更新日時や今日ではない)。
- `movie_2010.mp4` … `作成日時: 2010/6/2 01:08`(端末が日本時間のとき。端末の時刻帯が違えば、UTC 2010/6/1 16:08 をその時刻帯で表した値)。
- `download.txt` … `作成日時:` が**置いた時刻**(上の `date` の時刻とほぼ同じ)で、`不明` ではない(③)。

## 2. 作成日時の順に並ぶ

1. 並び順を「作成日時」(昇順)にする。

- `canon_2008.jpg` → `movie_2010.mp4` → `download.txt` の順。作成日時が不明という警告は出ない。

## 3. 改名しても作成日時が変わらない(代表例 50)

1. **少なくとも1分待ってから**、ルールを `[元の名前]` の後ろに `_r` を足す形にして実行する(3つとも改名される)。
2. 「別フォルダへ」→「すべて」で同じ folder を開き直し、3つを選び直して確定する(読み込み直し)。

- 3つとも、`作成日時:` が手順1と同じ(改名した時刻に変わっていない)。

## 4. カメラとスクリーンショット

1. エミュレータのカメラで写真を1枚、動画を1本撮る(`DCIM/Camera` に入る)。スクリーンショットを1枚撮る(`Pictures/Screenshots`)。
2. それぞれの folder を開いて読み込み、`作成日時:` を見る。

- どれも撮った時刻で、`不明` ではない。
- 作成日時を基準にした日時トークン(例: `[日時 作成 YYYYMMDD_HHmmss]`)をルールに入れると、変更後の名前に撮った時刻が入る。

(スクリーンショットは中身に日時が無いので、②`DATE_TAKEN` か ③`DATE_ADDED` の値になる。どちらでも撮った時刻なので、ここでは見分けない。順番は test が固定している。)

## 5. 後片付け

```powershell
& $adb shell rm -r /storage/emulated/0/Download/brm-010-t03
Remove-Item -Recurse $dir
```

カメラ・スクリーンショットのファイルは残してよい(消してもよい)。

## 報告

結果は会話で自由に書いてほしい(項目番号ごとに OK / 気になった点)。1 の3行の `作成日時:` の値と、`adb shell date` の出力を書いてもらえると照合しやすい。
