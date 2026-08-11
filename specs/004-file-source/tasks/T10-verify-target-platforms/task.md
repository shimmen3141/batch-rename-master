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

## Current state / handoff

- Last checkpoint: 実装と自動testは既存taskで完了。manual手順をT10へ移行
- Blocker category: none
- Waiting for: none
- Requested action: Agentが検証branch・exact buildを準備してから人間へchecklistを依頼する
- Evidence revision: 未確定。code/build変更後の古い観測は再利用しない
- Next Agent action: 現在のmanual待ちtaskと同じbuildで併行確認できるかを確認し、検証workspaceを準備する
