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
- [`manual-verification.md`](manual-verification.md)でdesktop実rename・連続rename・競合時の無変更とAndroid不変を同一code revisionのbuildで確認する。permission拒否の分類は人間にOS権限を変更させず、native wrapper testとCIで確認する。
- 手動証拠を含む最終独立reviewがPASSする。

## 作業記録

- 2026-08-09 / Android `DocumentsContract.renameDocument`に原子的no-replace契約が無いことを独立reviewで検出。provider依存raceの受容は不採用。
- 2026-08-09 / desktopを排他的native renameへ変更し、Android SAFを安全なunsupportedへ改訂。PR #116をDraftで保持。
- 2026-08-12 / hostの`flutter run -d emulator-5554`で、code assetを要求しないhook invocationが`input.config.code`へ先にアクセスして終了コード255になった。アプリ画面が残っていても検証buildは失敗として修正を再開。
- 2026-08-12 / 保存された同じinputで修正前は例外を再現し、`buildCodeAssets` guard追加後は`dart ... hook/build.dart --config=...`がexit 0。Dev ContainerのFlutter testは今回と別の既知制約（C compilerなし）で開始前に停止。
- 2026-08-12 / manualを人間向けに再構成。開始状態、専用fixture、画面上のボタン、期待する文言、実file確認、結果の返し方を順番化し、内部用語と不可視な「providerを呼ばない」確認を除いた。
- 2026-08-12 / hostで`flutter build apk --debug --no-pub`がexit 0（`app-debug.apk`生成）、`flutter run -d emulator-5554 --no-resident --no-pub`がexit 0（build・install・launch成功）。元のnative asset errorは再発しなかった。
- 2026-08-12 / CI run 31522320234は337 tests PASS後、hook実装文字列を旧形で固定した1 testだけFAIL。guardとlocal `targetOS`を確認する期待へ更新し、振る舞い条件は維持。
- 2026-08-12 / CI run 31522657379 PASS: analyze 0、338 tests。build hook回帰testを含むcurrent headをmanual evidence待ちへ戻した。

## Current state / handoff

- Last checkpoint: code/build `d6a4e18`をAndroid emulatorへbuild・install・launchし、current PR head `dc04019`のCIがanalyze 0・338 testsでPASS
- Blocker category: manual evidence
- Waiting for: 人間によるT05 Android/DesktopとT06 Desktop undoの番号付き結果
- Requested action: Agent準備済みworkspaceでT05/T06 manualを実施し、各項目を`PASS / FAIL / 確認不能`で返す
- Evidence revision: code/build `d6a4e18`; PR head `dc04019`; CI run 31522657379
- Next Agent action: manual結果を正本へ記録し、code/build以後の差分を照合してcurrent rangeの最終独立reviewを行う
