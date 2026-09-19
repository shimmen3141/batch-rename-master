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
- Android実機での manual 確認([`T30` の手順書](../T30-selection-bar-height-and-hint/manual-verification.md)へまとめた)(どちらも同じ画面の見せ方で、
  実機での確認項目は数個ずつである)。

## 実装(2026-09-19)

### 決めたこと

- **`ReorderableListView.proxyDecorator` を与えた。** 掴んでいる間だけ差し替わる木を
  そこで作れるので、行側に「掴まれているか」の状態を持たせずに済む。
- **色は `surface`**(ヘッダ・帯と同じ面の色)。要望の「文字が読める程度の灰色
  (ヘッダーの色とか)」そのままである。行の面は通常 `null`(背景が透ける)なので、
  ここを敷くと掴んだ行だけが持ち上がって見える。**token は足していない。**
- **選択モードの選択行(`selectedSurface`)とは別の色である**ことを test で固定した。
  モード中はつまみを出さない(002 REQ-018)ので同時には起きないが、**同じ色なら
  「掴んでいる」と「選んでいる」が読み分けられない** — `008:T29` で分けた区別が戻る。
- **影は既定と同じように上げる。** 面の色を**足すだけ**にして、浮き上がりという
  手掛かりを減らさない(対照は M358)。
- **`008:T30` と同じ branch・同じ PR に載せた。** 同じ画面の見せ方で、実機での確認は
  数項目ずつなので**manual確認を1回にまとめる**ためである(rollback の境界も同じ)。

## 検証(2026-09-19)

- `flutter test` **PASS(925)**(`T32` で1本追加) / `flutter analyze` PASS / `dart format` PASS。
- `mutation_check.py`: **M355 / M357 / M358 を追加**(表は348件、find の一致は全件1回)。

### mutation の生出力

```
command: flutter test test/spec_002_file_list
M355 | KILLED | 掴んだ行を選択モードの選択行と同じ色にする
M357 | KILLED | 掴んだ行の面を染めない
M358 | KILLED | 浮き上がりを消す
3 mutations: 3 KILLED, 0 SURVIVED, 0 SKIPPED
```

- **実機buildはAI containerで実行できない**(Android SDK 無し)。manual確認が要る。

## 独立review(2026-09-19)

`T30` と同じ範囲(`dev...07c218f`)をまとめて見た — 結果と生出力は
[`T30` の task.md](../T30-selection-bar-height-and-hint/task.md#独立review2026-09-19)にある。
**PASS。成果物の欠陥は0件。**

`T32` に対して reviewer が確かめた点: 掴んだ瞬間に色が付く(animate するのは elevation だけ)、
`selectedSurface` とは実値も別、`reorder → custom` の自動切替は無改変、
**掴む(つまみ)と選ぶ(モード)はコード構造上同時に起こり得ない**
(`selecting` 中は `ReorderableDragStartListener` 自体を出さない)。
reviewer の対照 `M362`(既定の長押しドラッグを戻す)を表へ取り込み、KILLED を確認した。

## Current state / handoff

- Last checkpoint: 独立review attempt 1 が PASS した(`T30` と同じ範囲。2026-09-19)
- Blocker category: manual(実機確認待ち)
- Waiting for: Android実機での manual 確認
- Requested action: [`T30` の手順書](../T30-selection-bar-height-and-hint/manual-verification.md)の手順3
- Evidence revision: 未取得(実機)
- Next Agent action: `T30` とまとめて結果を受け取り、成立していればmergeする
