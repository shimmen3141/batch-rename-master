# T20 ルール設定buttonと実行buttonの提示を整える

## 目的

下部バーの2つのbutton——ルール設定と実行——を参考designの形へ寄せ、**何が押せるのか・
何が起きるのか**がbuttonの見た目から読めるようにする。

## 入力と依存

- **`T17`で承認された 002 / 005 spec**(実行可否の部分)。**承認前に着手しない。**
  見た目と文言だけなら仕様の承認を待たずに設計できるが、**`T17`が「ルール単位の警告表示を
  外す」形を確定させないと、このbuttonの構成そのものが決まらない**ので、着手は`T17`の後にする
  (`dependsOn`もそうしてある)。実行可否と見た目は**commitを分けること。**
- `docs/design/Bulk Renamer.html`。**適用する画面範囲は下部バーの2つのbuttonに限る。**
  該当する土台は `execLabel` / `execBg` / `execFg`、ルール設定buttonの2行の形と`編集`chip、
  `ruleSummary`。
- 現行実装: `lib/ui/file_list/file_list_view.dart`の`_RuleButton`と実行button。
  **`_RuleButton`は`008:T16`が参考designの2行の形へ作り直した**が、警告の種別を載せていた。
  `T17`で**ルール単位の警告表示が無くなる**ので、そのぶんを外すのもこのtaskである。
- **`005:T09`の成果**(下部固定バーへ集約した実行導線)。**バーの構成そのものとルール設定
  sheetの開き方は動かさない。**

## 変更範囲

観測の出所は[`T16`のtask.md](../T16-implement-row-level-warnings/task.md)の
「受領したUIの改善要望(2026-09-02、原文)」。番号は同節のもの。

- **要望9(押せると分かる形)**: 「参考designだと全体がボタンと認識しやすいが、現状だと右の
  編集ボタンを押す必要があると錯覚する。」**button全体が一つの押下対象に見える**形にする。
- **要望9(ルールの表示)**: 「参考designだと`[元の名前][01][YYYYMMDD]`のようなトークン的な
  表示だが、現状は『連番1桁+作成日時』のような説明的な表示になってしまっている。」
  `describeToken`の連結をやめ、トークンを**そのまま並べた形**にする。
- **要望9(アイコン)**: 左のアイコンを参考designのものへ合わせる。
- **要望14(実行buttonの文言)**: 参考designの`execLabel`は
  `対象を選択してください` / `N 件をリネーム` / `ルールを設定してください`の3状態を持つ。
- **要望1(実行可否)**: 「ルールに元の名前だけを設定したときにリネームボタンを押せるように
  するかは考える余地がありそう。参考designではルール未設定時と同様に押せないようになっている。」
  **`T17`が決めた形に従う。**`T17`より先にこの部分を実装しない。
- **`T17`の結果に伴い、ルール設定buttonから警告の種別表示を外す。**

### 他taskとの分担

- 行の提示は`T18`、詳細modalは`T19`。**下部バーはこのtaskが持つ。**
- 余白・字体は`T10`。
- 実行前確認dialogとその文言は`T14`。

## 引き受けた申し送り(`008:T17`の独立reviewから)

**`test/spec_005_rename_exec/occupied_names_test.dart:386`「空ベース名が同一 folder に2件 +
強制実行でも例外を投げない」が、新しい REQ-019 の実装で FAIL する。** このtestは
`RenameExecutionController.execute` を直接呼んで `expect(outcome, isNotNull)` を置いており、
**0件ガードを入れると `execute` が `null` を返して落ちる**(空振りではなく赤くなる)。
このtestは独立reviewのP1由来の回帰guardなので、**3件目(変更が生じるファイル)を足して経路を残すこと。**
消したり skip したり assertion を緩めたりしない。

## 着手時の宣言(2026-09-04)

### machine検証する範囲

**CIで閉じるのは次である。** `AGENTS.md` は「CIで実行できない領域を含むtaskは、着手時に
machine検証する範囲と引き受け先を宣言する。**宣言の外側の指摘は安全網の穴として扱う**」
としている。

