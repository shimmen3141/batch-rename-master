# 手動確認: アプリ内のファイル選択と、Android での名前の変更

この文書は、**実機でしか分からないこと**だけを扱う。画面の出し分け、階層の辿り方、
選択が移動で解除されること、名前の一覧が取れることは自動テストで確かめてあるので、
ここには含めない。

見てほしいのは、**実際の保存場所が正しく出るか**、**本当に名前を変更できるか**、
そして**操作して分かりやすいか**である。

## 使う端末

**Android 11 以上**の端末またはエミュレータ。起動手順は
[`docs/development/emulator-verification.md`](../../../../docs/development/emulator-verification.md) に従う。

**先にアプリを入れて、「すべてのファイルへのアクセス」を許可しておく。**
許可の出し方は前のタスクで確認済みなので、ここでは扱わない。

## 0. いま動いているのが、このタスクのビルドか確かめる

**手順1へ進む前に、必ずこれを確かめてほしい。** ホストとコンテナは同じ作業ツリーを
共有しているので**ブランチはすでにこのタスクのもの**になっているが、**端末に入っている
アプリは、入れ直すまで古いまま**である。

ホストのターミナルで、リポジトリのルートから:

```powershell
git branch --show-current   # asdd/013-safe-android-rename/T07-implement-android-file-browser
git log --oneline -1        # このタスクのコミットか
flutter pub get             # コンテナと .pub-cache が別のため
flutter devices             # device_id を確認
flutter run -d <device_id>
```

アプリで「ファイルを選ぶ」→「すべて」を押したとき、**次の画面が出れば新しいビルド**である。

- 上に **「ファイルを選ぶ」**、左は **×(閉じる)**。
- 最初に出るのは **保存場所の一覧**(「内部ストレージ」など)。
- ファイルの行は **左端にチェックボックス**が並ぶ(**長押しは要らない**)。

**次のものが出たら、古いビルドが動いている。**

- 左上に**ハンバーガーメニュー**、横から出るサイドバー、上部に**パンくずリスト**。
- 保存場所の名前が `sdk_gphone…` のような**端末の内部名**。
- ファイルを1つ押すとそのまま確定し、**複数選ぶには長押し**が要る。
- 前回開いた場所が復元される。

これは **Android 標準のファイル選択画面**で、このタスクが置き換えた**前の**入口である。
**古いビルドのままでは、手順3で「SAF ではフォルダ内のファイル名を一覧できません」と
出て名前を変更できない。** それは古いビルドとしては正しい動作なので、アプリを入れ直して
からやり直してほしい。

## 準備するファイル

端末の「Download」フォルダに、**捨ててよいファイルを3つ**置く(`test1.txt` /
`test2.jpg` / `test3.pdf`)。**拡張子が違うもの**が要る — アプリが拡張子で絞り込まない
ことを見るためである。

**エミュレータのファイルアプリでは、新しいファイルを作れない。** ホストの PowerShell
から置いてほしい。

```powershell
$adbPath = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
$fixturePath = Join-Path $env:TEMP 'asdd-013-t07'
Remove-Item -Recurse -Force -LiteralPath $fixturePath -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $fixturePath | Out-Null
Set-Content -LiteralPath (Join-Path $fixturePath 'test1.txt') -Value 'test1-original'
Set-Content -LiteralPath (Join-Path $fixturePath 'test2.jpg') -Value 'test2-original'
Set-Content -LiteralPath (Join-Path $fixturePath 'test3.pdf') -Value 'test3-original'
& $adbPath shell "rm -f /sdcard/Download/test1.txt /sdcard/Download/test2.jpg /sdcard/Download/test3.pdf /sdcard/Download/keep.txt"
& $adbPath push "$fixturePath/." /sdcard/Download/
& $adbPath shell ls -l /sdcard/Download
```

**期待**: 最後の `ls` に `test1.txt` `test2.jpg` `test3.pdf` の3つが出る。

