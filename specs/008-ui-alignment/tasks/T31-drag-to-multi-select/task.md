# T31 長押ししたままドラッグして複数選択する

## 目的

除去のための選択モード(002 REQ-018)で、**長押しした指を離さずに他の行へ動かすと、
通過した行も選択される**ようにする。1件ずつ tap する手間を減らす。

## 受領した要望(2026-09-19、原文)

`008:T29` の実機確認で受領した5件のうちの1件である。

> - 一つのファイル行を長押しした後、そのままほかの行にドラッグで複数選択できるようにしたい。

## これは仕様の追加である

**002 REQ-018 は「行の長押しで入る」「モード中は各行が選択の切り替えを提示する」までしか
定めていない。** 長押しから続くドラッグで複数選択するのは**新しい観測可能な振る舞い**なので、
文言・配色のような非規範の範囲には収まらない。

- **REQ-018 へ追記し、開発者の再承認を取る。** 追記は「(c) 長押しから指を離さずに一覧を
  なぞると、通過した行も選択候補に加わる」という趣旨になる。
- **代表例を足す**(6f 系列の続き)。少なくとも「a を長押しして b・c までなぞる → 3件が選択」
  「なぞっている途中で戻る → どうなるか(下の決めること)」の2つ。
- **並び替え(REQ-003 / REQ-014)との衝突は起きない** — モード中はつまみを出さないと
  REQ-018 が定めており、`ReorderableListView` も `buildDefaultDragHandles: false` で
  **行の長押しドラッグを既に切ってある**(`file_list_view.dart` の注記)。
  この「切ってあること」がこのtaskの前提でもある。

## 先に決めること(仕様の文面を書く前に)

- **なぞって戻ったときの扱い。** (a) 通過した行は**加えるだけ**(戻っても外れない) /
  (b) 起点の選択状態を反転させる方向へ**塗る**(Android の Files app 系の挙動) /
  (c) 戻ると外れる。
  **推奨は (a)** — 指が震えて意図せず外れる事故が起きず、外したい行は指を離してから
  tap すればよい。REQ-018 の「選択は外す候補であり、やめれば一覧は変わらない」ので
  取り返しがつく。
- **すでに選択済みの行を長押しした場合**の起点。加えるだけなら変化しない。
- **画面端での自動スクロール**を行うか。行うと「見えていない行まで選ばれる」ので、
  **既定は行わない**(見えている範囲だけ)。要るなら別の観測可能な振る舞いとして足す。
- **長押しで入った直後のドラッグと、モード中の行からのドラッグ**を同じ扱いにするか
  (**同じにするのが素直**)。

## 気をつけること

- **モードに入っていないときの長押しドラッグを増やさない。** 通常表示で行をなぞって
  何かが選ばれると、REQ-016(通常表示は選択の概念を出さない)と衝突する。
- **つまみの長押しドラッグ(並び替え)を壊さない。** `T29` の実機確認 手順5 が成立した経路で、
  `T32` も同じ場所を触る。
- gesture の test は widget test で書ける(`TestGesture` で down → moveTo → up)。
  **「なぞった」ことを本当に見ているか**を mutation で確かめる(通過判定を外しても
  落ちない test になりやすい)。
- 行の高さは可変である(警告の有無・場所の表示・文字倍率)。**固定の行高で位置を計算しない。**

## 入力と依存

- [`T29`](../T29-selection-mode-presentation/task.md)(選択モードの現在の作り。`merge` 済み)。
- `lib/ui/file_list/file_list_view.dart`、`lib/ui/file_list/removal_selection.dart`。
- `specs/002-file-list/spec.md` REQ-016 / REQ-018、代表例 6f〜6j。
- **`T30` / `T32` と同じ file を触る。** 直列に進める(並行させない)。

## 受け入れ証拠

- REQ-018 の追記が**開発者の再承認を得ている**(spec の Status 行に記録する)。
- 追加した代表例が widget test で成立する。
- **通常表示では行をなぞっても何も選ばれない。**
- つまみの長押しドラッグで並び替えられることが変わらない(既存testが緑のまま)。
- `flutter test` / `flutter analyze` / `dart format` / `mutation_check.py` が PASS。
- Android実機での manual 確認(`manual-verification.md` を作る) — **指の操作なので
  emulator だけでは足りない**。

## 調査checkpoint (2026-09-20、仕様判断前)

観測可能な振る舞いはまだ変更していない。現行実装と Flutter 3.44.6 のgesture APIを
照合し、次を確認した。

- 行の長押しは `_FileRow` の preview・名前領域にある `GestureDetector` だけが受け、
  右端の並び替えつまみは別のpointer経路にある。この境界を保ったまま
  `onLongPressStart` / `onLongPressMoveUpdate` / `onLongPressEnd` を足せる。
