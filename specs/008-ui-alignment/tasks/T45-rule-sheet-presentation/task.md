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

## manual 1回目の結果と改善点(2026-09-29、code `874adce`、受領: 会話。原文)

> - 確認事項については、いくつか気になる部分があります。
>     - プレビューの矢印が薄くて見えづらいので、濃くしてください。
>     - チップの種別名と×マークについて、種別名は左寄せ、×マークは右寄せにしてください。
>     - チップの×マークが小さくて押しにくいので、円の中に×マークがあるデザインでやや大きくし、円の上と右がチップの上辺と右辺に重なるぐらいの配置にしてください。×マークは今の大きさでよく、円の大きさ分の判定が増えるイメージです。色は各チップの色に合わせてください。円の外周と×マークがチップのアクセントカラー、背景がチップの背景色と同じです。
>     - 「タップで設定/長押しで並び替え」の文言は見えづらいので、点線枠内には書かず、命名ルールの下の線と点線枠の間にスペースを設けてそこに書いてください。ただし、チップが1つ以上設定されている時だけ表示し、チップが0この場合はスペースだけ開けて空行にしてください。文言は、「チップを押すと各設定が開けます。チップを長押ししてドラッグすると並び替えられます。」にしてください。
>     - プレビューが画面の下ぎりぎりなので、少しだけ下に余白を設けてください。

- 挙がった点のほかは問題なしと読む(「いくつか気になる部分があります」)。5点を直し、manualはやり直す。

### 改善点の実装(2026-09-29、code `889b442`)

- チップ: 種別名を左寄せ(上段の行)。削除は右上の円(直径22、`_DeleteCircle`)を`Stack`で重ね、円の上端と右端をチップの上辺・右辺に合わせた。×は12のまま、押せる範囲は円。円の縁と×は種類の色、中はチップの面(枠の暗い面に種類の色を薄く敷いた不透明な色。チップの面も同じ色に揃えた)。
- 並べ替えの案内: 点線の枠の中(末尾)から、枠の上(見出しの下の線と枠の間、高さ44の置き場`tokenReorderHintKey`)へ。文言は「チップを押すと各設定が開けます。チップを長押ししてドラッグすると並び替えられます。」。チップが0個なら文を出さず空きだけ(枠の位置は変わらない)。
- プレビュー: 矢印を`textPrimary`へ。下の余白を18から32へ。
- **土台から離れた点の更新**: 案内は土台では枠の中(チップの後ろ)にあるが、開発者の指定で枠の外へ。削除は土台では種類名の横の小さな×だが、開発者の指定で右上の円へ。
- test: 既存の「種類ごとの色」のtestは面の色の定義(不透明に揃えた)へ追随。新しいtest6件(案内の位置と文言、0個のとき空き、左寄せと円の位置、円の大きさ・色・円の端で消える、矢印の色と下の余白)。
- mutation `M533`〜`M540`を足した。初回`M540`(種別名の中央寄せ)がSURVIVED: testのチップの値が短く、上段の行がチップの幅を決めていたので寄せ方で位置が変わらなかった。値が長いチップで確かめる形に直してKILLED。範囲付き(`flutter test test/spec_003_rule_builder`)で、変更した箇所を守る既存の`M527`〜`M530`も回した生出力(NOTEは省いた):

```text
M527 | KILLED | lib/ui/rule_builder/rule_builder_view.dart | exit 1
M528 | KILLED | lib/ui/rule_builder/rule_builder_view.dart | exit 1
M529 | KILLED | lib/ui/rule_builder/rule_builder_workspace.dart | exit 1
M530 | KILLED | lib/ui/theme/token_colors.dart | exit 1
M533 | KILLED | lib/ui/rule_builder/rule_builder_view.dart | exit 1
M534 | KILLED | lib/ui/rule_builder/rule_builder_view.dart | exit 1
M535 | KILLED | lib/ui/rule_builder/rule_builder_view.dart | exit 1
M536 | KILLED | lib/ui/rule_builder/rule_builder_view.dart | exit 1
M537 | KILLED | lib/ui/rule_builder/rule_builder_view.dart | exit 1
M538 | KILLED | lib/ui/rule_builder/rule_builder_workspace.dart | exit 1
M539 | KILLED | lib/ui/rule_builder/rule_builder_workspace.dart | exit 1
M540 | SURVIVED | lib/ui/rule_builder/rule_builder_view.dart | exit 0   ← testを直した(上)
12 mutations: 11 KILLED, 1 SURVIVED, 0 SKIPPED
M534 | KILLED | lib/ui/rule_builder/rule_builder_view.dart | exit 1
M540 | KILLED | lib/ui/rule_builder/rule_builder_view.dart | exit 1   ← testの手直し後
2 mutations: 2 KILLED, 0 SURVIVED, 0 SKIPPED
```

