# Development finding: review FAIL後に人間へ返す条件が明示されておらず、修正の途中で報告して止まった

- 観測日: 2026-08-12
- 観測した作業: 005 T09完了後のmanual checklist復元(PR #121)。attempt 1がFAILし、修正後の扱いで人間から指摘を受けた
- 改善先: ASDD plugin(`run-plan`と`review-task`の反復規律)、および筆者の実行
- 関連artifact: `/home/dev/.claude/skills/asdd/skills/run-plan/SKILL.md`の57・61行目、`/home/dev/.claude/skills/asdd/skills/review-task/SKILL.md`の「5. 報告する」

## 観測した事実

PR #121の独立reviewがFAIL(P1×1、P2×7)を返した。実装Agent(筆者)はP1とP2を修正してpushしたが、**再reviewを起動せずに人間へ報告して停止した**。人間から「再レビューは、あなたが直したらその場で再び呼びだして行うものではないのですか」と指摘された。

そのとおりである。3回FAILで止める規律は反復を前提にしており、修正の途中で人間へ返す必然性は無かった。

skill側の記述を確認した。

- `run-plan` 57行目: 「同じtaskの独立reviewが合計3回FAILしたら`blocked`へ変更し、各回の実出力、否定された仮定、次に必要な判断を報告する」
- `run-plan` 61行目: 「各独立review後、task所有Agentは`task.md`の作業記録へ`Review attempt N: ...`を一行で残す」
- `review-task` 末尾: 「修正も依頼された場合は、指摘を返して実装contextへ切り替え、修正と再検証を別passで行う」

3回FAILという**上限**と、attemptを記録する**義務**は書かれている。一方で、**loopをどこで抜けて人間へ返すか**は明示されていない。「PASS、BLOCKED、または3回FAILに達するまで、修正と再reviewを繰り返してから人間へ返す」と読むのが自然だが、条文としては存在しない。`review-task`の「別passで行う」も、そのpassを誰がいつ起動するかまでは書いていない。

## 期待していた動きと実際の動き

- 期待: FAIL → 修正 → 再review を、PASS / BLOCKED / 3回FAIL のいずれかに達するまで実装Agent側で回し、その結果を人間へ返す。
- 実際: FAIL → 修正 → 報告 で止まり、人間に「次はどうするのか」を判断させた。

## 影響とworkaround

- 影響: 人間がloopの進行役になる。1往復ごとに人間の入力が要り、3回FAIL規律の意味も薄れる(回数を数える主体が曖昧になる)。
- 影響: 未解決のP1を抱えたまま報告が出るため、人間が「今この成果物を使ってよいのか」を毎回判断させられる。今回は`004:T10`のmanual確認を人間へ渡す寸前だった。
- 影響の限定: 記録側は`Review attempt N:`が規定されているので、回数の復元自体は可能(ただし筆者はT09で散文形式で書き、#121では記録していなかった。これも同時に修正した)。
- workaround: 実装Agentが自分でloopを回す。今回は指摘を受けてattempt 2を起動した。

## 仮説と提案

- **主因は筆者の実行**である。skillが禁じていたわけではなく、3回上限から反復は読み取れた。ただし条文が上限だけを定めて終了条件を書いていないため、読み方に幅が残る。
- `run-plan`へ一文足すと曖昧さが消える。例: 「独立reviewがFAILなら、実装Agentは指摘を解消して同じrangeで再reviewを取る。人間へ返すのはPASS、BLOCKED、または3回FAILに達したときとする。途中経過を報告する場合も、次にAgentが再reviewを行うことを明示する。」
- 併せて、`review-task`の「別passで行う」を「実装Agentが修正後に再度reviewを起動する」と主語付きにする。
- 人間が明示的に途中で止めたい場合の逃げ道(「1回目のFAILで一度相談する」等)は、taskのriskで決めるより、人間がその場で指示する方が実態に合う。既定は「PASSまで回す」でよい。

## 改善結果

未対応(plugin側)。projectでは、attempt 1のFAILを修正したうえでattempt 2を起動し、`Review attempt N:`の1行記録を規定形式で3件のtaskへ補った。
