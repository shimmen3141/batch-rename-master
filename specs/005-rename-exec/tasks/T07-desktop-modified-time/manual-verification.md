# 手動確認: 更新日時を一覧の並び順にずらす

## 確認すること

改名したファイルの更新日時を、**画面に並んでいる順**に少しずつずらす設定です。次に見返したときに「更新日時順＝意図した並び」になるようにするための機能で、**既定はOFF**です。

自動テストでは、順序・失敗時の挙動・設定の出し分けまで検査しています。実機でしか分からないのは次の3つです。

- **実際のファイルの更新日時が本当に書き換わるか**
- **Androidでは設定そのものが出ないこと**(更新日時を書き換える手段が無いため)
- 更新日時の更新だけが失敗したとき、**改名は成功として残るか**

## 進め方について

**PowerShellのコマンドは、すべてそのままコピーして貼れば動きます。** 前のコマンドで作った変数を引き継がないので、別のウィンドウで実行しても、順番を飛ばしても失敗しません。

各ステップの最初に**ファイルを作り直します。** 改名を重ねると `a_m_n_o.txt` のように名前が伸びていくため、毎回同じ状態から始めます。

コマンドが使えない場合は、エクスプローラーで `C:\asdd-fixtures\mtime` を開き、**表示 → 詳細**にして「更新日時」列を見ても構いません。ただし秒までは出ないので、**「更新日時」列でソートしたときの並び順**で判断してください。

## 事前準備

起動手順は[`docs/development/emulator-verification.md`](../../../../docs/development/emulator-verification.md)に従ってください。**branchの移動は不要です。**Agentが対象のbranchとcommitを用意した状態で待ちます。

必要なもの: Windows desktop build と、Android(エミュレータまたは実機)。Androidは設定が出ないことの確認だけなので短時間です。

## Windows desktop

### 1. 設定は既定でOFF

1. ファイルを作ります。**更新日時をわざと逆順**(a が最新)にしておきます。

```powershell
Remove-Item -LiteralPath 'C:\asdd-fixtures\mtime' -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path 'C:\asdd-fixtures\mtime' | Out-Null
'a','b','c' | ForEach-Object { Set-Content -LiteralPath "C:\asdd-fixtures\mtime\$_.txt" -Value $_ }
(Get-Item 'C:\asdd-fixtures\mtime\a.txt').LastWriteTime = '2020-01-03 10:00:00'
(Get-Item 'C:\asdd-fixtures\mtime\b.txt').LastWriteTime = '2020-01-02 10:00:00'
(Get-Item 'C:\asdd-fixtures\mtime\c.txt').LastWriteTime = '2020-01-01 10:00:00'
Get-ChildItem 'C:\asdd-fixtures\mtime' | Select-Object Name, @{n='更新日時';e={$_.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')}}
```

2. アプリで「ファイルを選ぶ」→「**すべて**」から `a.txt` `b.txt` `c.txt` を選びます。
3. 下部のバーを見ます。
   - 確認: 「**更新日時を一覧の並び順にずらす**」というチェックボックスがある。
   - 確認: **チェックが入っていない**(既定OFF)。

4. ルールを設定します(「変更する名前を設定する」→ `元の名前` と 文字列 `_m` を追加)。
5. OFFのまま「名前を変更」を押します。
6. 確認します。

```powershell
Get-ChildItem 'C:\asdd-fixtures\mtime' | Select-Object Name, @{n='更新日時';e={$_.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')}}
```

   - 確認: 名前は `a_m.txt` `b_m.txt` `c_m.txt` になっている。
   - 確認: **更新日時は 2020-01-03 / 01-02 / 01-01 のまま変わっていない**。

### 2. ONにすると一覧の並び順にずれる

1. ファイルを作り直します(前のステップで名前が変わっているため)。

```powershell
Remove-Item -LiteralPath 'C:\asdd-fixtures\mtime' -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path 'C:\asdd-fixtures\mtime' | Out-Null
'a','b','c' | ForEach-Object { Set-Content -LiteralPath "C:\asdd-fixtures\mtime\$_.txt" -Value $_ }
(Get-Item 'C:\asdd-fixtures\mtime\a.txt').LastWriteTime = '2020-01-03 10:00:00'
(Get-Item 'C:\asdd-fixtures\mtime\b.txt').LastWriteTime = '2020-01-02 10:00:00'
(Get-Item 'C:\asdd-fixtures\mtime\c.txt').LastWriteTime = '2020-01-01 10:00:00'
```

2. アプリで一覧を選び直します(「ファイルを選ぶ」→「すべて」→3件)。
3. 一覧の並び順を「**元の名前順**」にします(a, b, c の順に並びます)。
4. 「更新日時を一覧の並び順にずらす」に**チェックを入れます**。
5. ルールはステップ1と同じ(`元の名前` + `_m`)のまま、「名前を変更」を押します。
6. 確認します。

