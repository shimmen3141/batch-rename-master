# T47 フッターのボタンの形を揃え、ルールをチップで見せる

## 目的

下部の固定バー(フッター)の2つのボタンの見た目を揃える。ルール設定ボタンは、ルールが未設定のときと設定済みのときで形が違う。これを設定済みの形へ統一し、リネームボタンの角丸もそれに合わせる。あわせて、ルール設定ボタンの `[元の名前]01` のような字面の要約を、ルール設定画面と同じチップの表示へ替える。

## 出所

開発者の要望(2026-09-30、原文): 「新たなタスクとして、フッターのボタンのデザインを改善したいです。現状、ルール設定時と未設定時でルール設定ボタンの形状が異なります。ルール設定時の形状に統一してください。それに伴い、リネームボタンの角丸の大きさもルール設定ボタンの角丸の大きさに合わせてください。ルール設定ボタンに表示される[元の名前]のようなテキストも、実際のチップに基づいた表示にしたいです。」

product-map の将来候補「ルールをchipのUIで見せる」(`T20`の実機確認で開発者が挙げた、2026-09-16)のうち、**下部バーの部分**にあたる。警告の詳細に chip を埋め込む部分はこのtaskに含めない。

## 開発者の決定(2026-09-30)

チップの見せ方を3案(値の1段 / 種類名の1段 / 設定画面と同じ2段)で尋ね、**2段(設定画面と同じ)**を採った。補足(原文): 「設定画面と同じにするが、×ボタン等は不要です。その分横幅を狭められるなら狭めてください。未設定時はボタン全体のデザインは揃えつつ、文言はそのままで色だけ白にし、左のアイコンや右の飾り、『命名ルール』の文字は不要です。」

- チップ: 上段に種類名、下段に一覧の1件目で描いた値(`TokenChip` と同じ色・語)。**削除の×と、そのために取っていた幅は持たない。** 入りきらないときは右端を「+N」にまとめる(質問の前提として示し、異論は無かった)。
- 未設定: 設定済みと同じ形(面の色・枠・角丸)のボタンに、**＋のアイコンと文言「命名ルールを設定する」を白で**出す(面は塗らない。白にするのは文字と＋だけ)。✎の四角、「編集」の飾り、「命名ルール」の見出しは出さない。**文言を「変更する名前を設定する」から「命名ルールを設定する」へ変えた**(同日、開発者の確認への回答: 「+のアイコンは出してよいです(これも文言と同じく白)。また、文言は『命名ルールを設定する』に変更することにします」)。
- リネームボタン: 角丸をルール設定ボタンと同じ(`ruleButtonRadius`)にする。

## 境界

- 仕様は変えない。005 REQ-019(ルールが空なら実行を始めない)・REQ-020(未設定であることが読める。バナーの案内が持つ)の判定と提示は動かさない。ボタンの見た目は視覚デザインで、仕様の対象外。
- ルール設定画面のチップ(`TokenChip`)の見た目・操作は変えない。
- `docs/design/Bulk Renamer.html` の下部バーのうち、**ルール設定ボタンとリネームボタンの見た目**に限って照合する。土台のルール設定ボタンは字面の要約(`[元の名前][01]`)なので、チップにすることは土台から離れる(開発者の決定による)。

## 受け入れ証拠

- widget test: 未設定と設定済みでルール設定ボタンの外形(角丸・枠・面)が同じ。未設定では＋と「命名ルールを設定する」が白で、✎・「編集」・「命名ルール」の見出しが無い。設定済みではトークンごとに2段のチップ(種類名・値)が並び、×が無い。入りきらないときは最後に見えるチップが途切れてフェードし、数は出さない(2026-09-30 の決定。当初は「+N」だった)。未設定のbuttonは設定済みよりひとまわり小さいくらいの高さ(2026-10-01 の指定)。フェードは列の右端まで届き、薄くするのは右端の 20px だけ(2026-10-01 の指定)。リネームボタンの角丸がルール設定ボタンと同じ。ボタン全体が一つの押下対象であること(2026-09-02 の要望9)を保つ。狭幅・文字 2.0 ではみ出さない。
- 既存の005の下部バーのtestが継続PASS(または新しい見た目に合わせた改訂で、assertionを緩めない)。
- `flutter test` / `flutter analyze` / `dart format --output=none --set-exit-if-changed .` がPASS。
- `manual-verification.md` で Android エミュレータの見た目を確認する。
- 独立reviewがPASSする。

