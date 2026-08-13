# T04 005契約のAndroid経路を更新する

## 目的

005 contractのAndroidを「安全な未対応」から「`renameat2`による対応」へ変える。**契約そのもの(INV-002、INV-003、OP-004)は緩めない。**

## 入力と依存

- [`decisions/ADR-002`](../../decisions/ADR-002-android-rename-storage-boundary.md)。
- 005 `contracts/behavior-contract.json` revision 3(Strict、approved)。
- [ADR-001](../../../005-rename-exec/decisions/ADR-001-android-saf-rename-safety.md)。**破棄しない。** SAFを使わない理由は今も有効である。
- `T02`で決まるAPI level方針。

## 決めること

1. **失敗の分類。** `errno`を`RenameErrorKind`のどれへ写すか。`EEXIST`→`nameConflict`、`EACCES`/`EPERM`→`permissionDenied`、`ENOENT`→`notFound`、`EXDEV`(別filesystem)は新設が要るか。
2. **`renameat2`が使えない端末の扱い**(`T02`の決定に従う)。`unsupportedPlatform`を返す経路を残すか。**API levelを境界として書き込まない** — `T02`が選ぶのはAPI levelでの分岐とは限らず、実行時検出の案もある。契約は「使えない端末では未対応を返す」という観測可能な形で書く。
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
- 承認されたREQ IDをT05の`task.json`の`covers`へ書く。
- 005の既存test(Android未対応のnegative testを含む)がどう変わるかを明示する。**退避経路のため、未対応adapterとそのtestは削除しない**(ADR-002)。
- `python <asdd-plugin>/scripts/workspace.py check specs`がPASS。

## 作業記録

- 2026-08-13 / ADR-002の採用決定を受けて定義。

## Current state / handoff

- Last checkpoint: 定義しただけ。未着手
- Blocker category: dependency
- Waiting for: `T02`のAPI level方針
- Requested action: なし
- Evidence revision: `dev@ec2e74f` + ADR-002
- Next Agent action: `T02`承認後に着手する。契約の差分は最小にし、platform例外を作らないことを最優先で確認する
