# T07 行と警告の情報階層を整える

## 目的

狭幅でも、どの行の作成日時が不明かと、警告の内容が読み取れるようにする。あわせて参考designの(b)「ファイル種別アイコンとリッチな行レイアウト」を行の情報階層の一部として入れる。仕様の変更を伴わない提示の調整。

(b)を分けないのは、**どちらも同じ行のlayoutを決める判断**だからである。別taskにすると同じwidgetを二度書き直すことになる。

## 入力と依存

- `specs/product-map.md`「008へ引き継いだ人間の決定(planへ反映済み)」の(h)(i)。
- `specs/history/asdd-0.x-discovery.md`の(b)。
- 現行の種別表現: `lib/ui/file_source/file_kind.dart`(読み込み時の種類chip)。行側に種別の表示は無い。
- 002 spec REQ-013(どのitemの作成日時が不明かを提示する。**提示方法の詳細は視覚デザインとして対象外**)。
- 005 specの「警告・確認・結果表示の視覚デザイン」→ 008送りの記載。
- 現行実装: `lib/ui/file_list/file_list_view.dart`の行サブ情報(`maxLines: 1` + ellipsisで1行にまとめている)、`lib/ui/file_list/rename_warning_view.dart`の警告帯。

## 変更範囲

- 行のサブ情報の折り返し・省略の優先順位・レイアウト。
- ファイル種別アイコンと行のlayout((b))。

  `FileKind`は**読み込み時に選ぶ種類**(004 REQ-011)であって、行ごとの種別ではない。行にアイコンを出すには拡張子かMIMEからの判定を新設することになる。これは提示ではなく**判定の追加**なので、次のいずれかに限る。

  - 拡張子からの分類を`lib/ui/`内の表示専用のものとして持ち、判定できないものは既定アイコンにする(改名の挙動に影響しない)。
  - 判定を持たず、アイコンを入れない。

  どちらを取るかは着手時に決め、`task.md`の作業記録へ根拠を書く。**004の決定D-2(実装が返したものをそのまま扱う)を曲げない**こと。種別を推測して読み込み対象を変えるような使い方はしない。
- 警告帯の情報階層。folder跨ぎの重複警告が通常経路で出るため((i))、件数が多いときに読めるかを含む。

**行ごとの「場所(元folder)」の提示はT07が持つ。** 一覧全体としての「何がどこから入っているか」はT08が持つ。同じ情報を二重に出さないよう、後に着手した側が先の結果に合わせる。詳細は[`T08のtask.md`](../T08-load-affordance-and-path/task.md)。
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
