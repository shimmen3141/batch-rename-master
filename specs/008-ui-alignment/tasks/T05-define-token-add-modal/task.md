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

## 決めることへの答え(改訂案。承認待ち)

正本は [`003 spec`](../../../003-rule-builder/spec.md) の REQ-008〜REQ-012・代表例6〜12・
「決定済み事項」。ここへは対応だけを置き、要件文を書き写さない。

| 決めること | 答えの置き場所 |
|---|---|
| cancelしたときtokenが追加されない | REQ-009(確定以外の**すべての**閉じ方)。**開いているあいだ変更通知も起きない**ことを REQ-008 に置いた |
| 既存tokenの編集 | REQ-011(追加と同じ種別のエディタを現在値で開き、確定時だけ差し替える)。現行実装は既にこの形 |
| 確定できない入力(必須項目) | REQ-012(自由テキスト・区切りの空、日時フォーマットの空。連番は範囲外を入力できない) |
| 追加直後のpreview反映のタイミング | REQ-008(**確定したときに初めて**反映。エディタ内の表示例は自由) |
| (追加で出た論点)設定項目の無い「元の名前」 | REQ-010(エディタを開かず即追加)。**2026-09-14 開発者決定** |

### 参考designから離れた点

参考designの `addToken` は**押した瞬間に既定値のtokenを列へ入れてからdialogを開き**、
キャンセルで開く前の列(snapshot)へ戻す。**この形を仕様にしなかった。** 途中で列が変わると
007 の `PersistentRuleController` が変更通知ごとに保存するので、dialogを開いたままアプリが
落ちると既定値のtokenが前回ルールとして残る。002 のプレビューも途中の値で描き直される。
**終状態だけでは区別できない**ので、REQ-008 は「開いているあいだ変更通知が起きない」を要求する。

また参考designは「元のファイル名」でもdialogを開く(大小変換の選択肢を持つため)。001 は
大小変換を持たないので、開発者決定により即追加とした(REQ-010)。

### 着手時に観測した仕様と実装の食い違い

改訂前の003 spec「決定済み事項」は自由テキストを「非空を確定して初めて挿入」と定めていたが、
実装(`lib/ui/rule_builder/token_presets.dart` の `defaultTokenFor`)は `LiteralToken('テキスト')` を
即挿入していた。REQ-008 がこの約束を全種別へ広げるので、**直すのは `T06`**。

## 作業記録

- 2026-08-12 / plan作成時に定義。実装(`T06`)はこのtaskの承認を待つ。
- 2026-09-14 / claim。003 spec へ REQ-008〜REQ-012 と代表例6〜12を足した改訂案を書いた。
  「元の名前」の扱いだけ開発者へ確認し、即追加と決まった。

## Current state / handoff

- Last checkpoint: 003 spec の改訂案を書いた(2026-09-14)
- Blocker category: human-approval
- Waiting for: 003 spec 改訂案(REQ-008〜REQ-012)の開発者による再承認
- Requested action: 改訂案を読み、承認するか修正点を返す
- Evidence revision: branch `asdd/008-ui-alignment/T05-define-token-add-modal`(`dev@b833603` から作成)
- Next Agent action: 承認を受けたら spec の Status を戻して承認日を記録し、`T06` の `covers` へ `003:REQ-008`〜`003:REQ-012` を書き、独立reviewを起動する