- ルール設定buttonが**一つの押下対象**であること(当たり判定をwidget testで測る)。
- 設定中のルールが**トークンを並べた形**で描かれ、**説明文になっていない**こと(両方向)。
- 実行buttonのlabelの状態分岐と、`N 件をリネーム` の N が**変更が生じるファイルの件数**に
  一致すること(両方向)。
- **変更が生じるファイルが0件のとき、実行が始まらず実ファイルを1件も変更しない**こと
  (005 REQ-019)。**buttonの無効化だけでなく、`RenameExecutionController.execute` の
  境界でも止める** — 別経路から実体を変更できる実装を排除する。
- **狭幅(< 840dp)と広幅(≥ 840dp)の両方。**広幅では `onEditRule` を渡さないと
  ルール設定buttonが生成されず、何を測っても通る(`T16` が2回この空振りを作った)。

### machineで閉じられない範囲と引き受け先

- **見た目が「押せると分かる」か**(要望9の主観的な部分)。構造(当たり判定が一つ・枠と塗りが在る)
  はCIで押さえるが、**実際に押せると見えるかは実機のmanual確認**で見る。
  `T18` が同じ型の穴(穴B)を `008:T10` へ渡している。**引き受け先: `008:T10`**(色・階層)。
- **余白・字体・アイコンの選択の妥当性。引き受け先: `008:T10`。**

## 参考designから離れた点(`AGENTS.md`: 離れた理由を書く)

**実行buttonのlabelを、参考designの3状態ではなく4状態にした。**

参考designは `execLabel: !sel.length ? '対象を選択してください' : changeCount ? changeCount + ' 件をリネーム' : 'ルールを設定してください'`
で、**「ルールが空」と「ルールはあるが変更が生じるファイルが0件」を同じ文言へ畳んでいる。**

**これは`T17`で承認された 005 spec と両立しない。** 例22a は「ルールが `[元の名前]` 1つだけ」
のとき「**命名ルールが未設定である旨は出さない — ルールは設定されている**」と定めており、
REQ-020 の案内は**ルールが空のときだけ**である。designの文言をそのまま使うと、ルールを
設定している利用者へ「ルールを設定してください」と出すことになる。

そこで**0件の理由で文言を分けた**(REQ-019 が「分岐は (a) ルールが空であるかどうかの1つだけ」
と定める分岐に一致する)。**判定はルールの形ではなく生成後名と現在名の比較で行う**
(用語「変更が生じるファイル」、例22b)。

## ルール単位の警告表示を両方の layout から外した(2026-09-04)

**開発者の決定である。** `T17` の記録にある原文は「**ルールの警告は無くす。**これによって、
ルールの警告と個々のファイルへの警告の2つに分かれていたものが、個々のファイルへの警告
だけになって認知負荷が下がると思う」。

表示は**2か所**にあった。**T20 の変更範囲は(1)だけだったが、2026-09-04 に開発者が
「両方とも今回外す」を選んだ。**

| | 場所 | 扱い |
|---|---|---|
| (1) | 狭幅: 下部バーのルール設定button内(`_RuleButton` の `RuleWarningNotice(compact: true)`) | **外した**(T20 の元の範囲) |
| (2) | 広幅: 右ペイン上部(`rule_builder_workspace.dart` の `RuleWarningNotice`) | **外した**(範囲を広げた) |

**片方だけ残すと、開発者が減らそうとした「警告が散らばっている」状態が desktop 側に
残る**ため、両方を同時に外した。`RuleWarningNotice` と `ruleWarningKinds`、
`ruleWarningNoticeKey` は未使用になったので削除した。

**種別が読めなくなったわけではない。** 005 REQ-009 は場所を課していない
(「場所・文言・UI 部品は自由とする点に残す」)。

- **(1) 各ファイルの種別**: **行**が出す(`008:T18`)。
- **(2) 原因の説明を件数ぶん繰り返さない**: 説明は**詳細dialog**が1つだけ持つ。
  常設の提示は行の種別で、`REQ-021` のまとめ規則で有界である。
- **(3) 全件と説明**: ヘッダの件数(`⚠ N 件の問題`)から開く詳細dialog。

### 落とした対照(`008:T16` が置いたもの)