## 作業記録

- 2026-09-30 / 起票・着手は Claude Opus 5.5。branch `asdd/008-ui-alignment/T47-footer-button-unification`、起点 `dev`@`5bfcc7a`。


### 実装(`55739ec`)

- `_RuleButton`(`lib/ui/file_list/file_list_view.dart`): 外形(面の色・枠・角丸 `ruleButtonRadius`)を未設定・設定済みで共通にし、中身だけを入れ替える。未設定は＋と「命名ルールを設定する」を白で中央に出す。以前の未設定は `FilledButton.icon`(シアンの塗り)だった。
- `RuleChipStrip` / `RuleSummaryChip`(新規 `lib/ui/rule_builder/rule_chip_strip.dart`): 設定画面の `TokenChip` と同じ色(`tokenHue`)・語(`tokenKindLabel` / `tokenChipValue`)・面の2段のチップ。×と、そのために取っていた幅(`tokenChipDeleteSize`)は持たない。値の幅の上限は設定画面と同じ 132。文字の幅を測り、入りきらない分を右端の「+N」にまとめる(折り返さない — button が伸びて一覧を削らないように)。値は一覧の1件目で描く。`TokenChip` 自体は変えていない。
- 読み上げは字面の要約(`describeRuleSummary`、`[元の名前][01…]`)を `Semantics` で持たせた。
- リネームbutton: `FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: ruleButtonRadius))`。
- 参考デザインから離れた点: 土台のルール設定buttonは字面の要約(`[元の名前][01]`)で、未設定の形は持たない。チップ・未設定の形は開発者の決定(2026-09-30)による。

### testの改訂と追加

- `bottom_bar_presentation_test`: 「ルールが長くてもbuttonが伸びない」は、あふれの前提を `RenderParagraph.didExceedMaxLines` から「+N が出ている」へ替えた(高さの一致の検査はそのまま)。「buttonに出るのもトークンの形」は「設定画面と同じ2段のチップ(種類名が上・値が下・種類の色・×なし・読み上げは字面)」へ書き換えた。足した: 未設定と設定済みで外形が同じ・未設定は＋と文言が白で✎・見出し・`編集`・塗りのbuttonが無い、リネームbuttonの角丸、幅 320/360・文字 2.0 ではみ出さない。
- `empty_rule_test` / `widget_test`: 文言を「命名ルールを設定する」へ。設定済みの要約は字面ではなくチップの中の値で見る。
- **assertionを緩めたものは無い。**

### mutation

- 作り直した: M192(チップの列を折り返させる)・M199(「+N」にまとめず全部並べる)・M241(入りきらない分を黙って落とす)— 字面の行数制限を守っていたものを、同じ保証(ルールが長くてもbuttonが伸びない・隠れたトークンがあると分かる)のチップの形へ。M197(未設定と設定済みの中身を入れ替える)は `find` を追随させた。
- 足した: M577〜M581(リネームbuttonの角丸、未設定の＋・文言を白にしない、チップの上段を落とす、チップの枠を種類の色にしない)。
- `check_mutation_finds.py` → `PASS: 535`。
- 範囲付きで回した(9件): `flutter test test/spec_005_rename_exec test/spec_002_file_list test/spec_003_rule_builder test/widget_test.dart`、対象 `55739ec`。

```text
M192 SURVIVED / M197 M199 M241 M577 M578 M579 M580 M581 KILLED
9 mutations: 8 KILLED, 1 SURVIVED, 0 SKIPPED
```

