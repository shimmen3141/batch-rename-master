# Development finding: T34をintegration branch上で開始した

- 観測日: 2026-09-20
- 観測した作業: 008 / T34
- 改善先: agent-runtime
- 関連Issue・commit・artifact: f19b165..7083756、specs/008-ui-alignment/tasks/T34-hint-refinements/task.md

## 観測した事実

T34の再開時に規定branchを確認せず、integration branchのdev上で5件の未push commitを作成した。AGENTS.mdはtask branchをasdd/<plan-id>-<plan-slug>/<task-id>-<task-slug>と定めている。

origin/devはf19b165のままであり、T34のcommitはpushされていなかった。working treeがcleanで、他のworktreeが無いことを確認した。

## 影響とworkaround

- 影響: local devが一時的にT34の5commitを含み、task単位のbranch境界を失っていた。remoteのdevには影響しなかった。
- その場のworkaround: 7083756にasdd/008-ui-alignment/T34-hint-refinementsを作り、そのbranchへ移動した後、local devをorigin/devのf19b165へ戻した。commitとworking treeの内容は失われていない。

## 仮説と改善案

- 仮説: resumeでtaskを選んだ後、branch名の照合を実装着手前の必須checkpointとして実行しなかった。
- 改善案: run-plan開始時にcurrent branchとtask IDから期待branch名を機械的に比較し、不一致なら最初の変更前に既存branchの検索または規定branch作成を行う。

## 改善結果

規定branchのHEADが7083756、local devとorigin/devがともにf19b165であることを確認した。