**全表の `--list` が `241 mutations, 12 with an unexpected match count` を返して検出した。**
`008:T18` の `M180` と同じ型(対照が無言で失効する)なので、**1件ずつ中身を見て分けた。**

| 扱い | mutation | 理由 |
|---|---|---|
| **`find` を追随させた** | M192 / M196 / M199 | 保証が新しい button の中に生き残っている(要約が1行であること、ルール編集の入口があること)。M196 は押下対象が `OutlinedButton` から `InkWell` へ変わっただけ |
| **落とした** | M177 / M183 / M189 / M190 / M193 / M200 / M201 / M202 / M203 | **守る対象のcodeが無くなった。** ルール単位の警告表示そのものと、その余白・折り返し・空判定に対する対照である。`find` が一致しないまま残すと、**そこを見ていないことが見えなくなる** |

**落とした9件が守っていた保証(常設側の占有が原因の数に依らない)は、新しい形で置き直した** —
`warning_display_test.dart` の「狭幅と広幅のどちらでもルール単位の警告表示が無い」と、
広幅で**原因 0 / 2 / 3 / 5 / 10 本のいずれでも `RuleBuilderView` の rect が同一である**ことを
固定する検査(相対比較ではなく絶対値)。

## 参考designから離れた点(その2): ルール要約の日時トークン

参考designの `summary()` は日時トークンを `[` + 書式 + `]` で書くが、**003 は作成 / 更新 /
現在の3つの基準を持つ**(designは1種類)。書式だけにすると `[YYYYMMDD]` がどの基準か
読めなくなるので、**基準を残して `[作成日時 YYYYMMDD]` とした。**トークン的な字面である
ことは保っている(要望9が求めているのは「説明的でないこと」)。

## 受け入れ証拠

- ルール設定buttonが**一つの押下対象**であることを、tapの当たり判定をwidget testで検査する
  (buttonのどこを押してもルール設定が開く)。
- 設定中のルールが**トークンを並べた形**で描かれることを検査する。**説明文になっていない**
  ことを両方向で固定する。
- 実行buttonのlabelが**4状態**(対象なし / 変更あり / ルール未設定 / 変更が0件)で切り替わることを検査する
  (着手時は3状態と書いていた。4状態にした理由は「参考designから離れた点」)。
  **`N 件をリネーム`の N が実際の変更件数に一致する**ことを含める。
- `T17`が実行可否を変えた場合、**実ファイルを1件も変更しない**ことを検査する
  (005 REQ-019 が「ボタンだけ無効にして別経路から実行できる実装」を排除している型)。
- **狭幅(< 840dp)と広幅(≥ 840dp)の両方**で検査する。**広幅では`onEditRule`を渡さず
  ルール設定buttonが生成されない**(`rule_builder_workspace.dart`の`_buildWide`)。
  渡さないまま測ると何を検査しても通る(`T16`が2回この空振りを作った)。
- `tool/mutations.json`へmutationを足して`KILLED`を確認する。生の出力を報告へ貼る。
- **`005:T09` / `005:T05` のmanual手順と`docs/development/emulator-verification.md`**が、
  作り直したbuttonの見た目に合っている(`T16`が同じ理由で3か所を直している)。
- `flutter test` / `flutter analyze` / `dart format --output=none --set-exit-if-changed .` がPASS。
- `manual-verification.md`でAndroid実機の狭幅表示を確認する。
- exact rangeの独立reviewがPASSする。

## mutation の記録

**必ず `tool/mutations.json` 全体を `--list` してから本番を回す**(`008:T18` の
独立review attempt 3 で `M180` が無言で失効した型)。**このtaskでも実際に12件の
不一致が出た**(上の「落とした対照」)。

```console
$ python3 <asdd-plugin>/scripts/mutation_check.py tool/mutations.json --root . --list
232 mutations, 0 with an unexpected match count
```

### M192 は等価mutantだった(2026-09-16 に訂正)

**以前の記録は「M192 を閉じた」としていたが、事実に反していた。** 長いルールの検査を足したあと
**再実行の出力を貼らずに「閉じた」と書いた。** 独立review attempt 1 が full suite で再実行し、
M192 が SURVIVED のままであることを示した(F1)。

