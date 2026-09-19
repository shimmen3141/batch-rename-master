# T28 まとめて外す選択モードを実装する

## 目的

`T27` で承認された 002 REQ-018 のとおり、**行の × を撤去し、長押しと常設の入口から入る
一時的な選択モードでまとめて外せる**ようにする。

## 入力と依存

- `T27` で承認された [`002 spec`](../../../002-file-list/spec.md) の REQ-016 / REQ-017 / REQ-018 と
  代表例 6e〜6j、および決定節「008 T27 由来の更新」。
- `docs/design/Bulk Renamer.html`。**適用する画面範囲は一覧の行とヘッダに限る**
  (designは選択モードを描いていないので、**土台から離れる点として `task.md` へ書く**)。
- 現行実装: `lib/ui/file_list/file_list_view.dart`(行の × とつまみ、ヘッダの `〇 件`)、
  `lib/ui/file_list/removal_undo.dart`(`T04` の取り消し)。

## 変更範囲

- **通常表示の行から × を撤去する**(REQ-016)。
- **選択モード**を足す(REQ-018): 長押しで入る / 長押しに依存しない入口 / モード中の行の選択切り替え /
  件数 / `リネーム候補から外す` / やめる / モード中はつまみを出さない。
- **まとめての除去を 1 回の取り消しで戻す**(REQ-017)。`removal_undo.dart` の
  snapshot guard(`T04` が3経路で固めた古いsnapshotの防止)を**壊さずに**複数件へ広げる。
- 002 の仕様由来 test の更新と追加。`tool/mutations.json` への追加。

### 行widgetの分担(`T07`・`T09` と共有する)

`T04` が定めた分担を引き継ぐ。**`T28` が持つのは操作**(× の撤去、選択モード、除去の導線)で、
情報階層と静的layoutは `T07`、mode別描画は `T09` が持つ。判断が割れたら `T07` の情報階層を優先する。

### `T25`(通知を閉じる)との境界

取り消しの提示そのものの見せ方は `T25` が持つ。`T28` は**取り消しが 1 回で全件戻る**ことだけを持つ。

## 気をつけること

- **`ReorderableListView` はモード中も同じ list である。** つまみを隠すだけでは
  長押しドラッグが残る実装になりうる(`ReorderableListView` は既定で長押しドラッグを持つ)。
  **モード中に長押しで並び替えが始まらない**ことを test で固定する。
- **× を撤去すると `004 REQ-006` の除去が UI から消える経路ができる。** 選択モードが
  一覧が空でない間**常に**到達できることを test で固定する(REQ-018 の入口(b)。代表例 6j)。
- `T04` の実機確認で観測したとおり、**× はハンドルを持つ行にだけ出ていた**。モードの選択も
  同じ制約を受けるのか(ハンドルの無い行は外せないのか)を実装前に確かめ、
  **外せない行が混ざるなら件数と実行結果の食い違いを防ぐ**。

## 受け入れ証拠

- 代表例 6e〜6j に対応する widget test。
- `flutter test` / `flutter analyze` / `dart format` / `mutation_check.py` が PASS。
- Android 実機での manual 確認(`manual-verification.md` を作成する)。

## 実装(2026-09-19)

### 決めたこと

- **選択モードの状態は `FileListView` 側に置いた**(`FileListController` へ入れない)。
  controller の選択(`toggleSelection` / `selectedCount`)は **rename 対象の選択**で、
  製品 UI では常に全件である(REQ-004 / REQ-016)。ここで選ぶのは**外す候補**で、
  モードを抜ければ消える別物なので、同じ状態へ混ぜると「外す候補にしただけで
  rename から外れる」振る舞いになりうる。`FileListView` を `StatefulWidget` へ変えた。
- **覚えるのはハンドル**である。項目は改名や読み込み直しで別の値へ入れ替わるが
  (005 REQ-018 / 004 REQ-004)、ハンドルは同じファイルを指す。**いま一覧にあるハンドルと
  交差させてから数える**ので、読み込み直しで消えた行は件数に入らない
  (「2 件」と出して1件しか外れない、を防ぐ)。
