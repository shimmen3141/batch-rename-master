# T04 ウィジェット: 各トークンの詳細エディタ(自由テキスト/区切り/連番/日時)

## 目的

- ウィジェット: 各トークンの詳細エディタ(自由テキスト/区切り/連番/日時)

## 入力と依存

- 依存: T02
- 同じworkspaceの`spec.md`、contract、decisions、仕様由来テスト。

## 変更範囲

- 旧planで定めた成果範囲。詳細は凍結履歴を参照する。

## 受け入れ証拠

- Chip タップで種別ごとの詳細エディタを開き、自由テキスト(文字列)・区切り(プリセット選択)・連番(start/digits/increment)・日時(source/format)を編集すると、対応する新しい `Token` に差し替わる。元のファイル名は設定項目なし。
  - 該当 REQ/VER を覆う widget test が通り、`flutter analyze`/`dart format` PASS。
- 参考: T1、T2、001 の各 `Token` の引数、参考デザインの詳細ダイアログ

## 作業記録

旧ASDD 0.xから、実際に記録されていたcheckpointだけを移行した。将来予定やlive状態には使わない。

- 2026-08-02 / 着手 / 担当: shimmen3141(Issue #29 を assign)。ブランチ asdd/003-rule-builder/T4。
  - 2026-08-02 / done / verifier PASS(試行1)+レビューパス(P0/P1 なし)。`token_editors.dart`(ボトムシートの詳細エディタ + `showTokenEditor`)を追加、`rule_builder_view.dart` の Chip タップを既定エディタ→`replaceAt` に配線(REQ-005)。自由テキスト/区切り=空不可ガード付き LiteralToken エディタ(区切りプリセット4種)、連番=ステッパー(start≥0/digits≥1/increment≥1、負を型で排除)、日時=基準選択+プリセット+自由入力、元名=設定なし。token_editors_test.dart 6件(spec_003 計23件)、`flutter analyze` 0 issue、`dart format` PASS。
  - 2026-08-02 / PR #34 作成(asdd/003-rule-builder/T4 → dev, Closes #29)。マージ待ちで停止。最後の T5(レスポンシブ外殻 + 002 setRule 連携)は T3・T4 のマージ後に実行可。
  - 2026-08-02 / PR #34 マージ済み(dev)。#29 close。
