# 手動確認: 並び順のメニューと、読み込み直しの並び順(Androidエミュレータ)

**対象buildは、`lib/`・`hook/`・`src/`の内容が commit `bba23bd` と同一のもの**である(4回目。1回目は`6b6c64c`、2回目は`b3a9f06`、3回目は`4932a39`で、結果は`task.md`)。branch `asdd/008-ui-alignment/T02-implement-sort-control` のHEADからbuildすればこれを満たす。**code・dependency・build設定が変わったら、この結果は再利用しない。**

**Androidエミュレータで確認する**(`008:T39`で開発者が決めた方針)。見るのは**見た目・押しやすさ・並び順**で、速さは見ないので debug build でよい。

widget testで確かめ済みのこと(8項目がある・印が1つだけ付く・選ぶと並ぶ・文字2.0で最後の項目へ届く・取り消しで並びが戻る)は、**実機での見え方と押しやすさ**だけを見る。

## 使う端末と準備

- 起動と`flutter run`は[`docs/development/emulator-verification.md`](../../../../docs/development/emulator-verification.md)のとおり。**host側でworktree `.worktrees/008-T02-implement-sort-control` へ`cd`してから`flutter pub get` → `flutter run`**する(branchの移動は不要。エミュレータが1台なら`-d`は要らない)。
- `adb devices`にエミュレータが**1台だけ**出ていることを確かめる。

### 準備するファイル

確認専用のフォルダ`Download/asdd-008-t02-a`と`Download/asdd-008-t02-b`だけを使い、**どちらかが既にあれば何も置かずに止まる**。

```powershell
$adbPath = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
$existing = "$(& $adbPath shell "if [ -e /sdcard/Download/asdd-008-t02-a ] || [ -e /sdcard/Download/asdd-008-t02-b ]; then echo exists; fi")".Trim()
if ($existing -eq 'exists') {
  Write-Host '端末に Download/asdd-008-t02-a か -b が既にあります。何も置かずに止めました。' -ForegroundColor Red
} else {
  & $adbPath shell "mkdir -p /sdcard/Download/asdd-008-t02-a /sdcard/Download/asdd-008-t02-b"
  & $adbPath shell "echo a > /sdcard/Download/asdd-008-t02-a/a.txt"
  & $adbPath shell "echo bbbbbbbbbb > /sdcard/Download/asdd-008-t02-a/b.txt"
  & $adbPath shell "echo ccccc > /sdcard/Download/asdd-008-t02-a/c.txt"
  & $adbPath shell "echo z > /sdcard/Download/asdd-008-t02-b/z.txt"
  & $adbPath shell "echo y > /sdcard/Download/asdd-008-t02-b/y.txt"
  & $adbPath shell "echo x > /sdcard/Download/asdd-008-t02-b/x.txt"
  & $adbPath shell "ls -l /sdcard/Download/asdd-008-t02-a /sdcard/Download/asdd-008-t02-b"
}
```

**期待**: `-a`に`a.txt`(2 B)`b.txt`(11 B)`c.txt`(6 B)、`-b`に`x.txt` `y.txt` `z.txt`が出る。

**上のcommandが「既にあります。何も置かずに止めました」と出した場合は、ここで止まる。** そのフォルダはこの手順が作ったものではないかもしれないので、**中身を確かめ、何のフォルダか分かるまで先へ進まず、後片付けでも消さない**(知らせてほしい)。

**後片付け**: **このcommandが作った場合だけ**、確認が終わったら端末のファイルアプリで`Download/asdd-008-t02-a`と`Download/asdd-008-t02-b`を消してよい。

## 4回目で見ること

3回目(`4932a39`)で受けた指定(バナーの印の位置と余白、「詳細」の余白と下線、「リネーム:」「並び順:」の文言)を直した。見るのは**バナーの2つの行**だけである。

**fixtureは前回のものが残っていれば、準備のcommandは実行しなくてよい**(既にあれば止まる)。

## 0. いま動いているのが、4回目のbuildか確かめる

問題があるルールのとき、バナーに「⚠ **リネーム:** N 件の問題 詳細」が出ていれば、4回目のbuildである。

## 1. バナーの2つの行を並べて見る

1. 「ファイルを選ぶ」→「すべて」→ `Download` → `asdd-008-t02-a` で3件を選び、「確定」する。
2. 命名ルールを**固定の文字列`same`だけ**にする。
3. 並び順のメニューで「**作成日時 古い順**」を選ぶ。

**こうなってほしい**

- バナーに2行が出る: 「⚠ **リネーム: 3 件の問題**  詳細」と「⚠ **並び順: 作成日時不明の 3 件は更新日時で代替しています**」(作成日時が取れるファイルばかりなら2行目は出ない。そのときは知らせてほしい)。
- **2つの ⚠ の左端が縦にそろっている**。⚠ の大きさも同じ。
- **⚠ と文の間の空きが、2つの行で同じ**。
- 「3 件の問題」と「詳細」の間が、前回より**広い**。
- 「詳細」の下線が、前回より**太く、文字から少し下に離れて**見える。
- 行のどこを押しても詳細が開く(前回と同じ)。

## 2. 文字サイズ最大

1. 端末の**設定 → ユーザー補助(または画面)→ フォントサイズを最大**にしてアプリへ戻る。

**こうなってほしい**

- 「リネーム: 3 件の問題」が切れずに読める。入りきらなければ「詳細」は次の行へ回ってよい。
- 「並び順: 作成日時不明の…」も切れずに読める。

確認後、フォントサイズを元へ戻す。

## 結果の伝え方

会話で自由に伝えてほしい(番号ごとに「期待どおり」「ここが違う」で足りる)。Agentが`task.md`へ記録する。
