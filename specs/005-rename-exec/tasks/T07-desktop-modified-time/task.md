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

## Current state / handoff

- Last checkpoint: 仕様と依存は確定。実装branchは未claim
- Blocker category: dependency
- Waiting for: 005:T05 / PR #116のdev統合
- Requested action: none
- Evidence revision: origin/dev@53acc33。T05はPR #116 head b866e35でmanual待ち
- Next Agent action: T05統合後にIssue #98をclaimし、optionとmtime失敗境界をtest-firstで実装する
