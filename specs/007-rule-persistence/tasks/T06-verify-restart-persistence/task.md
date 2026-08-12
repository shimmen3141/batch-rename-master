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
- Review attempt 2: PR #121 `dev@abc8007...aaacf5d` — FAIL — 残るP0/P1: none(このtaskへの指摘はattempt 1記録の誤り=P1-Bのみ。復元内容は網羅性を確認済み)

## Current state / handoff

- Last checkpoint: 自動testと配線は完了。実storageの再起動証拠をT06へ移行
- Blocker category: none
- Waiting for: none
- Requested action: Agentが検証branch・exact buildを準備してから人間へchecklistを依頼する
- Evidence revision: 未確定。code/dependency/build変更後の古い観測は再利用しない
- Next Agent action: 現在のmanual待ちtaskと同じbuildで併行確認できるかを確認し、検証workspaceを準備する
