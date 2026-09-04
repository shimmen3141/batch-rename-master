# 手動確認: Androidでファイルを変更せず停止し、Desktopで安全に名前を変更できること

## 確認すること

確認するのは次の3点です。

1. Androidでは、現在未対応である理由が画面に表示され、選んだファイルが一切変わらないこと。
2. Desktopでは、実際のファイル名が変更され、続けてもう一度変更できること。
3. Desktopで変更後と同じ名前のファイルが既にある場合、そのファイルを上書きせず停止すること。

## 起動できたと判断する条件

共通の起動方法は[エミュレータ / 実機での確認手順](../../../../docs/development/emulator-verification.md)を参照してください。

Androidで`flutter run -d emulator-5554`を実行した場合、次の両方を満たして初めて「起動成功」です。

- terminalに`Building native assets failed`などのbuild失敗が出ず、`flutter run`がアプリとの接続を保っている。
- emulatorに「一括リネーム」画面が表示され、ボタンを操作できる。

terminalがエラーで終了した場合は、emulatorに以前のアプリ画面が残っていても失敗として、その出力をAgentへ返してください。

## Android確認

### 事前準備

消えても問題ない専用ファイルだけを使います。ホストのPowerShellで次を実行してください。

```powershell
$adbPath = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
$fixturePath = Join-Path $env:TEMP 'asdd-rename-check'
New-Item -ItemType Directory -Force -Path $fixturePath
Set-Content -LiteralPath (Join-Path $fixturePath 'alpha.txt') -Value 'alpha-original'
Set-Content -LiteralPath (Join-Path $fixturePath 'beta.txt') -Value 'beta-original'
Set-Content -LiteralPath (Join-Path $fixturePath 'alpha_checked.txt') -Value 'do-not-overwrite'
& $adbPath shell rm -rf /sdcard/Download/asdd-rename-check
& $adbPath shell mkdir -p /sdcard/Download/asdd-rename-check
& $adbPath push $fixturePath/. /sdcard/Download/asdd-rename-check/
& $adbPath shell ls -l /sdcard/Download/asdd-rename-check
```

`alpha_checked.txt`は、上書きされないことを確認するために先に置いておくファイルです。アプリでは選択しません。

### 操作と期待する結果

1. アプリ下部のルール設定ボタン(「命名ルール」の見出しと設定中のルールの2行。右端に「編集」)を押します。**button のどこを押しても開きます**(`008:T20` で押下対象を一つにした。「編集」は飾りです)。既存のルール要素を各要素の×ですべて削除します。
   - 確認: 「↓ 下のボタンから要素を追加」と表示されます。

2. 「＋ 元の名前」、続けて「＋ 自由テキスト」を押します。「テキスト」と表示された要素を押し、文字列を`_checked`に変えて「確定」を押します。
   - 確認: ルールが「元の名前」「_checked」の順になります。

3. 「ファイルを選ぶ」→「すべて」を押し、`Download/asdd-rename-check`へ移動します。`alpha.txt`と`beta.txt`だけを選び、選択を確定します。
   - 確認: 一覧が2件になり、変更後の名前として`alpha_checked.txt`と`beta_checked.txt`が表示されます。

4. 実行button(`N 件をリネーム`)を押します。
   - 確認: 画面下部に「0 件を改名しました」と、Androidでは安全な改名に現在対応していない旨が表示されます。
   - `成功`や`1 件を改名しました`などと表示された場合はFAILです。

5. 同じ状態でもう一度実行button(`N 件をリネーム`)を押します。
   - 確認: 4と同じく0件で停止し、一覧の現在名は`alpha.txt`と`beta.txt`のままです。

6. PowerShellでファイルの実体を確認します。

```powershell
& $adbPath shell ls -l /sdcard/Download/asdd-rename-check
& $adbPath shell cat /sdcard/Download/asdd-rename-check/alpha.txt
& $adbPath shell cat /sdcard/Download/asdd-rename-check/beta.txt
& $adbPath shell cat /sdcard/Download/asdd-rename-check/alpha_checked.txt
```

期待結果は、`alpha.txt`、`beta.txt`、`alpha_checked.txt`の3件だけが存在し、内容が順に`alpha-original`、`beta-original`、`do-not-overwrite`のままであることです。`beta_checked.txt`は作成されません。

## Desktop確認

### 事前準備

DesktopのPowerShellで次を実行し、表示されたfolderを使います。

```powershell
$desktopFixture = Join-Path $env:TEMP 'asdd-desktop-rename-check'
New-Item -ItemType Directory -Force -Path $desktopFixture
Set-Content -LiteralPath (Join-Path $desktopFixture 'desktop.txt') -Value 'desktop-original'
$desktopFixture
```

Android確認と同じ手順で、ルールを「元の名前」+「_checked」にしてください。

### 正常な名前変更と連続実行

1. 「ファイルを選ぶ」から`desktop.txt`だけを選び、実行button(`N 件をリネーム`)を押します。
   - 確認: 「1 件を改名しました」と表示され、folder内が`desktop_checked.txt`になります。内容は`desktop-original`のままです。

2. 画面の一覧で現在名が`desktop_checked.txt`へ更新されたことを確認し、もう一度実行button(`N 件をリネーム`)を押します。
   - 確認: 「1 件を改名しました」と表示され、folder内が`desktop_checked_checked.txt`になります。内容は変わりません。

### 同名ファイルを上書きしない確認

1. PowerShellでfixtureを作り直します。

```powershell
Remove-Item -LiteralPath $desktopFixture -Recurse
New-Item -ItemType Directory -Force -Path $desktopFixture
Set-Content -LiteralPath (Join-Path $desktopFixture 'conflict.txt') -Value 'source-content'
Set-Content -LiteralPath (Join-Path $desktopFixture 'conflict_checked.txt') -Value 'keep-this-content'
```

2. アプリで`conflict.txt`だけを選び、実行button(`N 件をリネーム`)を押します。
   - 確認: 0件で停止し、「同名のファイルが既に存在します」と表示されます。

3. PowerShellで確認します。

```powershell
Get-ChildItem -LiteralPath $desktopFixture
Get-Content -LiteralPath (Join-Path $desktopFixture 'conflict.txt')
Get-Content -LiteralPath (Join-Path $desktopFixture 'conflict_checked.txt')
```

期待結果は2ファイルとも残り、内容が`source-content`と`keep-this-content`のままであることです。

権限拒否の実OS確認は、OSごとに安全なfixture準備方法が異なるため、この文書だけで権限を変更させません。Agentの自動testでエラー分類を確認し、実OS証拠が追加で必要なら対象OSに限定した手順を別途準備します。

## 後片付け

確認後、不要なら専用fixtureだけを削除してください。

```powershell
& $adbPath shell rm -rf /sdcard/Download/asdd-rename-check
Remove-Item -LiteralPath $fixturePath -Recurse -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $desktopFixture -Recurse -ErrorAction SilentlyContinue
```

## 結果の返し方

次の形式で、各番号を`PASS`、`FAIL`、`確認不能`のいずれかで返してください。FAIL時は画面の文言とcommand出力を添えてください。

```text
Android 1-3（準備と一覧）:
Android 4-5（0件で停止）:
Android 6（3ファイルと内容が不変）:
Desktop 正常変更:
Desktop 連続変更:
Desktop 同名時の無変更:
起動時のエラー:
補足:
```
