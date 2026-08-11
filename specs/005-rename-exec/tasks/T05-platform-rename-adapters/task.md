# T05 desktop安全renameとAndroid安全未対応を統合する

## 目的

desktopで既存targetを置換しない実renameを行い、Android SAFでは保証不能なrenameを実行せず、いずれもfile実体とapplication状態を一致させる。

## 入力と依存

- `T04`の実行導線と結果表示。
- approved 005 contract revision 1、およびPR #116で人間判断済みのrevision 2意味差分。
- Issue #96、Draft PR #116、review range `53acc33b..b866e35`。

## 変更範囲

- desktopの排他的native rename、stableな競合・permission・notFound分類、新しいabsolute handleの投影。
- Android SAFの副作用なし`unsupportedPlatform`と理由表示。
- application composition、仕様・ADR・test・同一buildのmanual証拠。
- Androidで成功するstorage境界の設計・実装は013へ分離する。

## 受け入れ証拠

- PR #116 head `b866e35`でCI成功: format 73 files/0 changed、analyze 0、337 tests。
- exact range独立review: P0 0 / P1 0、`BLOCKED (manual evidence pending)`。
- [`manual-verification.md`](manual-verification.md)でdesktop実rename・競合・permission拒否とAndroid不変を同一commit/buildで確認する。
- 手動証拠を含む最終独立reviewがPASSする。

## 作業記録

- 2026-08-09 / Android `DocumentsContract.renameDocument`に原子的no-replace契約が無いことを独立reviewで検出。provider依存raceの受容は不採用。
- 2026-08-09 / desktopを排他的native renameへ変更し、Android SAFを安全なunsupportedへ改訂。PR #116をDraftで保持。

## Current state / handoff

- Last checkpoint: PR #116 head b866e35のCIとexact range独立reviewはP0/P1なし
- Blocker category: manual evidence
- Waiting for: b866e35から作成したAndroid・desktop buildの手動結果
- Requested action: Agentが検証workspaceをb866e35で維持し、manual-verification.mdのchecklistを人間へ依頼する
- Evidence revision: 53acc33b..b866e35 / CI run 31330970689
- Next Agent action: 証拠受領後、同じheadの最終独立reviewを行い、PR #116のready可否を判定する