- 触ったfileを`file`に持つmutationの`find`は、すべてちょうど1回一致する。
- 検証: `flutter test` 1079件PASS、`flutter analyze`・`dart format` PASS。手順書の2.・4.を改善後の画面へ書き直した。

## manual 2回目の結果と改善点(2026-09-29、code `889b442`、受領: 会話。原文)

> 変更なしと変更ありの場合で、プレビューの高さが変わってボトムシートがガタついているようです。修正してください。ほかにも高さが変わる要因があるなら修正してください。また、チップの×マークはチップから少しはみ出るぐらいに少し移動させてください。それによって点線の枠やチップ同士の余白に余裕がなくなるのであれば、余白を少しだけ追加してもよいです。

- 挙がった点のほかは問題なしと読む。codeを変えるのでmanualはやり直す。

### 改善点の実装(2026-09-29、code `5a6c084`)

- プレビュー: 2行目(変更ありの矢印と新しい名前 / 変更なしの文)を高さ20の箱(`ruleSheetPreviewResultKey`)に入れ、どちらでも同じ高さにした。**ほかに高さが変わる要因**として、名前の折り返し(ルールを変えるたびに新しい名前の長さが変わる)を見つけ、元の名前・新しい名前とも1行に収めて「…」で省くようにした。並べ替えの案内の置き場(44)と点線の枠(76)はもともと固定。
- 削除の円: チップの上と右に`tokenChipDeleteOverhang`(5)の余白を持たせ、その角(`Stack`の内側)に円を置いた。円は5だけはみ出し、はみ出した部分も押せる(`Stack`の外へ`Positioned`で出すと押せなくなるため)。点線の枠を高さ76・上下の余白10へ広げた。チップ同士の間は6 + 5 = 11(円がはみ出す5を引いて6が残る)。
- test: 円の位置のtestを「5はみ出す」へ、端のタップを「はみ出した部分」へ直した。新しいtest: プレビューの高さが変更あり・なし・長い名前で変わらない(シートの高さも)、名前が1行・省略、チップが0個 ↔ 1個でシートの高さが変わらない。
- mutation: `M538`・`M540`の`find`を字下げの変更に追随。`M541`〜`M544`を足した。初回`M542`・`M543`(名前を折り返す)がSURVIVED: 新しい名前は高さ固定の箱の中なので折り返しても高さは変わらず(文字が箱の外へはみ出して描かれる)、高さのtestでは検出できない。名前が1行・省略であることを直接確かめる形を足してKILLED。範囲付き(`flutter test test/spec_003_rule_builder`)の生出力(NOTEは省いた):

```text
M529 | KILLED | lib/ui/rule_builder/rule_builder_workspace.dart | exit 1
M534 | KILLED | lib/ui/rule_builder/rule_builder_view.dart | exit 1
M535 | KILLED | lib/ui/rule_builder/rule_builder_view.dart | exit 1
M536 | KILLED | lib/ui/rule_builder/rule_builder_view.dart | exit 1
M537 | KILLED | lib/ui/rule_builder/rule_builder_view.dart | exit 1
M538 | KILLED | lib/ui/rule_builder/rule_builder_workspace.dart | exit 1
M540 | KILLED | lib/ui/rule_builder/rule_builder_view.dart | exit 1
M541 | KILLED | lib/ui/rule_builder/rule_builder_workspace.dart | exit 1
M542 | SURVIVED | lib/ui/rule_builder/rule_builder_workspace.dart | exit 0   ← testを足した(上)
M543 | SURVIVED | lib/ui/rule_builder/rule_builder_workspace.dart | exit 0   ← 同上
M544 | KILLED | lib/ui/rule_builder/rule_builder_view.dart | exit 1
11 mutations: 9 KILLED, 2 SURVIVED, 0 SKIPPED
M542 | KILLED | lib/ui/rule_builder/rule_builder_workspace.dart | exit 1   ← testの追加後
M543 | KILLED | lib/ui/rule_builder/rule_builder_workspace.dart | exit 1
2 mutations: 2 KILLED, 0 SURVIVED, 0 SKIPPED
```

- 触ったfileを`file`に持つmutationの`find`は、すべてちょうど1回一致する。
- 検証(code `5a6c084`): `flutter test` 1081件PASS、`flutter analyze`・`dart format` PASS。手順書の2.・4.を書き直した。

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

- attempt 2: `72a711b..dca9d7a`(差分、implementation) — **PASS**(指摘なし)。reviewerのmodelは`gpt-6-luna`。P2・P3が閉じたこと、`firstSelectedRow`が連番の1番目が振られるファイルと一致しプレビュー・チップの値・T44の表示例で一貫すること、「プレビュー（1つ目のファイル）」の文言と矛盾しないこと、`M517`・`M532`の妥当性、手順書4.3の真偽を確認された。full test 1074件・format・analyze・`check specs`・`git diff --check` PASS。`M517`・`M532` KILLED。
  - 連鎖: `8d65b0c..72a711b` PASS → `72a711b..dca9d7a` PASS。

