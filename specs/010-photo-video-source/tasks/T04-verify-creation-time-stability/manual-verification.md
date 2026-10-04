# 手動確認: 改名しても作成時刻が変わらないか(Androidエミュレータ)

アプリの画面は操作しない。**アプリと同じパッケージ・同じ権限で動く調査用のテスト**を端末で走らせ、
製品と同じ改名を2回行って、その前後で「ファイルがこの端末に作られた時刻」が変わるかを見る。

**どの結果でも不具合ではない。** 分かるのは、ダウンロードやスクリーンショットに作成日時を付ける経路に、
どの値を使えるかである(`010:T04` の task.md)。

対象: branch `asdd/010-photo-video-source/T01-define-capture-date` の HEAD(`integration_test/creation_time_probe*.dart`)。
branch の移動は不要(`/workspace` はすでにこの branch にある)。

## これまでの観測で分かったこと(手順の理由)

- 1回目: `statx` の作成時刻は返らない。照会の command は二重引用符の入れ子で失敗した(直した)。
- 2回目: **アプリが path で書いた file は MediaStore に載らない**(照会で directory の行しか出なかった)。また、
  `flutter test` は**終わるとアプリを消す**ので、次の実行では「すべてのファイルへのアクセス」が外れ、書き込みが権限で失敗した。
- そこで3回目は、**`adb shell` で file を置いて MediaStore に載せ**、それをアプリに改名させる。アプリは先に入れて権限を与え、
  `--no-uninstall` で消さずに走らせる。

## 使う端末

いつもの電話のエミュレータ(Android 11 以上)。起動は
[`docs/development/emulator-verification.md`](../../../../docs/development/emulator-verification.md)。
以下の `<device_id>` は `flutter devices` で確かめる(前回は `emulator-5554`)。

PowerShell で、先に adb の場所を変数へ入れておく(以下はこれを使う)。

```powershell
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
```

## 手順1 — 前回の残りを消す

```powershell
& $adb shell rm -r /storage/emulated/0/Download/brm-010-probe
```

**期待**: 何も出ないか、`No such file or directory`。どちらでもよい。

## 手順2 — アプリを入れて権限を与える

```powershell
flutter pub get
flutter install --debug -d <device_id>
& $adb shell appops set --uid com.example.batch_rename_master MANAGE_EXTERNAL_STORAGE allow
& $adb shell appops get --uid com.example.batch_rename_master MANAGE_EXTERNAL_STORAGE
```

**期待**: 最後の行が `MANAGE_EXTERNAL_STORAGE: allow`。

## 手順3 — shell で file を置き、MediaStore に載ったことを確かめる

```powershell
& $adb shell 'mkdir -p /storage/emulated/0/Download/brm-010-probe && echo x > /storage/emulated/0/Download/brm-010-probe/brm010-shell.txt'
& $adb shell 'content query --uri content://media/external/file --projection _display_name:_data:date_added:date_modified:datetaken --where _display_name\ LIKE\ \''brm%\'''
```

**期待**: `_display_name=brm010-shell.txt` の行があり、`date_added=` に数字が入っている。**出力をそのまま貼ってほしい**
(行が無くても、そのまま貼ればよい)。

## 手順4 — 観測を走らせる(アプリを消さない)

**手順3から少なくとも10秒あけてから**実行する(`DATE_ADDED` は秒単位なので、置いた時刻と改名の時刻を見分けるため)。

```powershell
flutter test integration_test\creation_time_probe_test.dart -d <device_id> --no-uninstall
```

**期待**: `=== 010:T04 作成時刻の観測 ===` から `=== ここまで。この出力をそのまま貼って返してください ===` までに、
`shell で置いた file: 改名する前` と `1回目の改名の後`・`2回目の改名の後` の段が出る。**`=== 010:T04` から最後の command の行まで、そのまま貼ってほしい。**
失敗したときは `=== 010:T04 作成時刻の観測: 途中で失敗した ===` と理由が出るので、それを貼ればよい。

## 手順5 — 改名の後の DATE_ADDED を読む

手順4の出力の最後に出た command(下と同じもの)を実行する。

```powershell

```

**出力をそのまま貼ってほしい。**

## 手順6 — 後片付け

```powershell
& $adb shell rm -r /storage/emulated/0/Download/brm-010-probe
```

## 報告

手順3・4・5の出力を、そのまま貼って返してほしい。読み解きは Agent が行う。
