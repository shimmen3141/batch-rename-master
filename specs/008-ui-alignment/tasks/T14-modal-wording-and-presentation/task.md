# T14 modalの文言と見せ方を整える

## 目的

`013:T07`の実機確認で開発者が挙げた**U5**を解消する。原文は「**モーダルの文言や
見せ方は改善の余地あり**」である。

## 着手時の決定(2026-10-02、開発者)

現状と修正案を示し、開発者が次のとおり決めた。

- **① 実行前確認dialog**: 提示した方針で進める(参考デザインの「実行前の確認」へ寄せ、種類ごとに1枠、
  強制実行したときに何が起きるかを書く)。開発者の補足(原文): 「連番の警告が出るルートはなくなったので、
  それは表示されないはずです」 — `008:T21` / `T52` 以後、桁数は下限より小さくできない。**001 の桁不足判定は
  安全網として残る**ので、コードは届いたときも書けるようにし、manual では見ない。
- **② 再採番の結果**: **案A**。通知には件数と入口(「名前を確認する」)だけを置き、押すと中央のdialogで
  「旧 → 新」を全件読む。原文: 「エラーと同様に自動で消えないようにしてください」 — **名前が変わった項目がある
  結果の通知は閉じるまで残す。「元に戻す」は期限(5秒。005 REQ-007)を過ぎたら通知から消す**(押しても
  何も起きない操作を残さない)。
  - 提示した選択肢: A 通知から開く(推奨) / B 自動で開く(undoをdialogへ移す) / C やらない(①だけ)。
  - **観測**: 「エラーと同様に」の前提と違い、**現在は「元に戻す」を持つ失敗結果は5秒で消える**
    (`008:T25` の決定。`M455`)。このtaskでは失敗結果の扱いを変えていない。揃えるかは開発者へ報告した。

### 対象の確定

表の1(実行前確認dialog)と、結果の提示手段。**表の2〜4はこのtaskの対象外**(2は`T08`、3は`T44`、4は`T45`が
完了済み)。U5 が指すmodalの確認は、残る対象が1だけになったため不要になった。

### design 土台との照合(適用範囲: 「実行前の確認」dialog `dlg.kind === 'validate'`)

合わせた点: 見出し「実行前の確認」、説明文、薄い赤の枠に⚠・見出し・説明、区切り線の下に「キャンセル」と赤い実行button
(角丸18のcard、`Dialog` の枠は `008:T44` のtokenエディタと同じ値)。

**離れた点と理由**:

- **実行buttonの文言を条件付きにした。** 土台は常に「自動解決して実行」。名前が空・日時不明だけの確認では
  何も自動解決しないので、そのときは「このまま実行」と書く(偽りの説明にしない)。
- **枠に対象ファイルの名前を添えた。** 土台は種類と件数だけ。既存の確認dialogは対象を読めており(test
  「警告時は全件を確認してから」)、dialogの上から警告の詳細は開けないので、読めるものを減らさない。
  件数ぶん行を増やさず「、」で1段落に並べる。
- **種類は「名前が空」「作成日時不明 / 更新日時不明」も持つ。** 土台は重複と桁数不足だけ。語彙は `T19` の正本
  (`warningKindLabel`)を使い、土台の「名前の重複」「連番の桁数不足」は使わない。
- **本文だけをscrollさせる。** 土台は件数が少ない前提。件数が多くても見出しとbuttonは画面に残す。

## 対象modalが特定できていない — 着手時に人間へ確認する(2026-10-02 に解消。上の「着手時の決定」)

**U5はどのmodalを指すか書かれていない。** 推測で直すと、指摘されていないものを変えて
manual確認をやり直させることになる。**着手した最初の質問として、下の一覧を示して
確認する**(AGENTS.md「一度に一つ、現実的で相互排他的な選択肢」)。

現在appにあるmodal / dialog。

| # | 実装 | 何を出すか | 所有 |
|---|---|---|---|
| 1 | `lib/ui/file_list/file_list_view.dart` の `Key('rename-confirmation-dialog')` の `AlertDialog` | 警告があるまま実行するかの確認 | **このtask** |
| 2 | `lib/ui/file_source/file_source_bar.dart:192` の `showModalBottomSheet` | 読み込む種類の選択(画像 / 動画 / すべて) | **`T08`**(読み込み導線の一部として確定させる)。**このtaskは文言だけを後から合わせる** — 分担は`T08`の`task.md`にも書いた |
| 3 | `lib/ui/rule_builder/token_editors.dart:13` の `showModalBottomSheet` | tokenの編集 | **`T05`/`T06`**(token追加の確定手順)。**このtaskでは触らない** |
| 4 | `lib/ui/rule_builder/rule_builder_workspace.dart` の `_openRuleSheet` の `showModalBottomSheet` | **ルール構築画面まるごと**(mobileの下部バー「ルール設定」から開く。中身は`RuleBuilderView`) | **このtask。** **狭幅(`breakpoint` = 840dp 未満。実機確認に使った phone を含む)ではルールの編集が必ずこのsheet越しなので、U5がこれを指す可能性が高い**(実機確認の手順3で開発者が実際に操作している)。**sheetの中にあるtoken追加・編集のmodalだけが`T05`/`T06`** |

