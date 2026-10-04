# T01 撮影日時の取り方を仕様にする

## 目的

写真・動画の撮影日時を**どこから・どの順で取り、どう表し、どう見せるか**を 004(と連動するなら 001・002)の仕様へ差分として書き、開発者の承認を得る。実装は T02・T03。

## 入力と依存

- [plan.md](../../plan.md) の「人間の決定」(撮影日時を先にする / 中身の撮影日時と `DATE_TAKEN` を使い、`DATE_ADDED` は使わない)。
- [R-001](../../decisions/R-001-mediastore-date-taken-source.md)(`DATE_TAKEN` の作られ方と、時刻帯のずれ)。
- 004 REQ-003(作成日時は取れたときだけ。代替しない)・REQ-010(経路の優先順位)・代表例 10。
- 001 の日時トークンと INV-006、002 REQ-002 / REQ-011 / REQ-013(作成日時の並び・不明の警告・行の表示)。
- product-map の 010 の前提「日時の意味変更は 001/002 を再承認する」。

## 決めること

- **経路の順位**: 中身(EXIF `DateTimeOriginal`・動画の撮影日時)→ `DATE_TAKEN`、を既定の案とする。中身と `DATE_TAKEN` が食い違うときの扱い。
- **時刻帯**: EXIF の撮影日時は時差を持たない(`OffsetTimeOriginal` があれば持つ)。`DATE_TAKEN` は UTC。動画の記録日時は多くが UTC。
  名前に入る「撮影日」を**撮影地の時刻**にするか**端末の時刻帯**にするか。`FileEntry` の作成日時の型と、001 の日時トークンがどの時刻で描くかを先に確かめる。
- **対象の形式**: 写真(JPEG・HEIC・WebP・PNG など)と動画(MP4・MOV など)のうち、どれを T02 で読むか。読めない形式は「不明」のまま。
- **呼び名**: 撮影日時が入る欄・並び順・トークンを「作成日時」のまま呼ぶか、「撮影日時」などへ変えるか(利用者から見える)。
- **不明のときの案内**: 撮影日時が不明なファイルに対して、警告で更新日時のトークンを案内するか(plan の決定 2026-10-04 `DATE_ADDED` の行)。
- **読み込みの時間**: 中身を読むので、件数が多いと読み込みが遅くなりうる。待たせ方を決める必要があるか。
- 001・002 の意味が動くか(動くなら再承認の対象に入れる)。

## 変更範囲

- `specs/004-file-source/spec.md`(必要なら `specs/001-rename-core/spec.md`・`specs/002-file-list/spec.md`)。
- code は変えない。

## 受け入れ条件

- [ ] 上の「決めること」が spec の差分になり、代表例で観測できる形になっている。
  - 証拠: spec の差分、`python3 tool/check_normative_terms.py`(`flutter test test/tooling`)PASS。
- [ ] 開発者が差分を承認している。
  - 証拠: この task.md の承認記録。
- [ ] 独立review が PASS。

## 作業記録

## Current state / handoff

- Last checkpoint: 未着手(plan を作った。2026-10-04)
- Blocker category: none
- Evidence revision: none
- Next Agent action: 001 の日時トークンと `FileEntry.createdAt` の時刻の扱いを確かめ、決めることを選択肢にして開発者へ一問ずつ尋ねる
