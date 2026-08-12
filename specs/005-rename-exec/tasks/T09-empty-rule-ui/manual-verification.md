# 手動確認: ルール未設定のときに実行を止め、下部バーへ導線をまとめること

## 確認すること

3つあります。

1. ルールが空の間は名前を変更できず、代わりに「未設定」と設定への導線が出ること(REQ-019 / REQ-020)。
2. ルール設定と実行のボタンが、参考デザインどおり一覧の下の固定バーに縦並びで出ること。
3. 実行後の結果トーストに出る「元に戻す」が、実際に押せること。

3つ目が今回いちばん見てほしい点です。自動テストでは押せることまで確認しましたが、実機のタップ範囲とSafeArea(画面下端のジェスチャーバー)まではテストで再現できません。

## 事前準備

Windowsデスクトップアプリで確認します。branchの移動は不要です。Agentが`asdd/005-rename-exec/T09-empty-rule-ui`(commit `<記入>`)を用意した状態で待っています。

PowerShellで専用folderとファイルを作ります。

```powershell
$emptyRuleFixture = Join-Path $env:TEMP 'asdd-empty-rule-check'
Remove-Item -LiteralPath $emptyRuleFixture -Recurse -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $emptyRuleFixture
Set-Content -LiteralPath (Join-Path $emptyRuleFixture 'photo.txt') -Value 'empty-rule-original'
$emptyRuleFixture
```

**以降のPowerShellは、この同じwindowで続けて実行してください。** `$emptyRuleFixture`はwindowを閉じると消えるため、別windowで実行すると`LiteralPath`にnullが渡り`引数が null であるため、パラメーター 'LiteralPath' にバインドできません`になります。その場合は上の1行目(`$emptyRuleFixture = ...`)だけをもう一度実行すれば復帰します。

アプリを起動したら、**ウィンドウ幅を840dpより狭く**してください(横幅をおよそ半分以下に縮める)。この幅がモバイル相当のレイアウトで、今回の下部バーが出ます。広いままだと右にルールペインが出る2ペイン表示になり、確認したい導線が出ません。

## 1. ルールを空にする

007の永続化で前回のルールが復元されるため、まず空にします。

1. 下部バーの「ルールを編集」を押し、開いたシートでトークンをすべて削除します。シートを閉じます。

   - 確認: 一覧の上に**赤い警告帯が出ない**。代わりに「命名ルールが未設定です。ルールを設定すると変更後の名前を確認できます」という案内が出る。
   - 確認: 下部バーのボタンが「＋ 変更する名前を設定する」に変わる(枠線だけの控えめな表示から、塗りつぶしの目立つ表示になる)。
   - 確認: その下の実行ボタンが灰色で押せなくなり、ラベルが「ルールを設定してください」になる。

2. 押せないはずの実行ボタンを実際に押してみます。

   - 確認: 何も起きない。トーストも出ない。

3. PowerShellで確認します。

```powershell
Get-ChildItem -LiteralPath $emptyRuleFixture
```

   - 確認: `photo.txt`のまま、1件も名前が変わっていない。

## 2. 位置を確認する

- 確認: ルール設定ボタンと実行ボタンが**両方とも一覧の下**にあり、上下に並んでいる。一覧の上や、離れた場所に分かれていない。
- 確認: 下部バーが画面下端に張り付き、ボタンがWindowsのウィンドウ枠に隠れていない。

## 3. トークンを足して戻す

1. 「＋ 変更する名前を設定する」を押し、「元の名前」と、リテラル「_ok」を追加してシートを閉じます。

   - 確認: 未設定の案内が消える。
   - 確認: 一覧の「変更後」に`photo_ok.txt`が出る。
   - 確認: 下部バーのボタンが「ルールを編集」(控えめな表示)に戻り、実行ボタンが押せるようになってラベルが「名前を変更」になる。

2. もう一度シートを開き、トークンをすべて削除して閉じます。

   - 確認: 未設定の案内が戻り、実行ボタンがまた押せなくなる。

3. 「元の名前」と「_ok」をもう一度足して、実行できる状態に戻します。

## 4. 実行して「元に戻す」を押す

1. 「名前を変更」を押します。

   - 確認: 画面下に「1 件を改名しました」のトーストが出て、その右に「元に戻す」がある。
   - 確認: **トーストが下部バーに重なっていても、「元に戻す」の文字を指/クリックで押せる**。押しづらい、反応しない、下のバーのボタンが反応してしまう、といったことがない。

2. 5秒以内に「元に戻す」を押します。

   - 確認: 「1 件を元に戻しました」と表示され、一覧とfolder内の名前が`photo.txt`へ戻る。
   - 確認: 「元に戻す」が消える。

3. もう一度「名前を変更」を押し、今度は何も押さずに6秒待ちます。

   - 確認: トーストごと消え、「元に戻す」が残らない。

4. PowerShellで確認します。

```powershell
Get-ChildItem -LiteralPath $emptyRuleFixture
Get-Content -LiteralPath (Join-Path $emptyRuleFixture 'photo_ok.txt')
```

   - 確認: `photo_ok.txt`が残り、内容が`empty-rule-original`のまま。

## 後片付け

```powershell
Remove-Item -LiteralPath $emptyRuleFixture -Recurse -ErrorAction SilentlyContinue
```

## 結果の返し方

```text
空ルールで警告帯ではなく未設定の案内が出た:
空ルールで実行ボタンが押せず、実ファイルも変わらなかった:
設定ボタンと実行ボタンが一覧の下に縦並びで出た:
トークン追加で通常状態へ戻り、削除で未設定へ戻った:
結果トーストの「元に戻す」が問題なく押せた:
5秒以内のundoで実ファイルがphoto.txtへ戻った:
6秒後は「元に戻す」が消えた:
補足:
```

各行を`PASS`、`FAIL`、`確認不能`で返してください。FAIL時は画面の文言とPowerShell出力を添えてください。押しにくさや見た目の違和感は`補足`へ書いてください。

## Evidence identity

- Commit: `d707e6d`(この確認以後、code / dependency / build設定の差分なし。以後の差分は証拠・記録・`origin/dev`のAGENTS.md取り込みのみ)
- Build/artifact: Windows desktop build(人間がhostでbuild)
- Environment/device: Windows / ウィンドウ幅840dp未満
- Fixture/data: `%TEMP%\asdd-empty-rule-check\photo.txt`
- Observer: 開発者
- Observed at: 2026-08-12
- Status: **PASS**(会話で報告。checklistを順番に実施し、全項目の動作を確認)
- Notes: 手順のPowerShellで`引数が null であるため、パラメーター 'LiteralPath' にバインドできません`が出た。`$emptyRuleFixture`がwindowをまたいで残らないための手順側の不備で、UIの確認結果には影響していない(rename・undo・実ファイルの変化は確認済み)。手順へ注意書きを追加した。