- **M192(チップの列を `Row` から `Wrap` へ)は等価mutantだった。** 入る数を先に測って決めるので、`Wrap` でも折り返しが起きない。保証が実際に崩れるのは幅の見積もりが実際より小さいときなので、**見積もりからチップの余白を落とす形へ作り直し**、回し直した: `1 mutations: 1 KILLED, 0 SURVIVED, 0 SKIPPED`。

### 実機確認 1回目(2026-09-30、対象 `55739ec`)と、それを受けた変更

- 開発者の結果(原文): 「種別名のほうが中身より長い場合(区切りや1文字のテキストなど)、中身がチップ内で左寄せになってしまっています。中身は中央寄せにしてください。」「『[元のファイル名]』を『ファイル名』にしてください。種別名を『元名』から『元の名前』に変えてください。設定内のチップの方も変えたいです(このタスク内でやった方が良いならまとめて変えてください)。」「『+N』を白にしてください。」「『命名ルール』の上には余白があるがチップとの余白が小さいので、チップとの余白を少し設けつつ上の余白を少しだけ削ってください。チップの下の余白も同じだけわずかに削ってよいです。ボタン内の左右の余白は削らないでください。」それ以外(形の統一、未設定の見せ方、角丸、文字サイズ最大)への指摘は無かった。
- 実装(`06f163b`):
  - チップの値を中央寄せにした(`IntrinsicWidth` + 横いっぱいに広げて `TextAlign.center`。種類名は左のまま。設定画面の `TokenChip` と同じ配置)。
  - `tokenKindLabel` の元の名前を「元名」→「**元の名前**」、`tokenChipValue` を「[元のファイル名]」→「**ファイル名**」。**設定画面のチップと下部バーは同じ関数を使うので、このtaskでまとめて変えた。**
  - 「+N」を白にした。
  - ルール設定buttonの上下の内側の余白を 11 → 8、「命名ルール」とチップの間を 4 → 7 にした(`ruleButtonVerticalPadding` / `ruleButtonHeadingGap`)。左右(12)は変えていない。未設定も同じ外形なので上下は同じだけ詰まる。
- testを直した・足した: 設定画面の test(`rule_builder_view_test`)と下部バーの test の語を新しい語へ。値が中央寄せ(種類名のほうが長い区切り `_` のチップ)、「+N」が白、見出しとチップの間・上の余白の値。
- mutation: M582〜M586 を足した(値の中央寄せを外す、「+N」を白にしない、間を 4 へ・上下を 11 へ戻す、値を以前の字面へ戻す)。`check_mutation_finds.py` → `PASS: 540`。
- 範囲付きで回した(9件): `flutter test test/spec_005_rename_exec test/spec_003_rule_builder test/widget_test.dart`、対象 `06f163b`。

```text
M192 M199 M580 M581 M582 M583 M584 M585 M586 すべて KILLED
9 mutations: 9 KILLED, 0 SURVIVED, 0 SKIPPED
```

### 実機確認 2回目(2026-09-30、対象 `06f163b`)と、それを受けた変更

- 開発者の結果(原文): 「『命名ルール』の上の余白をもう少しだけわずかに狭めつつ、チップとの余白をその分ひろげてください。チップの下の余白も同じだけわずかに削ってよいです。ボタン内の左右の余白は削らないでください。」「『+N』について、+の前後に空白をいれてください。チップとの間とNとの間に空白が入るイメージです。」「上記以外は問題ありません。」
- 実装(`c5f94ad`):
  - 上下の内側の余白 8 → 6、「命名ルール」とチップの間 7 → 9。左右(12)は変えていない。
  - 「+N」を「 + N」にした(`ruleChipOverflowLabel`)。入る数を決める幅の見積もりも同じ文字列で測る。
  - **チップの列の高さをチップ1つ分に固定した。** 「+N」の幅が広がったことで、幅 360・文字 2.0 でチップが1つも入らず「+N」だけになるルールが現れ、列が文字の高さまで縮んで button が低くなり、一覧の高さが変わった(`row_presentation_test`「種別が 1 つ増えても、増える高さは 1 行ぶんで止まる」が `lost = -5` で落ちた)。**空白を足す前からの弱点**(チップが1つも入らないと高さが変わる)で、今回の変更で表に出た。
