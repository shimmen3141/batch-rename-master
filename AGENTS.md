# エージェント共通の規約

このファイルが規約の正本である。Claude Codeは`CLAUDE.md`の`@AGENTS.md`経由、Codexはこのファイルを直接読む。同じ規約本文を別ファイルへ複製しない。

## AI sandbox前提

AIエージェント作業はDev Container（`compose.ai.yml`）内で行う。`printenv AI_SANDBOX`が`1`か確認する。

- `secrets/`、環境変数、慣習的な`.env`の値はダミーである。本物の値を探索・表示しない。
- `compose.ai.yml`と`.devcontainer/`はread-only。変更は人間へ依頼する。
- 各worktreeではignoredな`secrets/ai.env`が存在しないことがある。これはComposeの構文上必要なだけで値は不要なので、Agentはコメントだけの空相当fileをそのworktreeへ作成してよい。別worktreeやhostから同名fileをcopyせず、credentialや環境変数代入を追加しない。これは「新しい秘密の生成」には含めない。
- push / PRは`gh`で行えるが、`.github/workflows`を含むpushは人間が行う。
- クラウド認証や広権限tokenを持ち込まない。infra/deployは人間監督下で行う。
- 新しい秘密を移動・生成する必要があれば人間へ依頼する。
- Android SDK / Xcodeは無い。`flutter analyze`と`flutter test`は実行できるが、実機・emulator buildはホスト側の人間が行う。

非対話の検証は既定で`docker compose -f compose.ai.yml run --rm ai-dev <command>`を使い、container内で`AI_SANDBOX=1`を確認する。既に同じworktree用containerが起動している場合だけ`exec`を使う。

# ASDD 1.0

- Protocol revision: 1.0.8
- Execution map schema: 1.0（protocol revisionとは独立）
- Integration branch: `dev`

複数ステップの開発は、必要最小限のdevelopment unitとして定義し、実際に観測した証拠で完了を判定する。小さく明白な修正に文書を作らない。

## 0.xからの移行境界

- Cutoff commit: `8d950ca173e2d0f22a6dad1432dd2b2e285cd2ec`
- 凍結済み旧配置: `specs/**/plan.md`、`specs/discovery.md`、`specs/findings/`
- 停止済み旧自動化: plan parser、Stop hook、Issue投影、specs index書き戻し、spec status gate
- 継続利用する仕様正本・検証: `specs/**/spec.md`、`specs/**/contracts/`、`specs/**/decisions/`、`test/spec_*/`
- 旧全体像の移行カバレッジ: `docs/development/project-development-map.md`
- Cutover外部監査（2026-08-09）: open PR 0、running/queued Actions 0。`dev`対象ruleset `20491071`はnon-fast-forwardとbranch deletionの禁止だけで、停止workflowのrequired status checkは無い

cutoff後は旧planのstatus、claim、log、Issue番号をlive stateや次作業の正本として読まない。既存REQ/VER ID、approved Strict contract、ADR、仕様由来testは改名・複製せず参照する。

旧`specs/discovery.md`と全旧planにあった能力、未完了受け入れ、将来候補、対象外は`docs/development/project-development-map.md`へ分類済みである。プロジェクト全体から次のunitを選ぶときは旧資料でなくこのmapを入口にする。mapはlive statusを持たず、実行中の状態はIssueから読む。

## 配置と正本

```text
development-units/<短く具体的な名前>/
├── definition.md       # unit全体の目的、境界、決定、受け入れ証拠
├── spec.md             # 既存の仕様正本がなく、高リスクまたは解釈差が重要な場合だけ
├── execution-map.md または .json # stableな依存と安全な並列境界が必要な場合だけ
├── manual-verification.md # unit固有の手動・実機確認が必要な場合だけ
└── decisions/          # 複数unitへ長く影響するWhy / Why notだけ
```

- `definition.md`: unit全体で観測する成果と境界の正本。
- 既存の`specs/**/spec.md`・contract: normativeな振る舞いと検証接続の正本。
- execution map: work packageのstableな依存、成果、既存のREQ/VER ID・test pathへの参照。status・担当・ログを置かない。
- GitHub Issues: 共有時のlive status、担当、外部待ち、branch/worktree、実際のcommit/rangeとreview結果の正本。

