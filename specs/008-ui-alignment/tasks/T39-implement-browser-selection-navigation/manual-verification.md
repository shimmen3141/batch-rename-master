# 手動確認: app内browserの選択と戻る導線(Androidエミュレータ)

**対象buildは、`lib/`の内容が commit `2cf0e09` と同一のもの**である(3回目。1回目は`073b354`、2回目は`30be394`で、結果は`task.md`に記録済み)。branch `asdd/008-ui-alignment/T39-implement-browser-selection-navigation` のHEADからbuildすればこれを満たす — それ以後のcommitは記録だけで、`lib/`を変えていない。**`lib/`・dependency・build設定が変わったら、この結果は再利用しない。**

**提示の正本は`T38`の操作状態表**([`../T38-define-browser-selection-navigation/task.md`](../T38-define-browser-selection-navigation/task.md)の「操作状態表」)である。ここでは実機で見る点だけを書く。

**Androidエミュレータで確認する**(2026-09-23 開発者の決定: 手動確認はこれまでどおりエミュレータで行う)。**10(TalkBack)は行わない** — 1回目にエミュレータでダブルタップが効かず、開発者がskipを決めた。物理端末に固有の差(実際の指での操作感、端末ごとの保存場所の構成)は見ない。

## 使う端末と準備

- **Androidエミュレータ**。起動と`flutter run`は[`docs/development/emulator-verification.md`](../../../../docs/development/emulator-verification.md)の「エミュレータで起動する」のとおり。**エミュレータを起動して`flutter devices`に出てから**、下のfixture準備を実行する(`adb`がエミュレータへ届く必要がある)。
- **Androidのbuildはこの環境で実行できない**(AI containerにAndroid SDKが無い)。**hostでbuildして流し込む。** branchの移動は不要 — **host側でworktree `.worktrees/008-T39-browser-selection-navigation` へ`cd`してから`flutter pub get` → `flutter run -d <emulator>`**する(このbranchのHEADがある)。
- **`adb devices`にエミュレータが1台だけ出ている**ことを確かめる。複数あると下の`adb`コマンドがどちらへ送るか決まらず失敗する。
- 全ファイルアクセスの許可は済んでいる前提(`013:T07`の手順書の「使う端末」)。

### 準備するファイル

ホストのPowerShellから、端末の`Download`へ**確認専用のフォルダ`asdd-008-t39`**を作って置く。**捨ててよいファイルだけ**である。

hostの`%TEMP%\asdd-008-t39`は**この手順専用の作業場所で、毎回作り直す**(最初の`Remove-Item`が消すのはここだけ)。

**端末のファイルは消さない。** 同じ名前のフォルダが既にあれば、**何も置かずに止まる**(下の`if`)。止まったら、そのフォルダが何かを確かめてから知らせてほしい — 前回この確認で作ったものなら、中身を見てから自分で消してよい。

```powershell
$adbPath = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
$fixturePath = Join-Path $env:TEMP 'asdd-008-t39'
Remove-Item -Recurse -Force -LiteralPath $fixturePath -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path "$fixturePath\t39\sub" | Out-Null
New-Item -ItemType Directory -Force -Path "$fixturePath\t39\empty" | Out-Null
New-Item -ItemType Directory -Force -Path "$fixturePath\t39\very_long_folder_name_for_breadcrumb_check_2026_09_travel_and_family\deeper_folder" | Out-Null
Set-Content -LiteralPath "$fixturePath\t39\very_long_folder_name_for_breadcrumb_check_2026_09_travel_and_family\deeper_folder\d.txt" -Value 'd'
Set-Content -LiteralPath "$fixturePath\t39\a.txt" -Value 'a'
Set-Content -LiteralPath "$fixturePath\t39\b.jpg" -Value 'b'
Set-Content -LiteralPath "$fixturePath\t39\c.pdf" -Value 'c'
Set-Content -LiteralPath "$fixturePath\t39\sub\s.txt" -Value 's'
Set-Content -LiteralPath "$fixturePath\t39\empty\.keep" -Value ''
$existing = "$(& $adbPath shell 'if [ -e /sdcard/Download/asdd-008-t39 ]; then echo exists; fi')".Trim()
if ($existing -eq 'exists') {
  Write-Host '端末に Download/asdd-008-t39 が既にあります。何も置かずに止めました。' -ForegroundColor Red
} else {
  & $adbPath shell "mkdir /sdcard/Download/asdd-008-t39"
  & $adbPath push "$fixturePath\t39\." /sdcard/Download/asdd-008-t39/
  & $adbPath shell "rm -f /sdcard/Download/asdd-008-t39/empty/.keep"
  & $adbPath shell "ls -R /sdcard/Download/asdd-008-t39"
}
```