**このあとのコマンドは `$adbPath` と `$fixturePath` を使う。同じ PowerShell を開いた
まま**進めてほしい。閉じてしまったら、上の最初の2行だけをもう一度実行すれば続けられる
(`Remove-Item` 以降は不要)。

`test2.jpg` と `test3.pdf` の**中身はただの文字列**である。ここでは中身を開かないので
それで構わない。

**端末のファイルアプリには、この3つがすぐ出ないことがある。** `adb push` で置いた
ファイルは端末のメディア索引にすぐ載らないためである。**この確認では、ファイルアプリ
ではなく `adb shell ls` の結果を正とする。** アプリは索引ではなくファイルシステムを
直接見るので、索引に無くても選択画面には出るはずである — **選択画面に出なければ
それは不具合なので書いてほしい。**

## 1. 保存場所と階層

1. 「ファイルを選ぶ」→「すべて」を選ぶ。
2. 出てきた保存場所の一覧を見る。
3. 「内部ストレージ」を選ぶ。
4. 「Download」へ入る。

**こうなってほしい**

- 手順2で、**この端末に実際にある保存場所**が並ぶ。SD カードや USB を挿しているなら
  それも出る。**挿していないものが出ていたら書いてほしい。**
- 手順3のあと、「Download」「DCIM」などの**近道**が上に出る。
  **実際には無いフォルダが近道として出ていないか**を見てほしい。
- 現在いる場所が画面の上に出ていて、フォルダを移動すると変わる。
- フォルダの中では、上向きの矢印で1つ上へ戻れる。
- **保存場所の一番上まで戻ると、上向きの矢印は消える**(それより上へは行けない)。
  代わりに、同じ位置に**保存場所を選び直すアイコン**(SDカードの絵。長押しすると
  「保存場所を選び直す」と出る)が現れる。

## 2. 選択して読み込む

1. 「Download」で、準備した3つのうち**2つ**にチェックを入れる。
2. 「確定」を押す。

**こうなってほしい**

- 一覧に、選んだ2つだけが並ぶ。
- **拡張子で絞り込まれていない**(準備した3つが選択画面にすべて出ていた)。
- 隠しファイルやサブフォルダも、選択画面ではそのまま並んでいた。

## 3. 名前を変更する(このタスクの中心)

1. ルールを作る。**「＋ 元の名前」を足し、続けて「＋ 自由テキスト」で `-x` と入力する。**
   元の名前を含む形にしておく — 固定の文字列だけにすると2つが同じ名前になり、
   確認のダイアログが1つ増える(それ自体は正しい動きだが、ここで見たいことではない)。
2. 実行する。**確認のダイアログが出たら、そのまま実行を選ぶ。**
3. PowerShell で実体を確かめる。

```powershell
& $adbPath shell ls -l /sdcard/Download
& $adbPath shell cat /sdcard/Download/test3.pdf
```

**こうなってほしい**

- **実際にファイルの名前が変わっている。** 選んだ2つが `test1-x.txt` のように
  **拡張子はそのままで**名前だけ変わっている。これが確認できれば、Android で名前を
  変更できるようになったことになる(これまでは「対応していません」で止まっていた)。
- 変えていない3つ目のファイルは、名前も中身(`test3-original`)もそのままである。
  **3つ目に `.pdf` 以外を選んだ場合は、`cat` の対象をそのファイルに読み替えてほしい。**
- 結果の表示に「元に戻す」が出るなら押してみて、**名前が元へ戻る**ことも見てほしい。

## 4. 読み込んでいないファイルとの衝突

**この手順は 3 の続きではない。** はじめに「Download」の中を片付け、はじめの3つへ
戻してから始める。PowerShell で次を実行してほしい(手順3で名前が変わったファイルを
消し、`keep.txt` を置くところまで一度に行う)。

