# 手動確認: 端末で排他 rename が本当に効くか

この確認は、**Androidで名前を変更できるか**ではない。それは `013:T07` で確かめた。
ここで知りたいのは **`renameat2(RENAME_NOREPLACE)` が実際に効いている端末はどれか**、
つまり **005 INV-002(既存ファイルを置換しない)がどこまで完全に成立しているか**である。

**効いていなくても機能は動く。** 効かない環境では実在確認をしてから通常の rename へ
落ちる(005 contract revision 4 が受容した劣化)。**したがって、この確認で「効かない」と
出ても不具合ではない。** 分かるのは保証の水準である。

## なぜアプリの画面で確かめられないのか

アプリは、目標名が既にあれば**改名の前に気づいて別の経路へ行く**。したがって
**画面をどう操作しても、フラグが効いているかどうかで見え方は変わらない**。
劣化は設計どおり透過である。

そこで、**アプリと同じパッケージ・同じ権限で動くテスト**を端末で走らせて、
内部の関数を直接呼ぶ。アプリを操作する手順はこの確認には無い。

## 使う端末

**Android 11 以上**。エミュレータでよい。起動手順は
[`docs/development/emulator-verification.md`](../../../../docs/development/emulator-verification.md)。

**実機・別のAPI level・SDカードがあれば、それも見たい**(手順4〜6)。無ければ
「無い」と書いてもらえれば、そのように記録する。

## 手順1 — 権限を与える

このテストは共有ストレージへ書く。**「すべてのファイルへのアクセス」が要る。**

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" shell appops set --uid com.example.batch_rename_master MANAGE_EXTERNAL_STORAGE allow
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" shell appops get --uid com.example.batch_rename_master MANAGE_EXTERNAL_STORAGE
```

**期待**: 2つ目のコマンドが `MANAGE_EXTERNAL_STORAGE: allow` と出す。

`013:T07` の確認でアプリから許可済みなら、ここは `allow` のままのはずである。
**アプリがまだ入っていない端末では、先に1度アプリを入れてから実行する**
(`flutter run -d <device_id>` を1回動かして終了させれば入る)。

## 手順2 — 観測を走らせる(この確認の中心)

リポジトリのルートで、**デバイスIDを確認してから**実行する。

```powershell
flutter pub get
flutter devices
flutter test integration_test\android_storage_probe_test.dart -d <device_id>
```

**`flutter pub get` を飛ばさないでほしい。** このタスクで依存(`integration_test`)が
増えており、**コンテナとホストで `.pub-cache` が別**なので、ホスト側では取り直しが要る
([`emulator-verification.md`](../../../../docs/development/emulator-verification.md))。

**期待**: 端末にアプリが入り、`=== 013:T08 排他 rename の観測 ===` から
`=== ここまで。この出力をそのまま貼って返してください ===` までの出力が出る。
**その範囲をそのまま貼って返してほしい。**

出力には、mount されている保存場所ごとに次が並ぶ。**共有ストレージ(FUSE)だけでなく、
比較用に「app の内部領域(非FUSE の対照)」も1件出る** — フラグを解釈しているのが FUSE 自身
なのか下の filesystem なのかを、後から切り分けるためである。

- `排他 rename:` — `nameConflict` なら**フラグが効いている**。`fallbackRequired` なら
  **効かないので通常 rename へ落ちる**。**どちらでも正常である。**
- `目標名の中身:` — `brm-t08-target` のままであること。**変わっていたら重大**である。
- `source の中身:` — `brm-t08-source` のままであること。
- `対照(通常 rename):` — `success` かつ中身が `brm-t08-source` に**置換されている**こと。
  これが起きて初めて「フラグが効いた」と言える(置換できない場所では比較にならない)。

テスト自体は、上の**目標名・source・対照**が崩れたときだけ失敗する。
**`fallbackRequired` では失敗しない。**

失敗した場合も、**出力をそのまま貼ってほしい**。失敗の行に理由が出る。

観測に使ったファイルは `brm-t08-` で始まり、**テストが自分で消す**。もし残っていたら
消してよい(残っていたことも書いてほしい)。

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" shell "ls /sdcard/brm-t08-* /sdcard/Download/brm-t08-* /sdcard/Android/*/com.example.batch_rename_master/ 2>/dev/null"
```

**期待**: 何も出ない(`No such file or directory` でよい)。

**SDカードやUSBを挿している場合は、手順2の出力に出た場所も同じように見てほしい**
(場所は端末によって変わるので、ここに書けない)。

## 手順3 — filesystem の種別を記録する

フラグを解釈するのが FUSE 自身なのか下の filesystem なのかを、後から切り分けられる
ようにする。**判定はしない。記録するだけである。**

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" shell getprop ro.build.version.sdk
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" shell getprop ro.product.model
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" shell stat -f /sdcard
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" shell stat -f /data/local/tmp
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" shell "mount | grep -E ' /storage| /mnt| /data '"
```

**期待**: それぞれ出力が出る。**中身の当否は問わない** — そのまま貼ってほしい。
最後の `mount` は行数が多いことがあるので、**長ければ `/storage` を含む行だけでよい。**

## 手順4 — 別の API level(あれば)

**別のAPI levelのエミュレータがあれば**、それを起動して**手順1・2・3を繰り返す**。
無ければ「無い」と書いてほしい。

`MediaProvider` の FUSE 実装はバージョンごとに変わるため、1つのAPI levelの結果を
全体の結論にできない。**1つでも増えれば、その分だけ成立範囲が分かる。**

## 手順5 — 実機(あれば)

**実機があれば**、USBデバッグを有効にして接続し、**手順1・2・3を繰り返す**。
無ければ「無い」と書いてほしい。

実機はvendorのkernelとfilesystem(f2fs等)で挙動が変わりうる。エミュレータの結果は
実機の証拠にならない。

## 手順6 — SDカード / USB(あれば)

**SDカードやUSBメモリを挿せる端末があれば**、挿した状態で**手順2**を実行する。
挿さっていれば**観測対象に自動で並ぶ**ので、手順は増えない。無ければ「無い」と
書いてほしい。

FAT系のfilesystemはフラグを扱えない可能性がある。**扱えなくても対応外にはしない** —
保証の水準が下がることを記録するだけである。

## 手順7 — Android のビルドが通ること

コンテナにはAndroid SDKが無く、**Agentはビルドを1度も実行できていない。**

```powershell
flutter pub get
flutter build apk --debug
```

**期待**: `Built build\app\outputs\flutter-apk\app-debug.apk` のような行で終わる。
**失敗したら、エラーの最後の20行くらいを貼ってほしい。**

## 報告

結果は会話で自由に書いてよい。**決まった書式や合否の記入は不要**である。

- 手順2の出力(`===` から `===` まで)は**そのまま**貼ってほしい。要約しないでほしい。
- 手順3〜6は「無い」で構わない。
- 気づいたこと(時間がかかった、端末が固まった、など)があればそのまま書いてほしい。
