# T45 ルール構築シート(ボトムシート)を参考デザインへ整える

## 目的

狭幅で下部の「命名ルール」から開くルール構築シート(`RuleBuilderWorkspace._openRuleSheet` → `RuleBuilderView`)を、参考デザイン`docs/design/Bulk Renamer.html`のボトムシートへ整える。広幅の2ペインの右側(同じ`RuleBuilderView`)への影響も着手時に決める。

## 出所

`T44`の範囲の決定(2026-09-29)で分けた。開発者の原文と、画面①②の対応表は[`T44`の task.md](../T44-token-editor-presentation/task.md)の「範囲の決定」にある。

## 境界

- `T44`がトークンの設定(①の上に開く中央のダイアログ)を持つ。このtaskは入れ物のシートと、その中のトークンの並び・追加ボタン・閉じ方を持つ。
- `T14`は実行前の確認ダイアログだけを持つ(表の4は、このtaskへ移した)。
- 取り込まないもの: プリセット(将来候補`009`)。003 REQ-001〜012(`RuleController`の操作、確定手順)は変えない。

## 受け入れ証拠(着手時に具体化する)

- widget test(003 REQ-008〜012を失っていないこと、狭幅・広幅)、full test・analyze・format。
- Androidエミュレータでの手動確認(`manual-verification.md`を着手後に作る)。

## 作業記録

着手は Claude Opus 5.5(2026-09-29)。branch `asdd/008-ui-alignment/T45-rule-sheet-presentation`、起点`dev`@`8d65b0c`。

土台(`docs/design/Bulk Renamer.html`、`sheetOpen` / `sheetView == 'build'`)と今の実装(`RuleBuilderWorkspace._openRuleSheet` → `RuleBuilderView`)の違い:

| 要素 | 土台 | 今の実装 |
|---|---|---|
| シートの枠 | 取っ手、見出し「命名ルール」、「閉じる」、上端の角丸22、暗い背景(#101216) | 見出しなし(トークンの列と追加ボタンだけ) |
| トークンの並び | 点線の枠の中で**折り返して複数行**、ドラッグで並び替え、枠の中に「タップで設定 / ドラッグで並び替え」 | **横1列でスクロール**、左端のつまみで並び替え |
| チップ | 種類ごとの色(区切り=黄、元名=灰、テキスト=シアン、連番=緑、日時=紫)。上段に小さな種類名と×、下段に**1件目のファイルでの値**(`01`、`旅行_`、`[元のファイル名]`) | 同じ色のチップに説明(`連番(2桁)`、`日時 YYYYMMDD`)とつまみと× |
| 追加ボタン | 枠線だけの控えめなボタン | 塗りのボタン |
| プレビュー | 下部に「プレビュー（1つ目のファイル）」: 元の名前(取り消し線)→ 新しい名前(緑)、変わらなければ「（変更なし）」 | なし |
| プリセット | 「保存ルールを呼び出す」「現在のルールを保存」 | なし(取り込まない。将来候補`009`) |

`RuleBuilderView`は広幅の2ペインの右側でも使う。チップの文字(`tokenLabel`)を頼りにするtestが多い。

## Current state / handoff

- Last checkpoint: 土台と今の実装の違いを洗い出した(2026-09-29)。
- Blocker category: human decision
- Waiting for: 開発者: 土台のどの要素を取り込むか
- Requested action: 会話で選ぶ
- Evidence revision: 起点`dev`@`8d65b0c`
- Next Agent action: 選ばれた要素を適用範囲としてこのtask.mdへ書き、失敗するwidget testから実装する