- **なぜ落ちないか**: `overflow: TextOverflow.ellipsis` は `maxLines` が null でも**最初にあふれる行で
  切る**(Flutter `TextPainter.ellipsis` の doc)。`maxLines: 1` を外しても画面が変わらない。
  **等価mutantで、どのtestでも落とせない。**
- **足した検査は本物だった**: 行数制限と省略記号を**両方**外す `M241` を足し、KILLED を確認した。
- **M192 は対照として残す**(`AGENTS.md`「対照として置いたものも落とさない」)。note に等価である理由を書いた。

このtaskが関わる分に `M43`(F2 の回帰が守る型)と `M241` を加えた20件を、**full suite**(`flutter test`)で回した。

```console
M43 | KILLED | lib/data/rename_exec/occupied_names.dart | ...
M192 | SURVIVED | lib/ui/file_list/file_list_view.dart | ... | exit 0: the tests passed with the mutation applied
M241 | KILLED | lib/ui/file_list/file_list_view.dart | ...
20 mutations: 19 KILLED, 1 SURVIVED, 0 SKIPPED
```

(M83 / M196 / M199 / M209〜M212 / M231〜M240 はすべて KILLED。)

## 実機確認の結果(2026-09-16)

| | |
|---|---|
| 対象 | `lib/` の最終commit `1f9c8b2`(ビルドしたのは branch 先端 `ff30cb6`。`git diff 1f9c8b2..ff30cb6 -- lib/` は空) |
| 端末 | Android(開発者の手元) |
| 結果 | **手順1〜4のすべての確認が成立** |

開発者の報告(原文):

- 手順1〜3: 「確認事項はすべて問題ありません。」
- 手順4: 「確認事項はすべて問題ありません。手順書の誤りについても、代わりの手順で対応できました。」
  — 手順4は「選択を100件以上」と書いていたが fixture は27件しかなく、Agent が示した
  代替(連番1桁・開始1で27件を全選択)で確認した。`manual-verification.md` を同じ形へ直した
  (記録だけの変更で、`lib/` は動いていない)。

### あわせて受領した指摘(このtaskの欠陥ではない)

**原文のまま。**

> ファイルの数を9件にし、連番を1桁・開始番号を10にすると、ファイルには正常に10~18の連番がつきますが、表示では連番の桁不足の警告が表示されます。少し混乱を招くと思いました。そもそも桁数がファイル数より小さくできなくするべきだと思いました(ファイルが100件あるなら2桁以下は選べない)。また、0埋めをしたくない場合を考えて、0埋めと0埋めなしを選択肢で選べるようにするのも一つの方法だと思いました。

**`T20` の範囲ではない。** 警告を出す判定は 001 の桁不足(「連番の計算値が `10^桁数` 以上」)で、
`T20` は判定も連番のエディタも変えていない。**`T21` として登録した。**

> 将来的には、命名ルール設定ボタン上の表示を、[元の名前][01...]のような表示からさらに発展させて、実際に設定しているチップのUIを並べるのもよいと思いました。警告詳細などで実際に警告の原因となっているUIに言及するときも、「3番目のトークン」のような説明でなく、説明文にチップのUIを埋め込むと視覚的にわかりやすくなりそうです。

**「将来的には」と本人が書いているので、`product-map.md` の将来候補へ置いた。** 断定へ強めない。

## 独立review

### attempt 1(2026-09-16、range `b833603...8d21497`)— FAIL

