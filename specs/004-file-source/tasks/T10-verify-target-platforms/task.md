# T10 target platformでファイル選択を受け入れ確認する

## 目的

Android SAFとdesktop pickerで、既存004仕様の選択・cancel・置換・警告が実際のplatform上でも成立する証拠を得る。

## 入力と依存

- `T09`の選択導線実装。
- `spec.md`のREQ-002〜005、REQ-009〜012。
- 共通環境手順[`docs/development/emulator-verification.md`](../../../../docs/development/emulator-verification.md)。

## 変更範囲

- 同一commit/buildの手動観測と、必要なら観測で判明した不具合の別task化。
- このtaskだけで選択仕様やUIを黙って変更しない。

## 受け入れ証拠

- [`manual-verification.md`](manual-verification.md)のAndroidとdesktop checklistが同一code revisionに対して記録される。
- exact revisionと証拠を対象に独立reviewがPASSする。

## 作業記録

- 旧004 T04/T09では自動検査まで完了した一方、target platformの最終受け入れが旧plan全体に残っていたため、移行時に独立taskとして抽出した。

- 2026-08-12 / manual checklistを復元した。ASDD移行で凍結側の9 stepが3 stepへ要約され、**REQ-011(「画像」「動画」は読み込まず未実装を示す / 「文書」はMIME絞り込み)**と、**追加の全file access権限を要求しないこと**の確認が落ちていた(`development-findings/2026-08-12-manual-checklists-lost-steps-in-migration.md`)。凍結側`history/asdd-1.x-development-unit/manual-verification.md`と突き合わせ、落ちた項目を戻したうえで、fixture作成commandと期待結果を人間が番号順に実行できる形にした。skillの規定に従い返信templateとstatus欄は置かない。未実施のため手戻りは無い。

- Review attempt 1: PR #121 `dev@abc8007...7cb943b` — FAIL — 残るP0/P1: none(P1-1 folder跨ぎstepの実行不能を`fb6f7d7`で解消済み。再review待ち)

## Current state / handoff

- Last checkpoint: 実装と自動testは既存taskで完了。manual手順をT10へ移行
- Blocker category: none
- Waiting for: none
- Requested action: Agentが検証branch・exact buildを準備してから人間へchecklistを依頼する
- Evidence revision: 未確定。code/build変更後の古い観測は再利用しない
- Next Agent action: 現在のmanual待ちtaskと同じbuildで併行確認できるかを確認し、検証workspaceを準備する
