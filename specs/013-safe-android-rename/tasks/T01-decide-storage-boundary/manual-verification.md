# 手動確認: 013:T01 spike S-2(`renameat2(RENAME_NOREPLACE)`)

## この確認で知りたいこと

**Androidで「既存fileを黙って上書きしないrename」が実現できるか。**

005は「目標名のfileが既にあるなら、置換せずに失敗する」ことを契約にしている(INV-002)。Linuxには`renameat2`に`RENAME_NOREPLACE`というフラグがあり、これを付けるとkernelが不可分に失敗させる。

ただしAndroid 11以降の`/sdcard`はMediaProviderのFUSEを経由するので、**このフラグが素通りするか、無視されるか、拒否されるかが資料から分かりません**。実機で確かめるしかありません。

**結果次第でAndroidの方針が決まります。**

- フラグが効く → Androidでもrenameを実装する方向へ進める
- 効かない → **Androidはこれまでどおり「未対応」のまま**にする(これは失敗ではなく、保証を下げないという判断です)

## 所要時間と前提

**15〜20分**(NDKが入っていれば10分程度)。

| 必要なもの | 確認方法 |
|---|---|
| Android実機またはemulator(Android 11以上) | 設定 > デバイス情報 > Androidバージョン |
| `adb`が使えること | `adb devices` でデバイスが1つ出る |
| Android NDK | 下の手順1で確認する |

**アプリのbuildは不要です。** 小さなCのプログラムを1つコンパイルして、`adb`で送って動かすだけです。プログラムは`spike/renameat2_spike.c`に用意してあります。

このcontainerにはAndroid SDK/NDKもemulatorも無いため(`AGENTS.md`の前提)、host側でお願いしています。

## 事前準備

**PowerShellを1つ開いてください。** 以下のコマンドはすべて同じPowerShellで、上から順に実行できます。**変数は使っていません**ので、途中で別のPowerShellに変わっても動きます。

デバイスが見えることを確認します。

```powershell
adb devices
```

`device`と表示された行が1つ出ればOKです。

## 手順1 — NDKのコンパイラを見つける

```powershell
Get-ChildItem "$env:LOCALAPPDATA\Android\Sdk\ndk" -Directory | Select-Object Name
```

**期待**: `27.0.12077973`のようなバージョン番号のフォルダが1つ以上出る。

出なかった場合、NDKが入っていません。Android Studio > SDK Manager > SDK Tools > **NDK (Side by side)** にチェックを入れてインストールしてください。**入れたくなければここで止めてください。** その旨を報告いただければ、別の方法を考えます。

次に、デバイスのCPUを調べます(コンパイル先が変わります)。

```powershell
adb shell getprop ro.product.cpu.abi
```

**期待**: `arm64-v8a`(実機に多い)または `x86_64`(emulatorに多い)。

## 手順2 — コンパイルする

**下のコマンドの `27.0.12077973` を、手順1で出たバージョンに置き換えてください。**

`arm64-v8a` だった場合:

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\ndk\27.0.12077973\toolchains\llvm\prebuilt\windows-x86_64\bin\aarch64-linux-android24-clang.cmd" -static -o "$env:TEMP\renameat2_spike" "specs\013-safe-android-rename\tasks\T01-decide-storage-boundary\spike\renameat2_spike.c"
```

`x86_64` だった場合:

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\ndk\27.0.12077973\toolchains\llvm\prebuilt\windows-x86_64\bin\x86_64-linux-android24-clang.cmd" -static -o "$env:TEMP\renameat2_spike" "specs\013-safe-android-rename\tasks\T01-decide-storage-boundary\spike\renameat2_spike.c"
```

**このコマンドはリポジトリのルート(`batch-rename-master`フォルダ)で実行してください。**

**期待**: 何も表示されずにプロンプトが戻る。警告が出ても、次のコマンドでファイルができていれば問題ありません。

```powershell
Get-Item "$env:TEMP\renameat2_spike"
```

**期待**: ファイルが1つ表示される(数百KB〜数MB)。

## 手順3 — デバイスへ送る

```powershell
adb push "$env:TEMP\renameat2_spike" /data/local/tmp/renameat2_spike
adb shell chmod 755 /data/local/tmp/renameat2_spike
```

**期待**: `1 file pushed` のような表示。2つ目は何も表示されません。

## 手順4 — 対照実験(まず普通のファイルシステムで試す)

`/data/local/tmp`はFUSEを通らない普通のext4です。**ここでフラグが効かなければ、`/sdcard`を試す意味がありません。**

```powershell
adb shell /data/local/tmp/renameat2_spike /data/local/tmp
```

**期待する出力**(末尾の判定行):

```text
=== 判定 ===
A) RENAME_NOREPLACE は有効。候補Eは成立しうる。
```

**出力を全部コピーして報告してください。**

`B)` や `C)` が出た場合は、**この時点で報告して止めてください**。手順5へ進む必要がありません(kernelレベルでフラグが使えないことになります)。

## 手順5 — 本番(共有ストレージ)

**これが本命です。**

```powershell
adb shell /data/local/tmp/renameat2_spike /sdcard
```

**期待する出力**: 手順4と同じく `A)`。

ただし**`B)` や `C)` になる可能性が十分にあります。それがこの確認の目的です。** どの結果でも「失敗」ではありません。

`/sdcard`へ書き込めずcase 2も失敗する場合は、プログラムがその旨を追加で表示します。その場合は次を試してから、両方の結果を報告してください。

```powershell
adb shell /data/local/tmp/renameat2_spike /sdcard/Download
```

## 手順6 — 片付け

```powershell
adb shell rm /data/local/tmp/renameat2_spike
```

プログラムは自分で作ったテスト用ファイルを自分で消すので、**`/sdcard`側に消し残しはありません**。念のため確認するなら:

```powershell
adb shell ls /sdcard/spike-c.txt /sdcard/spike-d.txt /sdcard/spike-e.txt
```

**期待**: 3つとも `No such file or directory`。

## 報告してほしいこと

会話で自由に書いてください。形式は問いません。

1. 手順4の出力(全部)
2. 手順5の出力(全部)
3. 使ったデバイス(実機かemulatorか、Androidのバージョン、CPU)
4. うまくいかなかった手順があれば、そのコマンドとエラー

**判定はこちらで行います。** プログラムが出す `A)` `B)` `C)` `D)` はあくまで目安なので、**生の戻り値とerrnoをそのまま送っていただければ十分です。**

## 別の端末でも試せる場合

filesystemによって挙動が変わりえます。余裕があれば、**Androidのバージョンが違う端末**や、**SDカード/USB OTG**でも手順5を実行していただけると判断の確度が上がります。**必須ではありません。**

## この確認のあとAgentがすること

- 結果を`task.md`の作業記録へ記録する。
- `A)`なら候補E(`MANAGE_EXTERNAL_STORAGE` + `renameat2`)のADR案と、Play審査の論点整理を作る。
- `B)`/`C)`ならAndroid未対応維持のADR案を作る。005の契約は変えない。
- どちらも**人間の承認前に実装しない**。

候補の全体像と一次資料は[`research-matrix.md`](research-matrix.md)にあります。
