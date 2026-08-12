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
$adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
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
   - 2回選べない画面なら「確認不能」で構いません。

### 4. フォルダをまたいで選んだとき(できる場合のみ)

> このstepは**できなくても構いません。** Androidの標準のファイル選択画面は、フォルダを移動すると選択が解除される作りで、1回の選択で2つのフォルダから選べないことがあります(2026-08-05に確認済み)。その場合は次のstepへ進んでください。同じ内容は開発側のテストでも検査しています。

1. 1回の選択で `asdd-src-a` の `same.txt` と `asdd-src-b` の `same.txt` を**両方**選べるか試します。ファイル選択画面の「最近」タブや検索から、フォルダを移動せずに両方を選べる場合があります。
2. 両方選べて確定できたら:
   - 確認: 読み込みは**成功する**。
   - 確認: 同名だが**2件**として残り、行の表示でどちらのフォルダか区別できる。
   - 確認: **複数のフォルダのファイルが混ざっている旨の警告**が出る。
3. 選べなければ「確認不能」で構いません。

### 5. 作成日時が分からないファイルの扱い

Androidでは作成日時が取れないため、通常はすべて「不明」になります。

1. 並び順を「**作成日時順**」にします。
   - 確認: 作成日時が分からない件数と、更新日時で代わりに並べている旨の警告が出る。
   - 確認: 各行の「作成日時: 不明」が**警告色・警告マークで強調**される。

2. 並び順を「**元の名前順**」に戻します。
   - 確認: 「不明」の表示自体は残るが、**強調は外れる**(警告色・警告マークが消える)。

### 6. 権限

1. ここまでの操作で、アプリから権限の許可を求められたか思い出してください。
   - 確認: **「すべてのファイルへのアクセス」やストレージ全体の許可を求められていない。**
2. 設定 → アプリ → このアプリ → 権限 を開きます。
   - 確認: ストレージ関連の権限が**付与されていない**(ファイル選択画面を経由するので、許可が要らない作りです)。

## Windows desktop

1. 「ファイルを選ぶ」→「**すべて**」を選び、`C:\asdd-fixtures\src-a` の `doc1.txt` と `same.txt` を選びます。
   - 確認: 一覧が選んだ2件で置き換わり、各行にフォルダが表示される。

2. 同じファイルを2回選べる場合は `doc1.txt` を重複させて選びます。
   - 確認: 一覧に入るのは1件だけ。2回選べなければ「確認不能」で構いません。

3. 「すべて」から `C:\asdd-fixtures\src-b` の `same.txt` **だけ**を選び直します。
   - 確認: 1件だけになり、前回分は残らない(Androidと同じ)。

4. ファイル選択画面をキャンセルします。
   - 確認: 一覧が変化せず、エラーや通知も出ない(Androidと同じ)。

5. 1回の選択で両フォルダの `same.txt` を選べるか試します(Windowsの選択画面も通常は同一フォルダ内に限られるため、**できなければ「確認不能」で構いません**)。
   - 選べた場合の確認: 2件として残り、フォルダをまたいでいる旨の警告が出る。行の表示で `src-a` と `src-b` が区別できる。

## 後片付け

```powershell
Remove-Item -LiteralPath 'C:\asdd-fixtures' -Recurse -ErrorAction SilentlyContinue
$adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
& $adb shell rm -rf /sdcard/Download/asdd-src-a /sdcard/Download/asdd-src-b
```

## 結果の伝え方

会話でそのまま教えてください。書式は問いません。うまくいかなかった箇所は、画面に出た文言と、必要なら`adb`やPowerShellの出力を添えてください。できなかったstepは「できなかった」と書いていただければ十分です。

結果を受け取ったらAgentが`task.md`へ記録し、受け入れ条件を満たしたかreviewします。
