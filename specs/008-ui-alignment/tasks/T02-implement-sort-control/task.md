# T02 並び順controlを実装する

## 目的

`T01`で承認された仕様どおり、並び順を現在の状態が見える一つのcontrolにし、連番の有無に関わらず手動並び替えできるようにする。

## 入力と依存

- `T01`で承認された002 spec。
- `docs/design/Bulk Renamer.html`の並び順control。**適用する画面範囲は一覧上部の並び順controlに限る**(下部の実行バーは005:T09の成果なので動かさない)。
- 現行実装: `lib/ui/file_list/file_list_view.dart`のsort chip、`lib/ui/file_list/file_list_controller.dart`の`manualOrderMatters`。

## 変更範囲

- 横並びchipを、現在の状態を示すcontrolへ置き換える。
- `manualOrderMatters`によるdrag handleとcustomの出し分けを廃止する。
- 昇順・降順(T01の決定に従う)。
- 002の仕様由来testの更新と追加。

## 受け入れ証拠

- 連番トークンが無いルールでもdrag handleが出て並び替えられ、並び順の表示が「カスタム」へ変わることをwidget testで検査する。
- 各sort keyの選択と、昇降(採用する場合)が状態へ反映されることをtestで検査する。
- 002 REQ-011/013(作成日時ソート時だけ強調)が壊れていないことを既存testの継続PASSで確認する。
- `flutter test` / `flutter analyze` / `dart format --output=none --set-exit-if-changed .` がPASS。
- [`manual-verification.md`](manual-verification.md)で実機の操作感を確認する。
- exact rangeの独立reviewがPASSする。

## 作業記録

- 2026-08-12 / plan作成時に定義。

## Current state / handoff

- Last checkpoint: plan作成時に定義しただけ。未着手
- Blocker category: dependency
- Waiting for: `T01`の仕様更新と人間の再承認
- Requested action: なし
- Evidence revision: `dev@ea1dd04`
- Next Agent action: `T01`承認後にclaimし、test-firstで実装する。manual手順は実装後にcurrent revisionと照合して具体化する