- attempt 3: `dca9d7a..abb9ef3`(差分、implementation。`dev`の取り込みを含む。競合なし) — **PASS**(指摘なし)。reviewerのmodelは`gpt-6-luna`。改善点5つが原文どおり、削除の円の押せる範囲が直径22でタップ・長押し・横スクロールと衝突しないこと、面の色の変更、testの変更が緩和でないこと、`M533`〜`M540`、手順書と「離れた点」の更新を確認された。full test 1079件・format・analyze・`check specs`(104 tasks)・`git diff --check` PASS。範囲付きmutation 12件KILLED。
  - 連鎖: `8d65b0c..72a711b` PASS → `72a711b..dca9d7a` PASS → `dca9d7a..abb9ef3` PASS。

- attempt 4: `abb9ef3..354c916`(差分、implementation) — **PASS**(P2 1件)。reviewerのmodelは`gpt-6-luna`。高さを固定した箱と1行の名前、円のはみ出しと押せる範囲・隣や枠と重ならないこと、操作の衝突が無いこと、testの変更が緩和でないこと、手順書、mutationの`find`を確認された。full test 1081件・format・analyze・`check specs`・`git diff --check` PASS。範囲付きmutation 6件KILLED。
  - **P2(成果物の欠陥)**: 固定の高さ(プレビューの2行目20・案内44・点線の枠76)は、端末の文字を大きくすると文字が切れうる。→ `f6ad967`で**高さを文字の拡大率に合わせて決める**ようにした(`tokenReorderHintHeight`・`tokenFrameHeight`・`tokenChipKindRowHeight`・プレビューは`scale(20)`)。開いている間は拡大率が変わらないのでガタつかず、拡大しなければ高さは今までと同じ(枠76、案内44.8)。
  - test: 文字を2倍にして、案内・チップの値・プレビューの文字が**本来要る高さ(折り返しを含む)で**箱に収まり、変更あり↔なしでシートの高さが変わらず、はみ出し(overflow)が無いこと。
  - mutation `M545`〜`M547`を足し、`M541`の`find`を追随させた。初回`M545`・`M546`がSURVIVED: 描かれる大きさは箱に切り詰められるので、描かれた位置だけを見るtestでは切れていることが分からなかった。本来要る高さ(`getMinIntrinsicHeight`)で見る形に直してKILLED。生出力(`flutter test test/spec_003_rule_builder`、NOTEは省いた):

```text
M534 | KILLED | lib/ui/rule_builder/rule_builder_view.dart | exit 1
M541 | KILLED | lib/ui/rule_builder/rule_builder_workspace.dart | exit 1
M545 | KILLED | lib/ui/rule_builder/rule_builder_workspace.dart | exit 1
M546 | KILLED | lib/ui/rule_builder/rule_builder_view.dart | exit 1
M547 | KILLED | lib/ui/rule_builder/rule_builder_view.dart | exit 1
5 mutations: 5 KILLED, 0 SURVIVED, 0 SKIPPED
```

  - full `flutter test` 1082件PASS、analyze・format PASS(code `f6ad967`)。

- attempt 5: `354c916..4b133af`(差分、implementation) — **PASS**(指摘なし)。reviewerのmodelは`gpt-6-luna`。attempt 4 のP2が閉じたこと(式を1.3倍・3倍でも照合)、シートを開いている間の高さの変化を新しく作っていないこと(OS側の拡大率を開いたまま変えた場合だけは変わりうる)、testが本来要る高さで見ていること、`M541`・`M545`〜`M547`を確認された。full test 1082件・format・analyze・`check specs` PASS。
  - 連鎖: `8d65b0c..72a711b` → `72a711b..dca9d7a` → `dca9d7a..abb9ef3` → `abb9ef3..354c916` → `354c916..4b133af`、すべてPASS。

## manual 3回目の結果(2026-09-30、code `f6ad967`、受領: 会話。原文)

> - 確認事項について、すべて問題ありませんでした。

- 環境: host側のAndroidエミュレータ、worktree `.worktrees/008-T45-rule-sheet-presentation`、fixture `Download/asdd-008-t25`の3件、縦向きから開始。
- 対象: 手順書の1.〜5.(ガタつき: 変更あり↔なし・長い名前・チップ0↔1個でシートの高さが変わらない。×の円のはみ出しと押せる範囲。シートの枠・並べ替え・プレビュー・広幅)。すべてPASS。
- `f6ad967`以後の差分はtest(`test/`)・`tool/mutations.json`・`specs/`だけで、`lib/`・依存・build設定は変わっていないため、この証拠はHEADにも有効。

## Current state / handoff

- Last checkpoint: manual 3回目 PASS(code `f6ad967`)。
- Blocker category: none
- Evidence revision: code `f6ad967`
- Next Agent action: final-evidence reviewを依頼する。PASSならPR #200をreadyにしてmergeする
