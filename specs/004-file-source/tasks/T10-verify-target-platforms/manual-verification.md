# 手動確認: Android SAFとdesktopでファイル選択が仕様どおり動くこと

## 確認すること

読み込み導線を、実際のAndroidとWindowsで確認します。開発側のテストでは確認できないもの——**OSのファイル選択画面が実際に返してくるもの**、**種類ごとの入口**、**Androidがアプリに要求する権限**——が対象です。

特に次の2つは、この確認以外に見る場所がありません。

- 「画像」「動画」を選んでも読み込みを始めず、未実装であることを示す。
- **アプリが「すべてのファイルへのアクセス」を要求しない。** このアプリは、ユーザーが選んだファイルだけを扱う方針です。

## 事前準備

起動手順は[`docs/development/emulator-verification.md`](../../../../docs/development/emulator-verification.md)に従ってください。**branchの移動は不要です。**Agentが対象のbranchとcommitを用意した状態で待ちます。

必要なもの: Android(エミュレータまたは実機)と、Windows desktop build。両方を1回ずつ確認します。

消えてよい確認用ファイルを、**2つのフォルダに分けて**作ります。片方に同名ファイルを置くのが要点です。

```powershell
$a = 'C:\asdd-fixtures\src-a'
$b = 'C:\asdd-fixtures\src-b'
Remove-Item -LiteralPath $a,$b -Recurse -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $a,$b
Set-Content -LiteralPath (Join-Path $a 'doc1.txt')  -Value 'a-doc1'
Set-Content -LiteralPath (Join-Path $a 'same.txt')  -Value 'a-same'
Set-Content -LiteralPath (Join-Path $b 'same.txt')  -Value 'b-same'
Set-Content -LiteralPath (Join-Path $a 'photo.jpg') -Value 'a-photo'
```

置き場所は `C:\asdd-fixtures\src-a` と `C:\asdd-fixtures\src-b` です(ファイル選択画面でここへ辿ってください)。

Androidのエミュレータにも同じものを置きます。

```powershell
# PATHに adb があればそれを、無ければ既定のSDK配置を使う。
$adb = (Get-Command adb -ErrorAction SilentlyContinue).Source
if (-not $adb) { $adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe' }
if (-not (Test-Path -LiteralPath $adb)) { Write-Host "adb が見つかりません。SDKの場所を確認してください: $adb" }
& $adb shell mkdir -p /sdcard/Download/asdd-src-a /sdcard/Download/asdd-src-b
& $adb push C:\asdd-fixtures\src-a\doc1.txt  /sdcard/Download/asdd-src-a/
& $adb push C:\asdd-fixtures\src-a\same.txt  /sdcard/Download/asdd-src-a/
& $adb push C:\asdd-fixtures\src-b\same.txt  /sdcard/Download/asdd-src-b/
& $adb push C:\asdd-fixtures\src-a\photo.jpg /sdcard/Download/asdd-src-a/
```

Android側は `内部ストレージ > Download > asdd-src-a` と `asdd-src-b` に入ります。

## Android

### 1. 種類の選択から始まる

1. 「ファイルを選ぶ」を押します。
   - 確認: 種類を選ぶ画面が出て、「画像」「動画」「文書」「すべて」の**4つ**がある。

2. 「画像」を選びます。
   - 確認: **ファイル選択画面が開かない**。一覧も変化しない。
   - 確認: まだ用意できていない旨(写真機能で対応予定)が表示される。

3. 「動画」でも同じことを確認します。

4. 「文書」を選びます。
   - 確認: ファイル選択画面が開き、`photo.jpg` が選べない(表示されないか、押しても選択できない)。
   - 戻ります。

### 2. 選ぶとリストが入れ替わる

1. 「すべて」から `asdd-src-a` の `doc1.txt` と `same.txt` を選んで確定します。
   - 確認: 一覧が**選んだ2件だけ**になる。
   - 確認: 2件ともチェックが入っている。
   - 確認: 各行に**どのフォルダのファイルか**が小さく表示される。

2. もう一度「すべて」から、今度は `asdd-src-b` の `same.txt` **だけ**を選んで確定します。
   - 確認: 一覧が**1件だけ**になる。前回の2件は**残らない**(足し算ではなく入れ替え)。

### 3. 同じファイルを2回選んだとき

1. 「すべて」から `asdd-src-a` の `doc1.txt` を選びます。同じファイルを2回選べる場合は2回選んでから確定します。
   - 確認: 一覧に入るのは**1件だけ**。
   - 2回選べない画面なら、その旨だけ教えてください。

### 4. 選ばずに戻ったとき

