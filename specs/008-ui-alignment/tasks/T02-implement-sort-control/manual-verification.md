# 手動確認: 並び順のメニューと、読み込み直しの並び順(Androidエミュレータ)

**対象buildは、`lib/`・`hook/`・`src/`の内容が commit `4932a39` と同一のもの**である(3回目。1回目は`6b6c64c`、2回目は`b3a9f06`で、結果は`task.md`)。branch `asdd/008-ui-alignment/T02-implement-sort-control` のHEADからbuildすればこれを満たす。**code・dependency・build設定が変わったら、この結果は再利用しない。**

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

## 3回目で見ること

2回目(`b3a9f06`)で受けた指定(ケバブの右の余白、「並び順:」、「N 件の問題」の印と「詳細」)を直した。見るのは**上の帯と件数の行**だけである。並べ替えの処理は1回目から変えていない。

**fixtureは前回のものが残っていれば、準備のcommandは実行しなくてよい**(既にあれば止まる)。

## 0. いま動いているのが、3回目のbuildか確かめる

ルールに問題があるとき、バナーに「⚠ N 件の問題 **詳細**」(「詳細」が太字・下線)が出ていれば、3回目のbuildである。

## 1. 上の帯

1. 「ファイルを選ぶ」→「すべて」→ `Download` → `asdd-008-t02-a` で3件を選び、「確定」する。

**こうなってほしい**

- **︙(ケバブ)の右に余白が目立たない。** ︙の右の空きが、左端の`3 件`の左の空きと同じくらい。
- 並び順が**︙のすぐ左**にあり、間に空きが無い。
- 並び順に**「並び順: 名前 A→Z」**と出る(「並び順:」が付いている)。
- メニューで「**作成日時 新しい順**」を選ぶと、「並び順: 作成日時 新しい順」が**1行に入るか**を見てほしい。入らない場合は「並び順:」が外れて「作成日時 新しい順」になる(それでよい。どちらになったかを知らせてほしい)。

## 2. 件数の行

1. 命名ルールを、**全件が同じ名前になるもの**(例: 固定の文字列`same`だけ)にする。

**こうなってほしい**

- バナーに「**⚠ 3 件の問題 詳細**」が赤で出る。先頭の印が**⚠(三角の警告マーク)**で、作成日時の代替の行と同じ形。「**詳細**」は**太字で下線付き**。
- 「詳細」を押すと、全件の詳細が開く。閉じて、今度は**行の右端のあたり(文字の無いところ)**を押しても開く。
- ルールを直して問題が無くなると「正常にリネームできます」(緑)になり、「詳細」は出ない。この行は押しても何も開かない。

## 3. 文字サイズ最大

1. 端末の**設定 → ユーザー補助(または画面)→ フォントサイズを最大**にしてアプリへ戻る。

**こうなってほしい**

- 上の帯の`3 件`が**切れずに読める**。並び順は「並び順:」が外れてよく、2行に折り返してよい。︙が画面外へはみ出さない。
- 「⚠ 3 件の問題 詳細」が切れずに読める。

確認後、フォントサイズを元へ戻す。

## 結果の伝え方

会話で自由に伝えてほしい(番号ごとに「期待どおり」「ここが違う」で足りる)。Agentが`task.md`へ記録する。