```powershell
Get-ChildItem 'C:\asdd-fixtures\mtime' | Sort-Object LastWriteTime | Select-Object Name, @{n='更新日時';e={$_.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')}}
```

   - 確認: 3件とも更新日時が**今の日時**に変わっている(2020年ではなくなっている)。
   - 確認: 更新日時の古い順に **`a_m.txt` → `b_m.txt` → `c_m.txt`** と並ぶ(一覧の並び順と一致)。
   - 確認: 3件の更新日時が**すべて違う**(同じ値に潰れていない)。間隔がきっちり1秒でなくても構いません。ディスクによっては丸められます。

### 3. 並び替えると、ずれる順序も追随する

> **ドラッグの取っ手は、ルールに連番トークンがあるときだけ出ます。** 連番が無いと、並び替えても変更後の名前が変わらない(元の名前・文字列・日時は並び順に依存しない)ため、意味のない操作を見せない作りです。取っ手を出すために連番を足すのであって、連番が順序を変えるわけではありません。

1. ファイルを作り直します。

```powershell
Remove-Item -LiteralPath 'C:\asdd-fixtures\mtime' -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path 'C:\asdd-fixtures\mtime' | Out-Null
'a','b','c' | ForEach-Object { Set-Content -LiteralPath "C:\asdd-fixtures\mtime\$_.txt" -Value $_ }
```

2. アプリで一覧を選び直し、ルールを **`元の名前` + 連番(開始番号 1・桁数 1)** にします。
   - 確認: 各行の右端に**ドラッグの取っ手が出る**。
3. 一覧の並び順を「元の名前順」にしてから、ドラッグで **c, b, a** の順に入れ替えます。
   - 確認: 並び順の表示が「カスタム順」に変わる。
4. 「更新日時を一覧の並び順にずらす」がONのまま、「名前を変更」を押します。
5. 確認します。

```powershell
Get-ChildItem 'C:\asdd-fixtures\mtime' | Sort-Object LastWriteTime | Select-Object Name, @{n='更新日時';e={$_.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')}}
```

   - 確認: 更新日時の古い順に **`c` で始まる名前 → `b` で始まる名前 → `a` で始まる名前** と並ぶ(画面で入れ替えた順と一致)。
   - 連番が付くので、名前は `c1.txt` `b2.txt` `a3.txt` のようになります。

### 4. 更新日時の更新だけが失敗しても、改名は成功のまま

1. ファイルを作り直し、`b.txt` だけ読み取り専用にします。

```powershell
Remove-Item -LiteralPath 'C:\asdd-fixtures\mtime' -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path 'C:\asdd-fixtures\mtime' | Out-Null
'a','b','c' | ForEach-Object { Set-Content -LiteralPath "C:\asdd-fixtures\mtime\$_.txt" -Value $_ }
Set-ItemProperty -LiteralPath 'C:\asdd-fixtures\mtime\b.txt' -Name IsReadOnly -Value $true
Get-ChildItem 'C:\asdd-fixtures\mtime' | Select-Object Name, IsReadOnly
```

2. アプリで一覧を選び直し、ルールを `元の名前` + 文字列 `_p` にします。チェックはONのままです。
3. 「名前を変更」を押します。
   - 確認: 画面下のメッセージに「**3 件を改名しました**」と出る。
   - 確認: 続けて「**改名は成功しましたが、1 件の更新日時は変更できませんでした**」と出る。
   - 確認: 改名の**失敗**としては表示されない。

> 読み取り専用でも更新日時を書き換えられる環境では、この失敗が起きません。その場合はメッセージが「3 件を改名しました」だけになります。**その旨だけ教えてください**(実装の問題ではなく、環境で再現しなかっただけです)。

4. 確認します。

```powershell
Get-ChildItem 'C:\asdd-fixtures\mtime' | Select-Object Name, IsReadOnly, @{n='更新日時';e={$_.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')}}
```

   - 確認: 3件とも名前が `_p` で終わっている(**改名は成功している**)。

## Android

1. Androidでアプリを起動し、ファイルを選んで下部のバーを見ます。
   - 確認: 「**更新日時を一覧の並び順にずらす**」のチェックボックスが**出ない**。
   - Androidには更新日時を書き換える手段が無いため、効かない設定を見せない作りです。

## 後片付け

```powershell
Get-ChildItem 'C:\asdd-fixtures' -Recurse -File | ForEach-Object { $_.IsReadOnly = $false }
Remove-Item -LiteralPath 'C:\asdd-fixtures' -Recurse -Force -ErrorAction SilentlyContinue
```

## 結果の伝え方

会話でそのまま教えてください。書式は問いません。更新日時を確認した出力(またはエクスプローラーで見た並び)を教えていただけると助かります。できなかったstepは「できなかった」で十分です。

結果を受け取ったらAgentが`task.md`へ記録し、受け入れ条件を満たしたかreviewします。
