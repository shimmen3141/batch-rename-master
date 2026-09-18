# 手動確認: 読み込み導線と場所の提示

## 何を確かめてほしいか

`008 / T08` で、**いま何がどこから入っているか**を読み込み帯が示すようにし、
**行の場所は一覧に複数の場所が混ざっているときだけ**出すようにしました(002 specの改訂を
2026-09-18 に承認いただいた分です)。

自動testが既に押さえているもの(帯の文言の出し分け、行に出る/出ないの両方向、
場所が2つ以上のとき帯が具体名を出さないこと)は**手順に入れていません**。
ここでお願いするのは、**実機とdesktopで読めるか・押せるか**だけです。

| | |
|---|---|
| 対象 | **`008 / T08` 読み込み導線と場所の提示を整える** |
| **`lib/` の最終commit** | 依頼時にお伝えします |
| branch | `asdd/008-ui-alignment/T08-load-affordance-and-path` |
| 端末 | **Android実機**(手順1〜3)と **Windows desktop**(手順4) |

**branchの切り替えは不要です。** Agent が `/workspace` をこのbranchにしたまま待ちます。
共通の起動手順は
[`docs/development/emulator-verification.md`](../../../../docs/development/emulator-verification.md)
にあります。

## Android(手順1〜3)

### 事前準備

[`008 / T07` のfixture](../T07-row-and-warning-presentation/manual-verification.md)
(`DCIM/t07-fixtures`。27件)を使います。

**`.worktrees/t07-fixtures/` は用意してあります**(27件。依頼時に存在を確認しました)。
repositoryのルートで**folderごと送ってください**。

```powershell
adb push .worktrees\t07-fixtures /sdcard/DCIM/
adb shell ls /sdcard/DCIM/t07-fixtures | Measure-Object -Line
```

**期待**: `Lines : 27` と表示される。

`.worktrees/t07-fixtures/` が消えている場合は、**Agent(container内)が
`python3 tool/make_t07_fixtures.py .worktrees/t07-fixtures` で作り直します**
(script は出力先folderを引数に取ります)。お知らせください。

### 手順1 — 読み込み前(1分)

appを起動し、**まだ何も読み込んでいない状態**で上の帯を見ます。

- **確認A**: 帯に **`未選択`** が出ている。
- **確認B**: button が **`ファイルを選ぶ`** になっている。

### 手順2 — 読み込み後(3分)

`ファイルを選ぶ` → `すべて` → `DCIM/t07-fixtures` の27件を選んで確定します。

- **確認A**: 帯が **`t07-fixtures`**(読み込んだfolderの名前)を示している。
- **確認B**: button が **`別フォルダへ`** に変わっている。
- **確認C**: **各行から場所が消えている。** 27行のどこにも `t07-fixtures` が出ていない
  (folderは1つなので、帯の1か所だけが示します)。
- **確認D**: 帯が**狭幅で崩れていない**。1回目(2026-09-18)の指摘を直した箇所です。
  - 帯が**画面幅いっぱい**に広がっている(未選択のときも短く浮かない)。
  - **folder 名の長さで `別フォルダへ` の位置が動かない。** 長い名前は `...` で省略されます。
  - はみ出し(赤い縞)が出ていない。文字を大きくする設定にしている場合は、その状態でも見てください。
- **確認E**: `別フォルダへ` が**指で押しやすい**。狙いを外して別のものが反応しない。

> **この手順は完了しています(2026-09-18)。** 手順1・手順3は `7387c9c`、手順2は修正後の
> `f71e2f6` で成立しました。手順4は Windows のファイル選択画面が folder を跨いだ選択を
> 許さないため**実行できません**
> (`development-findings/2026-09-18-desktop-picker-cannot-span-folders-so-the-multi-folder-path-is-unreachable.md`)。
> 結果は[`task.md`](task.md)の「manual確認の結果」が正本です。手順2で受領した
> **場所の文字列が末尾から省略される件**は[`T23`](../T23-source-path-legibility/task.md)が
> 引き受けました。

## 手順3 — 外したとき(1分)

`すべて外す` を押します。

- **確認A**: 帯が **`未選択`** へ戻り、button が **`ファイルを選ぶ`** へ戻っている。

## Windows desktop(手順4)

### 事前準備

2つのfolderにファイルを作ります。**pathはそのまま貼ってください**(変数は使いません)。

```powershell
New-Item -ItemType Directory -Force C:\temp\t08-a
New-Item -ItemType Directory -Force C:\temp\t08-b
1..3 | ForEach-Object { Set-Content -Path ("C:\temp\t08-a\a" + $_ + ".txt") -Value "a" }
1..3 | ForEach-Object { Set-Content -Path ("C:\temp\t08-b\b" + $_ + ".txt") -Value "b" }
```

起動は次のとおりです。

```powershell
flutter run -d windows
```

### 手順4 — 複数folderが混ざる(4分)

`ファイルを選ぶ` → `すべて` → **`C:\temp\t08-a` の3件と `C:\temp\t08-b` の3件を
まとめて選んで**確定します(選択ダイアログでfolderを移動しながら選べます。
一度にできない場合は、6件を1回の選択に入れられる方法で構いません)。

- **確認A**: 帯が **`複数のフォルダ`** と出ている。**`t08-a` / `t08-b` という名前は帯に出ない。**
- **確認B**: **各行にその file のfolder名**(`t08-a` / `t08-b`)が出ている。
  どの行がどちらのfolderのものか読み取れる。
- **確認C**: 「複数のフォルダのファイルが含まれています。…」の警告が**一度出る**。
  帯の `複数のフォルダ` と**同じ文が二重に出ていない**。
- **確認D**: 続けて `別フォルダへ` → `C:\temp\t08-a` の3件だけを選び直すと、
  帯が **`t08-a`** になり、**行から場所が消える**。

## 結果の返し方

会話で自由に書いてください。**「問題なかった」だけでも構いません**が、**どの確認まで見たか**を
書いていただけると、Agentが記録を過大にしません。気になった点は**そのままの言葉**で書いてください。

**desktopが今すぐ用意できない場合は、手順1〜3(Android)だけでも構いません。**
そのときは手順4を未確認として記録し、残余riskの引き受け先を書きます。

## 結果を受け取ったあとのAgent作業

1. 結果と対象commitを`task.md`へ記録します(開発者の言葉は原文のまま引用します)。
2. 不成立があれば直し、`lib/`が動いた場合は**動いた範囲だけ**の再確認をお願いします。
3. 成立していれば、PR #170 をreadyにしてmergeします。