- testを足した: 「+N」の文言が `^ \+ \d+$`、チップの列の高さがチップの高さと一致し「+N」だけでも変わらない(文字 1.0 / 2.0)。
- mutation: M584・M585 の `find` を新しい値へ追随させた。M587(+ の前後の空白を外す)・M588(列の高さを固定しない)を足した。`check_mutation_finds.py` → `PASS: 542`。
- 範囲付きで回した(7件): `flutter test test/spec_005_rename_exec test/spec_002_file_list test/spec_003_rule_builder test/widget_test.dart`、対象 `c5f94ad`。

```text
M192 M199 M583 M584 M585 M587 M588 すべて KILLED
7 mutations: 7 KILLED, 0 SURVIVED, 0 SKIPPED
```

### 「+N」の飛びと、フェードの採用(2026-09-30、実機確認3回目の途中)

- 開発者の観測(原文): 「チップがギリギリ表示される状態で新しくチップを追加したとき、『 + 1』が入りきらずに一気に『 + 2』まで飛んでしまい、違和感があります。かといって、余裕があるのに『 + 1』で置き換えたくはありません。」
- Agentが3案を出した: A(最後のチップを省略して細くし「+1」の場所を作る)、B(数を出さず、最後のチップを途切れさせてフェードする)、C(いまのまま)。推奨はA。
- **開発者の決定**(原文): 「案AとBを組み合わせます。『 + N』が入りきらない場合は最後のチップをフェードさせつつ『 + N』を表示します。フェードさせるチップはNに含めません。これにより、チップを追加していくと『フェード』→『フェード + N』という順番で表示が変わるはずです。『フェード + N』が入りきらずにいきなり『 + 2』に飛ぶことは許容します。」
- **同日、実装の途中で開発者が決定を変えた**(原文): 「すみません、やっぱり+Nはやめて最後のチップをフェードさせるだけにします。」→ **案B** を採る。
- 実装の方針: 全部入るならチップだけ。入らなければ、入る分を並べ、次のチップを残りの幅で途切れさせてフェードする。**それより後ろのチップは出さず、数も出さない。** フェードのチップを置ける幅が下限(24)に満たなければ、1つ手前のチップをフェードにする(続きがあることは常にフェードで示す)。
- 実装(`b63f121`): `RuleChipStrip` の並べ方を `_layoutChips` にした(全体を出す数 + フェードのチップの幅)。フェードのチップは本来の幅で描いて `ClipRect` + `SizedBox(width)` で切り、`ShaderMask`(左 35% から右端へ透明)で薄くする(`_FadedChip`、key `ruleChipFadeKey`)。「+N」の表示・文言(`ruleChipOverflowKey` / `ruleChipOverflowLabel`)・白の字体を取り除いた。列の高さはチップ1つ分に固定したまま(フェードのチップは `OverflowBox` で描くので、高さを決めておく必要もある)。**途中で一度「フェード + N」を実装したが、commit する前に開発者の決定が変わったので残していない。**
- testの改訂: 「ルールが長くてもbuttonが伸びない」の前提を「+N が出ている」→「フェードが出ている」へ。「+N は白で + の前後に空白」を外した。足した: 幅 320〜440(8刻み)× トークン 1〜7 で、全部入るならフェード無し・入らなければフェードがちょうど1つで見えている最後のチップ・「+」が出ない、ちょうど収まっていたところへ1つ足したときにフェードが出る場面がある。高さの test は「1つ目のチップからフェードしても変わらない」へ。
- mutation: **外した: M583(「+N」を白にしない)・M587(+ の前後の空白)・M590(フェードを N に数える)** — 「+N」そのものが無くなり守る対象が無い。作り直した: M199(入りきらなくても全部並べる)・M241(フェードのチップを出さない)・M589(フェードのチップを残りの幅で切らない)。`check_mutation_finds.py` → `PASS: 541`。範囲付きで回した(5件): `flutter test test/spec_005_rename_exec test/spec_002_file_list`、対象 `b63f121`。

