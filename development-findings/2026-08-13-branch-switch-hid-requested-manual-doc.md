# Development finding: manual依頼の直後にbranchを切り替え、依頼した文書を人間から見えなくした

- 観測日: 2026-08-13
- 観測した作業: `013:T01`のspike S-2を人間へ依頼した直後に、`008`の後続作業のため同じworktreeでbranchを切り替えた
- 改善先: Agentの実行(worktree運用)。`AGENTS.md`の記述自体は正しい
- 関連artifact: `specs/013-safe-android-rename/tasks/T01-decide-storage-boundary/manual-verification.md`、branch `docs/asdd-008-plan-approval`

## 観測した事実

1. `013:T01`の`manual-verification.md`を`asdd/013-safe-android-rename/T01-decide-storage-boundary`へcommitし、pushした。
2. 人間へ「この手順で実機確認をお願いします」と依頼し、**repository-relative link**で示した。
3. **その直後**、`008`のplan承認記録とP2修正のため、同じworktreeで`docs/asdd-008-plan-approval`へ`git switch`した。
4. 人間から「`manual-verification.md`が見えません。reload windowしても見えないままです」と報告された。

`/workspace`はhostとcontainerで同じ作業treeである。branchを切り替えれば、**人間のIDEからもfileが消える。** `docs/asdd-008-plan-approval`は`dev`から切ったbranchで、013の作業は含まれていない。

## 期待していた動きと実際の動き

- 期待: 依頼した文書は、人間が作業を終えるまでその場所にある。
- 実際: 依頼から数分でAgentが消した。人間は「なぜ見えないのか」の調査に時間を使った。**link先が正しくても、fileがそこに無い。**

## 根本原因

`AGENTS.md`は既に正しく定めている。

> manual確認を依頼する前に、Agentが検証対象branch、exact commit/build、人間が実行するworkspaceを準備し、**その状態を維持して待つ**。人間によるbranch移動は原則不要と明記し、`git switch`や`git checkout`を通常手順にしない。

筆者はこの条文を「**人間にbranch移動をさせない**」と読んでいた。実際には「**その状態を維持する**」が主で、誰が動かすかは関係ない。Agentが動かしても人間の作業は同じだけ壊れる。

なぜ動かしたかというと、**待ち時間を無駄にしたくなかった**からである。013が人間待ちなので008を進めた。判断自体は妥当で、間違っていたのは**やり方**である。

`AGENTS.md`は並列作業の手段も既に定めている。

> worktree: 並列作業、長い外部待ち、独立reviewではproject内`.worktrees/<plan-id>-<task-id>-<slug>`を優先する。

**「長い外部待ち」がまさに今回である。** 条文は揃っていて、筆者が結び付けていなかった。

## 影響とworkaround

- 影響: 人間が実機確認に着手できず、原因調査に時間を使った。**人間の時間はこのprojectで最も高価な資源**で、Agentのやり直しと違って取り返せない。
- 影響: 「reload windowしても直らない」という、原因から遠い症状に見える。gitのbranchが原因だと気づきにくい。
- workaround: `/workspace`を対象branchへ戻した。以後、実機確認が終わるまでここを動かさない。

## 仮説と提案

- **人間待ちの間に別branchの作業をするときは、`/workspace`を動かさず`.worktrees/`を使う。** これがこの件の再発防止のすべてである。今回で言えば`.worktrees/008-T07-row-and-warning`のようなworktreeを作り、`/workspace`は013のbranchに置いたままにする。
- **manual依頼を出したら、その時点で`/workspace`は「予約済み」と扱う。** 結果を受け取るまでbranch、commit、未commit変更を動かさない。動かす必要が出たら、動かす前に人間へ伝える。
- 一般化: **共有された作業treeの状態は、Agentだけの持ち物ではない。** commitやbranchはAgentの作業単位だが、worktreeは人間との共有面である。共有面を変えるのは、外部への操作と同じ扱いにする。
- `AGENTS.md`への追記は不要と考える。条文は既にあり、足りなかったのは筆者の適用である。ただし「Agent自身のbranch切り替えも含む」と一言明示すれば誤読は減る。人間の判断に委ねる。

## 改善結果

`/workspace`を`asdd/013-safe-android-rename/T01-decide-storage-boundary@2993d5e`へ戻し、`manual-verification.md`と`spike/renameat2_spike.c`が見える状態にした。008の作業は既にpush・PR済み(#134)なので失われていない。

以後、実機確認の依頼中に別branchの作業が必要になったら`.worktrees/`を使う。

誤読を減らすため、「Agent自身も共有workspaceを動かさない」をproject PR #136とASDD PR #10で明記した。
