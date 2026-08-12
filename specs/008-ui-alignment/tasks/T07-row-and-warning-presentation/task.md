# T07 行と警告の情報階層を整える

## 目的

狭幅でも、どの行の作成日時が不明かと、警告の内容が読み取れるようにする。仕様の変更を伴わない提示の調整。

## 入力と依存

- `specs/product-map.md`「008へ引き継ぐ人間の決定」の(h)(i)。
- 002 spec REQ-013(どのitemの作成日時が不明かを提示する。**提示方法の詳細は視覚デザインとして対象外**)。
- 005 specの「警告・確認・結果表示の視覚デザイン」→ 008送りの記載。
- 現行実装: `lib/ui/file_list/file_list_view.dart`の行サブ情報(`maxLines: 1` + ellipsisで1行にまとめている)、`lib/ui/file_list/rename_warning_view.dart`の警告帯。

## 変更範囲

- 行のサブ情報の折り返し・省略の優先順位・レイアウト。
- 警告帯の情報階層。folder跨ぎの重複警告が通常経路で出るため((i))、件数が多いときに読めるかを含む。
- **仕様は変えない。** 002 REQ-013の識別自体は現行でも警告アイコンで成立している(アイコンは省略対象外)。読みやすさの改善である。

## 受け入れ証拠

- 狭幅で`作成日時: 不明`が読み取れることをwidget testで検査する(幅を指定して省略位置を検査する)。
- 警告が複数件あるときに内容が読み取れることをwidget testで検査する。
- 002/005の既存testが継続PASSする(判定も文言の意味も変えていない)。
- `flutter test` / `flutter analyze` / `dart format --output=none --set-exit-if-changed .` がPASS。
- [`manual-verification.md`](manual-verification.md)でAndroid実機の狭幅表示を確認する。**004:T10で見切れを観測したのと同じ条件で確認する。**
- exact rangeの独立reviewがPASSする。

## 作業記録

- 2026-08-12 / plan作成時に定義。(h)は`004:T10`のAndroid実機確認で観測、(i)は同確認でfile選択画面の種類チップがfolderを横断すると判明したことによる。

## Current state / handoff

- Last checkpoint: plan作成時に定義しただけ。未着手
- Blocker category: なし
- Waiting for: なし
- Requested action: なし
- Evidence revision: `dev@ea1dd04`
- Next Agent action: 他taskと独立に着手できる。狭幅の再現条件をwidget testで固定してから調整する
