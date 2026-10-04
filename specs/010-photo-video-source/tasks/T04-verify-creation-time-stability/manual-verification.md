# 手動確認: 改名しても作成時刻が変わらないか(Androidエミュレータ)

アプリの画面は操作しない。**アプリと同じパッケージ・同じ権限で動く調査用のテスト**を端末で走らせ、
製品と同じ改名を2回行って、その前後で「ファイルがこの端末に作られた時刻」が変わるかを見る。

**どの結果でも不具合ではない。** 分かるのは、ダウンロードやスクリーンショットに作成日時を付ける経路に、
どの値を使えるかである(`010:T04` の task.md)。

対象: branch `asdd/010-photo-video-source/T01-define-capture-date` の HEAD(`integration_test/creation_time_probe*.dart`)。
branch の移動は不要(`/workspace` はすでにこの branch にある)。

## 使う端末

いつもの電話のエミュレータ(Android 11 以上)。起動は
[`docs/development/emulator-verification.md`](../../../../docs/development/emulator-verification.md)。

## 手順1 — 権限

このテストは `Download/` へ書く。「すべてのファイルへのアクセス」が要る(アプリで許可済みなら `allow` のはず)。

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" shell appops get --uid com.example.batch_rename_master MANAGE_EXTERNAL_STORAGE
```

**期待**: `MANAGE_EXTERNAL_STORAGE: allow`。`allow` でなければ次を実行してから進む。

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" shell appops set --uid com.example.batch_rename_master MANAGE_EXTERNAL_STORAGE allow
```

## 手順2 — 観測を走らせる

リポジトリのルートで、デバイスIDを確認してから実行する。

```powershell
flutter pub get
flutter devices
flutter test integration_test\creation_time_probe_test.dart -d <device_id>
```

**期待**: 10秒ほどで終わり、`=== 010:T04 作成時刻の観測 ===` から
`=== ここまで。この出力をそのまま貼って返してください ===` までと、その後の
`--- DATE_ADDED を読む command` の1行が出る。**`=== 010:T04` から最後の command の行まで、そのまま貼って返してほしい。**

## 手順3 — DATE_ADDED を読む

手順2の出力の最後に出た command を、**そのまま** PowerShell で実行する(下と同じもの)。

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" shell "content query --uri content://media/external/file --projection _display_name:date_added:date_modified:datetaken --where \"_data LIKE '/storage/emulated/0/Download/brm-010-probe/%'\""
```

**期待**: `Row: 0 _display_name=brm-010-control.txt, date_added=…` のような行が2行(`brm-010-control.txt` と
`brm-010-a-renamed-2.txt`)。**出力をそのまま貼って返してほしい。** `No result found.` やエラーでも、そのまま貼ればよい。

## 手順4 — 後片付け

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" shell rm -r /storage/emulated/0/Download/brm-010-probe
```

## 報告

手順2と手順3の出力を、そのまま貼って返してほしい。読み解きは Agent が行う。
