# mutation runnerを2つ同時に走らせ、偽のSKIPPEDを成果として報告しかけた

- 日付: 2026-09-01
- 観測: `008:T16` の mutation 実行2回目
- 種類: 検証漏れ

## 何が起きたか

`mutation_check.py` の実行が10分の上限に掛かったので background で起動し直した。1回目を
停止したつもりだったが**実際には生きており**、2つのrunnerが同じfileを書き換え合って
互いの復元を壊した。

結果、**5件が SKIPPED(`matched 0 time(s)`)** と報告された。実装が変わったからではなく、
working tree へ他方のmutationが適用されたままだったためである。`git diff` を取ると
M182・M183・M188・M189 の mutation が残っていた。

**この表をそのまま報告していたら、「testが対象を押さえていない」と読める嘘の証拠が
task.mdへ残っていた。**

## なぜ起きたか

- `TaskStop` を呼んだあと、**プロセスが実際に消えたかを確認しなかった。**
- 再実行の前に `git status` を見なかった。runnerはworking treeがcleanでないと動かない
  仕組みなのに、**片方がcleanな瞬間を捉えて起動してしまった**(競合の窓が開いていた)。

## どう直したか

- 停止後に `ps aux | grep -c "[m]utation_check"` が 0 であることを確認してから起動する。
- 起動前に `git status --short` が空であることを確認する。
- **汚染された表は報告に使わない。**復元し、`flutter test` の全件PASSを確認したうえで
  単独で再実行した(3回目 = 28件すべてKILLED)。経緯も `task.md` へ残した。

## 一般化できること

`AGENTS.md` は「**『対象が見つからなかった』と『testが落ちなかった』を区別するのが要点**」
と書いている。この事故は**その区別そのものを壊す**ので、SKIPPED が出たときは実装の変更を
疑う前に **working tree の汚染を疑う**のが先である。

- SKIPPED を見たら、まず `git status --short` と `git diff` を見る。
- runner は**同時に1つだけ**走らせる。分割して逐次実行するのはよいが、並列にしない。

## 検証・forward-test

- 単独での再実行で 28件すべて KILLED(その後 M201〜M203 を足して **31件すべて KILLED**)。
- 独立review attempt 6 が同じ表を独立に再実行し、**SKIPPED は1件も再現しなかった**。
  「mutation の `find` はすべて現在の実装を指している」ことが外から確認された。
- forward-test は未了 — 次にmutationを走らせるtaskで、この手順が守られるかを見る。

## 追記(2026-09-03、`008:T18`)

**同じ症状を再現させた。** 経緯と、そこから分かった見分け方を残す。

1. runner を `nohup` で起動したら**親shellの終了で殺され**、mutation適用済みのfileが
   working tree へ残った。**harnessのバックグラウンド実行を使えば起きない。**
2. その残骸がある状態で流したので、**SKIPPEDが5件**出た(`15 KILLED / 1 SURVIVED /
   5 SKIPPED`)。KILLED/SURVIVED の側も互いの復元を壊した結果で信用できなかった。
3. 木を復元して単独で流し直し、`0 SKIPPED` を得た。独立reviewが `--list` を走らせ、
   `21 mutations, 0 with an unexpected match count` を得たことで、**5件すべてが偽**
   だったことが確定した。
4. **本物のSKIPPEDも別に1件出た** — `find` がfile内に5か所あり `matched 5 time(s)`。
   直前のコメント行を含めて一意にして解決した。

### 見分け方

**本番の前に `--list` を走らせる。** test を回さないので数秒で終わり、

- `0 with an unexpected match count` なら、**対象はすべて特定できている**。この後に出た
  SKIPPED は**競合を疑う**(木が汚れていないかを `git status --short` で見る)。
- `matched N time(s), expected 1` が出たら、**`find` が一意でない**。これは本物である。

**この2つを混同すると、「testが落ちなかった」を「対象が見つからなかった」と読み違える。**

