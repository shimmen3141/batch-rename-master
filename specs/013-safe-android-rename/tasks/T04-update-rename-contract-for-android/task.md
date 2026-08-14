# T04 005契約を衝突の採番回避へ改訂する(revision 4)

## 目的

005 contractを2つの点で改訂する。

1. **衝突を「失敗」ではなく「採番で回避するもの」として扱う**([005 ADR-002](../../../005-rename-exec/decisions/ADR-002-collision-resolution-by-numbering.md)、2026-08-14 開発者決定)。**これはplatform非依存の変更で、desktopにも及ぶ。**
2. Androidを「安全な未対応」から「`renameat2`による対応」へ変える。

**INV-002は緩めない。ただし成立範囲が環境依存になる。** 原子的no-replaceを提供する環境では完全に成立し、提供しない環境ではTOCTOUの分だけ成立しない。**この限界は開発者が受容した。**

## 入力と依存

- [`decisions/ADR-002`](../../decisions/ADR-002-android-rename-storage-boundary.md)。
- 005 `contracts/behavior-contract.json` revision 3(Strict、approved)。
- [ADR-001](../../../005-rename-exec/decisions/ADR-001-android-saf-rename-safety.md)。**破棄しない。** SAFを使わない理由は今も有効である。
- `T02`で決まるAPI level方針。
- [005 ADR-002](../../../005-rename-exec/decisions/ADR-002-collision-resolution-by-numbering.md)(proposed)。**この改訂の主たる駆動要因である。**
- 001の自動解決規則(` (n)`、先頭出現は据え置き)。**採番規則の正本は001であり、005は適用するだけである。**

## 決めること

0. **再採番の試行上限**(contract `open_questions` OQ-001)と、上限に達したときの提示。**無限に試さない。**
1. **失敗の分類。** `errno`を`RenameErrorKind`のどれへ写すか。`EEXIST`→`nameConflict`、`EACCES`/`EPERM`→`permissionDenied`、`ENOENT`→`notFound`、`EXDEV`(別filesystem)は新設が要るか。
2. **`renameat2`が使えない端末の扱い。** `T02`のD-2により、**「対応外」にはしない** — 実在確認による事前検出へ劣化させる。契約はREQ-025でその形を定めた。`unsupportedPlatform`はSAF退避経路のために残す。**API levelを境界として書き込まない。**
3. **handleの意味。** Androidのhandleが不透明なSAF URIから**絶対path**へ変わる。INV-005(handleは最後に得た値)の書き方が変わるか確認する。
4. **更新日時ずらし**(REQ-014〜016)。pathが手に入るので`ModifiedAtWriter`をAndroidでも実装できる。**このplanの範囲に入れるか、別taskへ送るか。**

## 変更範囲

- 005 `contracts/behavior-contract.json`をrevision 4へ。`spec.md`の検証表も契約と一致させる。
- **Strict仕様なので人間の再承認が要る。**
- **ADR-001は残す。** ADR-002がその上に載る形にする。

## 受け入れ証拠

- 契約の差分がINV-002 / INV-003 / OP-004を緩めていないことを、差分から読める形で示す。
- `spec.md`の検証表が契約の`verification`と全行一致する(005で一度driftさせた箇所)。
- **人間による契約の再承認**(revision 4)。
- 承認されたREQ IDをT05とT10の`task.json`の`covers`へ書く。**`task.json`の`covers`は所属planのspecへ解決される**ため、005契約のREQ IDはここへ書かない(同じ番号が013 specの別要求と衝突する)。**このtaskが触った005側のIDは次のとおり**: REQ-004、REQ-011、REQ-018、REQ-023、REQ-024、REQ-025、INV-002、INV-003、OP-004、VER-008。
- **再採番の経路がtestで検査できる形になっていること。** `nameConflict`を注入し、次の候補名で再試行し、結果に「確認した名前と異なる」が現れることを検査する。
- **preflightに関する記述が契約・spec・taskのどこにも残っていないこと**(2026-08-14に削除した)。
- 005の既存test(Android未対応のnegative testを含む)がどう変わるかを明示する。**退避経路のため、未対応adapterとそのtestは削除しない**(ADR-002)。
- `python <asdd-plugin>/scripts/workspace.py check specs`がPASS。

## 作業記録

- 2026-08-14 / **契約のdraftを作成した。** `contracts/behavior-contract.json`をrevision 4 / `status: draft`にし、REQ-004・REQ-011・REQ-018を改訂、REQ-023(再採番)・REQ-024(結果の提示)・REQ-025(no-replaceが無い環境の代替)を追加、INV-002の成立範囲とINV-003の記録名を明記、OP-004の`errors`へ`nameConflict`→再採番を書いた。用語へ「確認した目標名」「再採番」「実在名」を追加した。**人間の承認待ち。**

- 2026-08-13 / ADR-002の採用決定を受けて定義。

- 2026-08-14 / **開発者がcontract revision 4を承認。** `status: approved`、ADR-002を`accepted`にした。005 `spec.md`へ代表例25〜27とVER-008を足し、契約と一致させた。013側はpreflightの記述を全taskから除き、`T09`削除・`T10`新設まで反映した。PR #138。

## Current state / handoff

- Last checkpoint: **005 contract revision 4がapproved。** PR #138で独立review待ち
- Blocker category: なし
- Waiting for: 独立review
- Requested action: なし
- Evidence revision: `dev@4fd6ab1` + 013 ADR-002 + [005 ADR-002](../../../005-rename-exec/decisions/ADR-002-collision-resolution-by-numbering.md)(accepted) + 005 contract revision 4(approved 2026-08-14)
- Next Agent action: reviewがPASSしたらmergeし、`T03`と`T10`へ進む。004の仕様改訂で範囲が重なるので着手時に調整する