**3(token編集)が対象だった場合は、このtaskで直さず`T05`/`T06`へ送る**(同じ画面を
2つのtaskが別々に変えない)。**2026-09-29 追記(改訂): 表の3(tokenの編集)は形も中身も`T44`へ、表の4(ルール構築シート)は`T45`へ移した**(開発者が参考デザインの適用を決め、2つのtaskに分けた。[`T44`の「範囲の決定」](../T44-token-editor-presentation/task.md))。**このtaskに残るのは表の1(実行前の確認dialog)の文言と見せ方だけ。****4は入れ物であって token の modal ではない**ので、
このtaskが持つ — ただし`T06`が中身を作り直すので、**入れ物の高さ・scroll・閉じ方を
変えるときは`T06`の結果と突き合わせる**。

### `T19`との分担(2026-08-27に`T16`と結び、2026-09-02に`T19`へ移した)

`T19`が**警告の詳細modal**を持つ(`T16`が作った入れ物を作り直す)。**このtaskが持つのは表の1**
(実行前の確認dialog)である。**同じmodalへ二つのtaskが手を入れない**よう、先に着手した側が
入れ物を確定させ、後の側が合わせる。分担は`T19`の`task.md`にも書いた。

**`describeWarning`系の文面は両方が使う。** `T19`の`task.md`は「着手時にどちらが文面の正本を
持つかを決めて両方の`task.md`へ書く」としている。**どちらが先でも、決めた側が両方のfileへ書く。**

**`T19`が先に着手した場合**、このtaskは`T19`が作った詳細の見せ方に合わせて確認dialogの
文言を整える(同じ警告を二つの語彙で説明しない)。

## 文言の正本は `T19` が持つ(2026-09-18に決めた)

`describeWarning` 系の文面は、警告の詳細modal(`T19`)と実行前確認dialog(このtask)の両方が使う。
**`T19` が文言の正本を持つ。** このtaskは確認dialogの体裁を持ち、文面は `T19` が決めた語彙
(`作成日時不明` / `更新日時不明` / `連番の桁不足`、種別の区切りは `・`)へ合わせる。同じ警告を
二つの語彙で説明しない。

### `T19` から引き渡された1件(2026-09-18)

- **行のバッジは `名前が重複`、詳細の見出しは `名前の重複`** で活用形が揃っていない。
  `T19` の独立review attempt 2 は「同じ概念の活用形であり、`T19` が宣言した検証範囲
  (日時と桁不足の語彙)の外」として欠陥にしなかった。**文言を触るこのtaskが字面を揃えるときに拾う。**
  経緯は [`T19` の task.md](../T19-warning-detail-modal/task.md) の「引き渡した残余risk」にある。
- **→ 2026-10-02 に確認: 既に揃っている。** `008:T50` が行・詳細・確認dialogの呼び名を `重複` 1つに縮めた
  (`duplicateKindLabel`)。このtaskの確認dialogも同じ関数を使う。

## 着手時に人間へ確認すること(`008:T06` から、2026-09-18)

開発者の問い(原文): 「ちなみに、参考desginはモーダルですが、ボトムシートからモーダルに変更する予定はありますか。」

token のエディタ(`token_editors.dart`)は `T06` で bottom sheet のままにした。003 spec は形を自由としており、
**形を変えるかは提示の判断**なのでこのtaskの範囲である。**対象modalを確認する最初の質問に、
「token エディタを含む modal の形を中央のdialogへ揃えるか」を含めること。** 断定ではないので決定として扱わない。**→ 2026-09-29 に決まった: tokenのエディタは参考デザインどおり中央のdialogにする(`T44`)。この質問はもう要らない。**

## 引き受けた残余risk(`008:T20` の独立review attempt 1 から)

`lib/ui/file_list/file_list_view.dart` の実行前確認dialogを触るときに、同じ file の次を片付けること。
経緯と3条件の判定は [`T20` の task.md](../T20-rule-and-exec-bar/task.md) の「独立review」にある。

