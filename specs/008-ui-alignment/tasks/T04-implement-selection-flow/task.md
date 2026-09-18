# T04 選択と除去の導線を実装する

## 目的

`T03`で承認された仕様どおり、選択と除去を混同しない導線にする。

## 入力と依存

- `T03`で承認された002/004 spec。
- `docs/design/Bulk Renamer.html`。**適用する画面範囲は一覧の行と読み込みbarに限る**。

## 変更範囲

- 行の×の廃止と、除去の新しい導線。
- 「すべて外す」の改名と、必要なら配置。
- 002/004の仕様由来testの更新と追加。

### 行widgetの分担(T07・T09と共有する)

`lib/ui/file_list/file_list_view.dart`の行は、**T04が操作(×の廃止、除去の導線、checkboxとの関係)**、**T07が情報階層と静的layout**、**T09がmode別描画**を持つ。判断が割れたらT07の情報階層を優先する。表は[`T07のtask.md`](../T07-row-and-warning-presentation/task.md)にある。

### `file_source_bar.dart`の分担(T08と共有する)

`すべて外す`(`clear-files-button`)、`ファイルを選ぶ`(`pick-files-button`)、種類chip(`file-kind-*`)、複数folder警告(`multi-folder-warning`)は**すべて`lib/ui/file_source/file_source_bar.dart`の同じbarにある**。T04とT08が同じfileへ入るので、分担を先に固定する。

- **T04が持つのは`clear-files-button`だけ**(文言と、必要なら配置)。
- **barそのものの構成・読み込み導線・場所の提示・複数folder警告はT08が持つ。**
- T04が先に着手した場合、`clear-files-button`以外へ触らない。T08が先に着手した場合、`clear-files-button`の文言は現状のまま残し、T04で改名する。

**どちらが先でも成立する**ようにこの分担を切ってある。依存edgeにしないのは、T04が`T03`の仕様承認待ちで、T08を不必要に止めたくないためである。

### `T03`から渡される入力(2026-08-29)

- **「n/n件を選択」の置き場所。** 開発者は`T07`の実機確認時に「並び順buttonや警告より下へ
  移したい」と述べた。**checkboxを残す形を`T03`が選んだ場合**の配置としてここで扱う。
  checkbox自体を廃止する案も`T03`の論点にあるので、**`T03`の承認前にこの配置を実装しない**。

## 引き受けた: 「すべて外す」の置き場所(`008:T08` から。2026-09-18)

実機確認で開発者が「**すべて外すボタンは後の実装で消えるとは思うが、こちらも『〇/〇件を選択』の帯と
同じ階層に置くべき**」と述べた。`T08` が3通り試したが、件数の帯は 320dp・文字倍率1.3 で余白が無く、
**label付きでも icon だけでも `008:T16` の保証(件数が多くても一覧を覆わない / 狭幅で数字が消えない)が
壊れる**。開発者の判断で**いまは読み込み帯に置いたまま**とし、見直しをこのtaskへ送った。

- このtaskは削除導線(左swipe)と「すべて外す」の**文言**を持つ。**置き場所もここで決める。**
- 置き場所を件数の帯にするなら、**その帯の作りを組み直す**必要がある(警告の件数chipを別行へ固定する等)。
  `008:T16` の保証を壊さないことを widget test で示すこと。
- **無くす**選択肢もある(開発者は「後の実装で消えるとは思う」と述べている)。その場合は
  004 REQ-006(一覧を空にする)への到達経路を別に用意すること。

## 受け入れ証拠

- 新しい除去導線で一覧から消え、checkboxの状態とは独立であることをwidget testで検査する。
- 改名した名前のbuttonが、checkboxの全解除と別の操作であることをtestで検査する。
- 004の読み込み契約(置き換え・cancel・警告)が壊れていないことを既存testの継続PASSで確認する。
- `flutter test` / `flutter analyze` / `dart format --output=none --set-exit-if-changed .` がPASS。
- [`manual-verification.md`](manual-verification.md)で、除去が誤操作になりにくいかを実機で確認する。
- exact rangeの独立reviewがPASSする。

