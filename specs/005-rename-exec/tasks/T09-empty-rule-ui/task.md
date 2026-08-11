# T09 空ルール時の実行防止UIを実装する

## 目的

ruleが空ならrenameを開始せず設定案内を表示し、token追加で通常状態へ戻る。

## 入力と依存

- `T08`で承認済みのREQ-019〜022。
- `T04`で統合済みのrename action境界。
- Issue #102。

## 変更範囲

- rename buttonのdisabled状態、未設定表示、rule設定への導線、token追加後の復帰。
- 警告確認・結果表示の再実装やUI全体の視覚調整は対象外。

## 受け入れ証拠

- 空ruleでadapter call 0、未設定案内、token追加後の通常実行をwidget/仕様由来testで検査する。
- [`manual-verification.md`](manual-verification.md)で利用者から見える導線を確認する。

## 作業記録

- T08の仕様更新は承認済み。T04はPR #110でdevへ統合済み。Issue #102は未claimで着手可能。

## Current state / handoff

- Last checkpoint: 依存T08/T04はdone。実装branchは未claim
- Blocker category: none
- Waiting for: none
- Requested action: none
- Evidence revision: dev@b7e6d54でT04統合・再検証済み
- Next Agent action: Issue #102をclaimし、005:T09 branch/worktreeでempty rule stateを実装する