```text
M192 M199 M241 M588 M589 すべて KILLED
5 mutations: 5 KILLED, 0 SURVIVED, 0 SKIPPED
```
- 検証(`b63f121`): `flutter test` +1121 PASS、`flutter analyze` No issues、`dart format` 0 changed。

### 実機確認 4回目(2026-10-01、対象 `b63f121`)と、それを受けた変更

- 開発者の観測(原文): 「少しフェードをかけるのが早いです。左にペンのアイコンがあると思いますが、そのペンアイコンとチップとの余白と同じぐらいの大きさまで右側も伸ばしてください。『フェードの終わりと編集マークの間の余白』と『ペンアイコンとチップの間の余白』の大きさが同じになるイメージです。」
- 4回目の 0・1 は上の指摘のほかは触れられておらず、2(余白)・3(文字サイズ最大)は回答が無い → 5回目で併せて見てもらう。
- 原因(Agentの見立て): (a) 薄くし始めるのがフェードの幅の 35% からで、幅が広いと長い距離をかけて消えていた。(b) 残りが下限(24)に満たず1つ手前をフェードにしたとき、フェードはそのチップの幅で止まり、右に最大 28px の空きが残った。列の右端から `編集` までは 8、✎ からチップまでは 11 である。
- 変更(`9be982b`、test `a4d5c50`): フェードの幅を常に**残りの幅(列の右端まで)**にし、1つ手前をフェードにしたときは次のチップの端もフェードの中に描く。**薄くするのは右端の `ruleChipFadeLength`(20)だけ**にした(`ruleChipFadeStart`)。線形に透明へ向かうので、右端の数 px はほぼ見えず、見えなくなる所から `編集` までは 8 + 数 px ≒ 11 になる見込み。列と `編集` の間(8)は変えていない(変えると全部入る幅が変わる)。
- test: 幅×数の loop に「フェードの右端が列の右端と一致」と「1つ手前をフェードにした経路を通る」を足した。「1つ目からフェードするときもフェードは列の右端まで届く」(画面の幅 240〜360)と「薄くするのは右端の決まった長さだけ」を足した。
- mutation: M589 の find を追随。足した: M593(1つ手前をフェードにしたとき次のチップを描かない)・M594(1つ目からフェードするときフェードを1つ目のチップの幅で止める)・M595(以前の 35% から薄くする)。`check_mutation_finds.py` → `PASS: 544`。範囲付きで回した(7件): `flutter test test/spec_005_rename_exec test/spec_002_file_list`。M594(当時の番号 M591)は最初 SURVIVED(既存の loop は 360 幅以上で、1つ目のチップの後ろに 24 未満しか残らない場面を通らなかった)→ test を足して KILLED。番号は、commit されなかった「フェード + N」の M590 と紛れないよう、回したあとで M593〜M595 へ振り直した。

```text
M199 M241 M588 M589 M590(現 M593) M592(現 M595) KILLED / M591(現 M594) SURVIVED   (対象 9be982b)
M591(現 M594) KILLED   (test を足したあと)
```
- 検証: `flutter test` +1123 PASS、`flutter analyze` No issues、`dart format` 0 changed。

### 実機確認 5回目(2026-10-01、対象 `9be982b`)と、それを受けた変更