| # | 重大度 | 分類 | 指摘 | 扱い |
|---|---|---|---|---|
| F1 | P1 | 成果物の欠陥 | M192 を「閉じた」とした記録が事実に反する(等価mutantで full suite でも SURVIVED) | **直した**(上の「M192 は等価mutantだった」、`M241` を追加) |
| F2 | P2 | 成果物の欠陥 | `occupied_names_test.dart` の回帰に足した `c.txt` が同じ `/A` にあり、reason「除外される file しかいない folder でも覆う」が成り立たない | **直した**(`c.txt` を `/B` へ移した。2か所) |
| F3 | P3 | 成果物の欠陥 | `_RenameActionBar.warnings` が未使用で、docが古い(「ルールが空のとき無効」)。`changedFileCount` が build ごとに 001 の評価をもう一度走らせる | **受容し `008:T14` へ送った** — `lib/` を動かすと実機証拠(`1f9c8b2`)が失効する。正しさに影響しない。`T14` は同じ `file_list_view.dart` の実行前確認dialogを持つ |
| F4 | P3 | 成果物の欠陥 | 検証の記録が `73 tasks` のまま | **直した** |
| F5 | P3 | 安全網の穴 | `_request` の0件ガード(`file_list_view.dart:180`)を外しても全testが通る | **残余riskとして受容し `008:T14` へ送った。** 3条件: (1) 製品経路 — 該当する。(2) データ損失等 — **該当しない**(`execute` の門が止め、M231/M232 が KILLED)。(3) CIで閉じられる — 該当する。(2) を満たさないため |
| F6 | P3 | 成果物の欠陥 | PR本文が `Refs #—` のまま、同じbranchの別変更を書いていない | **直した**(PR本文を更新) |

### attempt 2(2026-09-16、range `b833603...e10226a`)— **PASS**

attempt 1 の F1/F2/F4/F6 が直っていること、F3/F5 が `T14` に記録されていることを確認した。
`lib/` は `1f9c8b2` から変わっておらず、実機証拠はそのまま有効。P0/P1 は無い。P3 が3件。

| # | 分類 | 指摘 | 扱い |
|---|---|---|---|
| 1 | 成果物の欠陥 | `warning_display_test.dart:435-437` のコメントが削除済みの `RuleWarningNotice` で説明している(assertion は正しい) | **`008:T19` へ送った** — 同じtestの入れ物を作り直すtaskで、review済みの範囲をここで動かさない |
| 2 | 成果物の欠陥 | 受け入れ証拠の行が「3状態」のまま | **直した**(記録のみ) |
| 3 | (F3 の再掲) | `_RenameActionBar.warnings` のdoc | 既に `T14` へ送った |

```console
flutter test:       00:27 +791: All tests passed!
flutter analyze:    No issues found!
dart format:        Formatted 119 files (0 changed)
workspace.py check: PASS: 8 plans, 74 tasks
mutation --list:    232 mutations, 0 with an unexpected match count
M43 KILLED / M192 SURVIVED(等価) / M241 KILLED
```

### 引き受けた文言(`008:T03`から。2026-09-18)

- **実行buttonの `対象を選択してください`**(`rename_warning_view.dart` の `executeLabel`、
  `selectedCount == 0` の分岐)。`T03` が行の checkbox を廃止して「一覧＝rename対象」にしたので
  (002 REQ-016)、この分岐は**「一覧が空」**を意味するようになる。文言の見直しは 005 REQ-019/020 の
  範囲なのでここが持つ。**判定そのものは変えない** — 0件で実行へ入らないことは 005 REQ-019 のままである。

## Current state / handoff

**この節は主張を持たない**(`008:T18` で5回続けて落ちた型を避ける)。検証結果は
「検証の記録」、範囲の判断は上の各節を読むこと。

- Last checkpoint: **独立review attempt 2 が PASS**(2026-09-16)。`lib/` は `1f9c8b2` から動いていない
- Blocker category: なし
- Evidence revision: branch `asdd/008-ui-alignment/T20-rule-and-exec-bar`(`dev@b833603` から作成)、PR #165(Draft)。**`lib/` の最終commitは `1f9c8b2`**
- Next Agent action: なし(PR #165 の merge 後に `dev` 上の結果を確認する)

## 検証の記録

**この表は commit ごとに置き換える。過去の値を積み上げない。**

| 検査 | 結果 |
|---|---|
| `flutter test` | PASS(791) |
| `flutter analyze` | PASS(No issues found) |
| `dart format --output=none --set-exit-if-changed .` | PASS(0 changed) |
| `mutation_check.py tool/mutations.json --root . --list`(全表) | `232 mutations, 0 with an unexpected match count` |
| `workspace.py check specs` | PASS(8 plans, 74 tasks) |