- `onLongPressMoveUpdate` は起点の行から外れた後もglobal座標を渡す。ただし移動eventが
  行ごとに来る保証はない。aからcへ一度に動いた場合もbを「通過」と数えるには、固定行高で
  indexを推測せず、実際に描画された各行の矩形と直前座標からの線分を照合する必要がある。
- 画面外の行は描画されていないため、自動scrollを足さなければ自然に「見えている行だけ」が
  対象になる。`T31`では自動scrollを足さない既定と両立する。
- 現行の `RemovalSelection.toggle` は最後の1件を外した瞬間にモードを抜ける。このため、
  起点が選択済みなら外す案はgesture中だけ0件を許すsession APIが必要で、加えるだけの案より
  状態遷移が広い。

選択肢の観測結果と実装・検証への影響は次のとおり。

| 案 | a→b→c→b の結果 | 選択済み行から開始 | 実装・検証への影響 |
|---|---|---|---|
| (a) 加えるだけ(推奨) | a,b,c のまま | その行を保ち、通過した未選択行だけ加える | idempotentな`mark`を足せばよく、指の震えで候補を失わない。現行の0件自動解除を変えない |
| (b) 起点の状態と逆へ塗る | 戻っても一度塗った状態を保つ | 起点が未選択なら通過行を選択、選択済みなら通過行を解除 | まとめて解除できるが、最後の1件から始めてもdragを続けるため、gesture終了まで0件自動解除を遅延する必要がある |
| (c) 戻った分を外す | cだけ外れ、a,b が残る。aまで戻ればb,cが外れる | gesture前から選択済みの行は保護し、このgestureで加えた行だけ戻り時に外す | 現在の軌跡とgesture開始時snapshotを持つ。分岐・飛び越しも含む経路testが必要で、3案中もっとも複雑 |

判断後の最小checkpointは、(1) REQ-018と代表例を選択案・見えている範囲・通常表示では
無効という文面で更新、(2) 実描画矩形に基づくgesture sessionとwidget test、(3) mutation・
関連/全体回帰・独立review・Android実機確認、の3つである。

既存Issue/PRは無い。実装では `file_list_view.dart`、`removal_selection.dart`、
`removal_selection_mode_test.dart`、002の`spec.md`、T31のmanual、`tool/mutations.json`を
触る見込みである。T33とは製品code・specが分かれるが、`tool/mutations.json`だけは統合時に
競合しうる。

## Current state / handoff

- Last checkpoint: 現行gesture経路、Flutter 3.44.6の長押し移動API、3案の状態遷移と
  test境界を調査し、既存の関連widget test 28件がPASSする基準点を得た(2026-09-20)
- Blocker category: product decision / spec approval
- Waiting for: 開発者
- Requested action: 「なぞって戻ったとき」を (a)加えるだけ / (b)起点の逆へ塗る /
  (c)戻った分を外す、のいずれにするか選ぶ。推奨は(a)
- Touches: `lib/ui/file_list/file_list_view.dart`(行のgesture)、`removal_selection.dart`、
  `specs/002-file-list/spec.md`(REQ-018 の追記。**再承認が要る**)
- 並行: **`T34` とは別file**なので同時に進められる。`T33` / `T35` とも別。
  ただし `tool/mutations.json` はどのtaskも触るので、**同時に走らせるとここだけ衝突しうる**
- Evidence revision: `0e5fac8` + working treeの調査記録(製品code・spec差分なし)
- Next Agent action: 選択を受領したら、見えている範囲だけ・通常表示では無効・モード中の
  行から始めても同じ規則、を含むREQ-018追記と代表例を確定し、実装へ進む

## 作業記録

- `python3 /home/dev/.agents/skills/asdd/scripts/workspace.py check specs` — PASS
  (8 plans, 88 tasks)
- `gh pr list --state open --head asdd/008-ui-alignment/T31-drag-to-multi-select ...` — `[]`
- `gh issue list --state open --search 'T31 drag multi select in:title' ...` — `[]`
- `flutter test test/spec_002_file_list/removal_selection_mode_test.dart` — PASS (28 tests)
- Flutter SDK sourceで `GestureDetector.onLongPressStart` / `onLongPressMoveUpdate` /
  `onLongPressEnd` が利用可能であることを確認(Flutter 3.44.6)

## 2026-09-20 更新（上の未決定事項とhandoffを置き換える）

- Last checkpoint: 開発者の決定(c)と画面端自動スクロールを、REQ-018の正確な追記案と代表例 6k〜6oへ文面化した。製品codeは変更していない。
- Requested action: 002-file-list/spec.md の更新済み REQ-018 追記案と代表例 6k〜6o を承認する。
- Evidence revision: 仕様承認checkpoint。製品code差分なし。
- Next Agent action: 再承認を受領したら、実際の行矩形を使うdrag session、自動scroll、widget test、mutation、manual確認を実装する。

- 開発者が「戻った分を外す」と画面端の自動スクロールを決定。REQ-018の正確な追記案と代表例6k〜6oを記録し、再承認待ちへ更新（製品code変更なし）。
