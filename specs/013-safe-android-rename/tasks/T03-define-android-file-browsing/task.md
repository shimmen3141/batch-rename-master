# T03 Androidの読み込み導線を定義する

## 目的

Androidのfile選択をSAFからapp内のfile browserへ変える。その振る舞いを004 specへ反映し、再承認を得る。

## 入力と依存

- [`decisions/ADR-002`](../../decisions/ADR-002-android-rename-storage-boundary.md)の「受け入れた条件2」。
- `T02`で決まる権限の方針(権限が無いときに何を見せるか)。
- 004 spec。特にREQ-011(種類の選択)、決定D-2(実装が返したものをそのまま扱う)、REQ-006。
- `development-findings/2026-08-12-documentsui-type-chip-crosses-folders.md`。**SAFの種類chipがfolderを横断する問題は、app内browserでは起きない。**

## 決めること

1. **何を見せるか。** folder階層を辿るのか、既知の場所(Downloads、DCIM等)への近道を出すのか、両方か。
2. **`FileKind`(画像/動画/文書/すべて)をどう扱うか。** SAFのMIME filterが無くなるので、拡張子で絞るのか、絞るのをやめるのか。004 REQ-011の意味が変わる。
3. **複数folderをまたぐ選択を許すか。** SAFでは事実上できてしまっていた(上記finding)。app内browserでは**設計で決められる**。005の重複警告の頻度に直結する。
4. **hidden fileとsystem領域の扱い。** 012(隠しfilter)の先取りにならない範囲で、最低限何を見せないかを決める。
5. **desktopとの差。** desktopはOS pickerのまま。**同じappで選択体験が2つになる**ことを仕様として認める。

## 変更範囲

- 004 specの更新と再承認。
- **判定を新設しない。** 004の決定D-2は維持する。app内browserは「filesystemが返したものをそのまま見せる」。

## 受け入れ証拠

- 004 specの更新差分が、上記の決めることすべてに答えている。
- **人間による004 specの再承認。**
- 承認されたREQ IDをT07の`task.json`の`covers`へ書く。
- `python <asdd-plugin>/scripts/workspace.py check specs`がPASS。

## 作業記録

- 2026-08-13 / ADR-002の採用決定を受けて定義。

## Current state / handoff

- Last checkpoint: 定義しただけ。未着手
- Blocker category: dependency
- Waiting for: `T02`の権限方針
- Requested action: なし
- Evidence revision: `dev@f97a2cc` + ADR-002
- Next Agent action: `T02`承認後に着手する。004 specのAndroid該当REQを洗い出してから案を作る
