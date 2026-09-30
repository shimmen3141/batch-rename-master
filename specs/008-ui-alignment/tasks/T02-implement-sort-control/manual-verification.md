# 手動確認: 並び順のメニューと、読み込み直しの並び順(Androidエミュレータ)

**対象buildは、`lib/`・`hook/`・`src/`の内容が commit `b3a9f06` と同一のもの**である(2回目。1回目は`6b6c64c`で、結果は`task.md`)。branch `asdd/008-ui-alignment/T02-implement-sort-control` のHEADからbuildすればこれを満たす。**code・dependency・build設定が変わったら、この結果は再利用しない。**

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

## 2回目で見ること

1回目(`6b6c64c`)で**動作はすべて問題なかった**。その後に変えたのは**配置だけ**である — 並び順をケバブの左へ移し、状態のメッセージを帯の下のバナーへまとめた。並べ替え・読み込み直し・取り消しの処理(`file_list_controller.dart`・`file_sort.dart`・`removal_undo.dart`)は1回目から変えていない。そこで2回目は**配置と見え方**だけを見る。

**fixtureは1回目のものが残っていれば、準備のcommandは実行しなくてよい**(既にあれば止まる)。

## 0. いま動いているのが、2回目のbuildか確かめる

ファイルを読み込むと、**一覧の上に並び順だけの帯が無く**、上の帯の右側、**︙(ケバブ)の左**に`⇅ 名前 A→Z ▾`が出ていれば、2回目のbuildである。

## 1. 上の帯

1. 「ファイルを選ぶ」→「すべて」→ `Download` → `asdd-008-t02-a` で3件を選び、「確定」する。

**こうなってほしい**

- 上の帯は**1行**で、左に`3 件`、右に`⇅ 名前 A→Z ▾`と︙が並ぶ。**「並び順:」の文字は無い**(帯に収めるため外した)。
- `⇅ 名前 A→Z ▾`を押すと、1回目と同じ8項目のメニューが開き、選ぶと並び替わる。

## 2. 状態のメッセージのバナー

1. 命名ルールが**未設定**のとき、上の帯の下に「命名ルールが未設定です…」が**色の付いた帯**で出る。上の帯とは色で見分けられる。
2. ルールを設定する(例: 先頭に文字列`x_`と元の名前)。

**こうなってほしい**

- 未設定の案内が消え、「**正常にリネームできます**」(緑)が同じ場所に出る。問題があるルールなら「**N 件の問題**」(赤)が出て、押すと全件の詳細が開く。
- 並び順を「**作成日時 古い順**」にすると、「**作成日時不明の N 件は更新日時で代替しています**」(赤)が**バナーにもう1行加わる**(作成日時が取れるファイルばかりなら出ない。出なかったら知らせてほしい)。
- 行が加わる・消えるとき、**一覧が一瞬で跳ばず、滑らかに下がる・上がる**。
- 「名前 A→Z」へ戻すと、作成日時の行が滑らかに消える。

3. 右上の︙ →「外すファイルを選ぶ」で選択モードへ入る。

- **一覧が上下にずれない**(メッセージはモード中も残る)。

## 3. 文字サイズ最大

1. 端末の**設定 → ユーザー補助(または画面)→ フォントサイズを最大**にしてアプリへ戻る。

**こうなってほしい**

- 上の帯の`3 件`・並び順・︙が**画面外へはみ出さない**。並び順の文字は2行に折り返してよい。
- 並び順を押すとメニューが開き、スクロールで「サイズ 大きい順」まで届く。
- バナーのメッセージも切れずに読める。

確認後、フォントサイズを元へ戻す。

## 結果の伝え方

会話で自由に伝えてほしい(番号ごとに「期待どおり」「ここが違う」で足りる)。Agentが`task.md`へ記録する。