同じ意味や状態を複数へ書き写さない。新しいunitやbranchへASDD独自の`001`等を採番せず、成果を表す名前を使う。既存Issue IDは検索性のため名前へ含めてよい。

## Development unitを作る判断

- 1〜2手で終わり受け入れ条件が明白: 作らない。
- 複数ステップ、sessionをまたぐ、境界の合意が必要: `definition.md`を作る。
- データ損失、お金、権限、security、公開API互換性、並行性、不可逆操作: 既存仕様正本を使い、なければ`spec.md`を作り、実装前に人間判断を得る。
- 正解がまだ分からない探索: 安全なspikeで学んでから定義する。
- 問題・利用者・作るunit自体が曖昧: `discover-requirements`で一問ずつ掘り下げる。

## 実行規律

1. project instructions、`docs/development/project-development-map.md`、definition、仕様正本、execution map、code、test、git差分、利用可能なIssue/PRを読む。
2. 依存を満たしたwork packageを実物から選ぶ。複数Agentなら編集前にIssue、担当、branch/worktreeをclaimする。
3. 直近1〜3個の検証可能なcheckpointだけ具体化する。
4. 実装後、関連checkと全体checkの実出力を確認する。
5. 対象scopeを実装文脈から分離したAgentでreviewする。work-package PASSはunit PASSではない。
6. FAILの根拠を次の実装passへ返し、修正・再検証する。

同じ根本原因が修正後も2回続いたら類似修正を止めて仮定を洗い直す。同じwork packageで独立verifierが3回FAILしたら自動修正を止め、diff、各回の実出力、未解決指摘、否定された仮定を報告する。回数をdevelopment unitへ書き戻さない。

高リスク、共有作業、PRのready化、merge、unit完了は独立reviewが利用できなければBLOCKEDとする。低リスクのlocal作業では`SELF-REVIEW ONLY`を残せるが、独立PASS、Issue done、merge、unit完了の代用にしない。

## 検証

- 関連check: 変更に対応する`flutter test <test-path>`
- 全体check:
  - `dart format --output=none --set-exit-if-changed .`
  - `flutter analyze`
  - `flutter test`
- 手動・実機確認: `docs/development/emulator-verification.md`に従いホスト側で行う。

project共通の起動・接続は上記共通docs、unit固有のfixture・操作・期待結果は各`development-units/*/manual-verification.md`を正本とする。

完了前にworking-treeの実差分、test/analyze/formatの実出力、仕様差分、受け入れシナリオ、必要なUI・実機証拠を確認する。実行不能な確認を実施済みと報告しない。testの削除・skip・assertion緩和、エラーの握りつぶしでPASSさせない。

## 人間が決めること

人間判断が必要なのは、利用者から見える振る舞い、scope、データ・権限・互換性、不可逆操作、受け入れるriskである。実装手段や低影響の内部詳細は既存規約に従ってAgentが決める。approvedな仕様正本の意味を変える場合は、対象revisionと意味差分を示して再判断を求める。

## PRとIssue

PRは一律1タスクごとではなく、独立して検証・統合・rollbackできるunitまたはwork package単位にする。draft PRは早期CIに使えるが、ready化とmergeには対象scopeの独立PASSが必要である。

work packageは`execution-map.*`に定義する永続的な成果・依存・検証境界であり、Issueそのものではない。このunitでは複数Agent/session間の調整が必要なため、各work packageへliveな子Issueを一つだけ対応させる。親Issueは任意のタスク束ではなくdevelopment unit一つに対応し、unit全体の観測可能な成果、最終受け入れ、統合、rollbackを調整する。独立して受け入れ・延期できる成果へ広がる場合は別unitと親Issueへ分ける。

外部操作の既定権限:

