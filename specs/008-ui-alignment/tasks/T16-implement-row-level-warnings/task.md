# T16 警告を行に出す提示を実装する

## 目的

`T15`で承認された仕様どおり、警告を各行へ出し、集約帯を置き換える。

## 入力と依存

- **`T15`で承認された 002 / 005 spec。** 承認前に着手しない(`plan.md`の方針)。
- `docs/design/Bulk Renamer.html` の行の`warnText` / `rowBg` / `cardBorder` と、
  ヘッダの`warnLabel`。**適用する画面範囲は一覧の行、ヘッダの警告表示、そして下部バーの
  警告の提示ぶんである。** 下部バーは`005:T09`の成果なので、**実行buttonの振る舞い・ルール
  設定sheetの開き方・バーの構成そのものは動かさない**(下記「下部バーの所有」)。
- 現行実装: `lib/ui/file_list/rename_warning_view.dart`(集約帯と文言生成)、
  `lib/ui/file_list/row_view.dart`(行データ)、`lib/ui/file_list/file_list_controller.dart`。
- `T07`が入れた行のlayout。**行は既に現在名・変更後名・サブ情報を縦に積んでいる**ので、
  警告はその構造の上に載る。`T07`の情報階層を壊さないこと。

## 変更範囲

- 行データが警告を持つ(`RowView`)。
- 行の警告表示(短い一文、行の色・枠)。
- 集約帯の置き換え(ヘッダの件数と、詳細のトグルまたはmodal)。

  **`T07`から引き受けた残余risk N-9**: 現行の帯は高さの上限を**画面**の割合で決めているが、
  帯は一覧の上に載るので、header・barを引いた**一覧の取り分**に対しては割合が跳ね上がる。
  2026-08-29のAndroid emulator確認で、開いた帯が**一覧の見える範囲の半分以上**を覆った。
  **`T15`が帯の廃止を決めたので、この論点そのものは消える。** ただし置換先(ヘッダーの件数と
  modal)が**一覧を覆わない**ことは、このtaskが確かめること — 常時の占有が0になるのが
  廃止の狙いである。
- `describeWarning`が作る文面の整理。**実行前確認dialog(`T14`が持つ)が使っている文面**を
  壊さないこと。分担は`T14`と突き合わせる。
- 置き換えた検証(下記)。

### `T14`との分担

`T14`は**実行前確認dialog**(`file_list_view.dart`の`Key('rename-confirmation-dialog')`)を持つ。このtaskが
作るのは**警告の詳細を見る**ための提示である。**同じmodalに二つのtaskが手を入れない**よう、
着手時にどちらが入れ物を持つかを決めて両方の`task.md`へ書く。

### `T09`との関係

`T09`はmodeごとの描画を持つ。**リッチ案は`T07`の行をそのまま使う**と決めてあるので、
このtaskが行へ足す警告表示も`T09`が引き継ぐ。グリッド・コンパクトで警告をどう出すかは
`T09`が決める。

### 提示の場所はこのtaskが決める(`T15` revision 8.0)

**005 も 002 も配置を「自由とする点」へ置いている。** `T15`が課すのは場所ではなく
**利用者から何が読めるか**である。どの部品のどこに置くかは**このtaskの裁量**で、
参考designと`T15`の設計指針を土台にする。

**必ず確かめること — 幅で分岐する。** `RuleBuilderWorkspace`は幅 840dp で分かれ、
**wide では`onEditRule`を渡さない**(`rule_builder_workspace.dart`の`_buildWide`)。
`FileListView`の`_RuleButton`は生成されず、**下部バーにルール設定の導線が無い。**
wide のルール編集は右ペインの`RuleBuilderView`である。**narrow だけを見て実装すると、
wide で原因の提示が行き場を失う**(`T15`の独立review attempt 3 が見つけた)。
**このplanは同じ型の誤りを一度直している** — 「Androidでは必ずsheet越し」は platform では
なく幅で決まる。**両方のlayoutをwidget testで通すこと。**

下部バーへ載せる場合、実行buttonの振る舞い・ルール設定sheetの開き方・バーの構成そのものは
動かさない(`005:T09`の成果)。余白・typographyは`T10`、modalの文言は`T14`。

## 受け入れ証拠

- 行に警告が出て、どのファイルが何の理由かを行から読み取れることをwidget testで検査する。
- **すべての種別が併発しても行の警告が2行に収まる**ことを、幅を指定したwidget testで
  検査する(`T15`が要求に入れた場合)。
- 詳細(トグルまたはmodal)で全件と説明が読めることをwidget testで検査する。
- **置き換えたtestが、元の要求を同じ強さで押さえている**ことを示す。
  `warning_display_test.dart` / `empty_rule_test.dart` の該当箇所は**緩めるのではなく
  付け替える** — 005 REQ-009 の「対象fileとトークンが特定できる」を、新しい提示に対して
  検査する。
- 001の判定を変えていないこと(既存testの継続PASS)。**提示だけを変える。**
- **空ルールのとき、行にも警告が出ない**ことを検査する(005 REQ-020)。**廃止するwidgetのkeyに
  依存しない形で書くこと** — 現行の`empty_rule_test.dart`は`renameWarningsKey`の不在で
  REQ-020を押さえており、帯を消すと**widgetが無いから通る**状態になる(`T15`の独立reviewが
  安全網の穴 N-15-1 として挙げ、このtaskを引き受け先に指定した)。002 REQ-015は「空ルールなら
  供給しない」とは書いていないので、行へ出す実装が空ルールでも出す穴が開きうる。
- **`[元名][日時 作成]`で作成日時が不明なとき**(名前は空にならない)、005の例20g/20hのとおり
  **30件それぞれで種別が読め、トークンの説明は1つ**であることを検査する。
- **狭幅(< 840dp)と広幅(≥ 840dp)の両方**で、005 REQ-009 の3つを満たすことをwidget testで
  検査する。**片方だけ通しても、もう片方の抜けは検出できない**(`008:T07`のM166/M167と同じ型)。
- `tool/mutations.json`へ、警告が行から消えるmutationを足して`KILLED`を確認する。
- `flutter test` / `flutter analyze` / `dart format --output=none --set-exit-if-changed .` がPASS。
- [`manual-verification.md`](manual-verification.md)でAndroid実機の狭幅表示を確認する。
  **件数の多い状態**(重複が数十件)を含める。
- exact rangeの独立reviewがPASSする。

## 作業記録

- 2026-08-27 / `T07`から分離して定義。`T07`は行のlayoutとpreviewで閉じる。

## Current state / handoff

- Last checkpoint: 定義しただけ。未着手
- Blocker category: dependency
- Waiting for: `T15`の仕様更新と人間の再承認
- Requested action: なし
- Evidence revision: `dev@7597342`
- Next Agent action: `T15`承認後にclaimし、行データの拡張から test-first で実装する。manual手順は実装後にcurrent revisionと照合して具体化する
