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
- Review attempt 3: PR #121 `dev@abc8007...6432da8` — FAIL — 残るP0/P1: none(このtaskへの指摘なし。P2-a/P2-b/P2-7は解消を確認)

- Review attempt 4: PR #121 `dev@abc8007...3255f87` — PASS — 残るP0/P1: none(このtaskへの指摘なし)

## Current state / handoff

- 2026-08-12 / 実装完了。`ModifiedAtWriter`能力interfaceで更新日時の書き込みを`RenameExecutor`本体から分離し、desktop executorだけが実装する形にした。これで`executor is ModifiedAtWriter`がそのまま「この端末でずらせるか」になり、REQ-015が実装の形から出る。順序はREQ-014の文言どおり実行計画ではなく表示順(`files.items`)を基準にし、実行計画と食い違う入力でtestを置いた。REQ-016は失敗しても後続を続け、`modifiedAtFailures`へ改名の失敗と分けて集める。
- 2026-08-12 / `manual-verification.md`を実UIに合わせて具体化した。書いた画面文言6件を`git grep`でrepository内の出所と突き合わせ済み(dry-run)。
- Last checkpoint: 実装と仕様由来testが通り、manual手順を具体化した
- Blocker category: manual
- Waiting for: 人間による[`manual-verification.md`](manual-verification.md)の実施。実filesystemの更新日時が実際に書き換わること、Androidで設定が出ないこと、更新日時だけ失敗しても改名が成功として残ることは実機でしか観測できない
- Requested action: 人間がWindows desktop buildとAndroid buildでchecklistを実施し、結果を会話で返す
- Evidence revision: branch `asdd/005-rename-exec/T07-desktop-modified-time`(base `dev@b7f1e1b`)
- Evidence: `flutter test`=PASS(354、うち`modified_time_test.dart` 8件)、`flutter analyze`=PASS(0)、`dart format --set-exit-if-changed`=PASS(76 files / 0 changed)、manual dry-run=PASS(画面文言6件の出所確認)
- Next Agent action: Draft PRを出し、manual結果を受け取ってから独立reviewへ回す
