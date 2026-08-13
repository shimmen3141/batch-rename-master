# エージェント共通の規約

このファイルが規約の正本である。Claude Codeは`CLAUDE.md`の`@AGENTS.md`経由、Codexはこのファイルを直接読む。同じ規約本文を別ファイルへ複製しない。

## AI sandbox前提

AIエージェント作業はDev Container（`compose.ai.yml`）内で行う。`printenv AI_SANDBOX`が`1`か確認する。

- `secrets/`、環境変数、慣習的な`.env`の値はダミーである。本物の値を探索・表示しない。
- `compose.ai.yml`と`.devcontainer/`はread-only。変更は人間へ依頼する。これらのpathが現在のHEADと移動先で異なる場合、container内の`switch`、`checkout`、`pull`、`merge`は途中まで適用して失敗しうるため実行せず、host側での更新とRebuildを依頼する。Git操作が失敗したら、何も変わっていないと仮定せず直ちに`git status --short`を確認する。
- 各worktreeではignoredな`secrets/ai.env`が存在しないことがある。Compose構文上必要なだけで値は不要なので、Agentはコメントだけの空相当fileをそのworktreeへ作成してよい。別worktreeやhostからcopyせず、credentialや環境変数代入を追加しない。
- push / PRは`gh`で行えるが、`.github/workflows`を含むpushは人間が行う。
- クラウド認証や広権限tokenを持ち込まない。infra/deployは人間監督下で行う。
- 新しい秘密を移動・生成する必要があれば人間へ依頼する。
- Android SDK / Xcodeは無い。`flutter analyze`と`flutter test`は実行できるが、実機・emulator buildはhost側の人間が行う。
- container内でCodexを起動するときは`codex-container`を使う。このwrapperが`AI_SANDBOX=1`、dummy secret shadow、非root、docker.sock不在、firewall初期化を確認してから、containerと重複する内側sandboxだけを無効化する。host側で`--sandbox danger-full-access`を直接使わない。

非対話の検証は既定で`docker compose -f compose.ai.yml run --rm ai-dev <command>`を使う。既に同じworktree用containerが起動している場合だけ`exec`を使う。

# ASDD protocol

このprojectは、番号付きplan・task・仕様を`specs/`の同じfeature workspaceへ置く。integration branchは`dev`である。

必要なASDD pluginは`2.0.0`以上である。plugin manifestまたはskillが1.xで`development-units/`を正本として要求する場合は実行を止め、pluginを更新する。旧skillへ合わせて`development-units/`を再作成したり、`specs/`と二重管理したりしない。

## 正本

- `specs/README.md`: 人間と新しいAgentの入口。詳細statusを複製しない。
- `specs/product-map.md`: 能力、未完了領域、将来候補、対象外、機能間依存。live statusを置かない。
- `specs/<NNN>-<name>/plan.md`: 目的、境界、方針、全体受け入れ、人間の決定。
- 同`plan.json`: plan ID、risk、plan間依存、task directory、plan全体のIssue番号。
- `tasks/<TNN>-<name>/task.md`: task固有の目的、範囲、受け入れ証拠、観測済みcheckpoint、handoff。
- 同`task.json`: task ID、status、依存、仕様被覆、Issue/PR番号、manual確認path。
- `spec.md`、contracts、decisions: 利用者から観測できる正しさと長期判断。
- `docs/design/Bulk Renamer.html`: 005のUIにおける**配置・導線・情報階層**の正本。対象taskは適用する画面範囲を`task.md`へ書き、review・widget test・manual確認で照合する。判定、状態遷移、データ保護、時間制約はdesignへ移さず、`spec.md`、contracts、decisions、testを正本とする。参考画像や探索中のdesignは正本として扱わない。
- Issueを使う場合: 担当、branch、review会話、外部結果link。taskの意味、依存、handoffを複製しない。

`NNN`と`TNN`は安定IDであり、順序・優先度ではない。挿入・分割・移行で既存IDを振り直さず、実行可否は依存から判断する。

## 状態と作業単位

task statusは`pending / in_progress / blocked / in_review / done`だけを使う。`ready`は保存せず、依存を満たす`pending`から導出する。

- 意味のある複数step、sessionをまたぐ作業、仕様境界の合意が必要な作業をplan/task化する。
- 1〜2手で終わる明白な修正へ形式を強制しない。ただし既存taskの受け入れを変える修正は所有taskへ接続する。
- 着手時にtaskを`in_progress`へ変更する。
- 完了は主張ではなくdiff、実際のproject-native検証、受け入れシナリオ、riskに応じたreviewから判定する。
- manual証拠は対象commit以後にcode、dependency、build設定が変わったら再利用しない。

## 検証とreview

