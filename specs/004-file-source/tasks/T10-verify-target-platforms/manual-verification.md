# 手動確認: Android SAFとdesktopでファイル選択が仕様どおり動くこと

## 確認すること

004の選択導線を、実際のplatformで確認します。fakeでは確認できないもの——**システムのpickerが返すもの**、**種類ごとの入口**、**Androidが要求する権限**——が対象です。

特に次の2つは、この確認以外に検査する場所がありません。

- 「画像」「動画」は読み込みを始めず、未実装であることを示す(**REQ-011**)。
- **追加の全ファイルアクセス権限を要求しない**(このprojectのAndroid権限方針。`MANAGE_EXTERNAL_STORAGE`を使わない)。

## 事前準備

共通の起動手順は[`docs/development/emulator-verification.md`](../../../../docs/development/emulator-verification.md)に従ってください。branchの移動は不要です。Agentが対象branchとcommitを用意した状態で待ちます。

- Commit: `<Agentが記入>`
- 対象: Android(emulatorまたは実機)と、Windows desktop build

消えてよいfixtureを**2つのフォルダに分けて**用意します。片方に同名ファイルを置くのが要点です(フォルダ跨ぎの警告と、handleの区別を見るため)。

Windows側:

```powershell
$a = Join-Path $env:TEMP 'asdd-src-a'
$b = Join-Path $env:TEMP 'asdd-src-b'
Remove-Item -LiteralPath $a,$b -Recurse -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $a,$b
Set-Content -LiteralPath (Join-Path $a 'doc1.txt')  -Value 'a-doc1'
Set-Content -LiteralPath (Join-Path $a 'same.txt')  -Value 'a-same'
Set-Content -LiteralPath (Join-Path $b 'same.txt')  -Value 'b-same'
Set-Content -LiteralPath (Join-Path $a 'photo.jpg') -Value 'a-photo'
```

以降のPowerShellは同じwindowで続けてください(`$a`・`$b`はwindowを閉じると消えます)。

Android側(emulatorへ同じものを置く):

```powershell
$adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
& $adb shell mkdir -p /sdcard/Download/asdd-src-a /sdcard/Download/asdd-src-b
& $adb push $a\doc1.txt  /sdcard/Download/asdd-src-a/
& $adb push $a\same.txt  /sdcard/Download/asdd-src-a/
& $adb push $b\same.txt  /sdcard/Download/asdd-src-b/
& $adb push $a\photo.jpg /sdcard/Download/asdd-src-a/
```

## Android SAF

### 1. 種類の選択から始まる(REQ-011)

1. 「ファイルを選ぶ」を押します。
   - 確認: 種類を選ぶシートが出て、「画像」「動画」「文書」「すべて」の**4つ**がある。

2. 「画像」を選びます。
   - 確認: **読み込みが始まらない**。ファイル選択画面も開かない。
   - 確認: 未実装である旨(写真機能で対応予定)が表示される。
   - 確認: 一覧は変化しない。

3. 「動画」でも同じことを確認します。

4. 「文書」を選びます。
   - 確認: システムのファイル選択画面が開き、**文書系のファイルに絞り込まれている**(`photo.jpg`が選べない、またはグレーアウトする)。
   - いったん戻ります。

### 2. 選択するとリストが置き換わる(REQ-004 / REQ-007 / REQ-009)

1. 「すべて」から`asdd-src-a`の`doc1.txt`と`same.txt`を選んで確定します。
   - 確認: 一覧が**選んだ2件だけ**になる。
   - 確認: 2件とも**チェックが入っている**(既定で全選択)。
   - 確認: 各行に**場所(元のフォルダ)**がサブ情報として出る。

2. もう一度「すべて」から、今度は`asdd-src-b`の`same.txt`だけを選んで確定します。
   - 確認: 一覧が**1件だけ**になる。前回の2件は**残らない**(蓄積せず置き換える)。

### 3. 同一ファイルと同名別ファイルの扱い(REQ-002 / REQ-004)

1. 「すべて」から`asdd-src-a`の`same.txt`と`asdd-src-b`の`same.txt`を**両方**選んで確定します。
   - 確認: 読み込みは**成功する**。
   - 確認: 同名だが**2件として残る**(別フォルダ＝別ファイル)。行の場所表示で区別できる。
   - 確認: **フォルダを跨いでいる旨の警告**が出る(REQ-012)。

2. システムの選択画面で**同じファイルを2回**選べる場合は、`doc1.txt`を重複させて確定します。
   - 確認: 一覧には**1件だけ**入る(同一handleは1件にまとめる)。
   - 選択画面が重複選択を許さない場合は「確認不能」で構いません。

### 4. cancelでは何も起きない(REQ-008)

1. 「すべて」を選び、ファイルを選ばずに戻る/キャンセルします。
   - 確認: 一覧が**まったく変化しない**(前回の選択が保たれる)。
   - 確認: **通知やメッセージも出ない**(エラー表示が出ないこと)。

### 5. 作成日時が不明なときの扱い(002 REQ-011 / REQ-013)

Android SAFは作成日時の列を持たないため、通常はすべて「不明」になります。

1. 並び順を**作成日時**にします。
   - 確認: 作成日時が不明な件数と、更新日時で代替して並べている旨の警告が出る。
   - 確認: 各行の日時表示で「作成日時: 不明」が**強調**される。

2. 並び順を**名前**に戻します。
   - 確認: 「不明」の表示自体は残るが、**強調(警告色・警告マーク)は外れる**。

### 6. 権限(このprojectの方針)

1. ここまでの操作を通して、アプリが要求した権限を思い出してください。
   - 確認: **「すべてのファイルへのアクセス」や、ストレージ全体の権限を要求されていない**。
   - 確認: 設定 → アプリ → このアプリ → 権限 で、ストレージ関連の権限が付与されていない(SAFはシステムのpicker経由なので権限付与が要りません)。

## Desktop (Windows)

1. 「ファイルを選ぶ」からOSのpickerを開き、`asdd-src-a`の`doc1.txt`と`same.txt`を選びます。
   - 確認: 一覧が選んだ2件で置き換わり、各行に場所が出る。

2. `asdd-src-b`の`same.txt`だけを選び直します。
   - 確認: 1件だけになり、前回分は残らない(Androidと同じ契約)。

3. pickerをキャンセルします。
   - 確認: 一覧が変化せず、通知も出ない(Androidと同じ契約)。

4. `asdd-src-a`と`asdd-src-b`の`same.txt`を両方選びます。
   - 確認: 2件として残り、フォルダ跨ぎの警告が出る。
   - 確認: 行の場所表示で、それぞれ`asdd-src-a`と`asdd-src-b`だと分かる(handleが絶対パスで、同名の別パスを別ファイルとして扱えている)。

## 後片付け

```powershell
Remove-Item -LiteralPath $a,$b -Recurse -ErrorAction SilentlyContinue
& $adb shell rm -rf /sdcard/Download/asdd-src-a /sdcard/Download/asdd-src-b
```

## 結果の伝え方

会話でそのまま教えてください。書式は問いません。うまくいかなかった箇所は、画面の文言と、必要なら`adb`やPowerShellの出力を添えてください。

Agentが記録する証拠は、対象commit・build・OS/device、置換前後の一覧、cancel前後の一覧、種類別の入口の挙動、フォルダ跨ぎ警告、作成日時警告、権限の状態です。結果は`task.md`の作業記録へ要約します(このfileにstatusは書きません。状態の正本は`task.json`です)。
