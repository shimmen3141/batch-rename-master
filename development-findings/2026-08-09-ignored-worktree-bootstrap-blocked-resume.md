# Development finding: ignoredなworktree bootstrap fileが再開を止めた

- 観測日: 2026-08-09
- 観測した作業: `complete-rename-execution` / `warning-confirmation-and-results` のfresh Terra forward-test
- 改善先: projectおよびASDD plugin
- 関連Issue・commit・artifact: #95、`AGENTS.md`、`compose.ai.yml`

## 観測した事実

fresh Agentはbranch、execution map、approved contract、clean diffから次packageを一意に選べた。しかし新しいworktreeにはgitignoredな`secrets/ai.env`が無く、`docker compose -f compose.ai.yml up -d`が`secrets/ai.env not found`で停止した。fileはComposeの構文上必要だが、このprojectでは値を必要とせず、コメントだけの空相当fileで隔離containerを起動できる。既存規約は「新しい秘密を移動・生成するなら人間へ依頼」とだけ述べ、非秘密placeholderをAgentが作成してよいか区別していなかった。

## 影響とworkaround

- 影響: clean cloneや新しいworktreeでAgentが実装前に停止し、「続けて」から再開できなかった。
- その場のworkaround: credentialを含まないコメントだけの`secrets/ai.env`を対象worktreeへ作り、project規約へ明示的な許可と禁止境界を追加する。

## 仮説と改善案

- 仮説: tracked fileだけを見た環境再現性と、ignoredなper-worktree bootstrapの前提が分離されていなかった。
- 改善案: project protocolへworktree bootstrap、safe placeholderの作成可否、既定のcontainer commandを記録する。ASDD setup/resume手順でもignored prerequisiteを監査し、credential生成とsafe placeholderを区別する。

## 改善結果

`AGENTS.md`へproject固有のbootstrap規則を追加した。ASDD plugin側の変更と再forward-test結果は、検証後に追記する。
