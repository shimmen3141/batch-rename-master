# T11 契約revision 4の実行経路を実装する

## 目的

005 contract revision 4で新設したREQ-023(再採番)、REQ-024(結果の提示)、REQ-025(常に実在確認)を実装する。**desktopを含む全platformが対象である。**

## なぜこのtaskが要るか

**revision 4を承認した時点で、承認済み契約と実装が食い違う状態が`dev`に生まれた。** `lib/data/rename_exec/desktop_rename_executor.dart`はnativeの排他renameを呼ぶだけで、REQ-025が求める実在確認をしていない。005のtaskはT01〜T09すべて`done`で、013の他のtaskはいずれもこの範囲を持たない。

**契約を先に承認し、実装するtaskを作らないまま進める形が一度できていた**(013:T02のreview attempt 2で同型の指摘)。ここで閉じる。

## 入力と依存

- `T04`で承認された005 contract revision 4(REQ-023、REQ-024、REQ-025、OP-001、OP-002、INV-002、INV-003、用語「占有名」「生存名」「確認した目標名」「再採番」)。
- 001の自動解決規則(` (n)`、先頭出現は据え置き、最小の非衝突n)。**001に「任意の名前集合に対する次候補を返す」操作は無い**ので、追加が要る(001 specとcontractの改訂を伴う)。
- 現行実装: `lib/data/rename_exec/`、`test/spec_005_rename_exec/`。

## 変更範囲

- **001**: 生存名を受け取って次候補名を返す操作。純粋Dartのまま。
- **005 実行orchestration**: `OP-001`へ`occupiedNames`、`OP-002`へ`occupiedNames`と`renumber`を通す。生存名の組み立て(5要素)は`execute`が持つ。
- **再採番のループ**: `nameConflict` → 次候補 → 再試行。試行上限と、`renumber`が`null`を返したときの失敗記録。
- **一時名・復旧改名・巻き戻しでは再採番しない**(REQ-023)。**利用者が確認していない名前を内部ステップで作らない。**
- **結果の提示**(REQ-024): 再採番された項目が「確認した名前と異なる」と分かる形。
- **改名ポート**(REQ-025): **常に**実在確認してから改名し、原子的no-replaceがあれば併用する。desktopとAndroidの両方。

## 決めること

- **再採番の試行上限**(contract `open_questions` OQ-001)と、上限に達したときの提示文言。
- **`renumber`が`null`を返す条件**(候補が尽きる場合があるか)。

## 受け入れ証拠

- 005 spec.mdの例24・26・28・29・30に対応するtestがある(VER-008)。
- **一時名への改名と復旧改名で再採番が起きない**ことをtestで検査する。**片方向だけでは足りない** — 再採番する側としない側の両方を固定する。
- **desktopで実在確認が行われる**ことをtestで検査する(REQ-025。現状の実装は満たしていない)。
- 生存名の5要素すべてが再採番の照合に効くことをtestで検査する。**特に「すでに確定した結果名」**(review attempt 2のP1-2)。
- 005の既存contract testが継続PASSする。
- `flutter test` / `flutter analyze` / `dart format --output=none --set-exit-if-changed .` がPASS。
- exact rangeの独立reviewがPASSする。

## 作業記録

- 2026-08-14 / `T04`のreview attempt 2のP1-5を受けて定義。**REQ-023〜025を所有するtaskが無く、承認済み契約を誰も実装しない状態だった。**

## Current state / handoff

- Last checkpoint: 定義しただけ。未着手
- Blocker category: dependency
- Waiting for: `T04`(005 contract revision 4)のreview PASSとmerge
- Requested action: なし
- Evidence revision: `dev@4fd6ab1` + 005 contract revision 4(approved 2026-08-14)
- Next Agent action: `T04`のmerge後に着手する。**`T10`(事前検出)と範囲が隣接するので、どちらが先かを決めてから始める**
