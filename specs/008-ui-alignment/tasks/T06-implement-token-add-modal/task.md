# T06 token追加をmodal確定へ変える

## 目的

`T05`で承認された仕様どおり、tokenは設定を終えてから列に入るようにする。既定値のままのtokenが紛れない。

## 入力と依存

- `T05`で承認された003 spec。
- `docs/design/Bulk Renamer.html`。**適用する画面範囲はルール構築のtoken追加に限る**。

## 変更範囲

- token追加の導線(modal)と、cancel時に追加されないこと。
- 003の仕様由来testの更新と追加。

## 受け入れ証拠

- modalをcancelするとtokenが追加されないことをwidget testで検査する。
- 設定を終えて確定すると、その設定値でtokenが列に入ることをtestで検査する。
- 007の永続化(ruleの保存・復元)が壊れていないことを既存testの継続PASSで確認する。
- `flutter test` / `flutter analyze` / `dart format --output=none --set-exit-if-changed .` がPASS。
- [`manual-verification.md`](manual-verification.md)で実機の操作感を確認する。
- exact rangeの独立reviewがPASSする。

## 作業記録

- 2026-08-12 / plan作成時に定義。

## Current state / handoff

- Last checkpoint: plan作成時に定義しただけ。未着手
- Blocker category: dependency
- Waiting for: `T05`の仕様更新と人間の再承認
- Requested action: なし
- Evidence revision: `dev@ea1dd04`
- Next Agent action: `T05`承認後にclaimし、test-firstで実装する