- **F3**: `_RenameActionBar.warnings` が未使用で、class doc が「ルールが空のとき実行を無効にする」のまま
  (005 REQ-019 revision 9.0 では「変更が生じるファイルが0件のとき」)。`controller.changedFileCount` が
  build ごとに 001 の評価をもう一度走らせる(同じ build の `preview` を再利用できる)。
- **F5**: `_request` の0件ガードを外しても全testが通る。`RenameExecutionController.execute` の門が止めるので
  実体は変わらない(多層防御の片側)。**縮む方向を縛る検査を置くこと。**

## あわせて拾う: 結果の提示手段(2026-08-15の決定)

`plan.md`の人間の決定表にある「**再採番結果の提示方法**」が、**どのtaskにも割り当てられて
いなかった**。内容は「`013:T11`が結果toastへ入れた『旧 → 新』の全件表示を008で見直す。
件数が多いとtoastが縦に伸びる(現在は高さ96pxで打ち切ってscroll)。**modalの方が向いて
いる**という指摘があった」である。

**提示手段は005 specが「自由とする点」に入れており、振る舞いは変わらない**ので008の
範囲である。**このtaskが引き受ける。**

## 変更範囲

- 上の表の 1・4 と、結果の提示手段。**2 は`T08`が確定させた後に文言だけを合わせる。**
- 文言(何を聞かれているか、実行すると何が起きるか)と、見せ方(高さ、scroll、
  botton の並び、破壊的操作の見分け)。

**判定は動かさない。** 005の実行可否、衝突・重複の警告条件、001の検証はそのままである。
**警告の内容そのもの**(何を警告するか)は`T07`(行と警告の情報階層)が持つ。

### `T15`との分担(2026-08-29)

`T15`は**警告の詳細を見るmodal**(ヘッダーの「⚠ N 件の問題」と行の警告文から開く)を定義し、
`T16`が実装する。このtaskが持つのは**実行前確認dialog**(`Key('rename-confirmation-dialog')`)
だけである。**同じmodalに二つのtaskが手を入れない。**

文言の体裁(見出し・本文・buttonの並び)はこのtaskが揃えるので、`T16`が作ったmodalへは
**後から文言だけを合わせる**。`T08`との関係と同じ形である。

## 受け入れ証拠

- 変更したmodalの文言と構造を widget test で検査する。**既存の実行経路のtestが継続
  PASSする**(確認を挟むこと自体は005の要求である)。
- 件数が多いときの結果提示が**画面内で読める**ことを widget test で検査する。
- `flutter test` / `flutter analyze` / `dart format --output=none --set-exit-if-changed .` がPASS。
- [`manual-verification.md`](manual-verification.md)で実機の見え方を確認する。
- exact rangeの独立reviewがPASSする。

## 作業記録

### 実装(2026-10-02、checkpoint `90b704e`)

実装は Claude Opus 5.5。起点は`dev`@`9b14ad5`、branch `asdd/008-ui-alignment/T14-modal-wording-and-presentation`。

- 新規 `lib/ui/file_list/rename_confirmation_view.dart`:
  - `confirmationIssues`: 001 の警告を**種類ごとに1つ**へまとめ、強制実行したときの処理を添える。重複は
    「末尾へ (1) (2) … を付けて改名」(001 の自動解決)、桁不足は「連番を N 桁に広げて改名」、名前が空は
    「これらのファイルは改名しません」(005 REQ-022)、日時不明は「その日時の部分を空にして改名」。**名前が空に
    なるファイルの日時不明は、日時不明の枠へ数えない**(改名しないファイルを改名すると書かない。REQ-021 規則1
    と同じ畳み方)。
  - `showRenameConfirmation`: 上の design 土台どおりのdialog。key(`rename-confirmation-dialog` /
    `rename-cancel` / `rename-force`)は既存のまま。
  - `showRenumberedDetail`: 再採番の「確認した名前 → 結果の名前」を全件並べるdialog(REQ-024)。
- `lib/ui/common/app_toast.dart`: `ToastAction.expiresAfter`。過ぎたら**通知は残したまま操作だけを外す**。
- `lib/ui/file_list/file_list_view.dart`:
  - 確認dialogを `showRenameConfirmation` へ置き換えた。判定(警告があれば確認を挟む、強制実行の名前)は変えていない。
  - 結果の通知: 再採番があれば「名前を確認する」(下線)を置き、`persist: true`。「元に戻す」へ `expiresAfter` を渡す。
  - **F3**: `_RenameActionBar` の未使用の `warnings` を外し、同じ build の `rows` を受けて
    `FileListController.changedFileCountIn(rows)` で数える(001 の評価をもう一度走らせない)。class doc を
    005 REQ-019 revision 9.0(変更が0件なら無効)へ直した。
  - **F5**: 0件ガードは残し、testで縛った(下)。
