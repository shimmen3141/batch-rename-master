# T07 desktopの更新日時ずらしを実装する

## 目的

desktopでだけ表示される既定OFFの設定により、rename成功後の更新日時を表示順にずらし、副次処理失敗でもrename成功を維持する。

## 入力と依存

- `T05`のdesktop adapter統合。
- 005 REQ-014〜016、VER-006。
- Issue #98。

## 変更範囲

- desktop限定option、表示順に対応するmtime更新、失敗結果の分離、仕様由来testとmanual確認。
- Androidでのmtime更新は対象外。

## 受け入れ証拠

- option既定OFF、ON時の順序、mtime失敗時もrename成功維持を自動testで検査する。
- [`manual-verification.md`](manual-verification.md)で実filesystemのmtimeとUIを確認する。

## 作業記録

- 旧005 T07とASDD 1.x work packageから未着手成果として移行。Issue #98はT05統合待ち。

- 2026-08-12 / manual checklistを点検した。004/007と違い、**移行での欠落は無かった**(凍結0.x planのT7受け入れ条件3件のうち、既定OFF/表示順と「ずらし失敗でもrename成功」は受け入れ証拠へ、「Androidでは設定自体を提示しない」は変更範囲へ移っている。受け入れ証拠側には無いが失われてはいない)。stubだったのは実装前だからで、UIが未確定のまま手順を書くと実画面と食い違うため、`manual-verification.md`には実装時にchecklistへ落とす観点6件(既定OFF、Android非提示、表示順、filesystem解像度、副次失敗でrename維持、失敗の見分け)を残し、実行手順は実装時に書くことを明記した。あわせてskillの規定に反していた返信templateとstatus欄を外した。

- Review attempt 1: PR #121 `dev@abc8007...7cb943b` — FAIL — 残るP0/P1: none(このtaskへの指摘はP2-2内部用語とP2-7 findingの粒度。前者は`fb6f7d7`で一部、残りをこの修正で解消)
- Review attempt 2: PR #121 `dev@abc8007...aaacf5d` — FAIL — 残るP0/P1: none(P2-a `manual-verification.md`に内部用語が残存、P2-b このattempt行の欠落。いずれもこの修正で解消)

## Current state / handoff

- Last checkpoint: 依存が解けて着手可能。実装branchは未claim
- Blocker category: なし
- Waiting for: なし。依存していた005:T05はPR #116で`dev`へ統合済み(`425c30a`)で、T05/T06ともstatusは`done`
- Requested action: なし
- Evidence revision: `dev@abc8007`(依存の統合を確認した時点)
- Next Agent action: Issue #98をclaimし、optionとmtime失敗境界をtest-firstで実装する。実装と同時に`manual-verification.md`の観点6件を実行手順へ具体化する
