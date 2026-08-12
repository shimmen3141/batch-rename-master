# T04 選択と除去の導線を実装する

## 目的

`T03`で承認された仕様どおり、選択と除去を混同しない導線にする。

## 入力と依存

- `T03`で承認された002/004 spec。
- `docs/design/Bulk Renamer.html`。**適用する画面範囲は一覧の行と読み込みbarに限る**。

## 変更範囲

- 行の×の廃止と、除去の新しい導線。
- 「すべて外す」の改名と、必要なら配置。
- 002/004の仕様由来testの更新と追加。

## 受け入れ証拠

- 新しい除去導線で一覧から消え、checkboxの状態とは独立であることをwidget testで検査する。
- 改名した名前のbuttonが、checkboxの全解除と別の操作であることをtestで検査する。
- 004の読み込み契約(置き換え・cancel・警告)が壊れていないことを既存testの継続PASSで確認する。
- `flutter test` / `flutter analyze` / `dart format --output=none --set-exit-if-changed .` がPASS。
- [`manual-verification.md`](manual-verification.md)で、除去が誤操作になりにくいかを実機で確認する。
- exact rangeの独立reviewがPASSする。

## 作業記録

- 2026-08-12 / plan作成時に定義。

## Current state / handoff

- Last checkpoint: plan作成時に定義しただけ。未着手
- Blocker category: dependency
- Waiting for: `T03`の仕様更新と人間の再承認
- Requested action: なし
- Evidence revision: `dev@ea1dd04`
- Next Agent action: `T03`承認後にclaimし、test-firstで実装する
