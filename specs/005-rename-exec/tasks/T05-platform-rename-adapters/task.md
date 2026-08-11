# T05 desktop安全renameとAndroid安全未対応を統合する

## 目的

desktopで既存targetを置換しない実renameを行い、Android SAFでは保証不能なrenameを実行せず、いずれもfile実体とapplication状態を一致させる。

## 入力と依存

- `T04`の実行導線と結果表示。
- approved 005 contract revision 1、およびPR #116で人間判断済みのrevision 2意味差分。
- Issue #96、Draft PR #116。product code baselineは`b866e35`で、ASDD 2.0移行後のexact review rangeはPR/Issueへ記録する。

## 変更範囲

- desktopの排他的native rename、stableな競合・permission・notFound分類、新しいabsolute handleの投影。
- Android SAFの副作用なし`unsupportedPlatform`と理由表示。
- application composition、仕様・ADR・test・同一buildのmanual証拠。
- Androidで成功するstorage境界の設計・実装は013へ分離する。

## 受け入れ証拠

- PR #116 product code baseline `b866e35`でCI成功: format 73 files/0 changed、analyze 0、337 tests。ASDD 2.0合流後のlatest headでもCIが成功する。
- exact range独立review: P0 0 / P1 0、`BLOCKED (manual evidence pending)`。
- [`manual-verification.md`](manual-verification.md)でdesktop実rename・競合・permission拒否とAndroid不変を同一commit/buildで確認する。
- 手動証拠を含む最終独立reviewがPASSする。

## 作業記録

- 2026-08-09 / Android `DocumentsContract.renameDocument`に原子的no-replace契約が無いことを独立reviewで検出。provider依存raceの受容は不採用。
- 2026-08-09 / desktopを排他的native renameへ変更し、Android SAFを安全なunsupportedへ改訂。PR #116をDraftで保持。
- 2026-08-12 / hostの`flutter run -d emulator-5554`で、code assetを要求しないhook invocationが`input.config.code`へ先にアクセスして終了コード255になった。アプリ画面が残っていても検証buildは失敗として修正を再開。
- 2026-08-12 / 保存された同じinputで修正前は例外を再現し、`buildCodeAssets` guard追加後は`dart ... hook/build.dart --config=...`がexit 0。Dev ContainerのFlutter testは今回と別の既知制約（C compilerなし）で開始前に停止。

## Current state / handoff

- Last checkpoint: `79e4c45`のAndroid手動確認開始時にnative asset hookの未guard accessを再現
- Blocker category: none（実装修正中）
- Waiting for: none
- Requested action: none
- Evidence revision: failing hook inputは`build_asset_types: []`、`hook/build.dart:12`で`Bad state: HookConfig.code should only be accessed when building code assets`
- Next Agent action: hookを修正してhost/container検査を通し、人間が操作だけで判定できるmanualへ改訂して新しいexact headを用意する
