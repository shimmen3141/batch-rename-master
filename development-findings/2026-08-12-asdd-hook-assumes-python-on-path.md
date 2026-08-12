# Development finding: ASDDのStop hookが`python`をPATHに前提し、containerで一度も動いていない

- 観測日: 2026-08-12
- 観測した作業: 人間からの「stop hookのerror表示はhooksが機能していないということか」という確認
- 改善先: ASDD plugin(`hooks/hooks.json`)、およびproject(AGENTS.mdのcommand例)
- 関連artifact: `/home/dev/.claude/skills/asdd/hooks/hooks.json`、`/home/dev/.claude/skills/asdd/scripts/hook_check.py`、`AGENTS.md`の「検証とreview」節

## 観測した事実

Agentの出力停止後、人間の画面に次が出ていた。

```
Ran 2 stop hooks
  ⎿  Stop hook error: Failed with non-blocking status code: /bin/sh: 1: python: not found
```

原因はplugin側のhook定義である。

```json
"command": "python -c \"import os,runpy;runpy.run_path(os.path.join(os.environ['CLAUDE_PLUGIN_ROOT'],'scripts','hook_check.py'),run_name='__main__')\""
```

このDev Container(`debian:bookworm-slim`)には`/usr/bin/python3`しか無く、`python`は存在しない。Debianは`python`という名前のcommandを提供せず、必要なら`python-is-python3`を別途入れる。したがって**このhookは一度も実行されていない**。

`python3`へ置き換えて手で走らせると正常に動く(exit 0)。hookが行うのは`workspace.py`の`load_workspace`によるASDD構造checkで、`specs/README.md`を持つ親directoryを探して読み取り専用で検査する。破壊的な処理は無い。

同じ前提はprojectのAGENTS.mdにもある。「ASDD構造: `python <asdd-plugin>/scripts/workspace.py check specs`」と書かれており、この環境ではそのまま実行すると`python: command not found`になる(Agentは毎回`python3`へ読み替えて実行していた)。

## 期待していた動きと実際の動き

- 期待: 応答終了ごとにASDD構造checkが走り、正本の不整合をその場で検出する。
- 実際: hookは起動直後に`python: not found`で落ち、non-blockingなので処理は続行する。checkは一度も走っていない。失敗が人間の画面には出るが、Agentの入力には現れないため、Agent側は気づけない。

## 影響とworkaround

- 影響: 構造checkの安全網が無効。今回はAgentが`workspace.py check specs`を毎回明示実行していたため実害は出ていないが、明示実行を忘れたsessionでは不整合が検出されないまま進む。
- 影響: hook失敗が毎回人間の画面に出続け、正常な失敗表示との区別が付きにくくなる。
- 影響: AGENTS.mdのcommand例がこの環境で動かないため、新しいAgentは最初の実行で必ず躓く。
- workaround: Agentが`python3`で明示実行する。実際そうしてきた。

## 仮説と提案

- pluginは`python`を`python3`にするか、`sh -c 'command -v python3 >/dev/null && exec python3 ... || exec python ...'`のようなfallbackにする。Debian系image、macOSのsystem python廃止後、多くのCI imageで`python`は無い。**`python`は既定で存在すると仮定できないcommandである。**
- non-blocking failureで済ませず、hookが依存するruntimeを見つけられないときは、その旨をAgentの入力にも出す設計にできると、Agent側が代替手段を取れる。現状はAgentから完全に不可視である。
- projectのAGENTS.mdは、この環境に合わせて`python3`と書くか、pluginの修正に合わせる。
- ASDD 2.0は「Stop verifierを停止済み」としているが、構造checkのStop hookは残っている。停止した自動化と残す自動化の境界を、`migration-coverage.md`の「停止した旧自動化」節と揃えて読めるようにしたい。

## 改善結果

未対応。pluginは`/home/dev/.claude/skills/asdd/`にあり対象project外なので、このprojectのbranchでは変更しない。projectのAGENTS.md側の表記も、pluginの方針が決まってから合わせる。

暫定として、Agentは`python3`で明示実行を続ける。`.devcontainer/Dockerfile`へ`python-is-python3`を追加すれば表示自体は消えるが、それはpluginの誤った前提をprojectの環境で吸収することになるため、pluginの判断を先に求める。
