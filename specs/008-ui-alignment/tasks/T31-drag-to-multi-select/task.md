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

## 2026-09-20 承認と実装順序（上のhandoffを置き換える）

- Last checkpoint: 開発者が REQ-018 の追記と代表例 6k〜6o を文面どおり承認した。製品codeは変更していない。
- Blocker category: user sequencing / T33 manual verification
- Waiting for: T33 の emulator manual verification 結果
- Requested action: なし。開発者から T33 の manual確認完了以外の作業は求めない。
- Evidence revision: 仕様承認checkpoint（未commit）。製品code差分なし。
- Next Agent action: T33 の manual確認完了を受領した後にのみ、T31 の実装を再開する。

## 作業記録（2026-09-20）

- 開発者が REQ-018 の追記と代表例 6k〜6o を承認。T33 の emulator manual verification 完了まで実装を開始しない。

## 2026-09-20 実装再開（上のhandoffを置き換える）

- Last checkpoint: T33 の emulator manual verification が PASS と受領され、承認済み REQ-018 の実装を開始した。製品codeはまだ変更していない。
- Blocker category: none
- Waiting for: なし
- Requested action: なし
- Evidence revision: T33 manual PASS 受領後の実装開始点（未commit）。
- Next Agent action: 行矩形ベースのdrag sessionとedge auto-scrollを実装し、widget testとmutationで検証する。


## 2026-09-20 実装・review handoff（上のhandoffを置き換える）

- Last checkpoint: `55966e7` が長押しの連続経路、開始時候補の保護、実描画行矩形、edge auto-scroll、widget test と Android 実機手順を追加した。`69a3117` が M393〜M395 を mutation 表へ追加した。
- Status: `in_review`。独立 implementation review を依頼する段階であり、Android 実機 manual はまだ行っていない。
- Machine verification scope: widget test は初回/モード中の往復、通常ドラッグ無効、可変行高の edge auto-scroll、lift/bounds を検証した。Android 実機でしか確認できない指の長押し・edge hold・cancel はこの T31 が引き受け、review PASS 後に実施する。
- Verification: `flutter test test/spec_002_file_list/removal_selection_mode_test.dart` PASS (32 tests)、`dart format --output=none --set-exit-if-changed .` PASS、`flutter analyze` PASS、`flutter test` PASS、`workspace.py check specs` PASS。M393〜M395 は scoped `mutation_check.py` で KILLED。
- Waiting for: 独立 implementation review の結果。
- Requested action: なし。
- Next Agent action: review PASS 後、対象 commit を固定して Android 実機 manual を依頼し、結果をこの task へ記録する。


## 2026-09-20 Android 実機 manual 待ち（上のhandoffを置き換える）

- Last checkpoint: 独立 implementation review が `4f7c2c9..fd964da` を PASS と判定した（reviewer: GPT-5 Codex、P0/P1 なし）。製品コード・依存・build 設定は reviewed commit `fd964da` から凍結する。
- Blocker category: external / Android physical-device manual verification
- Waiting for: Android 実機で [`manual-verification.md`](manual-verification.md) の全項目を行った結果。emulator のポインタ操作だけでは指の長押し・端保持の証拠にならない。
- Requested action: `fd964da` の製品コードを対象に Android 実機で manual-verification.md を実施し、端末名/Android 版、各項目の PASS/FAIL、失敗時の再現手順を会話で返す。branch の切替は不要。
- Evidence revision: この後の evidence-only checkpoint は manual 文面とhandoffだけを変え、製品コード・依存・build 設定を変えない。
- Next Agent action: 結果を受領したら証拠metadataを記録し、final reviewへ進む。

### M393〜M395 scoped mutation_check.py の結果

`python3 /home/dev/.agents/skills/asdd/scripts/mutation_check.py /tmp/t31-mutations/mutations.json --root .` は stdout/stderr を出力せず exit status 0 で完了した。出力が無かったため空の code block は保存しない。対象3 mutation は script の終了規約により KILLED と判定した。


## 2026-09-21 Android 実機 manual FAIL と修正再開（上のhandoffを置き換える）

- Last checkpoint: Android physical-device manual は FAIL。端末名/Android 版は受領していないため記録しない。
- Observed failure 1: 上方向へ drag した指がリスト外の header 付近へ入ると auto-scroll が止まる。header へ近づく/越えるほど上スクロールを速くする。
- Observed failure 2: 最下部で最下段を長押しして選択モードへ入ると、下部 rename UI が隠れて viewport が広がり、開始行が画面最下部へ急に移動する。下部 UI を隠す仕様は維持しつつ、開始行の画面上の位置を安定させる。
- Status: `in_progress`。既存の reviewed product code はこの修正の比較基準であり、2件の再現 widget test を先に追加する。
- Machine verification scope: widget test で header 範囲の上方向 auto-scroll と、最下部開始行の位置安定を再現する。Android 実機でしか検証できない指の追従感は修正後のこの T31 が再確認する。
- Waiting for: なし。
- Requested action: なし。
- Next Agent action: 再現testを赤にした後で実装・mutation・回帰検証を行い、manual checklistへ2件を追加する。