- 開発者の回答(原文): 「フェードについては問題ありませんでした。ルール未設定時のルール設定ボタンの大きさが気になります。もう少し縦に大きくしてください。ルール設定後の大きさよりひとまわり小さいぐらいの大きさにしてください。」
- 1(フェードの終わり)は **OK**。2(余白)・3(文字サイズ最大)は触れられていない → 6回目で併せて見てもらう。
- 測った高さ(幅 360): 未設定 34 / 設定済み 78(文字 1.0)、54 / 128(文字 2.0)。
- 変更(`4c2bafc`): 未設定の中身に最小の高さ `ruleButtonEmptyMinContentHeight`(50。文字の拡大に合わせて伸ばす)を与えた。button は文字 1.0 で 64(設定済みの約 82%)、文字 2.0 で 114(同 89%)。
- test: 「未設定のbuttonは設定済みよりひとまわり小さいくらいの高さ」(文字 1.0 / 2.0 で、設定済みより低く、その 0.8 倍以上)。
- mutation: M197・M579 の find を追随、M596(最小の高さを外す)・M597(文字の拡大に合わせない)を足した。`check_mutation_finds.py` → `PASS: 546`。範囲付き(`flutter test test/spec_005_rename_exec test/spec_002_file_list`、対象 `4c2bafc`)で4件: `M197 M579 M596 M597 KILLED / 4 mutations: 4 KILLED, 0 SURVIVED, 0 SKIPPED`。
- 検証(`4c2bafc`): `flutter test` +1124 PASS、`flutter analyze` No issues、`dart format` 0 changed。

### 独立review

reviewerは`gpt-6-luna`(開発者指定)。AGENTS.md の既定は「実装より一段軽いmodel」だが、開発者の指定を優先した(記録)。

- **attempt 1**: `5bfcc7a..52e63fa`(全範囲) — **PASS**(P2 1件)。確認された点: 開発者の指定(外形の共通化・未設定の白い＋と文言・2段チップ・×なし・「+N」・リネームbuttonの角丸)、005 REQ-019/020、要望9(一つの押下対象)、幅の見積もりと狭幅・文字 2.0、testの改訂(緩和なし)。`flutter test` 1117 PASS・analyze・format PASS。reviewerが回したmutation 9件 KILLED。
  - **P2(成果物の欠陥)**: M192 の説明に、字面の時代の「等価mutantで SURVIVED が正しい」が残り、作り直した今の M192(KILLED)と食い違う → 説明を書き直した。`tool/` の差分なので SELF-CHECK にせず、差分reviewを attempt 2 とする。`lib/` は変わらないので、実機確認は並行して依頼した。
- **attempt 2**: `52e63fa..d6b0b6f`(差分review) — **BLOCKED**(指摘なし)。reviewerは`gpt-6-luna`。前回のP2が閉じたこと、差分が触った4 fileに前回までとの食い違いが無いことを確認した。BLOCKED の理由は**検証を `docker compose` 経由で流そうとし、この環境に `docker` が無かった**ことだけである(attempt 1 は同じ環境で直接実行できていた)。`git diff --check` は PASS。
  - **SELF-CHECK**(2026-09-29 の前例に倣う): 所有Agentが同じ HEAD `d6b0b6f` で `flutter test` → `+1117: All tests passed!`、`python3 tool/check_mutation_finds.py` → `PASS: 535 mutation(s)`。reviewer が確認できなかったのはこの2つの実行だけで、判断に関わる指摘は無い。
