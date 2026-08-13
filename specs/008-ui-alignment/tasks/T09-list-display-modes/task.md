# T09 リスト表示モードの切替を入れる

## 目的

参考designの(a)「リスト表示の3案切替(リッチ / グリッド / コンパクト)」を扱う。1画面に入る件数と、1件あたりに見える情報量のどちらを取るかを利用者が選べるようにする。

## 入力と依存

- `specs/history/asdd-0.x-discovery.md`の(a)。
- 参考design `docs/design/Bulk Renamer.html`の3案。
- T07が決めた行の情報階層。**リッチ案はT07の行そのもの**なので、T07の後に着手する。
- 002 spec。行の描画方法は「視覚デザインは非規範」として対象外だが、**表示modeという利用者から見える状態を足す**ことは提示以上の変更にあたる。

## 先に決めること

**3案すべてが要るとは限らない。** 着手時に次を人間へ確認し、`plan.md`の決定表へ記録してから実装する。

- 3案すべてを出すか、2案(リッチ / コンパクト)に絞るか。グリッドは名前の可読性を犠牲にするため、改名appでの有用性が案ごとに違う。
- 選んだmodeをsessionをまたいで覚えるか。覚えるなら007の永続化基盤を使うか、別に持つか。覚えないなら起動のたびに既定へ戻る。
- 選択checkboxと手動並び替え(T02でREQ-014を廃止して常時可能になる)を、どのmodeでも使えるようにするか。グリッドでのdragと選択は両立しにくい。

上記は仕様変更の要否を左右する。「覚える」を選ぶと002へ状態が増えるため、仕様更新taskを分けるかをその時点で判断する。

## 変更範囲

- 表示modeの状態と切替control。
- 各modeの行・cellの描画。
- 選択、手動並び替え、警告表示が各modeで成立すること。

## 受け入れ証拠

- 各modeで選択・手動並び替え・警告表示が成立することをwidget testで検査する。
- modeを切り替えても選択状態と並び順が失われないことをtestで検査する。
- 002/005の既存testが継続PASSする。
- `flutter test` / `flutter analyze` / `dart format --output=none --set-exit-if-changed .` がPASS。
- [`manual-verification.md`](manual-verification.md)でAndroid実機とWindows desktopの各modeを確認する。
- exact rangeの独立reviewがPASSする。

## 作業記録

- 2026-08-13 / 人間の判断で(a)〜(d)を008の対象へ入れた際に定義。

## Current state / handoff

- Last checkpoint: 定義しただけ。未着手
- Blocker category: なし
- Waiting for: T07(行の情報階層)。リッチ案がT07の成果そのもののため
- Requested action: なし
- Evidence revision: `dev@ea1dd04`
- Next Agent action: T07完了後、「先に決めること」の3点を人間へ一度に確認してから設計する
