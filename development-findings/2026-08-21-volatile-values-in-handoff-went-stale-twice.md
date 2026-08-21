# handoffへ書いた揮発値が2回続けて陳腐化し、独立reviewが同じ指摘を2回出した

- 日付: 2026-08-21
- 観測: `013:T10` の独立review attempt 4(P2-1〜P2-3)と attempt 5(P2-1〜P2-3)
- 種類: 手戻り / 仕組みの不足

## 何が起きたか

`task.md` の「検証結果」表と `Current state / handoff` に、**commitのたびに変わる値**を prose として書いていた。

- `flutter test` の件数(463 → 464)
- required CI の run 番号(`32497528506` → `32502111699` → `32505011582`)
- `Last checkpoint` と `Evidence revision` が指す review attempt と commit

**独立reviewが attempt 4 と attempt 5 で、同じ3種類の陳腐化を指摘した。** attempt 4 で全部直したのに、その修正commit自体がheadを動かしたので、attempt 5 の時点でCI run番号がまた古くなっていた。

- attempt 4: 「表は463件だが実測は464」「run `32497528506` の headSha は `f22f8cf` で最新headではない」「`Evidence revision` が attempt 2 基準のまま」
- attempt 5: 「`Last checkpoint` が attempt 3 のまま(同じ節の `Evidence revision` と自己矛盾)」「`Next Agent action` が既に完了した作業を指す」「required CI 行が `ddc4ddc` を指したまま(**修正後にもう一度再発**)」

attempt 5 の reviewer が `AGENTS.md` の「同じ根本原因が修正後も2回続いたら解き方を変える」に該当すると明示した。

## なぜ起きたか

**docs commit を積むこと自体がheadを動かす**、という循環がある。

1. reviewを依頼する
2. review が P2 を挙げる
3. 直して commit する ← **ここでheadが変わり、CI run番号と「最新head」の指し先が同時に古くなる**
4. 次の review が同じ種類の陳腐化を指摘する

書き直す限りこの循環は終わらない。**値を正しく保つ作業ではなく、値を持つこと自体が問題だった。**

もう一つの要因は、**同じ節の中に「動く値」と「動かない値」を混ぜていた**ことである。`Current state / handoff` には `Blocker category`(動かない)と `Evidence revision`(commitごとに動く)が並んでいた。片方だけ更新すると節の中で自己矛盾する — attempt 5 の P2-1 がまさにそれだった。

## 得られた知見

- **prose に揮発値を持たない。** 「どこを見れば分かるか」を書けば、値そのものは書かなくてよい。CI の結果は PR の checks 欄が正本であり、`task.md` へ写した瞬間に**二重管理**になる。`AGENTS.md` は Issue や PR について「taskの意味、依存、handoffを複製しない」と書いているが、**逆方向(外部の揮発値をtaskへ複製する)**は書いていない。
- **「最新」「以後の差分」のような相対表現は、commitを積むと嘘になる。** 絶対のcommit hashで書くか、書かないかのどちらかにする。
- **書き直しを繰り返す修正は、2回目で止めて手順を変える。** これは `AGENTS.md` が既に定めていることで、今回はreviewerに指摘されるまで自分で気づけなかった。**「値を直す」は毎回成功するので、失敗のパターンとして見えにくい。**

## ASDD側で緩和できること

- **`AGENTS.md` の再開・報告の節へ「handoffへ揮発値を書かない」を加える。** 対象は CI の run 番号、test 件数、「最新head」のような相対表現。**どこを見れば分かるかを書く。**
- **例外**: 完了時点で凍結する値(merge した commit、manual確認の対象commit/build)は書いてよい。**動かなくなったものだけを書く**、という基準にできる。
- `review-task` skill の報告項目に「handoffの揮発値が現在のHEADと一致しているか」を入れることも考えられるが、**それは陳腐化を検出し続ける形であって、解き方を変えたことにならない。** 書かせない方が良い。

## 改善結果

- 2026-08-21 / `013:T10` の `task.md` から **required CI の run 番号を外した**。「正本は PR #142 の checks 欄(`gh pr checks 142`)で、headSha 一致の確認は merge 直前に行う」と書き換えた。
- 2026-08-21 / `flutter test` の件数は残したが、「**最終の実装commit時点の値で、docs commitでは変わらない**」と条件を明示した。件数は `lib`/`test` が変わらない限り動かないので、揮発しない。
- 2026-08-21 / `Evidence revision` から「最新HEAD」「以後の差分は〜だけ」という相対表現を外し、**どの commit に対する review PASS かを絶対で書く**形にした。
- forward-test: **未実施。** 次に PR を伴う task で、docs commit を積んでも handoff が陳腐化しないかを見る。
