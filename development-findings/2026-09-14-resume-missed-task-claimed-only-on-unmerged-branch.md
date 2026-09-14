# resumeが、未mergeのtask branchでだけclaimされたtaskを見落とした

## 観測したこと(2026-09-14)

開発環境をWindows側の不具合で初期化した後、`dev`(`b833603`)で
`workspace.py resume specs` を実行すると **`0 resume focus; 8 eligible`** を返し、
`008:T20` を **`pending` の着手可能task** として並べた。

実際には `T20` は branch `asdd/008-ui-alignment/T20-rule-and-exec-bar` 上で
`in_progress` になっており、Draft PR #165 があり、handoff は「Android実機確認の結果を待つ」
だった。claim(`task.json` の `status` 変更)がtask branchのcommitにしか無く、`dev` へは
mergeされていないため、`dev` だけを読む `resume` からは見えなかった。

`AGENTS.md` の再開手順の4番目(taskが所有するIssue/PR)まで進んで `gh pr list` を見たので
気付けたが、`resume` の結果だけを信じると、**同じtaskの既存branchとPRがあるのに
新しいbranchを作って `T20` を最初からやり直す**ところだった(`AGENTS.md`「同じtaskの既存
branch、worktree、Issue、PRがあれば新設しない」に反する)。

## なぜ起きたか

- 状態の正本(`task.json`)はGit管理だが、claimはtask branchでcommitされ、merge時に初めて
  integration branchへ入る。
- 初期化でlocal branchとworktreeが失われ、local `dev` だけが残った。以前のsessionは同じ
  checkoutをtask branchにしていたので、この差が表に出なかった。

## 改善の候補(未適用)

- 再開手順で、`resume` の前に **open PR と remote の `asdd/*` branch** を見て、
  `resume` が `pending` と言うtaskにbranch/PRが無いかを突き合わせる。
- あるいは `resume` 自体が remote branch 上の `task.json` を読んで、`dev` との食い違いを示す。

## 変更先と検証

未適用。