- 連鎖: `5bfcc7a..52e63fa` PASS → `52e63fa..d6b0b6f`(reviewer は指摘なし、検証の実行は SELF-CHECK で補った)。
- **attempt 3**: `6185920..b7d292b`(差分review。実機確認1回目の指定) — **PASS**(指摘なし)。reviewerは`gpt-6-luna`。語の変更が設定画面と下部バーで一貫、中央寄せ後も幅の見積もりと描画が一致、testの改訂に緩和なし、M582〜M586 が妥当。`flutter test` 1120 PASS・analyze・format・`check_mutation_finds.py` 540・`git diff --check` PASS。reviewerが回したmutation 5件 KILLED。
- 連鎖: 上に続けて (記録 `d6b0b6f..6185920`) → `6185920..b7d292b` PASS。
- **attempt 4**: `c3e7fbd..054b1a5`(差分review。実機確認2回目の指定) — **PASS**(指摘なし)。reviewerは`gpt-6-luna`。`_chipHeight` が文字 1.0 / 2.0 で実際のチップの高さと一致し「+N」だけでも保たれること、「+N」の幅の見積もりが表示と同じ文字列・字体であること、testの改訂に緩和なし、M584・M585・M587・M588 が妥当。`flutter test` 1121 PASS・analyze・format・`check_mutation_finds.py` 542・`git diff --check` PASS。
- 連鎖: 上に続けて (記録 `b7d292b..c3e7fbd`) → `c3e7fbd..054b1a5` PASS。
- **attempt 5**: `7909c79..d8f00b0`(差分review。「+N」をやめてフェードだけ) — **BLOCKED**(P0/P1 なし)。reviewerは`gpt-6-luna`。確認された点: `_layoutChips`(全部入ればフェード無し、入らなければフェードちょうど1つ・その前は全体)、`_FadedChip` の構成と列の高さの固定、「+N」の除去に漏れが無い、`flutter test` +1121 PASS、format 0 changed、`check_mutation_finds.py` 541 PASS、reviewer が回した M199・M241・M588・M589 KILLED。BLOCKED の理由は **`flutter analyze` が reviewer の待ち時間(60秒)内に終わらなかった**ことだけである(この環境では約100秒かかる)。
  - **SELF-CHECK**: 所有Agentが同じ HEAD `d8f00b0` で `flutter analyze` → `No issues found! (ran in 102.8s)`。
  - P2(成果物の欠陥): 受け入れ証拠が「+N」のままだった → 最新の決定へ直した(記録だけの差分。SELF-CHECK で閉じる)。
  - P2(安全網の穴): フェードの下限の分岐を直接検査する test が無い → 残余riskとして受容した(引き受け先 `008:T10`。「引き継ぎメモ」)。
- 連鎖: 上に続けて (記録 `054b1a5..7909c79`) → `7909c79..d8f00b0`(指摘は上のとおり閉じた。analyze の実行は SELF-CHECK)。
- **attempt 6**: `5a36873..9db1cfe`(差分review。実機確認4回目の指定) — **FAIL**(P1 1件)。reviewerは`gpt-6-luna`。確認された点: フェードが残りの幅で列の右端まで届き、足りれば次のチップも中に描く。test が右端の位置・次のチップが覗く経路・1つ目からフェードする経路・薄くする長さを検査する。`flutter test` +1123 PASS、`flutter analyze` No issues(120.9s)、format 0 changed、範囲付き mutation 7件(M199・M241・M588・M589・M593〜M595)KILLED。
  - **P1(成果物の欠陥)**: `manual-verification.md` の冒頭が対象buildを `b63f121`(4回目)のままにしていて、handoff の `9be982b` と食い違う → `9be982b`(5回目)へ直した。P1 なので SELF-CHECK にせず、差分review attempt 7 で閉じたかを確かめる。
- **attempt 7**: `9db1cfe..187f3f5`(差分review。`specs/` だけ) — **PASS**(P2 1件)。reviewerは`gpt-6-luna`。attempt 6 の P1 が閉じた(手順書の対象buildが `9be982b` で handoff と一致、`9be982b..187f3f5` で `lib/`・依存・build設定の差分なし)。`git diff --check` PASS。
  - P2(成果物の欠陥): handoff の「Next Agent action」が attempt 6 のままだった → 直した(記録だけの差分。**SELF-CHECK** で閉じる。commit は下の handoff 更新)。
- 連鎖: 上に続けて (記録 `d8f00b0..5a36873` SELF-CHECK) → `5a36873..9db1cfe` FAIL(P1)→ `9db1cfe..187f3f5` PASS(P1 が閉じた)→ 以後の記録だけの差分は SELF-CHECK。
- **attempt 8**: `6fa8a74..4b5cd1e`(差分review。実機確認5回目の指定) — **PASS**(指摘なし)。reviewerは`gpt-6-luna`。未設定の最小の高さが文字の倍率に追随し、1.0 / 2.0 で設定済みより低くその 0.8 倍以上であることを test が確かめる。M197・M579 の追随と M596・M597 が妥当。`flutter test` +1124 PASS、`flutter analyze` No issues(135.3s)、format 0 changed、範囲付き mutation 4件 KILLED、`git diff --check` PASS。
- 連鎖: 上に続けて (記録 `187f3f5..6fa8a74` SELF-CHECK) → `6fa8a74..4b5cd1e` PASS。