## 作業記録

- 2026-08-12 / plan作成時に定義。

## `T03`が承認した仕様(2026-09-18)

**行のcheckboxを廃止し、一覧＝rename対象にする**(002 REQ-016)。`covers` は `002:REQ-016` と
`002:REQ-017` を持つ。範囲は次のとおり。

- 行の checkbox、全選択の切り替え(`select-all-toggle`)、「n/n 件を選択」(`selection-count`)を**撤去**する。
  総件数そのものを出すかは**このtaskの裁量**(開発者の「並び順buttonや警告より下へ移したい」という
  指摘は、帯が無くなることで論点ごと消えた)。
- **行の × は残す。** 左swipeへは移さない(`T03` の決定。desktopとaccessibilityに代替導線が要るため)。
- 読み込み帯の **`すべて外す` を `一覧を空にする` へ改名**する。**`T08` から預かった置き場所の論点は
  これで解ける** — `clearFiles` の1義になり、一覧側の選択操作と競合しなくなる。
- **除去の取り消し**(002 REQ-017)を出す。除去前の**位置**へ戻す。取り消しは `setFiles` で
  操作前の並びへ戻せばよく、状態層に新しい操作を足さない。
- 通知の見た目(閉じる操作)は [`T25`](../T25-dismissible-toast/task.md) が持つ。
  **取り消しの通知もそちらの形に揃える**(順番はどちらが先でもよい)。

**状態層は変えない。** `toggleSelection`/`selectAll`/`clearAll` は 002 REQ-004 として残る
(001・005 が選択の概念を持ち続けるため)。UI が外さないので、製品では全件が選択された状態が保たれる。

## machine検証する範囲(着手時の宣言)

**閉じる**: checkbox・全選択トグル・「n/n 件を選択」が出ないこと / 一覧の全件が変更後名を持つこと /
行の × と「一覧を空にする」が**取り消せる**こと(元の位置へ戻る・占有名も戻る) /
何も外れていないときは通知を出さないこと / `一覧を空にする` の文言 /
`008:T16` の (i)(狭幅・大きい文字でヘッダの数字が消えない)が続いていること。

**閉じられない範囲と引き受け先**: 実機での**押しやすさと見え方**(× の当たり判定、取り消しの通知が
下部バーに隠れないか)→ このtaskの `manual-verification.md`。通知の**閉じる操作**は
[`T25`](../T25-dismissible-toast/task.md)。余白・字体は [`T10`](../T10-spacing-and-typography/task.md)。

## 実装の記録(2026-09-18)

### 撤去したもの

- 行の `Checkbox` と `onToggle`(002 REQ-016)。
- `_SelectAllButton`(`select-all-toggle`)と「n/n 件を選択」(`selection-count`)。
  **ヘッダは総件数だけ**になった(`fileCountKey` = `N 件`)。「いま何件を扱っているか」は
  実行前に知りたいので**件数そのものは残す**(`T03` が提示の裁量としてこのtaskへ渡した)。

**状態層は触っていない。** `toggleSelection` / `selectAll` / `clearAll` は 002 REQ-004 として残る —
001 と 005 は選択の概念を持ち続けており、controller の unit test(VER-001)がそのまま検証する。
UI が外さないので、製品では**全件が選択された状態が保たれる**(REQ-008)。

### 取り消し(002 REQ-017)

`lib/ui/file_list/removal_undo.dart` の `removeUndoably` に1か所へまとめ、**行の ×** と
**「一覧を空にする」**の両方が通る。

- **控えてから外す。** `items` を丸ごと控え、取り消しでは `setFiles(控え)` で戻す。
  **末尾へ付け足さない**ので元の位置が保たれる(代表例6c。対照 `M294`)。
