# mutation実行中に対象fileを編集し、編集がrunnerの復元で消えた

- 発生: `013:T05`(2026-08-23)
- 検出: 独立review attempt 5 のP2-2「`task.md`が『直した』と書いたP2が、実diffに存在しない」

## 観測

独立review attempt 4 のP2対応として `lib/data/rename_exec/plain_rename.dart` の doc comment
へ限界注記を足した。編集scriptは成功を返し(`ok2`と出力)、`task.md`の作業記録へ
「6件とも直した」と書いた。**しかしcommitにその変更は入っていなかった。**

原因は単純である。**そのとき別の mutation runner が背景で走っていた。** runnerは各変異の
前後で対象fileをsnapshotから復元するので、`plain_rename.dart`(`M53`/`M55`の対象)への
編集は次の復元で上書きされた。編集scriptは自分の書き込みが成功したことしか見ていない。

`2026-08-20-two-mutation-runners-ran-concurrently.md` と**同じ危険の裏返し**である。
あちらは変異がproductionへcommitされる向き、こちらは正しい編集が消える向き。
前回の改善は「runnerを同時に2つ起動しない」だったが、**「runnerが走っている間に対象fileを
編集しない」は書いていなかった**。

## なぜ自分で気づけなかったか

- 編集scriptの成功(`ok2`)を「変更が入った」の証拠として扱った。AGENTS.mdは
  「構造検査やtestのPASSは『壊していない』であって『意図した変更が入った』ではない」と
  書いているが、**同じことが自分のscriptの戻り値にも当てはまる**とは書いていない。
- `git status --short` を見たが `| head -3` で切っており、8件中3件しか読んでいない。
- commitは `git add -A` なので、消えた編集は**差分が無いだけ**でerrorにならない。

## 改善案(未実施。人間の判断が要る)

1. **AGENTS.mdのmutationの節へ1行足す。** 「runnerが走っている間は、表が対象とするfileを
   編集しない。runnerはsnapshotから復元するので、編集は黙って消える。」
2. **報告に書く前に、主張した変更が実diffにあることを確かめる。** 今回なら
   `git show --stat` か `grep` 1回で足りた。AGENTS.mdの「実差分を確認する」は完了前の
   手順として書かれているが、**「直した」と記録する時点**でも必要である。
3. mutation runner側で「実行中」を示すlock fileを置き、編集系のscriptがそれを見る、
   という手もあるが、runnerはASDD plugin側の共有scriptなのでこのprojectからは変えられない。
   1と2で足りると考える。

## 再発(2026-08-26、`013:T08`)— 別の原因で同じ結果になった

**runnerと編集が競合する状況が、今度は「編集した側の不注意」ではなく
「runnerが死んだと誤認した」ことで起きた。**

1. mutation を `timeout 900` 付きで前景実行したところ、**Agentのshell tool側の2分の上限**で
   呼び出しが切られた。切れたのは**wrapperだけで、`mutation_check.py`本体は生き残った**。
2. 生存を `/proc` で確認したが、**そのときは検出できなかった**(kill の遅延)。「死んだ」と
   判断して `git checkout -- <file>` で復元した。
3. その後 runner は生きたまま次の mutation を適用し、file は**再び書き換わった**。
   background で起動し直した runner は `has uncommitted changes` で正しく拒否した。
4. `/proc` を見直すと**元のrunnerがまだ走っていた**。kill してから復元し、
   background で走らせ直して `11 KILLED / 0 SURVIVED` を得た。

**このfileの既存の教訓(「runnerが走っている間は編集しない」)は守っていた** — 守れなかった
のは**「走っているかどうかの判定」**である。

### 追加で得た知見

- **前景の長い実行は、上限で切られてもプロセスが残る。** 呼び出しが返らなかったことを
  「止まった」と読まない。**`timeout` を付けても、それはwrapperの寿命であって、
  切られた側の子processは残りうる。**
- **mutation は最初から background で実行する。** 数十件の表は前景の上限を超える。
  今回、最初から background にしていれば競合そのものが起きなかった。
- **`/proc` の一度きりの走査を「居ない」の証拠にしない。** kill には遅延があるので、
  居ないことを確かめるなら少し待って2回見る。
- **runnerの `has uncommitted changes` は安全網として働いた。** 汚れたtreeで走り出さない
  ので、被害は「時間を捨てた」だけで済んだ。**この防御があることを前提に、
  復元→再実行を焦らない。**
