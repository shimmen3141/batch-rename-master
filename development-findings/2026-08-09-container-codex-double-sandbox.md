# Development finding: container内Codexの二重sandboxが再開を止めた

- 観測日: 2026-08-09
- 観測した作業: `complete-rename-execution` / `platform-rename-adapters` のcontainer再開確認
- 改善先: projectのAI container構成、`ai-sandbox-setup`
- 関連artifact: `compose.ai.yml`、`.devcontainer/Dockerfile`、`docs/development/ai-sandbox.md`

## 観測した事実

ASDD plugin 1.0.7をcontainerのCodexへinstallし、`続けて`から`asdd:run-development-unit`が選択されるところまでは成功した。しかし通常の`codex exec --sandbox read-only`では、repositoryを読む最初のcommandが`bwrap: No permissions to create a new namespace`で停止した。外側のDocker containerにはsecret shadow、非root user、egress allowlistがある一方、CodexがLinux内側sandboxとして使うbubblewrapは追加のunprivileged user namespaceを作れなかった。

外側workspaceをread-only bind mountした検証containerでCodexの内側sandboxだけを無効化すると、Agentはbranch `feat/96-platform-rename-adapters`、HEAD `dfbd4c0`、未統合の実装commit、関連definition・execution map・manual verification、次の関連testを正しく復元した。変更前後のworking treeも一致した。

## 影響とworkaround

- 影響: container内で`codex`を通常起動すると、skillは認識してもshell commandを一つも実行できず、「続けて」から再開できない。
- その場のworkaround: 外側containerをread-onlyにした確認に限り`--dangerously-bypass-approvals-and-sandbox`を指定した。
- 注意: このflagをhost側で使うと外側の隔離が無いため、一般手順として直接案内してはいけない。

## 仮説と改善案

- project imageへ専用wrapperを焼き込み、`AI_SANDBOX=1`と`/workspace/secrets/.dummy-marker`を確認できた場合だけCodexの内側sandboxを無効化する。
- container内の通常起動名と理由を`AGENTS.md`と人間向けsandbox guideへ一度だけ記録する。
- `ai-sandbox-setup`のCodex profileにも同じwrapperとforward-testを追加する候補とする。

## 改善結果

`codex-container` wrapper、起動規約、利用ガイドを追加した。image buildは成功し、wrapperは`AI_SANDBOX`不在とdummy shadow不在をそれぞれexit 1で拒否した。正規compose環境ではwrapper経由のCodexが`git branch --show-current`を実行し、`feat/96-platform-rename-adapters`を返した。ASDDのread-only forward-testでは同branch、HEAD `dfbd4c0`、未統合package、次の関連testと手動検証を正しく復元した。再開後の最初のcheckpointとして`flutter test test/spec_005_rename_exec/`を実行し、52件すべてPASSした。

追加レビューで、wrapperを`--dangerously-bypass-approvals-and-sandbox`から`--sandbox danger-full-access`へ狭め、approval policyを上書きしない形にした。`AI_SANDBOX`とdummy shadowに加えて非root user・docker.sock不在も起動条件にした。一般化先の`ai-sandbox-setup`にはCodex選択時のwrapper生成、`/workspace`限定のsystem safe.directory、利用ガイド、拒否条件の検証、forward-test用evalを追加した。

独立レビューで、`docker compose run`はDev Containerの`postStartCommand`を通らず、firewall未初期化でもwrapperが起動できるfail-openを検出した。firewall modeをwrapper本文へ焼き込み、onならwrapper自身が許可済みsudo scriptを実行して、自己検証後にrootが作る`/run/ai-firewall-ready`を要求するよう修正した。さらに再初期化途中の失敗で古いmarkerが残る再現を受け、script開始時にmarkerを削除し、成功時だけroot所有・固定内容のregular fileをatomic生成するようにした。一般化先では生成先repositoryにもshell entrypointのLF固定を追記する。
