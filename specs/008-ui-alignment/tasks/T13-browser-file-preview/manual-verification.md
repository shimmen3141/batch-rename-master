# 手動確認: browserのファイル行のpreview(Androidエミュレータ)

**対象buildは、`lib/`の内容が commit `ba6e815` と同一のもの**である。branch `asdd/008-ui-alignment/T13-browser-file-preview` のHEADからbuildすればこれを満たす — それ以後のcommitは記録だけで、`lib/`を変えていない。**`lib/`・dependency・build設定が変わったら、この結果は再利用しない。**

**Androidエミュレータで確認する**(`008:T39`で開発者が決めた方針)。**テキストのpreviewは出さない**(2026-09-24の決定。テキストは種別アイコンになることだけを見る)。

## 使う端末と準備

- 起動と`flutter run`は[`docs/development/emulator-verification.md`](../../../../docs/development/emulator-verification.md)のとおり。**host側でworktree `.worktrees/008-T13-browser-file-preview` へ`cd`してから`flutter pub get` → `flutter run -d <emulator>`**する(branchの移動は不要)。
- `adb devices`にエミュレータが**1台だけ**出ていることを確かめる。

### 準備するファイル

**画像と動画はエミュレータの中で作る**(`screencap`は画面のPNG、`screenrecord`は画面の動画を書き出す。hostで画像を用意しなくてよい)。確認専用のフォルダ`Download/asdd-008-t13`だけを使い、**既にあれば何も置かずに止まる**。

```powershell
$adbPath = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
$d = '/sdcard/Download/asdd-008-t13'
$existing = "$(& $adbPath shell "if [ -e $d ]; then echo exists; fi")".Trim()
if ($existing -eq 'exists') {
  Write-Host '端末に Download/asdd-008-t13 が既にあります。何も置かずに止めました。' -ForegroundColor Red
} else {
  & $adbPath shell "mkdir -p $d/many $d/deep/level1/level2"
  & $adbPath shell "screencap -p $d/shot.png"
  & $adbPath shell "screenrecord --time-limit 3 $d/clip.mp4"
  & $adbPath shell "echo hello > $d/note.txt"
  & $adbPath shell "echo not-an-image > $d/broken.jpg"
  & $adbPath shell "for i in `$(seq 1 200); do cp $d/shot.png $d/many/img_`$i.png; done"
  & $adbPath shell "cp $d/shot.png $d/deep/level1/level2/deep.png"
  & $adbPath shell "ls $d; ls $d/many | wc -l"
}
```

**期待**: 最後の`ls`に`broken.jpg` `clip.mp4` `deep` `many` `note.txt` `shot.png`、その次に`200`が出る。
(`screenrecord`は3秒かかる。エミュレータによっては動かないことがある — `clip.mp4`が無ければ、2の動画の項目は飛ばして報告に書いてほしい。)

**後片付け**: 確認が終わったら、端末のファイルアプリで`Download/asdd-008-t13`を消してよい(中身はすべてこの手順で置いたもの)。

## 0. いま動いているのが、このtaskのbuildか確かめる

「ファイルを選ぶ」→「すべて」→ `Download` → `asdd-008-t13` を開いて:

- **ファイルの行の左に、正方形の枠**(画像の縮小か、種別のアイコン)がある。フォルダの行は従来どおりフォルダのアイコン。

枠が無ければ古いbuildである。

## 1. preview の出方

`asdd-008-t13`で:

- `shot.png`: 行の左に**画面の縮小画像**が出る。
- `clip.mp4`: 行の左に**動画の1コマ**が出る(出ずに動画のアイコンなら、そう報告してほしい)。
- `note.txt`: **文書のアイコン**(中身は出さない。仕様どおり)。
- `broken.jpg`: **壊れた画像のアイコン**(中身が画像ではないため。preview の無い行とは違うアイコン)。
- **4つとも一覧に並んでいる**(previewが無いものも隠れない)。**並び順はpreviewの有無で変わらない。**
- 開いた直後、枠の中で**くるくる回る表示は出ない**(届いたものから絵に置き換わる)。

## 2. 件数の多いフォルダ

1. `many`(200件)へ入る。
2. 一覧を**上から下まで素早くスクロール**し、また上へ戻る。

- 開くまでの時間が、previewの無かったときと比べて**目立って遅くならない**(体感でよい)。
- スクロールが**引っかからない**。絵は少し遅れて埋まってよい。
- 下まで行って戻ったとき、上の行の絵が**別のファイルの絵に入れ替わっていない**。

## 3. 選択はそのまま使える

`many`で:

1. 行の**左の縮小画像のところ**を押す → その行が選ばれる(面がシアンに染まり、右端の丸にチェック)。
2. 別の行をマウスの左ボタンで押したまま約1秒待ち、下へ動かして離す → まとめて選ばれる。
3. 「確定」→ リネーム画面の一覧に入る。

## 4. パンくずの区切りを押す(`008:T40`から引き受けた項目)

1. `asdd-008-t13` → `deep` → `level1` → `level2`へ入る。
2. パンくずの**途中の`level1`**を押す。

- `level1`の中身になり、帯が「… › deep › level1」になる。**押しにくくない**(1回で当たる)。

## 報告

結果は会話で自由に書いてよい。決まった書式は不要である。**2の速さとスクロールの感触**、1で動画の絵が出たかどうか、期待と違った点(スクリーンショットがあると助かる)を書いてほしい。