**期待**: 最後の`ls`に`a.txt` `b.jpg` `c.pdf`、フォルダ`sub`(中に`s.txt`)、空の`empty`、長い名前のフォルダ(その下に`deeper_folder/d.txt`)が出る。

**1回目のfixtureが端末に残っている場合**は、上の全体を流し直さず(既にあるので止まる)、足りない長い名前のフォルダだけを足せばよい:

```powershell
& $adbPath shell "mkdir -p /sdcard/Download/asdd-008-t39/very_long_folder_name_for_breadcrumb_check_2026_09_travel_and_family/deeper_folder"
& $adbPath shell "echo d > /sdcard/Download/asdd-008-t39/very_long_folder_name_for_breadcrumb_check_2026_09_travel_and_family/deeper_folder/d.txt"
& $adbPath shell "ls -R /sdcard/Download/asdd-008-t39"
```
(**`adb push`は空のフォルダを送らない**ので、`deeper_folder`には`d.txt`を入れてある(1回目はこれが無く、長い名前のフォルダごと届かなかった)。長い名前のフォルダを**ASCIIにしている**のは、Windowsの`adb push`が日本語のpathで失敗することがあるため。`empty`は空のフォルダを`adb push`で送れないため、`.keep`を送ってから消している。消すのは**このfixtureの`.keep`だけ**である。)

**後片付け**: 確認が終わったら、端末のファイルアプリで`Download/asdd-008-t39`を消してよい(中身はすべてこの手順で置いたもの)。

**確認の前に**、リネーム画面に何か1件読み込んでおく(1〜6とは別のファイルでよい)。**7で「戻っても元の一覧が保たれる」ことを見るため**である。

## 0. いま動いているのが、このtaskのbuildか確かめる

「ファイルを選ぶ」→「すべて」を押して開いた画面で:

- **画面の下の左に「← リネーム画面へ」**(暗い背景・シアンの枠と文字。**文言が「…」で切れずに全部見える**)、右に「確定」がある。
- **左上に「×」が無い**(何も選んでいないとき)。
- 右上に**︙(ケバブ)**がある。

どれかが違えば古いbuildである。

## 1. 入口

**エミュレータにはSDカードが出る**(`T12`の確認で観測済み)ので、保存場所は**2件**になる。したがって**保存場所の一覧から始まる**のが正しい。

**保存場所が1件のときの入口**(一覧を挟まずrootから始まる)は**このエミュレータでは見られない**。
widget testとmutation `M109`で固定してあり、見られないことは`task.md`へ残余riskとして記録済みである。**この項目は実施不要。**
(もし最初に一覧が出ず、いきなり内部ストレージの中身が出たなら、そのエミュレータはSDカードを持っていない。その場合は
上の段の**左に何も無い**こと、中央が「内部ストレージ」、帯が「内部ストレージ」だけ、︙に「すべて選択」だけ、「確定」が灰色であることを見て、報告に書いてほしい。)

- 最初に**保存場所の一覧**が出る。上の段の中央は「**ファイルを選ぶ**」、**左に何も無い**。
- ︙を押す: 「すべて選択」が**灰色**。「確定」も**灰色**。
- 「内部ストレージ」を選ぶと、上の段の左に **`←`** が出る。押すと**保存場所の一覧へ戻る**(画面は閉じない)。

## 2. フォルダの中(何も選んでいない)

1. `Download` → `asdd-008-t39` へ入る。

- 上の段: 左に **`←`**、中央は「**内部ストレージ**」のまま。
- 帯: 上の段の下、フォルダの一覧の上に「**内部ストレージ › Download › asdd-008-t39**」。**左寄せ**で、上の段と同じ色の背景は敷かれていない(一覧と同じ背景)。`›`は**はっきり読める濃さ**。
- フォルダの行(`sub`・`empty`・長い名前)は**右端に `›`** があり、**丸いチェックが無い**。
- ファイルの行(`a.txt`など)は**右端に丸いチェック**がある。
- `←`を押すと`Download`へ戻る。もう一度`asdd-008-t39`へ入る。

## 3. 1件選ぶ

1. `a.txt`の行を押す。