| 指示・操作 | 許可範囲 |
|---|---|
| 「Issueを作って」 | 対象Issueのcreateだけ |
| 「IssueでW1を管理・実装して」 | 必要な親IssueとW1子Issueのcreate/reuse、assign、comment、gate後のdoneまでのstatus更新。親doneはunit全体も依頼scopeの場合だけ |
| Issue close/reopen/delete/担当移譲 | 個別の明示依頼が必要 |
| 通常push / PR作成・ready化 | 明示依頼が必要 |
| merge / auto-merge | 下記の条件付き事前許可を満たすwork-package PRだけ追加確認不要。それ以外は対象と条件を指定した明示依頼が必要 |
| force push | 履歴改変を明示した依頼が必要 |

### Work-package PRの条件付き自動merge

このprojectでは、execution mapの一つのwork packageへ対応するPRに限り、次の条件を**すべて**満たしたAgentは、追加の人間確認なしでGitHubのauto-mergeを有効化するか、PRをmergeしてよい。これは通常pushやPR作成の事前許可を追加せず、unit全体の最終PR、別unit、別repositoryへも拡張しない。

1. PRがdraftではなく、対象development unit、work package、子Issue、base/headが一意に特定されている。
2. exact `base..head` rangeについて、実装文脈から分離した独立reviewがPASSしている。`SELF-REVIEW ONLY`や、手動証拠待ちの`BLOCKED`は代用にならない。
3. required CI、required review、branch protectionがすべて成功し、未解決のreview threadがない。
4. execution mapが示す依存work packageが統合済みで、最新baseとの競合がなく、必要な関連checkと回帰checkが最新headでPASSしている。
5. scopeで必須のUI・実機・host確認がある場合、同じcommit/buildの観測結果がIssueまたはPRに記録され、独立reviewがその証拠を含めて最終PASSしている。
6. 未解決P0/P1、仕様・scope・risk判断待ち、data loss・permission・compatibilityに関する未受容のriskがない。
7. PRが`.github/workflows/`、AI sandbox・secret境界、infra/deploy、権限規約、この`AGENTS.md`自身を変更していない。これらは個別の明示merge依頼を必要とする。

一条件でも確認不能または不成立ならmergeせず、欠けている証拠を報告する。merge methodはrepositoryで許可された通常方式を使い、force push・履歴改変でgateを迂回しない。merge後は統合commitを取得して必要な検査をintegration branch上で再実行し、その結果を報告してからIssueを`done`にする。Issueのcloseは引き続き個別の明示依頼を必要とする。

実装依頼や「続けて」だけでは外部操作権限を追加しない。権限がなければbranch、commit/range、検証結果、Issue/PR案まで準備して止める。

## Development findings

実際に観測したskillの曖昧さ、検証漏れ、二重管理、handoff失敗、再利用価値のある手戻りは`record-development-finding`で`development-findings/YYYY-MM-DD-<具体的なslug>.md`へ一件一ファイルで残す。これは改善入力であり、仕様、一般的TODO、live status、担当、優先度を置かない。追跡が必要ならIssueを正本にし、改善後は変更先と検証・forward-test結果だけを追記する。

既存の`specs/findings/`は0.xの履歴として保持し、新規findingを追加しない。

## 中断から再開

「続けて」と言われたら、current branch/worktree、`git status --short`、staged/unstaged diff、未追跡file、変更されたdefinition/spec/test、利用可能なIssue/PRを調べる。候補が一つなら次の検証可能なcheckpointへ進み、複数なら候補と根拠を示して一問だけ確認する。旧planや古い完了報告だけを信じない。

意図的な中断・担当交代では、Issueへwork package、branch/worktree、完了済み成果、失敗中の証拠、最後の検証出力、次のcheckpoint、blocker、無関係なdirty変更をhandoffとして残す。予期しない中断では最後に観測可能なcheckpointから再開する。

activeなbranch・diff・Issueが無く、プロジェクト全体の次を求められた場合は`docs/development/project-development-map.md`から依存を満たす定義済みunitまたは将来候補を列挙する。候補が複数なら製品優先度を推測せず、一問だけ選択を求める。将来候補のIssueはあらかじめ一括作成せず、選ばれた候補をdefinitionへ具体化して共有調整を始めるときだけ作成または再利用する。
