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

## Current state / handoff

- Last checkpoint: `T27` で 002 spec が承認され、実装taskとして起票した(2026-09-19)
- Blocker category: none
- Waiting for: なし
- Requested action: なし
- Evidence revision: 未着手
- Next Agent action: 現行の行widgetとヘッダを読み、選択モードの状態の置き場所(controller か widget か)を
  決めてから、代表例 6f〜6j の test を先に書く