1. 「すべて」を選び、**ファイルを選ばずに**戻る/キャンセルします。
   - 確認: 一覧が**まったく変化しない**(直前の選択がそのまま残る)。
   - 確認: エラーやお知らせも**出ない**。

### 5. フォルダをまたいで選んだとき

> 2026-08-12の実施で、**到達できる経路が判明しました。** フォルダを辿るだけでは片方のフォルダのファイルしか出ませんが、ファイル選択画面**上部のチップ(「Documents」など、種類で絞り込むタブ)**を選ぶと、フォルダをまたいで同じ種類のファイルが一覧に集まります。左側のフォルダ選択が `asdd-src-a` のままでも、`asdd-src-b` のファイルが並びます。

1. 「すべて」を選んでファイル選択画面を開きます。
2. 画面上部の「**Documents**」チップ(端末の言語によっては「ドキュメント」)を選びます。
   - 確認: `asdd-src-a` と `asdd-src-b` の `same.txt` が**両方**一覧に出る。
   - チップが見当たらない機種では、フォルダを辿って両方選べるか試してください。それも無理なら、その旨だけ教えてください。
3. 両方の `same.txt` を選んで確定します。
   - 確認: 読み込みは**成功する**。
   - 確認: 同名だが**2件**として残り、行の表示でどちらのフォルダか区別できる。
   - 確認: **複数のフォルダのファイルが混ざっている旨の警告**が出る。

### 6. 作成日時が分からないファイルの扱い

Androidでは作成日時が取れないため、通常はすべて「不明」になります。

1. 並び順を「**作成日時順**」にします。
   - 確認: 作成日時が分からない件数と、更新日時で代わりに並べている旨の警告が出る。
   - 確認: 各行の「作成日時: 不明」が**警告色・警告マークで強調**される。

2. 並び順を「**元の名前順**」に戻します。
   - 確認: 「不明」の表示自体は残るが、**強調は外れる**(警告色・警告マークが消える)。

### 7. 権限

1. ここまでの操作で、アプリから権限の許可を求められたか思い出してください。
   - 確認: **「すべてのファイルへのアクセス」やストレージ全体の許可を求められていない。**
2. 設定 → アプリ → 「**batch_rename_master**」 → 権限 を開きます(アプリ一覧にはこの名前で出ます。最近使ったアプリの画面では「一括リネーム（デモ）」、アプリ内の見出しは「一括リネーム」で、3つとも別の場所の名前です)。
   - 端末の言語によっては英語表示になります。2026-08-12の実施では `No permissions allowed` と出ました。
   - 確認: ストレージ関連の権限が**付与されていない**(ファイル選択画面を経由するので、許可が要らない作りです)。

## Windows desktop

1. 「ファイルを選ぶ」→「**すべて**」を選び、`C:\asdd-fixtures\src-a` の `doc1.txt` と `same.txt` を選びます。
   - 確認: 一覧が選んだ2件で置き換わり、各行にフォルダが表示される。

2. 同じファイルを2回選べる場合は `doc1.txt` を重複させて選びます。
   - 確認: 一覧に入るのは1件だけ。2回選べなければ、その旨だけ教えてください。

3. 「すべて」から `C:\asdd-fixtures\src-b` の `same.txt` **だけ**を選び直します。
   - 確認: 1件だけになり、前回分は残らない(Androidと同じ)。

4. ファイル選択画面をキャンセルします。
   - 確認: 一覧が変化せず、エラーや通知も出ない(Androidと同じ)。

5. 1回の選択で両フォルダの `same.txt` を選べるか試します(Windowsの選択画面も通常は同一フォルダ内に限られるため、**できなければ、その旨だけ教えてください**)。
   - 選べた場合の確認: 2件として残り、フォルダをまたいでいる旨の警告が出る。行の表示で `src-a` と `src-b` が区別できる。

## 後片付け

```powershell
Remove-Item -LiteralPath 'C:\asdd-fixtures\src-a','C:\asdd-fixtures\src-b' -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath 'C:\asdd-fixtures' -Force -ErrorAction SilentlyContinue
$adb = (Get-Command adb -ErrorAction SilentlyContinue).Source
if (-not $adb) { $adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe' }
& $adb shell rm -rf /sdcard/Download/asdd-src-a /sdcard/Download/asdd-src-b
```

## 結果の伝え方

会話でそのまま教えてください。書式は問いません。うまくいかなかった箇所は、画面に出た文言と、必要なら`adb`やPowerShellの出力を添えてください。できなかったstepは「できなかった」と書いていただければ十分です。

結果を受け取ったらAgentが`task.md`へ記録し、受け入れ条件を満たしたかreviewします。