## 2026-09-21 修正・review handoff（上のhandoffを置き換える）

- Last checkpoint: `abc39cb` が header 範囲でも続く距離比例 auto-scroll と、選択開始時に隠す下部 rename UI と同じ高さの末尾余白を追加した。`08edfca` が M396〜M397 を追加した。
- Status: `in_review`。製品codeの修正後、Android 実機 manual は未再実施である。
- Verification: `flutter test test/spec_002_file_list/removal_selection_mode_test.dart` PASS (34 tests)。再現testは header を越えた上方向scrollと、最下段開始行の位置安定を検証する。M396〜M397 は scoped mutation_check.py で KILLED。
- Machine verification scope: Android 実機でしか確認できない finger の速度感と位置安定は、この修正後の commit で T31 が再確認する。
- Waiting for: 独立 implementation review の結果。
- Requested action: なし。
- Next Agent action: review PASS 後、修正後 commit を固定して Android 実機 manual を依頼する。

### M396〜M397 scoped mutation_check.py の生出力

```text
command: flutter test test/spec_002_file_list/removal_selection_mode_test.dart
ID | STATUS | FILE | NOTE | DETAIL
--- | --- | --- | --- | ---
M396 | KILLED | lib/ui/file_list/file_list_view.dart | 008:T31 header に入った上方向 drag を viewport 外として停止する。manual FAIL regression test が落とす | exit 1
M397 | KILLED | lib/ui/file_list/file_list_view.dart | 008:T31 選択開始時に消える下部 UI の末尾余白を除く。最下段開始行が下へ跳ぶ | exit 1
2 mutations: 2 KILLED, 0 SURVIVED, 0 SKIPPED
```


## 2026-09-21 修正後 Android 実機 manual 待ち（上のhandoffを置き換える）

- Last checkpoint: 独立 implementation review が exact `ed5d23c..fe9397e` を PASS と判定した（reviewer: GPT-5 Codex、attempt 2、P0/P1/安全網の穴なし）。
- Manual target: `fe9397e` の製品code identity は `abc39cb` である。`abc39cb` 以後の commit は mutation と evidence/handoff だけで、製品code・test・dependency・build 設定を変えない。
- Blocker category: external / Android physical-device manual verification
- Waiting for: Android 実機で [`manual-verification.md`](manual-verification.md) を実施した自由形式の結果。emulator のポインタ操作だけでは finger の長押し、header 外での速度、開始行の位置安定の証拠にならない。
- Requested action: `fe9397e` を対象に Android 実機で manual-verification.md を実施し、観測結果を会話で返す。branch の切替は不要。
- Evidence revision: この後の evidence-only checkpoint は manual 文面とhandoffだけを変え、製品code・test・dependency・build 設定を変えない。
- Next Agent action: 結果を受領したら証拠metadataを記録し、final reviewへ進む。


## 2026-09-21 Android 実機 manual 再FAIL と pointer 所有の修正再開（上のhandoffを置き換える）

- Last checkpoint: Android physical-device manual は再度 FAIL。端末名/Android 版は受領していないため記録しない。
- Observed failure: 15番目付近から先頭まで上へ auto-scroll 後に指を中央/下へ戻しても、選択解除も下方向への反転も起きない。逆方向でも同じ。20番目付近から上へ十分scrollした後は、指を中央/下へ戻しても指を離すまで上scrollが続く。
- Working hypothesis: 長距離 scroll で開始行が offscreen となり `_FileRow` とその GestureDetector が dispose されると move/up/cancel が親へ届かず、親Stateの timer/session が古い pointer と速度を保持する。
- Status: `in_progress`。row の lifecycle に依存しない active pointer 追跡を list 親で持つ。開始行が offscreen になった後の停止・反転・往路候補解除を、上→下と下→上の widget testで先に赤にする。
- Machine verification scope: widget test で長距離往復、既存の header 速度・開始行位置維持・lift/cancel/boundsを検証する。Android 実機でしか確認できない連続 finger drag は修正後の T31 が再確認する。
- Waiting for: なし。
- Requested action: なし。
- Next Agent action: 親Listenerへpointer所有を移した後、mutation・回帰・manual checklist更新を行う。