## Current state / handoff

- Last checkpoint: 実機確認5回目でフェードはOK。未設定のbuttonの高さの指定を受けて直した(`4c2bafc`、2026-10-01)。差分review attempt 8 PASS。review 側の確認は揃った
- Blocker category: human verification
- Waiting for: 開発者によるAndroidエミュレータでの確認6回目(`/workspace/.worktrees/008-T47-footer-button-unification/specs/008-ui-alignment/tasks/T47-footer-button-unification/manual-verification.md` の「6回目で見ること」)
- Requested action: worktree の HEAD から build し(`lib/` は `4c2bafc` と同一)、1〜3 を確かめて結果を会話で伝える
- Evidence revision: `4c2bafc`(`lib/`)
- Next Agent action: 実機確認6回目の結果を記録する → OK なら done にして PR #204 を merge(手順は次のとおり)
  1. 結果を「実機確認 6回目」節として記録する。指摘があれば直して、差分review(range は前回の head から)→ 実機確認をやり直す。review が `lib/` を変える指摘を出したら、実機確認もその build でやり直す。
  2. OK なら status を done にし、PR #204 を ready → CI PASS を確かめて merge commit で merge、`dev` で `workspace.py check specs` を確かめ、worktree と branch を片付ける(`.worktrees/` の空フォルダが権限で消せないことがある。そのときは人間へ伝えて残す)。

### 引き継ぎメモ(別セッション向け)

- worktree: `/workspace/.worktrees/008-T47-footer-button-unification`、branch `asdd/008-ui-alignment/T47-footer-button-unification`、PR #204(Draft)。起点 `dev`@`5bfcc7a`。
- **独立review は開発者の指定で `gpt-6-luna`**: `codex-container exec -m gpt-6-luna -C <worktree> -o <out.md> - < <prompt.md>`。prompt は `/home/dev/.agents/skills/asdd/skills/review-task/SKILL.md` を指し、**差分review の range と前回までの連鎖**(この task.md の「独立review」節)を書く。**「検証は docker を使わず worktree で直接実行する」と必ず書く** — この環境は既に container の中で `docker` が無く、書かないと reviewer が BLOCKED を返す(attempt 2 で起きた)。 **あわせて「`flutter analyze` はこの環境で約100秒かかるので終わるまで待つ」「mutation と full test を同時に走らせない」も書く**(attempt 5 は analyze を60秒で打ち切って BLOCKED、attempt 3・4 は並行実行で偽の失敗を一度出した)。
- mutation は範囲付きで回す(AGENTS.md)。`mutation_check.py` は**追跡済みの file しか扱えない**ので、新しい file を足したら先に commit する。
- 実機確認は開発者が host 側の Android エミュレータで行う。依頼の文面は**日本語**で、file は **`/workspace/...` の絶対 path をそのまま**書く(markdown のリンクに隠さない)。
- 残余risk(受容。引き受け先 `008:T10`): **フェードの下限(24)に満たないとき1つ手前をフェードにする分岐と、下限そのものを直接検査する test が無い**(attempt 5 の P2・安全網の穴)。表示の穴で、AGENTS.md の FAIL 条件(データ損失・偽の成功など)に当たらない。分岐は M199・M241・M588・M589 と「フェードがちょうど1つ・見えている最後のチップ」の test が間接に守る。`T10` は同じ下部バーの余白・階層を最後に整える task なので、下限の値を見直すときに test を足す。
- 決定の経緯: チップは設定画面と同じ2段(×なし)、未設定は＋と「命名ルールを設定する」を白、リネームbuttonの角丸を合わせる、語は「元の名前 / ファイル名」、余白は上下 6・見出しとチップの間 9、入りきらないときは最後に見えるチップのフェードだけ(「+N」は採らなかった)。すべて上の各節と 008 plan の「人間の決定」にある。
