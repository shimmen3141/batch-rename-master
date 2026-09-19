# T32 並び替えのドラッグ中の行を見分けられるようにする

## 目的

つまみを長押しして**並び替えが始まった行**を、色で見分けられるようにする。いま「掴めたのか
どうか」が分からないまま動かすことになっている。

## 受領した要望(2026-09-19、原文)

`008:T29` の実機確認で受領した5件のうちの1件である。

> - ドラッグ用のつまみを長押ししてドラッグ可能になったら、ファイル行の色を変えてほしい。文字が読める程度の灰色(ヘッダーの色とか)がよさそう。

「ヘッダーの色」は読み込み帯・一覧ヘッダの面の色(`AppColors.surface`)を指す。

## 変更範囲

- [`lib/ui/file_list/file_list_view.dart`](../../../../lib/ui/file_list/file_list_view.dart)
  の `ReorderableListView.builder`。**`proxyDecorator` を与える**のが素直で、
  掴まれている間だけ差し替わる widget をそこで作れる。既定の `proxyDecorator` は
  `Material` の elevation を上げるだけなので、**面の色も指定する**。
- 色は `AppColors` のセマンティック名で参照する(UI側の規約)。`surface` で足りるか、
  行の背景との対比が足りずに token を足すかは実装時に見る。

## 先に決めること

- **選択モード中との関係。** モード中はつまみを出さない(002 REQ-018)ので**同時には起きない**。
  それでも「選択行の面(`selectedSurface`)」と「掴まれた行の面」が同じ色にならないようにする
  — 別々の状態が同じ見た目になると、`T29` で分けたばかりの区別が戻る。
- **影(elevation)を残すか。** 既定の挙動を丸ごと置き換えると浮き上がりが消える。
  **面の色を足すだけ**にして、掴まれていることの手掛かりを減らさない。
- **文字が読めること**が要望の条件である。面を変えたとき、現在名・変更後名・警告の
  いずれも背景との対比が落ちないことを見る(変更後名は緑、警告は赤)。

## 気をつけること

- **`T29` の実機確認 手順5(つまみを1秒ほど押したままドラッグして並び替えられる)を壊さない。**
- `T01` → `T02` が 002 REQ-014 を廃止して**つまみを常時出す**ようになっても、この見せ方は
  そのまま成立する(掴まれたかどうかの提示であって、つまみを出す条件とは独立である)。
- **`T30` / `T31` と同じ file を触る。** 直列に進める。

## 入力と依存

- [`T29`](../T29-selection-mode-presentation/task.md)(`merge` 済み)。
- `lib/ui/file_list/file_list_view.dart`、`lib/ui/theme/app_colors.dart`。
- `specs/002-file-list/spec.md` REQ-003 / REQ-014 / REQ-018。
  **REQ の改訂は要らない** — 並び替えの振る舞いは変えず、提示だけを足す(002 は視覚デザインを
  非規範としている)。

## 受け入れ証拠

- 掴まれている間だけ行の面の色が変わる(widget test。`proxyDecorator` が返す木を見る)。
- 掴んでいないときの行の見た目が変わらない。
- **選択モードの選択行の色とは別の色である。**
- 並び替えの結果(`reorder` → `custom` へ自動切替)が変わらない(既存testが緑のまま)。
- `flutter test` / `flutter analyze` / `dart format` / `mutation_check.py` が PASS。
- Android実機での manual 確認 — **`T30` と同じ回にまとめる**(どちらも同じ画面の見せ方で、
  実機での確認項目は数個ずつである)。

## Current state / handoff

- Last checkpoint: `T29` の実機確認で受領した1件をtask化した(2026-09-19)
- Blocker category: none
- Waiting for: なし
- Requested action: なし
- Evidence revision: 未着手
- Next Agent action: 着手時に `proxyDecorator` で面の色を足し、選択行の色と別であることを
  test で固定する
