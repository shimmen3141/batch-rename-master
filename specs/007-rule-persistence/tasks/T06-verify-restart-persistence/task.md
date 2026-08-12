# T06 process再起動をまたぐルール復元を受け入れ確認する

## 目的

Androidとdesktopで、保存したruleがアプリprocess終了後も実storageから復元される証拠を得る。

## 入力と依存

- `T05`のshared_preferences adapterとapplication配線。
- `spec.md`のREQ-005〜008。
- 共通環境手順[`docs/development/emulator-verification.md`](../../../../docs/development/emulator-verification.md)。

## 変更範囲

- 同一commit/buildでの保存・process終了・再起動・復元の観測。
- serializationや保存仕様の変更は、観測された不具合を別checkpointとして定義してから行う。

## 受け入れ証拠

- [`manual-verification.md`](manual-verification.md)のAndroidとdesktop checklist。
- exact revisionと証拠に対する独立reviewのPASS。

## 作業記録

- 旧007 T05はmockを含む自動検査を完了したが、実storageのprocess再起動確認を残したままdoneだったため、移行時に独立taskとして抽出した。

- 2026-08-12 / manual checklistを復元した。ASDD移行で、凍結側にあった**hot restartとcold startの区別**と、**ruleを変更してからの2回目のcold start(上書き保存の確認)**が落ちていた(`development-findings/2026-08-12-manual-checklists-lost-steps-in-migration.md`)。復元前は復元しか検査せず、「一度保存したきり更新されない」不具合を見逃す手順だった。識別可能なruleを2種類(A/B)定義し、A保存 → hot restart → cold start → Bへ変更 → 2回目のcold startの順に確認する形へ戻した。未実施のため手戻りは無い。

- Review attempt 1: PR #121 `dev@abc8007...7cb943b` — FAIL — 残るP0/P1: none(P2-2「人間向けmanualへ内部用語」がこのtaskのmanualにも該当。`fb6f7d7`で解消)
- Review attempt 2: PR #121 `dev@abc8007...aaacf5d` — FAIL — P1: このtaskのattempt 1記録がFAILをPASSと書いていた(P1-B。`6432da8`で解消)。復元内容自体は網羅性を確認済み
- Review attempt 3: PR #121 `dev@abc8007...6432da8` — FAIL — 残るP0/P1: none(このtaskへの指摘はattempt 2行の形式=P2-2のみ)

- Review attempt 4: PR #121 `dev@abc8007...3255f87` — PASS — 残るP0/P1: none(P2-4/P2-5: 例示がサンプル実file名でない、連番labelが実UIと不一致。この後のcommitで解消)

- 2026-08-12 / PR #121が`dev`へmerge済み(`7154ce3`)。復元したchecklistで実機確認を依頼する段階になったため、statusを`blocked`(manual待ち)へ変更した。

## Current state / handoff

- Last checkpoint: manual checklistの復元がPR #121で`dev`へ統合済み。実機確認の依頼を出した
- Blocker category: manual
- Waiting for: 人間による[`manual-verification.md`](manual-verification.md)の実施。Android(emulatorまたは実機)とWindows desktop buildの両方が要る
- Requested action: 人間が`dev@7154ce3`のbuildでchecklistを実施し、結果を会話で返す
- Evidence revision: `dev@7154ce3`。Agentはこのcommitでcheckoutを維持し、実施中はcode/dependency/build設定を変更しない
- Evidence: 復元内容の独立review attempt 4=PASS、`workspace.py check specs`=PASS(7 plans, 43 tasks)、`flutter test`=PASS(346)。**manual自体は未実施**
- Next Agent action: 結果を受け取って作業記録へ要約し、受け入れ条件を満たしたか判定する。満たせば独立reviewへ回す