- test:
  - 新規 `test/spec_005_rename_exec/rename_confirmation_presentation_test.dart`(11件): 種類ごとのまとめ
    (重複30件が1枠 / 名前が空と日時不明の畳み / 日時不明だけ / 桁不足)、dialogの見出し・説明・1枠・赤いbutton・
    強制実行で改名、320×640・文字1.6倍・60件でも見出しとbuttonが画面内、**古いcallbackで変更0件のまま要求しても
    確認も占有名の取得もしない(F5)**、再採番の通知は閉じるまで残り undo だけ期限で消える、12件でも通知へ
    名前を並べずdialogで全件読める、再採番が無い結果は従来どおり期限で消える。
  - `warning_confirmation_results_test.dart` の REQ-024 の2件: 「旧 → 新」を通知ではなく詳細dialogで数える
    ように変えた(決定 A による提示場所の変更。**4件を落とさない**主眼と件数の assertion は同じ)。

検証(`90b704e`、container内で直接実行):

- `dart format --output=none --set-exit-if-changed .` — PASS(0 changed)
- `flutter analyze` — No issues found
- `flutter test` — **All tests passed(1174件)**
- `python3 tool/check_mutation_finds.py` — PASS(587件)

mutation: 今回足した `M634`〜`M643` と、`find` を追随させた `M455` の11件を、
`command` を `flutter test test/spec_005_rename_exec test/spec_002_file_list/app_toast_test.dart` へ絞って回した:

```text
command: flutter test test/spec_005_rename_exec test/spec_002_file_list/app_toast_test.dart
M455 | KILLED | lib/ui/file_list/file_list_view.dart | 008:T25 「元に戻す」を持つ失敗結果を閉じるまで残す ... | exit 1
M634 | KILLED | lib/ui/file_list/file_list_view.dart | 008:T14 名前が変わった項目がある結果を期限で消す ... | exit 1
M635 | KILLED | lib/ui/common/app_toast.dart | 008:T14 期限を過ぎても「元に戻す」を残す ... | exit 1
M636 | KILLED | lib/ui/file_list/file_list_view.dart | 008:T14 「元に戻す」に期限を渡さない ... | exit 1
M637 | KILLED | lib/ui/file_list/file_list_view.dart | 008:T14 結果の通知から詳細の入口を落とす ... | exit 1
M638 | KILLED | lib/ui/file_list/rename_confirmation_view.dart | 008:T14 名前が空になるファイルの日時不明を「空にして改名します」へも数える ... | exit 1
M639 | KILLED | lib/ui/file_list/rename_confirmation_view.dart | 008:T14 何も解決しないのに「自動解決して実行」と書く ... | exit 1
M640 | KILLED | lib/ui/file_list/rename_confirmation_view.dart | 008:T14 重複を1ファイル1枠に戻す ... | exit 1
M641 | KILLED | lib/ui/file_list/rename_confirmation_view.dart | 008:T14 本文だけをscrollさせるのをやめる ... | exit 1
M642 | KILLED | lib/ui/file_list/rename_confirmation_view.dart | 008:T14 確認の実行buttonを通常の色にする ... | exit 1
M643 | KILLED | lib/ui/file_list/file_list_view.dart | 008:T14(008:T20 の F5) 画面の0件ガードを外す ... | exit 1
11 mutations: 11 KILLED, 0 SURVIVED, 0 SKIPPED
```

### 独立review

reviewer は開発者の指定どおり `gpt-6-luna`(`codex-container exec -m gpt-6-luna`)。実装は Claude Opus 5.5。

