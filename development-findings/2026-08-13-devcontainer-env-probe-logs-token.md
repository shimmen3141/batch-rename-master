# Development finding: Dev Containerの環境probeがPATをhostログへ記録する

- 観測日: 2026-08-13
- 観測した作業: Dev Containers: Rebuild Container
- 改善先: project / ai-sandbox-setup
- 関連Issue・commit・artifact: `.devcontainer/devcontainer.json`、VS CodeのDev Containers debug log

## 観測した事実

rebuildはpostStart処理まで正常終了していたが、その後もegress firewallが遮断したMicrosoft telemetryのtimeoutだけが出力され続けた。切り分けのためhost側Dev Containers debug logを確認すると、既定の`loginInteractiveShell`によるuser environment probeが、`GH_TOKEN`を含むcontainer環境全体をJSONとしてhostログへ記録していた。

期待する動きは、fine-grained PATをcontainer内のAIと`gh`が利用できる一方、追加の環境probeやhost側debug logには値を複製しないことである。

## 影響とworkaround

- 影響: 対象repositoryへ限定したPATでもhostログへ不要な複製が残り、ログを読めるprocessやAgentの秘密接触面が広がる。telemetry timeoutはrebuild失敗ではないが、完了済みか判断しづらくする。
- その場のworkaround: rebuild logで`postStartCommand`の終了を確認し、Microsoft telemetry domainはallowlistへ追加しない。観測時に使われていたPATは失効・再発行する。

## 仮説と改善案

- 仮説: Dev Containersの`userEnvProbe`既定値が`loginInteractiveShell`であり、probe結果をdebug logへ出力する。VS Code telemetryもfirewallの外向き遮断後に再送する。
- 改善案: `userEnvProbe: "none"`で追加probeを無効化し、container固有の`telemetry.telemetryLevel`を`off`にする。Composeからcontainerへ渡す`GH_TOKEN`は維持する。

## 改善結果

`.devcontainer/devcontainer.json`へ上記2設定を追加した。forward-testは、rebuild後に`gh auth status`が成功し、Dev Containers debug logに`GH_TOKEN`またはPAT値が現れず、OneCollectorへの再送が続かないことを人間が確認する。