- **占有名も控える。** `setFiles` は「置き換え後の folder と無関係になる」占有名を捨てるので、
  戻さないと**外して戻しただけで一覧の重複警告が弱くなる**(005 REQ-026。対照 `M296`)。
- **何も外れていないなら通知しない**(`removeFile` は一致が無ければ無変化。002 REQ-009。対照 `M295`)。
- **状態層に新しい操作を足していない** — `setFiles` / `setOccupiedNames` は 002 が既に持つ操作である
  (`T03` が 004 spec へ「ポート契約に操作を足さない」と書いたのと同じ理由)。

### 「すべて外す」→「一覧を空にする」

`clearFiles` の1義になったので改名した(`T03` の決定)。**`T08` から預かっていた置き場所の論点は
これで閉じる** — 一覧側に選択の帯が無くなり、狭幅で件数と場所を取り合う構図が消えた。

### 触った既存test

- `file_list_view_test.dart`: checkbox / 全選択トグルの widget test を**REQ-016 の検査へ置き換えた**。
  REQ-004 は状態層の要求になったので、ここでは検証しない(VER-001 の controller test が持つ)。
- `row_presentation_test.dart`: (i) の錨を `selection-count` から `fileCountKey` へ。
  (h) の「狭幅で削られるのは更新日時の側」は、**checkbox が消えて行が広がり 360dp では収まるように
  なった**ので、**足りなくなる幅(280dp)で測る**ように変えた。固定したいのは
  「足りなくなったとき**どちらから**削るか」であり、保証は変えていない。
- `warning_display_test.dart`: 描画された行数を `Checkbox` の数で数えていたので、
  **preview の枠(`RowPreviewView`)**で数えるようにした(枠は preview を出せない file でも必ず在る)。
- `load_affordance_test.dart`: 文言を `一覧を空にする` へ。代表例6d(空にした直後も戻せる)を足した。

## mutation の記録

`M291`〜`M298` を足し、**`M188`(`008:T16` の独立reviewが置いた対照)を貼り直した**。

**`M188` は最初 SURVIVED した。** 「n/n 件を選択」を総件数へ置き換えたことで、元の形
(`maxLines` を 1 にして省略する)が**等価mutantになった** — `1000 件` は短く、狭幅・文字倍率3.0でも
省略が起きないためである。`AGENTS.md` の手順どおり**全件でも確かめ**(SURVIVED)、
**切り詰めが実際に起きる形(件数の幅を固定する)へ替えた**。保証(`1000 件` が `1…` と読めてはならない)は
変えていない。`M186`(ヘッダを `Wrap` から `Row` へ戻す)が**いまも KILLED** であることも確かめた。

```text
9 mutations: 9 KILLED, 0 SURVIVED, 0 SKIPPED
M188(貼り直し後) / M291 / M292 / M293 / M294 / M295 / M296 / M297 / M298
```

## 検証の記録

**この表は commit ごとに置き換える。**

| 検査 | 結果 |
|---|---|
| `flutter test` | PASS(883) |
| `flutter analyze` | PASS(No issues found) |
| `dart format --output=none --set-exit-if-changed .` | PASS(0 changed) |
| `mutation_check.py --list`(全表) | `289 mutations, 0 with an unexpected match count` |
| 範囲を絞った mutation | `M188`/`M291`〜`M298` = **9 KILLED, 0 SURVIVED**。`M186` = KILLED(据え置きの確認) |
| `workspace.py check specs` | PASS(8 plans, 79 tasks) |
| Android実機 | **未実施**(`manual-verification.md`) |

## Current state / handoff

- Last checkpoint: 実装と機械検証が完了(`flutter test` 883 PASS、範囲を絞った mutation 9 KILLED)
- Blocker category: review
- Waiting for: 独立review(Sonnet)
- Requested action: なし(人間の作業は実機確認から)
- Evidence revision: branch `asdd/008-ui-alignment/T04-implement-selection-flow`(`dev@161b024` から作成)
- Next Agent action: 独立reviewを回し、PASSしたら実機確認を依頼する