## 2026-09-21 長距離 pointer 修正・review handoff（上のhandoffを置き換える）

- Last checkpoint: `4e0ea21` が active pointer の move/up/cancel を行の GestureDetector から list 親の Listener へ移した。`d0e2a09` が M398〜M399、`a16bcae` が offscreen 後 cancel regression test を追加した。
- Status: `in_review`。開始行が dispose された後も、上→中央停止→下反転と下→上反転で往路候補を戻せる。
- Verification: `flutter test test/spec_002_file_list/removal_selection_mode_test.dart` PASS (37 tests)。header 距離速度、最下段位置維持、lift/cancel/bounds、offscreen後の両方向反転と解除を含む。M398〜M399 は scoped mutation_check.py で KILLED。
- Machine verification scope: Android 実機での長距離 finger drag と header 外からの反転はこの修正後の T31 が再確認する。
- Waiting for: 独立 implementation review の結果。
- Requested action: なし。
- Next Agent action: review PASS 後、修正後 commit を固定して Android 実機 manual を依頼する。

### M398〜M399 scoped mutation_check.py の生出力

```text
command: flutter test test/spec_002_file_list/removal_selection_mode_test.dart
ID | STATUS | FILE | NOTE | DETAIL
--- | --- | --- | --- | ---
M398 | KILLED | lib/ui/file_list/file_list_view.dart | 008:T31 offscreen開始行後も親Listenerが active pointer のmoveを反映する経路を無効化する。長距離の停止・反転・往路解除が失敗する | exit 1
M399 | KILLED | lib/ui/file_list/file_list_view.dart | 008:T31 offscreen開始行後のpointer upを親Listenerで終えない。lift後のauto-scroll停止が失敗する | exit 1
2 mutations: 2 KILLED, 0 SURVIVED, 0 SKIPPED
```


## 2026-09-21 長距離 pointer 修正後 Android 実機 manual 待ち（上のhandoffを置き換える）

- Last checkpoint: 独立 implementation review attempt 3 が exact `6b1220f..1362afe` を PASS と判定した（reviewer: GPT-6 Codex、related 37 / full 948 PASS、P0/P1/安全網の穴なし、M398〜M399 KILLED）。
- Manual target: 製品code commit は `4e0ea21`。current evidence head は `1362afe` であり、`4e0ea21` 以後は mutation・test・evidence/handoff のみで、製品code・dependency・build 設定を変えない。
- Blocker category: external / Android physical-device manual verification
- Waiting for: Android 実機で [`manual-verification.md`](manual-verification.md) を実施した自由形式の結果。emulator だけでは offscreen 後の連続 finger drag、反転、lift/cancel を証明できない。
- Requested action: current head `1362afe` を対象に Android 実機で manual-verification.md を実施し、観測結果を会話で返す。branch の切替は不要。
- Evidence revision: この後の evidence-only checkpoint は manual 文面とhandoffだけを変え、製品code・test・dependency・build 設定を変えない。
- Next Agent action: 結果を受領したら証拠metadataを記録し、final reviewへ進む。

## 2026-09-21 Android 実機 manual PASS と final-evidence review handoff（上のhandoffを置き換える）

- Last checkpoint: 人間が 2026-09-21 に Android physical-device manual の [`manual-verification.md`](manual-verification.md) 全項目 PASS を報告した。対象 current HEAD は `650448e`、製品code identity は `4e0ea21` である。
- Manual evidence: 通常の往復選択・selection mode 内の開始・edge auto-scroll・edge 離脱/lift/cancel/list bounds での停止・normal mode での並べ替え無効・header 距離比例速度・最下段での選択開始位置安定・開始行が offscreen になった長距離の上→中央停止→下反転/往路候補解除・下→上反転/往路候補解除・offscreen 後の lift/cancel 停止を含む全 checklist 項目が PASS。
- Device metadata: 端末名と Android 版は提供されていないため、捏造せず未記録とする。
- Product identity: `4e0ea21` 以後 current HEAD `650448e` まで、製品code・dependency・build 設定の変更はない。manual 証拠は `4e0ea21` の製品内容に対応する。
- Status: `in_review`。final-evidence review で正本、実機証拠、既存の implementation review と検証結果を照合する。
- Verification: independent implementation review attempt 3 は exact `6b1220f..1362afe` を PASS と判定した（reviewer: GPT-6 Codex、related 37 / full 948 PASS、P0/P1/安全網の穴なし、M398〜M399 KILLED）。
- Waiting for: final-evidence review の結果。
- Requested action: なし。
- Next Agent action: evidence-only checkpoint を基準に final-evidence review を行い、PASS なら統合条件を確認する。