- **まとめての除去は `removeFile` の反復**で行う。`setFiles(残り)` は**占有名を捨てる**ので
  (005 REQ-026)、外しただけで一覧の重複警告が弱くなり、`T04` の控えの照合も毎回
  「古い」と判定されて取り消せなくなる(mutation M315 がこの経路を塞いでいる)。
- **常設の入口は「一覧が空でない間」で出す**(外せる行があるかでは出し入れしない)。
  REQ-018 の文面がそれであり、行の中身でヘッダの高さが変わるのも避けられる。
- **ハンドルを持たない行は選べない**(切り替えを出さず、幅だけ残して行頭を揃える)。
  004 REQ-006 はハンドルで対象を指すので、選べても外せない — **選べるのに外れない件数**を
  出すほうが悪い。製品経路では 004 が必ずハンドルを持たせる。
- **端末の戻るでもモードを抜ける**(`PopScope`)。REQ-018 が課すのはヘッダの × だけだが、
  選択モードから戻るの期待は強い。対照は mutation M318。

### 参考designから離れた点

`docs/design/Bulk Renamer.html` は**行に常時 checkbox** を持ち、ヘッダに
`n / m 件を選択`、実行buttonに `対象を選択してください` を持つ。**離れる。**
002 REQ-016(`T03` 承認)で常時の checkbox と件数表示を撤去し、REQ-018(`T27` 承認)で
除去のための一時的なモードへ移したためである。designにこのモードの絵は無いので、
ヘッダの3要素(× / 見出しと件数 / `リネーム候補から外す`)は spec の要求から組んだ。

### machine検証できる範囲と引き受け先

widget testで確かめたのは、代表例 6e〜6j、入口2系統、0 件での実行不可、モード中に
つまみと `カスタム順` が出ないこと、モード中の長押しで並べ替えが始まらないこと、
一覧が空になったときの畳み込み、読み込み直しで消えたハンドルの扱い、戻るでの離脱である。
**CIで閉じられないのは実機の当たり判定・視覚(押しやすさ、文字の大きさ、余白)**で、
これは manual 確認と `T10`(余白・階層・typography)が引き受ける。

## 検証(2026-09-19)

- `flutter test` **PASS(909)**。新規は `test/spec_002_file_list/removal_selection_mode_test.dart`(17件。
  代表例 6e〜6j と、入口2系統・0件・モード中の並び替え・件数の食い違い・戻る)。
- `flutter analyze` PASS / `dart format` PASS。
- `mutation_check.py` は**表全体で 310 件・異常0**。`T28` 周辺へ範囲を絞って回した 37 件は
  **36 KILLED / 1 SURVIVED**で、SURVIVED は既知の `M221`(現行名の行数上限。
  **残余riskとして受容済みで引き受け先は `T10`**)だけである。新規の M305〜M319 はすべて KILLED。
- **実機buildはAI containerで実行できない**(Android SDK 無し)。manual確認が要る。

### 既存testの付け替え

行の × が無くなったので、除去を通っていた test を選択モード経由へ移した
(`file_list_view_test.dart` の REQ-017 系 7件、`spec_004_file_source/ui_entry_test.dart` 1件、
`widget_test.dart` 1件)。**経路は `test/spec_002_file_list/removal_mode.dart` の共通手順に集めた** —
testごとに書き写すと、次に導線が変わったとき一部だけ古い前提のまま残る。

`widget_test.dart` の「全行が外せる」は、`Checkbox` の総数では数えないように直した
(demo の tree には下部バーの更新日時ずらしの checkbox も居る)。**作られた行を列挙して、
その行の checkbox が在るか**を見る形にした。

## Current state / handoff

- Last checkpoint: 実装・test・mutationが揃った(2026-09-19)
- Blocker category: manual(実機確認待ち)
- Waiting for: 独立review と、Android実機での manual 確認
- Requested action: 独立reviewの起動 → PASS後に [`manual-verification.md`](manual-verification.md) を依頼する
- Evidence revision: 未取得(実機証拠はまだ無い)
- Next Agent action: 独立reviewを走らせ、PASSならPRをready化して manual 確認を依頼する