- その行の**面がうっすらシアンに染まり**、右端の丸が**シアンで塗られてチェックが入る**。**リネーム画面で「外すファイルを選ぶ」にしたときと同じ見た目**である。
- 上の段: 左が **`×`** に変わり、中央が「**1件選択中**」。**`←`は消えている**(これは仕様どおり)。
- ︙を押す: 「すべて選択」と「**選択をすべて解除**」の2つがある。
- 「確定」が押せる色になる。

## 4. すべて選択

1. ︙ →「すべて選択」。

- 「**3件選択中**」になる。**フォルダ(`sub`など)は選ばれない**。
- もう一度︙を押すと「すべて選択」が**灰色**。

## 5. `×`で解除する(画面は閉じない)

1. 左上の **`×`** を押す。

- **画面は閉じない。** 3件とも選択が外れ、上の段が **`←` + 「内部ストレージ」** に戻る。帯も`asdd-008-t39`のまま。

## 6. ︙から解除する / フォルダを移ると解除される

1. ︙ →「すべて選択」→ ︙ →「**選択をすべて解除**」。

- **画面は閉じない。** 選択がすべて外れる。︙を開くと「選択をすべて解除」が**もう無い**。

2. `a.txt`と`b.jpg`を選んだまま、`sub`フォルダを押す。

- `sub`の中へ入り、**選択は解除される**(上の段は `←` + 「内部ストレージ」)。帯は「… › asdd-008-t39 › sub」。

3. `←`で`asdd-008-t39`へ戻り、`empty`へ入る。

- 「**このフォルダにファイルはありません**」が**一覧の領域の中央**(上下・左右とも)に出る。︙の「すべて選択」は**灰色**、「確定」も**灰色**。

## 7. 画面を閉じる導線

1. `asdd-008-t39`で`a.txt`を選び、**「← リネーム画面へ」**を押す。

- リネーム画面へ戻る。**`a.txt`は読み込まれず**、準備で読み込んでおいた**元の一覧がそのまま**残っている。

2. もう一度開いて`asdd-008-t39`で`a.txt`を選び、**端末の戻る操作**をする(エミュレータ右のツールバーの`◁`、画面下のナビゲーションの`◁`、またはジェスチャーナビなら画面の左端から右へドラッグ。PowerShellから`& $adbPath shell input keyevent 4`でもよい)。

- 1と同じ: **親フォルダへ戻るのでも、選択の解除でもなく**、リネーム画面へ戻る。一覧はそのまま。

3. もう一度開いて`asdd-008-t39`で`a.txt`と`c.pdf`を選び、「確定」を押す。

- リネーム画面の一覧にその**2件だけ**が加わる。

## 8. 長押しでまとめて選ぶ(`T37`の回帰)

1. `asdd-008-t39`で`a.txt`の行を**マウスの左ボタンで押したまま約1秒待ち**、ボタンを離さずに`c.pdf`まで動かして離す(エミュレータではマウスが指の代わりになる)。

- `a.txt`〜`c.pdf`の3件が選ばれ、「3件選択中」になる。
- 長押しせずに上下へスクロールしただけでは、何も選ばれない。

## 9. 狭い幅と長い名前

1. エミュレータの設定で**フォントサイズと表示サイズを最大**にする(設定 → ディスプレイ(またはユーザー補助)→ 表示サイズとテキスト。終わったら戻す)。
2. `asdd-008-t39` → `very_long_folder_name_…` → `deeper_folder`へ入る。

- 帯は**末尾(`deeper_folder`)が見えている**。**帯をマウスで右へドラッグする**(押したまま右へ動かす)と、先頭の「内部ストレージ」まで見られる。2回目はここが動かなかった。
- 上の段の文字、下の「← リネーム画面へ」「確定」が**重ならず、はみ出さない**(文字が「…」で切れるのは許容)。
- 何か1件選べる場所(`asdd-008-t39`)で「N件選択中」も同じく重ならない。

## 10. TalkBack(読み上げ) — **行わない**

**2026-09-23 の開発者の決定で、このtaskの確認範囲から外した**(エミュレータではダブルタップが効かず操作できなかった)。
操作名・tap action・行を1つの項目として読ませることは widget test(semantics)と mutation `M418` 等で固定してあり、
実際の読み上げは`task.md`の残余riskとして受容している。**実施も報告も不要。**

## 報告

結果は会話で自由に書いてよい。決まった書式は不要である。**1で最初に保存場所の一覧が出たか**と、期待と違った点(スクリーンショットがあると助かる)を書いてほしい。