- related test: 変更に対応する`flutter test <test-path>`
- format: `dart format --output=none --set-exit-if-changed .`
- static analysis: `flutter analyze`
- full regression: `flutter test`
- build: taskで必要なplatform build。AI containerで実行不能なら未実施と明記する。
- 共通manual環境: `docs/development/emulator-verification.md`
- task固有manual操作・期待結果: 所有taskの`manual-verification.md`
- ASDD構造: `python <asdd-plugin>/scripts/workspace.py check specs`

完了前にworking treeの実差分、test/analyze/formatの実出力、仕様差分、受け入れシナリオ、必要なUI・実機証拠を確認する。testの削除・skip・assertion緩和、errorの握りつぶしでPASSさせない。

高リスク、共有作業、PR ready化、merge、plan完了では、対象実装の文脈から分離した独立reviewを必要とする。低リスクlocal作業で独立Agentを利用できなければ`SELF-REVIEW ONLY`を残せるが、独立PASSや完了の代用にしない。

同じ根本原因が修正後も2回続いたら類似修正を止めて仮定を洗い直す。同じtaskで独立verifierが3回FAILしたら自動修正を止め、diff、各回の実出力、未解決指摘、否定された仮定を報告する。回数をtaskへlive counterとして保存しない。

## Git・worktree・commit

- branch: `asdd/<plan-id>-<plan-slug>/<task-id>-<task-slug>`
- worktree: 並列作業、長い外部待ち、独立reviewではproject内`.worktrees/<plan-id>-<task-id>-<slug>`を優先する。Dev ContainerとIDEから到達できる絶対pathを作成前に確認する。
- 同じtaskの既存branch、worktree、Issue、PRがあれば新設しない。
- 人間が使用中のworktreeや未commit変更を黙ってswitch、stash、移動しない。

commitは「一つの観測可能な主張を再現・検証・revertできるcheckpoint」で分ける。一taskを無理に一commitへせず、file数や時間だけでも分けない。

```text
<type>(asdd-<plan-id>/<task-id>): <観測可能になった結果>

ASDD-Plan: <NNN>
ASDD-Task: <TNN>
Checkpoint: implementation | verification | evidence | handoff
Evidence: <commandとPASS/FAIL、またはnot-runと理由>
```

shared branchをamend、rebase、force pushで黙って書き換えない。中断保護の未完commitは`wip`と明示し、taskを`in_review`や`done`へ進めない。

## Issue・PR・merge

Issueはremote collaborationの共有窓口であり、task statusの正本ではない。共有編集を始めるplan/taskだけに作成または再利用し、将来候補や全taskを一括投影しない。

- 一Issueは一planまたは一taskだけが所有する。番号は所有する`plan.json`または`task.json`へ一度だけ保存する。
- claim、block、review依頼、handoffで担当・branch・review range・外部結果linkを更新する。
- 継続的なGit↔Issue双方向同期は行わず、Issue closeをtask完了判定に使わない。
- Issue create/reuse、assign、comment、通常のstatus更新は対象plan/taskのclaimとしてAgentが行える。close/reopen/delete/所有移譲は個別の明示依頼を必要とする。
- plugin CLIが使える場合は`python <asdd-plugin>/scripts/github_issue.py specs <NNN[:TNN]>`を使う。使えないAIは`gh`またはUIで同じ最小情報を保存する。

PRはremote collaboration、CI、独立review、manual gate、integrationに意味がある場合に使う。最初の検証可能なcheckpoint後にDraftを作る。既定は一task branch=一PRだが、同じreview・rollback境界の小さな隣接taskはまとめてよい。

- titleとbodyは日本語で書く。titleは`[ASDD NNN/TNN] <観測可能な成果>`を既定とする。
- 本文にplan/task、risk、Issue、成果と対象外、実検査、review base/head/range、manual要否、未解決P0/P1、人間判断、後続taskを含める。
- task固有Issueがmergeで調整終了する場合だけ`Closes #N`、plan Issueや継続利用Issueは`Refs #N`とする。
- 通常push、PR作成、ready化は、remote共有・CI・review・handoffに必要ならAgentが行い、結果を報告する。`.github/workflows`を含むpushは人間が行う。

このprojectでは、次をすべて満たすwork-package PRに限り、追加の人間確認なしでAgentがauto-mergeを有効化またはmergeしてよい。