- Review attempt 1: `9b14ad5..d7c2db6` — **FAIL** — P1 1件(T14-R1)
  - **T14-R1(P1・成果物の欠陥)**: `[元の名前][作成日時]` で作成日時が取れないファイルは生成後名が現在名と同じで
    改名されない(005 REQ-019 の「変わらない」)のに、確認dialogが「その日時の部分を空にして改名します」と書く。
  - 確認できた点(次回の前提): 重複・桁不足の説明は001の自動解決どおり、空名は REQ-022 どおり、判定・キャンセル・key
    は維持、再採番の詳細dialogは全件(REQ-024)、undo は5秒で操作だけ消える(REQ-007)、REQ-024 test の assertion
    は維持、F3/F5 は閉じた、manual のbutton名・重複の名前例は current code と一致。reviewer の mutation 3件
    (M638 / M639 / M643)は KILLED。analyze PASS、full test 1174 PASS。
  - **修正(`6d2f56d`)**: 行と警告を**同じ評価**(`controller.preview`)から取り、`rowHasNoChange` で名前が変わらない
    ファイルを「日時が取れず名前が変わらないため、これらのファイルは改名しません」の枠へ分けた。**行の `source` と
    警告の `file` は別の評価の instance で一致しない**ので、名前が変わらない行は行が持つ警告のファイルで数える
    (`source` で数えると一致せず黙って直らない — `M645` が対照)。
  - **同じ型の誤りを自分の記録でも見つけて直した**: manual の手順2(`[元の名前][作成日時]` で12件)は、
    端末のファイルでは作成日時が取れないので**12件とも名前が変わらず、実行buttonが押せない**手順だった。
    `[元の名前][自由テキスト _][作成日時]` に変えた(名前が `photo_01_.txt` に変わる)。unit test の
    「日時不明だけ」も同じ前提の誤りで「空にして改名」を期待していたので、名前が変わる場合と変わらない場合の2件へ分けた。
  - 検証(`6d2f56d`): `flutter analyze` No issues、`dart format` 0 changed、`flutter test` **1176 PASS**、
    `check_mutation_finds.py` PASS(589件)。範囲付き mutation(`flutter test test/spec_005_rename_exec`):

```text
M638 | KILLED | lib/ui/file_list/rename_confirmation_view.dart | 008:T14 名前が空になるファイルの日時不明を「空にして改名します」へも数える ... | exit 1
M639 | KILLED | lib/ui/file_list/rename_confirmation_view.dart | 008:T14 何も解決しないのに「自動解決して実行」と書く ... | exit 1
M643 | KILLED | lib/ui/file_list/file_list_view.dart | 008:T14(008:T20 の F5) 画面の0件ガードを外す ... | exit 1
M644 | KILLED | lib/ui/file_list/rename_confirmation_view.dart | 008:T14 日時不明で名前が変わらないファイルも「その部分を空にして改名します」と書く ... | exit 1
M645 | KILLED | lib/ui/file_list/file_list_view.dart | 008:T14 名前が変わらないファイルを行の source で数える ... | exit 1
5 mutations: 5 KILLED, 0 SURVIVED, 0 SKIPPED
```

- Review attempt 2(差分): `d7c2db6..7afd544` — **PASS** — 未解決 P0/P1 なし、P2/P3 なし
  - T14-R1 が閉じた(同じ `controller.preview` から行と警告を取り、名前が変わらない日時不明は「改名しません」)。
    空名の畳みとも一致。manual 手順2は current code で実行できる。task.md の記録は差分と一致。
  - reviewer の mutation: M638 / M644 / M645 KILLED。`flutter test` 1176 PASS、`flutter analyze` No issues。
  - 連鎖: `9b14ad5..d7c2db6`(FAIL、T14-R1)→ `d7c2db6..7afd544`(PASS、T14-R1 の閉鎖を確認)。

### machine検証の範囲と、manualで見ないもの

- **再採番の詳細dialog**は widget test だけで確かめる(実行の最中に他processが同名を作る競合が要り、手で再現できない)。
- **「名前が空」の枠**は、実機では確認dialogまで届かない(日時だけのルールでは他のファイルも変更0件になる)ので
  widget test だけ。**「桁不足」の枠**は画面から出ない(`T52` の自動引き上げ)ので unit test だけ。
- 実機で見るのは、重複・作成日時不明の確認dialogの読みやすさ、色、狭幅、実際の改名と取り消し([manual](manual-verification.md))。

- 2026-08-25 / `013:T07`の実機確認(U5)を受けて定義。開発者が「U1〜U5をすべてtask化する」
  と決定した。あわせて、割り当て先の無かった2026-08-15の決定(結果の提示手段)をここへ
  接続した。

## Current state / handoff

- Last checkpoint: implementation の独立review PASS(`9b14ad5..7afd544`)。実機確認待ち
- Blocker category: manual-evidence
- Waiting for: 開発者(host 側の Android エミュレータ)
- Requested action: [manual-verification.md](manual-verification.md) の手順0〜2(3は任意)を、`lib/` が `6d2f56d` と同一の build で行う。`/workspace` は branch `asdd/008-ui-alignment/T14-modal-wording-and-presentation` のまま待つ
- Evidence revision: `6d2f56d`(code)/ `7afd544`(記録)
- Next Agent action: 結果を受け取ったら作業記録へ要約し、問題が無ければ final-evidence の review を経て PR #209 を ready にする
