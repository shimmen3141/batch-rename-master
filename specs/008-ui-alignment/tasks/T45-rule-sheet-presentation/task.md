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

## 範囲の決定(2026-09-29、開発者)

取り込む要素を尋ねた(複数選択)。回答(原文): 「シートの枠と追加ボタン, シート内プレビュー, チップの色分けと中身, 　「閉じる」ボタンは逆に混乱を招きそうなので不要です。「折り返して並べる」については、点線の枠内で横にスクロールできるようにします。その枠内でドラッグによる並び替えができるようにしたいです。」

- **取り込む**: シートの枠(取っ手・見出し「命名ルール」・上端の角丸)、枠線だけの追加ボタン、シート下部のプレビュー、チップの色分けと中身(種類名 + 一覧の1件目での値)、点線の枠。
- **取り込まない**: 「閉じる」ボタン(開発者: 逆に混乱を招く)、折り返し(横スクロールのまま)、プリセット(将来候補`009`)。
- **並べ替え**: 点線の枠の中でドラッグ(横スクロールのまま)。

## 土台から離れた点と理由

- **「閉じる」ボタン無し**(開発者の決定)。閉じ方は外のタップ・下へのスワイプ・戻る操作。
- **折り返さず横スクロール**(開発者の決定)。
- **並べ替えは長押ししてから動かす**: 土台はブラウザのドラッグ。タッチでは押してすぐの横移動を枠のスクロールに使うので、長押しで区別する(`ReorderableDelayedDragStartListener`)。手掛かりの文言も「タップで設定 / **長押し**で並び替え」。
- **文字列の種類名**: 土台はトークンが区切り / テキストの種類を持つ。003 の`LiteralToken`は入口を持たない(REQ-011)ので、値が区切りのプリセットなら「区切り」(黄)、それ以外は「テキスト」(シアン)。
- **日時の種類名**は土台と同じく基準の名前。1件目の日時が不明なら値は「不明」(001 INV-006)。1件目が無いときは値にフォーマットそのものを出す(土台は空)。
- **色**: チップの色は土台の色相をそのまま使う(`lib/ui/theme/token_colors.dart`。意味の色ではなく種類を見分けるための色)。シートの面は`AppColors.surface`(土台は`#101216`で近い)。
- **広幅**: `RuleBuilderView`を2ペインでも使うので、チップと点線の枠は広幅も同じ見た目になる。見出しとプレビューはシートだけ(広幅は左に一覧が見えている)。

## 作業記録

着手は Claude Opus 5.5(2026-09-29)。branch `asdd/008-ui-alignment/T45-rule-sheet-presentation`、起点`dev`@`8d65b0c`。code `b2ca70c`、testの手直しを含むcode(`lib/`)は`b2ca70c`のまま。

- `lib/ui/rule_builder/rule_builder_view.dart`: 点線の枠(`_DashedBorderPainter`、`tokenFrameKey`)の中に横スクロールの`ReorderableListView`、末尾に手掛かり。公開の`TokenChip`(種類ごとの色、種類名 + 値、×、長押しで並べ替え。`description` = `tokenLabel`を読み上げとtestに使う)。`sampleListenable`(一覧の変化で描き直す)。追加ボタンを枠線だけに。
- `lib/ui/rule_builder/token_presets.dart`: `tokenKindLabel`・`tokenChipValue`。`lib/ui/theme/token_colors.dart`: `tokenHue`。
- `lib/ui/rule_builder/rule_builder_workspace.dart`: シートに取っ手・角丸・見出し(`_SheetHeader`)・プレビュー(`_SheetPreview`、`ruleSheetPreviewKey`)。高さは画面の78%まで(超えたらシートの中がスクロール)。広幅にも`sampleListenable`。
- **testの変更**: 既存testはチップの説明(`連番(2桁)`など)を画面の文字として探していたので、`TokenChip.description`で探す`tokenChip()`(`test/spec_003_rule_builder/token_chip_support.dart`)へ置き換えた(27箇所。確かめる内容は同じ)。「各トークン種別のラベルを表示する」は、種類名と値を確かめる形に書き足した(種類名「テキスト」と値「テキスト」が同じ字面になるため)。
- 新しいtest: `test/spec_003_rule_builder/rule_sheet_presentation_test.dart`(11件。見出し・取っ手・「閉じる」が無い、プレビュー(取り消し線・追随・変更なし・空)、チップの種類名と値、一覧の変化で描き直す、不明、種類ごとの色、横スクロールと手掛かり、長押しで並べ替わる、押してすぐでは並べ替わらない)。
- mutationの初回で`M528`(すぐ始まる並べ替え)がSURVIVEDだった。「押してすぐ」のtestが一度に大きく動かしており、並べ替えが位置を拾わないので壊しても落ちなかった。長押しのtestと同じ動かし方(少しずつ)に直し、KILLEDを確かめた。
- 検証: `flutter test` 1073件PASS、`flutter analyze`・`dart format` PASS。

### mutation

`M500`・`M515`の`find`を追随させた(シートに見出しとプレビューを足して字下げが変わった)。`M524`〜`M531`を足した。`command`を`flutter test test/spec_003_rule_builder`へ絞り、変更した箇所を守る既存の`M242`・`M256`・`M501`・`M516`も回した14件の生出力(NOTEは省いた):