1. PRがDraftでなく、plan/task、Issue、base/headが一意。
2. exact rangeの独立reviewがPASSし、`SELF-REVIEW ONLY`やmanual待ちBLOCKEDでない。
3. required CI・review・branch protectionが成功し、未解決threadが無い。
4. 依存が統合済みでlatest baseと競合せず、必要なrelated/full regressionがlatest headでPASS。
5. 必須UI・実機証拠が同じcode/buildに対応し、その後code/dependency/build差分が無い。
6. 未解決P0/P1、仕様・scope・risk判断待ち、data loss・permission・compatibilityの未受容riskが無い。
7. `.github/workflows/`、AI sandbox・secret境界、infra/deploy、権限規約、この`AGENTS.md`を変更しない。

merge methodはcheckpointとmanual evidenceのidentityを保つmerge commitを既定とする。merge後は`dev`上の結果、CI/smoke、task可視性、Issueの扱いを確認してからworktreeを整理する。force pushでgateを迂回しない。

## 再開と報告

「続けて」と言われたら、次の順で現在地を復元する。

1. `specs/README.md`と`python <asdd-plugin>/scripts/workspace.py resume specs`。全task一覧が必要な場合だけ`summary`を使う。
2. `resume`が示したtaskの`Current state / handoff`。
3. current branch/worktree、`git status --short`、staged/unstaged diff、未追跡file。
4. taskが所有するIssue/PRとexact review range。

`in_progress / in_review / blocked`を、実行可能な新しい`pending`より先に再開する。同じPR・exact buildに属する複数のblocked taskは一つのresume focusとして扱い、manual checklistをまとめて依頼できる。外部待ちがある間に無関係なpending taskへ黙って移らない。

Git管理されたhandoffとIssueが食い違う場合はhandoffを正本とし、外部操作の許可範囲でIssueを追随更新する。候補が一つなら次の検証可能なcheckpointへ進む。複数なら番号・状態・依存・人間証拠の要否を示し、一問だけ確認する。旧historyや閉じたIssueから未登録taskを開始しない。

開始時と終了時の報告には次を含める。

1. 現在地: `NNN / TNN 名前 — status`、branch、Issue/PR。
2. 今回行うこと／行ったこと。
3. 検証結果と未確認領域。
4. 人間の判断（無ければ「なし」）。
5. 人間の作業（無ければ「なし」）。
6. 次にAgentがすること。
7. 次に実行可能なtaskと並列可否。

## 人間への質問とmanual確認

コード、test、仕様、Git、Issue/PRから分かることは質問しない。scope、利用者から見える振る舞い、data・互換性・権限・公開・費用、受け入れ証拠を変えるmaterial ambiguityだけを、一度に一つ、現実的で相互排他的な選択肢2〜3個と推奨案・影響を付けて尋ねる。

manual確認を依頼する前に、Agentが検証対象branch、exact commit/build、人間が実行するworkspaceを準備し、その状態を維持して待つ。これはAgent自身もそのworkspaceのbranchやcommitを動かさないという意味であり、待機中の別作業は別worktreeで行う。人間によるbranch移動は原則不要と明記し、`git switch`や`git checkout`を通常手順にしない。未commit変更、使用中worktree、container/IDE制約で安全に準備できない場合だけblockerと選択肢を示す。

共通起動手順はdocsへlinkする。task固有manualを依頼するときは、対象`NNN / TNN`とtask名、クリック可能なrepository-relative link（例: [`specs/005-rename-exec/tasks/T09-empty-rule-ui/manual-verification.md`](specs/005-rename-exec/tasks/T09-empty-rule-ui/manual-verification.md)）を示す。`manual-verification.md`というfile名だけや「文書を確認してください」だけで依頼しない。今回固有の操作、fixture、期待結果、結果受領後のAgent作業も報告内の一つのchecklistへ要約する。人間の結果は会話で自由形式に受け取り、証拠metadataはAgentが`task.md`へ記録する。

## Development findings

実際に観測した不具合、ASDD手順の曖昧さ、検証漏れ、手戻り、再開失敗は`development-findings/YYYY-MM-DD-<具体的なslug>.md`へ一件一fileで記録する。findingは改善入力であり、task status、担当、優先度の正本にしない。改善後は変更先と検証・forward-test結果を追記する。

## 旧ASDDからの移行境界

- 0.x cutoff: `8d950ca173e2d0f22a6dad1432dd2b2e285cd2ec`
- 1.x migration base: `53acc33b22ce5f793d041ce37ba51d7b0fc4ac6b`
- 凍結した旧配置: `specs/**/history/`、`specs/history/`、`development-findings/legacy-asdd-0.x/`
- 対応表: `specs/migration-coverage.md`
- 停止済み: plan parser、Issue投影、Stop verifier、spec status gate、index書き戻し、projectへcopyしたASDD script。

旧historyのstatus、claim、log、Issue番号をlive stateや次作業の正本として読まない。対応表に無い旧pending項目を直接開始しない。`development-units/`をactiveな第二正本として再作成しない。
