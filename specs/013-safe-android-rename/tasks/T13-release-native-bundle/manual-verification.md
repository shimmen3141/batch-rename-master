# 手動確認: release buildでnative改名が動く(Androidエミュレータ)

**対象buildは、`lib/`・`hook/`・`src/`の内容が commit `a13877b` と同一のもの**である。branch `asdd/013-safe-android-rename/T13-release-native-bundle` のHEADからbuildすればこれを満たす。**code・dependency・build設定が変わったら、この結果は再利用しない。**

**Androidエミュレータで確認する**(`008:T39`で開発者が決めた方針)。**debugではなく`--release`で起動する**のがこの確認の本体である。

## 使う端末と準備

- 共通の手順は[`docs/development/emulator-verification.md`](../../../../docs/development/emulator-verification.md)。**host側でworktree `.worktrees/013-T13-release-native-bundle` へ`cd`**して実行する(branchの移動は不要)。
- `adb devices`にエミュレータが**1台だけ**出ていることを確かめる(1台なら`flutter run`は`-d`無しでその端末を使う。**PowerShellでは`-d <emulator>`の`<`がそのまま書けない**ので、指定するなら`-d emulator-5554`のように実際のIDを書く)。

### 準備するファイル

確認専用のフォルダ`Download/asdd-013-t13`だけを使い、**既にあれば何も置かずに止まる**。

```powershell
$adbPath = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
$d = '/sdcard/Download/asdd-013-t13'
$existing = "$(& $adbPath shell "if [ -e $d ]; then echo exists; fi")".Trim()
if ($existing -eq 'exists') {
  Write-Host '端末に Download/asdd-013-t13 が既にあります。何も置かずに止めました。' -ForegroundColor Red
} else {
  & $adbPath shell "mkdir -p $d"
  & $adbPath shell "echo one > $d/one.txt"
  & $adbPath shell "echo two > $d/two.txt"
  & $adbPath shell "echo keep > $d/x_two.txt"
  & $adbPath shell "ls $d"
}
```

**期待**: `one.txt` `two.txt` `x_two.txt` の3つが出る。

**後片付け**: 確認が終わったら、端末のファイルアプリで`Download/asdd-013-t13`を消してよい(中身はすべてこの手順で置いたもの)。

## 1. release buildが通る

```powershell
flutter pub get
flutter run --release
```

- **`Hook.build hook ... has invalid output` / `does not have a link hook` が出ない。** アプリが起動する。
- 途中の警告(Javaの restricted method、clang の max-page-size、依存の更新通知)は今回の対象外で、出てもよい。

## 2. release版で改名が動く

1. 「ファイルを選ぶ」→「すべて」→ `Download` → `asdd-013-t13` で **`one.txt`と`two.txt`だけ**を選んで確定する(`x_two.txt`は選ばない)。
2. 命名ルールを「`x_` + 元の名前」にする(文字列のトークン`x_`の後ろに元の名前)。
3. 一覧で、`two.txt`の変更後名が`x_two.txt`と衝突する旨の警告が出ることを見る。
4. 実行する。

**こうなってほしい**

- 実行が成功する(「ライブラリを読めない」「改名できない」の類のエラーが出ない)。
- PowerShellで`& $adbPath shell "ls /sdcard/Download/asdd-013-t13"`を実行すると、
  **`x_one.txt`**、既存の**`x_two.txt`(中身は`keep`のまま)**、**`x_two (1).txt`** が並ぶ。`one.txt`と`two.txt`は無い。
- 既存の`x_two.txt`は**上書きされていない**: `& $adbPath shell "cat /sdcard/Download/asdd-013-t13/x_two.txt"` が `keep` を返す。

## 報告

結果は会話で自由に書いてよい。決まった書式は不要である。1でbuildが通ったか、2の`ls`と`cat`の出力を貼ってほしい。