```powershell
& $adbPath shell "rm -f /sdcard/Download/test* /sdcard/Download/keep*"
& $adbPath push "$fixturePath/." /sdcard/Download/
Set-Content -LiteralPath (Join-Path $env:TEMP 'keep.txt') -Value 'keep-original'
& $adbPath push "$env:TEMP\keep.txt" /sdcard/Download/keep.txt
& $adbPath shell ls -l /sdcard/Download
```

**期待**: `test1.txt` `test2.jpg` `test3.pdf` `keep.txt` の**4つだけ**が出る。
手順3で付いた `-x` の名前は、上の `rm` が `test*` でまとめて消している。
**それ以外の名前が残っていたら手で消してほしい**
(`& $adbPath shell "rm -f '/sdcard/Download/<残った名前>'"`)。

**アプリを開いたままここへ来た場合は、一覧を読み込み直してほしい** — アプリが持って
いる一覧は、上のコマンドで消したファイルを指したままだからである。

1. 「Download」に、**読み込んでいない**ファイル `keep.txt` が置かれている(上で置いた)。
2. アプリで **`.txt` のファイルを1つだけ**読み込む(拡張子は変わらないので、
   `.jpg` を選ぶと `keep.jpg` になってしまい、この手順の目的から外れる)。
3. **ルールのトークンをすべて外し**、「＋ 自由テキスト」で `keep` だけにする。
   **拡張子は入力しない**(自動で保たれる)。前回のルールが残っていることがあるので、
   **必ず全部外してから**作り直す。
4. 実行しようとする。

**こうなってほしい**

- 実行の前に、**同じ名前がすでにあることが警告として出る**。
- そのまま実行すると、`keep.txt` は**上書きされず**、新しい名前に番号が付く
  (`keep (1).txt`)。
- **`keep.txt` の中身が変わっていない**ことを PowerShell で確かめてほしい。

```powershell
& $adbPath shell ls -l /sdcard/Download
& $adbPath shell cat /sdcard/Download/keep.txt
```

**期待**: `keep.txt` の中身が `keep-original` のままで、`keep (1).txt` が増えている。

## 5. アプリごとの保存領域

1. 選択画面で「内部ストレージ」→「Android」へ入る。
2. 「media」へ入る。その中にフォルダがあれば、さらに1つ入ってみる。
3. 「Android」へ戻り、「data」へ入ってみる。

**こうなってほしい**

- 手順1で、「名前を変更できないことがあります」という**注記**が出る。
  **その下に `data` `media` `obb` などのフォルダが並んでいて、隠されていない。**
  (このフォルダの直下には、ふつうファイルは無い。フォルダだけで構わない。)
- 手順2で「media」へ入ると、**注記は出ない**。
- 手順3の「data」は、**「このフォルダを開けませんでした」になることがある。**
  そうなっても正しい — 許可があっても読めない場所があるためである。
  **開けたか開けなかったかを書いてほしい。**

**この手順ではファイルを用意しない。** 注記が出る側(`Android` 直下や `data`)は
Android 11 以上ではアプリから読めないことが多く、置いても手順3と同じ
「開けませんでした」になるだけである。**注記が出る場所での改名が成功するかどうかは、
実機の構成に依存する** — この確認では扱わず、`013:T08` が引き受ける。

## 6. 操作感

- 画面が狭いときに、フォルダ名やファイル名が読めるか。
- チェックを付ける範囲が押しやすいか。
- 深い階層まで辿ったとき、現在地の表示が長すぎて読めなくならないか。

## 後片付け

確認が終わったら、置いたファイルを消してよい。

```powershell
& $adbPath shell "rm -f /sdcard/Download/test* /sdcard/Download/keep*"
Remove-Item -Recurse -Force -LiteralPath $fixturePath -ErrorAction SilentlyContinue
```

## 報告

結果は会話で自由に書いてよい。**決まった書式や合否の記入は不要**である。
気づいたこと(出るはずのない保存場所が出た、階層が辿りにくい、など)があれば
そのまま書いてほしい。
