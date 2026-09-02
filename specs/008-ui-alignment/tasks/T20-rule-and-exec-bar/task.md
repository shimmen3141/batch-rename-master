# T20 ルール設定buttonと実行buttonの提示を整える

## 目的

下部バーの2つのbutton——ルール設定と実行——を参考designの形へ寄せ、**何が押せるのか・
何が起きるのか**がbuttonの見た目から読めるようにする。

## 入力と依存

- **`T17`で承認された 002 / 005 spec**(実行可否の部分)。**承認前に実行可否を動かさない。**
  見た目と文言だけなら`T17`より先に進められるが、**分けてcommitすること。**
- `docs/design/Bulk Renamer.html`。**適用する画面範囲は下部バーの2つのbuttonに限る。**
  該当する土台は `execLabel` / `execBg` / `execFg`、ルール設定buttonの2行の形と`編集`chip、
  `ruleSummary`。
- 現行実装: `lib/ui/file_list/file_list_view.dart`の`_RuleButton`と実行button。
  **`_RuleButton`は`008:T16`が参考designの2行の形へ作り直した**が、警告の種別を載せていた。
  `T17`で**ルール単位の警告表示が無くなる**ので、そのぶんを外すのもこのtaskである。
- **`005:T09`の成果**(下部固定バーへ集約した実行導線)。**バーの構成そのものとルール設定
  sheetの開き方は動かさない。**

## 変更範囲

観測の出所は[`T16`のtask.md](../T16-implement-row-level-warnings/task.md)の
「受領したUIの改善要望(2026-09-02、原文)」。番号は同節のもの。

- **要望9(押せると分かる形)**: 「参考designだと全体がボタンと認識しやすいが、現状だと右の
  編集ボタンを押す必要があると錯覚する。」**button全体が一つの押下対象に見える**形にする。
- **要望9(ルールの表示)**: 「参考designだと`[元の名前][01][YYYYMMDD]`のようなトークン的な
  表示だが、現状は『連番1桁+作成日時』のような説明的な表示になってしまっている。」
  `describeToken`の連結をやめ、トークンを**そのまま並べた形**にする。
- **要望9(アイコン)**: 左のアイコンを参考designのものへ合わせる。
- **要望14(実行buttonの文言)**: 参考designの`execLabel`は
  `対象を選択してください` / `N 件をリネーム` / `ルールを設定してください`の3状態を持つ。
- **要望1(実行可否)**: 「ルールに元の名前だけを設定したときにリネームボタンを押せるように
  するかは考える余地がありそう。参考designではルール未設定時と同様に押せないようになっている。」
  **`T17`が決めた形に従う。**`T17`より先にこの部分を実装しない。
- **`T17`の結果に伴い、ルール設定buttonから警告の種別表示を外す。**

### 他taskとの分担

- 行の提示は`T18`、詳細modalは`T19`。**下部バーはこのtaskが持つ。**
- 余白・字体は`T10`。
- 実行前確認dialogとその文言は`T14`。

## 受け入れ証拠

- ルール設定buttonが**一つの押下対象**であることを、tapの当たり判定をwidget testで検査する
  (buttonのどこを押してもルール設定が開く)。
- 設定中のルールが**トークンを並べた形**で描かれることを検査する。**説明文になっていない**
  ことを両方向で固定する。
- 実行buttonのlabelが3状態(対象なし / 変更あり / ルール未設定)で切り替わることを検査する。
  **`N 件をリネーム`の N が実際の変更件数に一致する**ことを含める。
- `T17`が実行可否を変えた場合、**実ファイルを1件も変更しない**ことを検査する
  (005 REQ-019 が「ボタンだけ無効にして別経路から実行できる実装」を排除している型)。
- **狭幅(< 840dp)と広幅(≥ 840dp)の両方**で検査する。**広幅では`onEditRule`を渡さず
  ルール設定buttonが生成されない**(`rule_builder_workspace.dart`の`_buildWide`)。
  渡さないまま測ると何を検査しても通る(`T16`が2回この空振りを作った)。
- `tool/mutations.json`へmutationを足して`KILLED`を確認する。生の出力を報告へ貼る。
- **`005:T09` / `005:T05` のmanual手順と`docs/development/emulator-verification.md`**が、
  作り直したbuttonの見た目に合っている(`T16`が同じ理由で3か所を直している)。
- `flutter test` / `flutter analyze` / `dart format --output=none --set-exit-if-changed .` がPASS。
- `manual-verification.md`でAndroid実機の狭幅表示を確認する。
- exact rangeの独立reviewがPASSする。

## Current state / handoff

- Last checkpoint: 未着手(2026-09-02に登録)
- Blocker category: 依存
- Waiting for: `T17`の承認(実行可否の部分)
- Requested action: なし(`T17`の完了を待つ)
- Evidence revision: なし
- Next Agent action: `T17`が`done`になってから claim する
