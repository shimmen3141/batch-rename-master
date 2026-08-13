# T03 選択と除去の振る舞いを定義する

## 目的

「rename対象の選択」と「一覧からの除去」の役割重複を解消する仕様を、002/004 specへ書いて人間の再承認を得る。実装は`T04`が行う。

## 入力と依存

- `specs/product-map.md`「008へ引き継いだ人間の決定(planへ反映済み)」の(g)。原文は凍結discoveryの47行。
- 現行の002 spec REQ-004(`toggleSelection`/`selectAll`/`clearAll`)、**REQ-009**(`removeFile`/`clearFiles`)。004 spec REQ-006。
- 現行実装: 行の×(`file_list_view.dart`の`removeFile`)、読み込みbarの「すべて外す」(`lib/ui/file_source/file_source_bar.dart`)。

## 変更範囲

- `specs/002-file-list/spec.md`と`specs/004-file-source/spec.md`の**提示に関するREQ**の更新。
- **状態層のAPIは残す**。`removeFile`/`clearFiles`は引き続き必要で、変えるのは提示の仕方である。
- このtaskでは実装もtestも変えない。

## 決めること

- 行の×を廃止し、除去を左swipeへ移す。swipeが使えない環境(desktop、accessibility)での代替をどうするか。
- 「すべて外す」を何という名前にするか。checkboxの全解除(`clearAll`)と、一覧を空にする(`clearFiles`)が別物であることが名前から分かる形にする。
- checkboxを外した行はrename対象から外れ**連番も飛ばさない**(001 REQ-006)ため除去とほぼ同じ目的を果たす、という前提をspecへ残すか。
- 誤って除去したときの取り消しを提供するか(005のundoは改名の巻き戻しで、一覧からの除去とは別)。

## 受け入れ証拠

- 002/004 specの更新差分が、上記の決めることすべてに答えている。
- 更新後のspecが**人間により再承認**される。
- 状態層のREQ(002 REQ-009 / 004 REQ-006)が意味を変えていないことが差分から読める。
- 承認されたREQ IDを、実装task **T04**の`task.json`の`covers`へ書く。`covers`は現在空で、REQが確定するのはこのtaskの承認時である。**ここで埋めないと空のまま`done`になる。**
- `python <asdd-plugin>/scripts/workspace.py check specs`がPASS。

## 作業記録

- 2026-08-12 / plan作成時に定義。実装(`T04`)はこのtaskの承認を待つ。

## Current state / handoff

- Last checkpoint: plan作成時に定義しただけ。未着手
- Blocker category: なし
- Waiting for: なし
- Requested action: なし
- Evidence revision: `dev@ea1dd04`
- Next Agent action: 現行002/004 specと現行実装を読み、「決めること」への案を作って人間へ一度に示す
