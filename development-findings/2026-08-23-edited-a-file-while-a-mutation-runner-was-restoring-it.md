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
