# 手動確認: 更新日時を一覧の並び順にずらす

## 確認すること

改名したファイルの更新日時を、**画面に並んでいる順**に少しずつずらす設定です。次に見返したときに「更新日時順＝意図した並び」になるようにするための機能で、**既定はOFF**です。

自動テストでは、順序・失敗時の挙動・設定の出し分けまで検査しています。実機でしか分からないのは次の3つです。

- **実際のファイルの更新日時が本当に書き換わるか**(エクスプローラーやPowerShellで見える値)
- **Androidでは設定そのものが出ないこと**(更新日時を書き換える手段が無いため)
- 更新日時の更新だけが失敗したとき、**改名は成功として残るか**

## 事前準備

起動手順は[`docs/development/emulator-verification.md`](../../../../docs/development/emulator-verification.md)に従ってください。**branchの移動は不要です。**Agentが対象のbranchとcommitを用意した状態で待ちます。

必要なもの: Windows desktop build と、Android(エミュレータまたは実機)。Androidは設定が出ないことの確認だけなので短時間です。

確認用ファイルを作ります。**わざと更新日時をバラバラにして**、あとで「ずれたかどうか」が分かるようにします。

```powershell
$dir = 'C:\asdd-fixtures\mtime'
Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $dir
'a','b','c' | ForEach-Object { Set-Content -LiteralPath (Join-Path $dir "$_.txt") -Value $_ }
# 更新日時を意図的に逆順(a が最新)にしておく。
(Get-Item (Join-Path $dir 'a.txt')).LastWriteTime = '2020-01-03 10:00:00'
(Get-Item (Join-Path $dir 'b.txt')).LastWriteTime = '2020-01-02 10:00:00'
(Get-Item (Join-Path $dir 'c.txt')).LastWriteTime = '2020-01-01 10:00:00'
Get-ChildItem -LiteralPath $dir | Select-Object Name, LastWriteTime
```

置き場所は `C:\asdd-fixtures\mtime` です。

## Windows desktop

### 1. 設定は既定でOFF

1. アプリを起動し、「ファイルを選ぶ」→「**すべて**」から `a.txt` `b.txt` `c.txt` を選びます。
2. 下部のバーを見ます。
   - 確認: 「**更新日時を一覧の並び順にずらす**」というチェックボックスがある。
   - 確認: **チェックが入っていない**(既定OFF)。

3. ルールを設定します(「変更する名前を設定する」→ `元の名前` と 文字列 `_m` を追加)。
4. OFFのまま「名前を変更」を押します。
5. PowerShellで確認します。

```powershell
Get-ChildItem -LiteralPath $dir | Select-Object Name, LastWriteTime
```

   - 確認: 名前は `a_m.txt` `b_m.txt` `c_m.txt` になっている。
   - 確認: **更新日時は 2020-01-03 / 01-02 / 01-01 のまま変わっていない**。

### 2. ONにすると一覧の並び順にずれる

1. 一覧の並び順を「**元の名前順**」にします(a, b, c の順で並ぶ)。
2. 「更新日時を一覧の並び順にずらす」に**チェックを入れます**。
3. ルールの文字列を `_m` から `_n` に変えて、「名前を変更」を押します。
4. PowerShellで確認します。

```powershell
Get-ChildItem -LiteralPath $dir | Sort-Object LastWriteTime | Select-Object Name, LastWriteTime
```

   - 確認: 3件とも更新日時が**今の日時**に変わっている。
   - 確認: **`a_n.txt` → `b_n.txt` → `c_n.txt` の順**に古い→新しいと並ぶ(一覧の並び順と一致)。
   - 確認: 3件の更新日時が**すべて違う**(同じ値に潰れていない)。間隔がきっちり1秒でなくても構いません。ディスクによっては丸められます。

### 3. 並び替えると、ずれる順序も追随する

1. 一覧でドラッグして順序を **c, b, a** に入れ替えます。
   - ドラッグの取っ手が出ない場合は、ルールに連番トークンを1つ足してください。
2. ルールの文字列を `_n` から `_o` に変えて、「名前を変更」を押します。
3. PowerShellで確認します。

```powershell
Get-ChildItem -LiteralPath $dir | Sort-Object LastWriteTime | Select-Object Name, LastWriteTime
```

   - 確認: 今度は **`c_o.txt` → `b_o.txt` → `a_o.txt` の順**に古い→新しいと並ぶ。

### 4. 更新日時の更新だけが失敗しても、改名は成功のまま

1. 1件だけ書き換えられないようにします。

```powershell
$target = Join-Path $dir 'b_o.txt'
Set-ItemProperty -LiteralPath $target -Name IsReadOnly -Value $true
Get-ItemProperty -LiteralPath $target | Select-Object Name, IsReadOnly
```

2. アプリで一覧を選び直し(「ファイルを選ぶ」→「すべて」→3件)、チェックはONのまま、ルールの文字列を `_p` に変えて「名前を変更」を押します。
   - 確認: 画面下のメッセージに「**3 件を改名しました**」と出る。
   - 確認: 続けて「**改名は成功しましたが、1 件の更新日時は変更できませんでした**」と出る(件数は環境により変わることがあります)。
   - 確認: 改名の**失敗**としては表示されない。

> 読み取り専用でも更新日時が書き換えられる環境では、この失敗が起きないことがあります。その場合はメッセージが「3 件を改名しました」だけになります。**その旨だけ教えてください。**

3. PowerShellで確認します。

```powershell
Get-ChildItem -LiteralPath $dir | Select-Object Name, LastWriteTime, IsReadOnly
```

   - 確認: 3件とも名前が `_p` になっている(**改名は成功している**)。

## Android

1. Androidでアプリを起動し、ファイルを選んで下部のバーを見ます。
   - 確認: 「**更新日時を一覧の並び順にずらす**」のチェックボックスが**出ない**。
   - Androidには更新日時を書き換える手段が無いため、効かない設定を見せない作りです。

## 後片付け

```powershell
Get-ChildItem -LiteralPath $dir | ForEach-Object { $_.IsReadOnly = $false }
Remove-Item -LiteralPath 'C:\asdd-fixtures' -Recurse -Force -ErrorAction SilentlyContinue
```

## 結果の伝え方

会話でそのまま教えてください。書式は問いません。更新日時を確認したPowerShellの出力を貼っていただけると助かります。できなかったstepは「できなかった」で十分です。

結果を受け取ったらAgentが`task.md`へ記録し、受け入れ条件を満たしたかreviewします。
