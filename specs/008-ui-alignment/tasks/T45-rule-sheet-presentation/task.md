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

## Current state / handoff

- Last checkpoint: 登録しただけ(2026-09-29)
- Blocker category: none
- Evidence revision: none
- Next Agent action: `T44`のmerge後、参考デザインのシート(`sheetView == 'build'`)の構成を読み取り、適用範囲と離れる点をこのtask.mdへ書く
