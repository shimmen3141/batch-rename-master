# 手動確認: Desktopで5秒以内だけ名前を元に戻せること

## 確認すること

名前変更直後の「元に戻す」が5秒以内だけ使え、押すと実ファイル名も元へ戻ることを確認します。T05のDesktop確認が成功してから、同じアプリで実施してください。

## 事前準備

PowerShellで専用folderとファイルを作ります。

```powershell
$undoFixture = Join-Path $env:TEMP 'asdd-desktop-undo-check'
Remove-Item -LiteralPath $undoFixture -Recurse -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $undoFixture
Set-Content -LiteralPath (Join-Path $undoFixture 'undo.txt') -Value 'undo-original'
$undoFixture
```

アプリのルールはT05と同じ「元の名前」+「_checked」にしてください。

## 5秒以内に元へ戻す

1. 「ファイルを選ぶ」から`undo.txt`を選びます。「名前を変更」を押す前に、次に押す「元に戻す」の位置を確認しておきます。

2. 「名前を変更」を押します。
   - 確認: 「1 件を改名しました」と表示され、一覧とfolder内の名前が`undo_checked.txt`になります。
   - 確認: 「元に戻す」ボタンが表示されます。

3. 5秒以内に「元に戻す」を押します。
   - 確認: 「1 件を元に戻しました」と表示されます。
   - 確認: 一覧とfolder内の名前が`undo.txt`へ戻り、内容は`undo-original`のままです。
   - 確認: `undo_checked.txt`は残りません。

## 5秒後には元へ戻せない

1. もう一度「名前を変更」を押します。
   - 確認: folder内の名前が`undo_checked.txt`になります。

2. 何も押さずに6秒待ちます。
   - 確認: 「元に戻す」ボタンが消えます。

3. PowerShellで確認します。

```powershell
Get-ChildItem -LiteralPath $undoFixture
Get-Content -LiteralPath (Join-Path $undoFixture 'undo_checked.txt')
```

期待結果は、`undo_checked.txt`が残り、内容が`undo-original`のままであることです。

## 後片付け

```powershell
Remove-Item -LiteralPath $undoFixture -Recurse -ErrorAction SilentlyContinue
```

## 結果の返し方

```text
5秒以内にボタンが表示された:
「1 件を元に戻しました」と表示された:
実ファイルがundo.txtへ戻った:
6秒後にボタンが消えた:
6秒後もundo_checked.txtが残った:
補足:
```

各行を`PASS`、`FAIL`、`確認不能`で返してください。FAIL時は画面の文言とPowerShell出力を添えてください。
