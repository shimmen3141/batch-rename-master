# 手動確認: 警告の詳細modal(Androidエミュレータ)

`008:T53` で作り直した**警告の詳細**(一覧の「リネーム: N 件の問題 詳細」と、行の「重複」から開くもの)を、
実機の字体と幅で確かめる。

**対象buildは、`lib/`・`hook/`・`src/`の内容が commit `0652b32` と同一のもの**である。branch
`asdd/008-ui-alignment/T53-warning-detail-grouping` のHEADからbuildすればこれを満たす。
**code・dependency・build設定が変わったら、この結果は再利用しない。**

組の分け方、相手の足し方、相手の他の警告が出ないこと、狭い幅で「閉じる」が画面に残ることは、
自動testで確かめてある。ここで見るのは**実機で読んで、どれとどれがぶつかるかが分かるか**である。

## 使う端末と準備

- 起動と`flutter run`は`/workspace/docs/development/emulator-verification.md`のとおり。branchの移動は不要
  (`/workspace` はすでにこのbranchにある)。host側で`flutter pub get` → `flutter run`する。
- 「すべてのファイルへのアクセス」は許可しておく。

**捨ててよいファイルを10個**、端末の `Download/asdd-008-t53` に置く。host の PowerShell から:

```powershell
$adbPath = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
$fixturePath = Join-Path $env:TEMP 'asdd-008-t53'
Remove-Item -Recurse -Force -LiteralPath $fixturePath -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $fixturePath | Out-Null
1..6 | ForEach-Object { Set-Content -LiteralPath (Join-Path $fixturePath ('photo_{0:D2}.txt' -f $_)) -Value "t53-$_" }
1..2 | ForEach-Object { Set-Content -LiteralPath (Join-Path $fixturePath ('memo_{0}.md' -f $_)) -Value "t53-memo-$_" }
Set-Content -LiteralPath (Join-Path $fixturePath 'solo.log') -Value 't53-solo'
Set-Content -LiteralPath (Join-Path $fixturePath 'same.log') -Value 't53-existing'
& $adbPath shell "rm -rf /sdcard/Download/asdd-008-t53 && mkdir -p /sdcard/Download/asdd-008-t53"
& $adbPath push "$fixturePath/." /sdcard/Download/asdd-008-t53/
& $adbPath shell ls /sdcard/Download/asdd-008-t53
```

**期待**: 最後の `ls` に `memo_1.md`、`memo_2.md`、`photo_01.txt` 〜 `photo_06.txt`、`same.log`、`solo.log` の10個が出る。

**読み込み**: アプリの「別フォルダへ」(初回は「ファイルを選ぶ」)→「すべて」→(保存場所の一覧が出たら「内部ストレージ」)→
`Download` → `asdd-008-t53` へ入り、「すべて選択」してから **`same.log` だけを押して選択を外し**、「確定」。
一覧に9件が並び、`same.log` は無い(フォルダにもともとある、読み込んでいないファイルの役)。
ルールが前回のまま残っていたら、チップを全部消してから始める。

## 0. いま動いているのが、このbuildか確かめる

手順1で開く詳細が、**角の丸い枠で、下に横長の「閉じる」がある**ならこのbuildである
(前の build は標準のdialogで、右下に小さな「閉じる」の文字があり、対象が「•」で並んでいた)。

## 1. 全件から開く(重複が変更後名ごとに分かれる)

1. 「命名ルールを設定する」→「＋ 自由テキスト」で `same` と入れて「追加」し、一覧へ戻る。
2. 一覧の上の「リネーム: 8 件の問題 詳細」を押す。

**こうなってほしい**

- 見出しが「8 件の問題」。薄い赤の枠が**1つ**あり、「重複 8 件」と「変更後の名前が同じになるファイルを、
  名前ごとにまとめています」が読める。
- その枠の中に**小さな枠が2つ**ある。
  - `→ 「same.txt」`の下に `photo_01.txt` 〜 `photo_06.txt` の6個。
  - `→ 「same.md」`の下に `memo_1.md` と `memo_2.md`。
- **どれとどれが同じ名前になるのかが、名前を見比べなくても分かる。**(分かりにくいところがあれば教えてほしい)
- 下の「閉じる」で閉じる。

## 2. 行から開く(その行と、同じ名前になる相手)

1. `memo_1.md` の行の右端の「重複」を押す。

**こうなってほしい**

- 見出しが「「memo_1.md」の問題」。
- 小さな枠が**1つ**で、`→ 「same.md」`の下に `memo_1.md` と **`memo_2.md`(相手)** が並ぶ。
- `photo_…` は出ない。

2. 「閉じる」で閉じる。

## 3. フォルダにもともとあるファイルとぶつかるとき

`solo.log` は `same.log` になるが、`same.log` は読み込んでいない。アプリはこのファイルの存在を、
**実行buttonを押したときに**調べる。

1. 「9 件をリネーム」を押し、確認が出たら「キャンセル」を押す(名前は変わらない)。
2. 一覧の上が「リネーム: 9 件の問題 詳細」になったことを確かめ、`solo.log` の行の「重複」を押す。

**こうなってほしい**

- `→ 「same.log」`の枠に `solo.log` と、灰色で **「フォルダにある既存のファイル」** が並ぶ。

3. 「閉じる」で閉じる。

## 4. 狭い幅・大きな文字(任意)

端末の設定で文字のサイズを最大にし、手順1をもう一度行う。

- 見出しと「閉じる」が画面に収まっている。中身が多いときは**枠の部分だけが縦に動き**、「閉じる」は押せる位置に残る。
  ファイル名が切れて読めないことがない。

## 後片付け(任意)

改名はしていないので、そのまま消してよい: `& $adbPath shell rm -rf /sdcard/Download/asdd-008-t53`

## 報告

結果は会話で自由に書いてよい。決まった書式は不要である。問題があったときだけ、どの手順で、
実際に何が見えたかを添えてほしい。
