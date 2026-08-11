# ASDD移行カバレッジ

## 境界

- 0.x cutoff: `8d950ca173e2d0f22a6dad1432dd2b2e285cd2ec`
- 1.x migration base: `origin/dev@53acc33b22ce5f793d041ce37ba51d7b0fc4ac6b`
- 移行branch: `asdd/000-asdd-migration/T01-unify-specs`
- rollback: このbranch/PRをmergeしない、またはmigration commitをrevertする。履歴改変は行わない。

## 配置の対応

| 移行元 | 移行先 | 扱い |
|---|---|---|
| `specs/<NNN>-<name>/spec.md` | 同じpath | 振る舞い仕様として維持 |
| `contracts/`, `decisions/` | 同じworkspace内 | 意味を変更せず維持 |
| 旧`plan.md`の目的・境界・決定 | 新`plan.md` | 人間向けのplan正本へ移行 |
| 旧`plan.md`の各`Tn` | `tasks/TNN-*/task.md`と`task.json` | IDをzero paddingして目的・証拠・状態・依存・Issue/PRを分離 |
| 旧`plan.md`原文 | 各`history/asdd-0.x-plan.md` | 凍結履歴。live stateには使わない |
| `specs/discovery.md` | `history/asdd-0.x-discovery.md` | 凍結し、現行分類を`product-map.md`へ移行 |
| `development-units/complete-rename-execution/` | `005-rename-exec/plan.md`とT04〜T09 | work packageを旧stable task IDへ統合。原文は005の`history/` |
| `development-units/verify-file-selection-on-target-platforms/` | `004:T10` | 実装doneと未完manual受け入れを分離。原文は004の`history/` |
| `development-units/verify-rule-persistence-across-restart/` | `007:T06` | 実装doneと未完manual受け入れを分離。原文は007の`history/` |
| PR #116内の`design-safe-android-rename-boundary` | `013-safe-android-rename/` | unmerged成果を出所とcommit付きで移行。production実装は約束しない |
| `specs/findings/` | `development-findings/legacy-asdd-0.x/` | 履歴として維持。新規findingは`development-findings/` |
| `docs/development/project-development-map.md` | `specs/README.md`と`product-map.md` | 二重正本を止め、specsを単独入口にする |

## plan・task被覆

| Plan | 旧task | 移行結果 |
|---|---:|---|
| 001 | T1〜T6 | T01〜T06へ移行。全件done |
| 002 | T1〜T5 | T01〜T05へ移行。全件done |
| 003 | T1〜T6 | T01〜T06へ移行。全件done |
| 004 | T1〜T9 | T01〜T09へ移行し、未完manual受け入れをT10へ追加 |
| 005 | T1〜T9 | T01〜T09へ移行。T04統合済み、T05/T06 manual待ち、T07/T09未完 |
| 007 | T1〜T5 | T01〜T05へ移行し、未完manual受け入れをT06へ追加 |

## 移行時の状態判断

- `done`は旧checkboxだけでなく、merge済み履歴・仕様由来test・既存Issue/PRの実結果が一致する実装成果に限った。
- 旧planがtaskを`done`にしながら全体のhost確認を未完としていた004/007は、実装taskを改変せず新しいmanual受け入れtaskへ分離した。
- PR #116のT05/T06は自動検査と独立reviewでP0/P1なしだが、同一commit/buildの手動証拠が無いため`blocked`とした。
- Issueのopen/closeはtask完了の根拠に使わない。既存Issue番号は所有するplan/taskのJSONだけに一度記録した。

## 停止した旧自動化

plan Markdown parser、Issue一方向投影、Stop verifier、spec status gate、index書き戻し、projectへcopyしたASDD scriptは再導入しない。ASDD 2.0の構造検査はplugin側の`workspace.py`を明示実行し、hookが無くても同じ手順で成立させる。
