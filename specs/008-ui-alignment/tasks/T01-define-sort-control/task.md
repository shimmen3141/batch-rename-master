# T01 並び順controlの振る舞いを定義する

## 目的

並び順の提示と手動並び替えの可否について、002 specを更新して人間の再承認を得る。実装は`T02`が行う。

## 入力と依存

- `specs/product-map.md`「008へ引き継ぐ人間の決定」の(e)。原文は凍結discoveryの45行。
- 現行の002 spec REQ-002(sort key)、REQ-003(`reorder`で`custom`へ)、**REQ-014**(連番が無いとき手動並び替えとcustomを隠す)。
- `docs/design/Bulk Renamer.html`の並び順control。

## 変更範囲

- `specs/002-file-list/spec.md`のREQ更新。**REQ-014の廃止**と、昇順・降順の扱い、`custom`の位置づけ。
- 002のVER表の対応更新。
- このtaskでは実装もtestも変えない。

## 決めること

- **REQ-014の廃止**。連番の有無に関わらず手動並び替えを提示する。廃止の理由(連番が無くても並び替えようとするのは自然。隠すと「どのchipも選択されていない」状態が生まれる)をspecへ残す。
- 昇順・降順を各sort keyへ持たせるか。現行は「昇順固定(MVP)・昇降トグルは将来」と決めていた。
- `custom`をsort keyの一つとして持つのか、手動並び替えの**結果を示す状態**として持つのか。controlの表示が「⇅ 並び順: カスタム」へ変わる挙動をどうREQで表すか。
- 002 REQ-011/013(作成日時ソート時だけ強調)が、昇降やcustomの追加で影響を受けないか。

## 受け入れ証拠

- 002 specの更新差分が、上記の決めることすべてに答えている。
- 更新後のspecが**人間により再承認**される(現在approved。2026-08-01承認 / 2026-08-05再承認)。
- 既存のVER-001/002が新しいREQをどう被覆するかがVER表から読める。
- `python <asdd-plugin>/scripts/workspace.py check specs`がPASS。

## 作業記録

- 2026-08-12 / plan作成時に定義。実装(`T02`)はこのtaskの承認を待つ。

## Current state / handoff

- Last checkpoint: plan作成時に定義しただけ。未着手
- Blocker category: なし
- Waiting for: なし
- Requested action: なし
- Evidence revision: `dev@ea1dd04`
- Next Agent action: 現行002 specと参考designを読み、「決めること」への案を作って人間へ一度に示す。承認後に`T02`へ進む