```text
M242 | KILLED | lib/ui/rule_builder/rule_builder_view.dart | exit 1
M256 | KILLED | lib/ui/rule_builder/rule_builder_view.dart | exit 1
M500 | KILLED | lib/ui/rule_builder/rule_builder_workspace.dart | exit 1
M501 | KILLED | lib/ui/rule_builder/rule_builder_workspace.dart | exit 1
M515 | KILLED | lib/ui/rule_builder/rule_builder_workspace.dart | exit 1
M516 | KILLED | lib/ui/rule_builder/rule_builder_workspace.dart | exit 1
M524 | KILLED | lib/ui/rule_builder/rule_builder_workspace.dart | exit 1
M525 | KILLED | lib/ui/rule_builder/rule_builder_workspace.dart | exit 1
M526 | KILLED | lib/ui/rule_builder/rule_builder_workspace.dart | exit 1
M527 | KILLED | lib/ui/rule_builder/rule_builder_view.dart | exit 1
M528 | SURVIVED | lib/ui/rule_builder/rule_builder_view.dart | exit 0   ← testを直した(上)
M529 | KILLED | lib/ui/rule_builder/rule_builder_workspace.dart | exit 1
M530 | KILLED | lib/ui/theme/token_colors.dart | exit 1
M531 | KILLED | lib/ui/rule_builder/token_presets.dart | exit 1
14 mutations: 13 KILLED, 1 SURVIVED, 0 SKIPPED
M528 | KILLED | lib/ui/rule_builder/rule_builder_view.dart | exit 1   ← testの手直し後
1 mutations: 1 KILLED, 0 SURVIVED, 0 SKIPPED
```

触った4ファイル(`rule_builder_view.dart`・`rule_builder_workspace.dart`・`token_presets.dart`・`token_colors.dart`)を`file`に持つmutationの`find`は、すべてちょうど1回一致する(追随後)。

## machine検証範囲と引き受け先

- **CIで閉じる**: widget test(シート・プレビュー・チップ・並べ替え、003 REQ-002〜005)とmutation。
- **このtaskのmanual(Androidエミュレータ)**: 見た目(参考デザインとの見比べ)と、タッチでの長押し・横スクロールの感触。引き受け先のtaskは無い。

## 独立review

既定のreviewerは`gpt-6-luna`(開発者指定)。UIの提示で、判定・contract・データ保護には触れない。

- attempt 1: `8d65b0c..72a711b`(全範囲、implementation) — **PASS**(P2 1件・P3 2件)。reviewerのmodelは`gpt-6-luna`。確認された点: 開発者が選んだ範囲の実装と「離れた点」の一致、狭幅・広幅の一覧の監視、チップの値の場合分け、REQ-002〜005・008〜011の維持、並べ替えとタップ・×の共存、testの置き換えが緩和でないこと、色を`token_colors.dart`へ集約した判断、触ったfileのmutationの`find`。full test 1073件・format・analyze・`check specs`・`git diff --check` PASS。
  - **P2(成果物の欠陥)**: 1件目が未選択だとプレビューが「（変更なし）」と出る(未選択は変更後名`null`。002 REQ-007)。→ `874adce`で**選択されている最初の行**(`firstSelectedRow`)をプレビュー・チップの値・エディタの表示例の共通の基準にした。testを足し、reviewerの対照`M532`を修正後のコードへ当てた形で取り込んだ(KILLED)。
  - **P3**: `RuleBuilderView`のコメント(色は`AppColors`を再利用)が事実と違う → 直した。**P3(安全網の穴)**: 高さの上限とスクロールの確認手順が無い → 手順書4.3に足した(トークンを足してもシートの高さは変わらないこと、画面が低いときのスクロール)。FAIL条件に当たらない。
  - あわせて`M517`の`find`を`firstSelectedRow`へ追随させた(KILLED)。
  - 修正後の範囲付きmutation(`flutter test test/spec_003_rule_builder`)の生出力:

```text
M515 | KILLED | lib/ui/rule_builder/rule_builder_workspace.dart | exit 1
M516 | KILLED | lib/ui/rule_builder/rule_builder_workspace.dart | exit 1
M525 | KILLED | lib/ui/rule_builder/rule_builder_workspace.dart | exit 1
M529 | KILLED | lib/ui/rule_builder/rule_builder_workspace.dart | exit 1
M532 | KILLED | lib/ui/rule_builder/rule_builder_workspace.dart | exit 1
5 mutations: 5 KILLED, 0 SURVIVED, 0 SKIPPED
M517 | KILLED | lib/ui/rule_builder/rule_builder_workspace.dart | exit 1
1 mutations: 1 KILLED, 0 SURVIVED, 0 SKIPPED
```

  - full `flutter test` 1074件PASS、analyze・format PASS。

## Current state / handoff

- Last checkpoint: attempt 1 の指摘を直した(code `874adce`)。
- Blocker category: none
- Evidence revision: code `874adce`
- Next Agent action: 独立review attempt 2(差分、`72a711b..HEAD`、`gpt-6-luna`)を起動する。PR #200(Draft)
