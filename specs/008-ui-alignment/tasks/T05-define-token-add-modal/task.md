# T05 token追加の確定手順を定義する

## 目的

tokenを「既定値で即追加してから編集」から「modalで設定を終えてから追加」へ変える仕様を、003 specへ書いて人間の再承認を得る。実装は`T06`が行う。

## 入力と依存

- `specs/product-map.md`「008へ引き継いだ人間の決定(planへ反映済み)」の(f)。原文は凍結discoveryの46行。
- 現行の003 spec のtoken追加REQ。
- 現行実装: `lib/ui/rule_builder/rule_builder_view.dart`の追加button、`lib/ui/rule_builder/token_editors.dart`。

## 変更範囲

- `specs/003-rule-builder/spec.md`のtoken追加に関するREQの更新。
- このtaskでは実装もtestも変えない。

## 決めること

- modalをcancelしたときtokenが追加されないこと(現行は既に追加済みなので取り消しの意味が違う)。
- 既存tokenの編集はどうするか。追加と同じmodalを使うのか、現行のtapで開く編集を残すのか。
- 設定を終えずに閉じられない項目(必須項目)があるか。連番の桁数、日時のフォーマットなど。
- 追加直後のpreview反映のタイミング。

## 受け入れ証拠

- 003 specの更新差分が、上記の決めることすべてに答えている。
- 更新後のspecが**人間により再承認**される。
- 承認されたREQ IDを、実装task **T06**の`task.json`の`covers`へ書く。`covers`は現在空で、REQが確定するのはこのtaskの承認時である。**ここで埋めないと空のまま`done`になる。**
- `python <asdd-plugin>/scripts/workspace.py check specs`がPASS。

## 作業記録

- 2026-08-12 / plan作成時に定義。実装(`T06`)はこのtaskの承認を待つ。

## Current state / handoff

- Last checkpoint: plan作成時に定義しただけ。未着手
- Blocker category: なし
- Waiting for: なし
- Requested action: なし
- Evidence revision: `dev@ea1dd04`
- Next Agent action: 現行003 specと実装を読み、「決めること」への案を作って人間へ一度に示す
