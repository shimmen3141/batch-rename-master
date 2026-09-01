# T16 警告を行に出す提示を実装する

## 目的

`T15`で承認された仕様どおり、警告を各行へ出し、集約帯を置き換える。

## 入力と依存

- **`T15`で承認された 002 / 005 spec。** 承認前に着手しない(`plan.md`の方針)。
- `docs/design/Bulk Renamer.html` の行の`warnText` / `rowBg` / `cardBorder` と、
  ヘッダの`warnLabel`。**適用する画面範囲は一覧の行、ヘッダの警告表示、そして下部バーの
  警告の提示ぶんである。** 下部バーは`005:T09`の成果なので、**実行buttonの振る舞い・ルール
  設定sheetの開き方・バーの構成そのものは動かさない**(下記「下部バーの所有」)。
- 現行実装: `lib/ui/file_list/rename_warning_view.dart`(集約帯と文言生成)、
  `lib/ui/file_list/row_view.dart`(行データ)、`lib/ui/file_list/file_list_controller.dart`。
- `T07`が入れた行のlayout。**行は既に現在名・変更後名・サブ情報を縦に積んでいる**ので、
  警告はその構造の上に載る。`T07`の情報階層を壊さないこと。

## 変更範囲

- 行データが警告を持つ(`RowView`)。
- 行の警告表示(短い一文、行の色・枠)。
- 集約帯の置き換え(ヘッダの件数と、詳細のトグルまたはmodal)。

  **`T07`から引き受けた残余risk N-9**: 現行の帯は高さの上限を**画面**の割合で決めているが、
  帯は一覧の上に載るので、header・barを引いた**一覧の取り分**に対しては割合が跳ね上がる。
  2026-08-29のAndroid emulator確認で、開いた帯が**一覧の見える範囲の半分以上**を覆った。
  **`T15`が帯の廃止を決めたので、この論点そのものは消える。** ただし置換先(ヘッダーの件数と
  modal)が**一覧を覆わない**ことは、このtaskが確かめること — 常時の占有が0になるのが
  廃止の狙いである。
- `describeWarning`が作る文面の整理。**実行前確認dialog(`T14`が持つ)が使っている文面**を
  壊さないこと。分担は`T14`と突き合わせる。
- 置き換えた検証(下記)。

### `T14`との分担

`T14`は**実行前確認dialog**(`file_list_view.dart`の`Key('rename-confirmation-dialog')`)を持つ。このtaskが
作るのは**警告の詳細を見る**ための提示である。**同じmodalに二つのtaskが手を入れない**よう、
着手時にどちらが入れ物を持つかを決めて両方の`task.md`へ書く。

### `T09`との関係

`T09`はmodeごとの描画を持つ。**リッチ案は`T07`の行をそのまま使う**と決めてあるので、
このtaskが行へ足す警告表示も`T09`が引き継ぐ。グリッド・コンパクトで警告をどう出すかは
`T09`が決める。

### 提示の場所はこのtaskが決める(`T15` revision 8.0)

**005 も 002 も配置を「自由とする点」へ置いている。** `T15`が課すのは場所ではなく
**利用者から何が読めるか**である。どの部品のどこに置くかは**このtaskの裁量**で、
参考designと`T15`の設計指針を土台にする。

**必ず確かめること — 幅で分岐する。** `RuleBuilderWorkspace`は幅 840dp で分かれ、
**wide では`onEditRule`を渡さない**(`rule_builder_workspace.dart`の`_buildWide`)。
`FileListView`の`_RuleButton`は生成されず、**下部バーにルール設定の導線が無い。**
wide のルール編集は右ペインの`RuleBuilderView`である。**narrow だけを見て実装すると、
wide で原因の提示が行き場を失う**(`T15`の独立review attempt 3 が見つけた)。
**このplanは同じ型の誤りを一度直している** — 「Androidでは必ずsheet越し」は platform では
なく幅で決まる。**両方のlayoutをwidget testで通すこと。**

下部バーへ載せる場合、実行buttonの振る舞い・ルール設定sheetの開き方・バーの構成そのものは
動かさない(`005:T09`の成果)。余白・typographyは`T10`、modalの文言は`T14`。

## 受け入れ証拠

- 行に警告が出て、どのファイルが何の理由かを行から読み取れることをwidget testで検査する。
- **すべての種別が併発しても行の警告が2行に収まる**ことを、幅を指定したwidget testで
  検査する(`T15`が要求に入れた場合)。**成立範囲は`textScaler` 1.0 である** — 2.0 では
  320dpで語尾が切れる(独立review attempt 3 が観測)。ただし**種別は両方読める**ので
  005 REQ-009 (1) は保たれる。
- 詳細(トグルまたはmodal)で全件と説明が読めることをwidget testで検査する。
- **`005:T09` / `005:T05` のmanual手順と`emulator-verification.md`**が、作り直した
  ルール設定buttonの見た目に合っている(literal「ルールを編集」が消えたため。
  独立review attempt 4 のP2-5)。
- **置き換えたtestが、元の要求を同じ強さで押さえている**ことを示す。
  `warning_display_test.dart` / `empty_rule_test.dart` の該当箇所は**緩めるのではなく
  付け替える** — 005 REQ-009 の「対象fileとトークンが特定できる」を、新しい提示に対して
  検査する。
- 001の判定を変えていないこと(既存testの継続PASS)。**提示だけを変える。**
- **空ルールのとき、行にも警告が出ない**ことを検査する(005 REQ-020)。**廃止するwidgetのkeyに
  依存しない形で書くこと** — 現行の`empty_rule_test.dart`は`renameWarningsKey`の不在で
  REQ-020を押さえており、帯を消すと**widgetが無いから通る**状態になる(`T15`の独立reviewが
  安全網の穴 N-15-1 として挙げ、このtaskを引き受け先に指定した)。002 REQ-015は「空ルールなら
  供給しない」とは書いていないので、行へ出す実装が空ルールでも出す穴が開きうる。
- **`[元名][日時 作成]`で作成日時が不明なとき**(名前は空にならない)、005の例20g/20hのとおり
  **30件それぞれで種別が読め、トークンの説明は1つ**であることを検査する。
- **狭幅(< 840dp)と広幅(≥ 840dp)の両方**で、005 REQ-009 の3つを満たすことをwidget testで
  検査する。**片方だけ通しても、もう片方の抜けは検出できない**(`008:T07`のM166/M167と同じ型)。
- **`sortMode`を名前順にしても**、`[元名][日時 作成]`の行から基準日時不明の種別が読めることを
  検査する(002 REQ-013)。**REQ-013 が `sortMode` でゲートしているのは日時表示そのものの強調**で
  あり、ルール文脈の警告はゲートの対象外である。真似てゲートすると REQ-009 (1) が破れるが、
  既存testでは検出されない(`T15`の独立reviewが安全網の穴 N-15-2 として挙げ、このtaskを
  引き受け先に指定した)。
- `tool/mutations.json`へ、**005 REQ-009 (1) の状態から警告の種別が読めなくなる**mutationを足して`KILLED`を確認する。**配置に依存しない言い方で書くこと** — 8.0 では場所は自由である。
- `flutter test` / `flutter analyze` / `dart format --output=none --set-exit-if-changed .` がPASS。
- [`manual-verification.md`](manual-verification.md)でAndroid実機の狭幅表示を確認する。
  **件数の多い状態**(重複が数十件)を含める。
- exact rangeの独立reviewがPASSする。

## 作業記録

- 2026-08-27 / `T07`から分離して定義。`T07`は行のlayoutとpreviewで閉じる。
- 2026-08-29 / claim。集約帯(`RenameWarningPanel`)を廃止し、005 revision 8.0 の3つを満たす提示へ置き換えた。`flutter test` = PASS(731)、`analyze` = PASS、`format` = PASS。
- 2026-08-29 / mutation 7件を`tool/mutations.json`へ追加(M173〜M179)。`mutation_check.py` = **7 KILLED, 0 SURVIVED**。生の出力は下記。
- 2026-08-29 / 独立review attempt 1 = **FAIL**(P1-1: ヘッダの文言が切り詰められる退行)。P2×8とあわせて修正し、reviewが足したmutation 6件を取り込んだ。`mutation_check.py` = **14 KILLED, 0 SURVIVED**。
- 2026-08-31 / 独立review attempt 2 = **FAIL**(P1-1: PR本文が検査より強い保証を主張。実装の欠陥ではない)。P2×4とあわせて修正。ヘッダを`Wrap`へ変えて狭幅の切り詰めを**残さず**閉じ、reviewが足したmutation X-Aを M187 として取り込んだ。`mutation_check.py` = **16 KILLED, 0 SURVIVED**。
- 2026-08-31 / 独立review attempt 3 = **FAIL**(P1-1: `RuleWarningNotice`に高さの上限が無く、原因が3つ以上・文字倍率2.0で一覧が0pxになり下部バーが画面外へ出る。P1-2: N-9を「閉じた」と書いていたが閉じていない)。**独立reviewが3回FAILしたので`blocked`にし、人間へ選択肢を返す。**
- 2026-08-31 / 案Dを実装。原因の常設側を**種別だけ**にし、説明を詳細dialogへ移し、`_RuleButton`を参考designの2行の形へ作り直した。`flutter test` = PASS(737) / `analyze` = PASS / `format` = PASS / `mutation_check.py` = **21 KILLED, 0 SURVIVED**
- 2026-08-31 / 独立review attempt 4 = **FAIL**(P1-1 記録: N-9閉鎖の根拠に存在しない検査範囲を挙げていた。P2×5)。**実装(案D)はreviewerのprobeで独立に裏が取れた** — 設計のやり直しは不要で、直したのは検査範囲の拡張と記録である。
- 2026-09-01 / 独立review attempt 5 = **FAIL**(P1-1 記録: 「警告が無ければ余白も出ない」を4か所で主張していたが、assertionは相対比較だけでreviewerのmutation Y-Aがすり抜けた。P2×3)。**実装は全840構成のprobeで裏が取れた** — overflow 0件、一覧0px 0件、下部バーの画面外 0件。

### 独立review

- Review attempt 1: `dev...e9241da` — **FAIL** — P1-1(狭幅でヘッダの文言が切り詰められる退行)、P2×8。すべて対処済み。
- Review attempt 2: `dev...cd3e6d6` — **FAIL** — P1-1(記録: PR本文が検査より強い保証を主張)、P2×4。すべて対処済み。
- Review attempt 3: `origin/dev...494b0bb` — **FAIL** — P1-1(実装: 原因の説明が一覧と下部バーを押し出す)、P1-2(記録: N-9は閉じていない)、P2×2。**記録だけ直し、実装は人間の選択を待った。**
- Review attempt 4: `origin/dev...08bc3ac` — **FAIL** — P1-1(記録: N-9閉鎖の根拠に存在しない検査範囲)、P2×5。すべて対処済み。**実装(案D)は独立に裏が取れた。**
- Review attempt 5: `origin/dev...ffe2247` — **FAIL** — P1-1(記録: 余白の主張をassertionが含まない)、P2×3。すべて対処済み。**実装は840構成のprobeで裏が取れた。**

**P1-1 は私が入れた退行である。** `_HeaderBar` へ `Flexible + Spacer + Flexible` を並べた
ため Row の余白が3等分され、**どちらの文言も intrinsic 幅を取れずに切り詰められた**。
360dpで200件だと `200 / 2…`、411dpで `200 / 20…` と出て、**総数を20と誤読できる**。
`dev` では flex child が無く intrinsic 幅で全文が出ていたので、このdiffが入れた退行である。
文字サイズ最大の N-8b(`T10`引き受け)とは別物で、**通常のfont sizeで起きる。**

**私が書いた「はみ出さない」testでは検出できなかった。** `Flexible` + ellipsis は
**内容を切ることで overflow を出さない**ので、`RenderFlex overflow` を見る検査では
原理的に落ちない。`didExceedMaxLines` で切り詰めそのものを見る形へ差し替えた。
**M186 がこの退行を殺す。**

その他: P2-3/P2-4(併発時の2行・行の種別の重複排除がtestで固定されていない)→ testを足して
M180/M181で殺した / P2-5(空ルールtestの説明側assertionが空振り)→ 導線がある状態で
pumpするよう直した / P2-8 `describeWarningSummary`が帯の廃止でdead codeになっていたので
削除 / P2-9 `preview`のdocが「build 1 回につき1回」と書いていたが広幅では2回走るので
実態へ直した / P2-10 ルールが空のときヘッダが「問題なし」と出ていたので**出さない**
ようにした(001は空名と重複を返しているので誤りになる) / P2-6・P2-7 記録の追随。

**独立reviewが足したmutationは6件すべて取り込んだ**(M180〜M185)。equivalent mutantと
判定された1件(ルールが空のとき原因の説明を出す)は取り込んでいない — ルールが空なら
トークンが無く、桁不足も基準日時不明も生じないため、説明は常に空である。

#### attempt 2

**成果物の欠陥は記録の1件だけだった。** attempt 1 のP1-1(`200 / 20…`と出て総数を誤読)は
実際に直っていることをreviewerのprobeが確認している。だがPR本文の「対象外」節へ
「通常のfont sizeで狭幅(320/360/411dp)の文言が切り詰められないことは、このPRが
`didExceedMaxLines` で検査している」と書いていた。**そこまで検査していなかった** —
320/360dpでは件数labelだけを見ており、選択件数は411dp以上でしか見ていなかった。
しかも事実でもなく、320dp・1000件では `1000 / 1…`(総数を1と誤読)になっていた(P2-1)。
textScaler 1.3では360dp・200件が `200 / 2…` になり、**attempt 1 とまったく同じ誤読の形**
だった(P2-2)。

**同じ形の指摘が2回続いたので、`Expanded`の配り方を調整する道をやめた。**
`Row`に並べるかぎり、幅が足りないときの逃げ道は「はみ出す」か「切り詰める」しかない。
`_HeaderBar`を **`Wrap`** へ変え、どちらの文言も intrinsic 幅のまま**次の行へ落ちる**
ようにした。これで幅・文字倍率・件数のどの組合せでも数字が消えない。

- probe(320/360/411dp × `textScaler` 1.0/1.3/2.0/3.0 × 1/30/200/1000件): **overflow 0件**。
- 同 probe の切り詰め: 1.0/1.3/2.0 で **0件**。
- `textScaler` **3.0** だけは、2行に落としてもなお末尾が切れる。ただし切れるのは語尾で
  **数字は常に残る**(`200 / 200 件を選` / `1000 / 1000 件を選` / `200 件の`)。
  これは`T10`へ **N-8b′** として渡した。

**P2-2 が指摘した `T10` の N-8b(`textScaler` 3.0 で `_HeaderBar` が水平に約69px
overflow する)は、この変更で再現しなくなった。** `T10`の記録を閉じ、残った切り詰めを
N-8b′ として置き換えた。**overflow が消えた代わりに誰も引き受けていない切り詰めが残る**
という状態にはしない。

P2-3(記録: N-15-1の押さえ直しを「問題なし」と書いていたが、実際の assertion は
`expect(find.byKey(warningCountKey), findsNothing)` で**「問題なし」を出さないこと**。
逆の主張だった)→ `task.md`とPR本文の両方を assertion へ合わせた。

P2-4(安全網の穴。reviewerのmutation **X-A** が SURVIVED — 005 REQ-021 規則1の
「基準日時不明を別立てで提示しない」が行の提示について固定されていない)→ 行の文言へ
`isNot(contains('作成日時'))` を足し、X-A を **M187** として取り込んだ。
reviewerの判定は「条件2に当たらないので受容可能」だったが、**1行のassertionで閉じる**
ので受容せずに殺した。

**reviewerの他のSURVIVED 3件は取り込んでいない。** X-B(`Expanded`→`Flexible`)は
`Wrap`化で対象そのものが消えた。X-C/X-D(0件でdialogを開く / 押せる)は**対で外すと
KILLED**(X-CD)であり、片方ずつのmutationは二重防御の片側を外しているだけである。
X-K(行の警告を選択状態でゲートする)は等価mutant — `validate`は選択されたfileしか
見ないので、ゲートしてもしなくても結果が同じである。

#### attempt 3 — 3回目のFAIL(`blocked`)

**ヘッダの切り詰めは直っていた。** reviewerが自分のprobeで確認し、`dev`と比べて
「320dp × textScaler 3.0 で `Row` が水平に181px overflow していたのが、overflowも
切り詰めも消えた」ことを示した。attempt 1/2 の「総数を誤読できる」形は再現しない。
`T10`の N-8b を閉じた判断も裏が取れている。

**だが別の場所で同じ種類の壊れ方を作っていた。** `RuleWarningNotice`(REQ-009 (2) の
原因の説明)に**高さの上限も scroll も無い**。原因(トークン)の数と文字倍率で
青天井に伸び、外側`Column`の非flexな子として一覧と下部バーを押し出す。

私自身のprobe(`onEditRule`を渡した狭幅の製品経路。30件、原因は連番の桁不足1つ +
作成日時不明を出すトークンn本):

| 画面 | textScaler | 原因 | notice高 | 一覧高 | overflow |
|---|---|---|---|---|---|
| 360×640 | 1.0 | 2 / 3 / 5 | 60 / 92 / 156 | 408 / 376 / 312 | 0 |
| 360×640 | 1.3 | 2 / 3 / 5 | 117 / 180 / 306 | 317 / 254 / **128** | 0 |
| 360×640 | 2.0 | 2 | 243 | **156** | 0 |
| 360×640 | 2.0 | 3 | 408 | **0** | **bottom 9px** |
| 360×640 | 2.0 | 5 | 738 | **0** | **bottom 339px** |
| 411×731 | 2.0 | 5 | 606 | **0** | **bottom 116px** |
| 731×411(横持ち) | 2.0 | 5 | 309 | **0** | **bottom 101px** |

**下部バーの「ルール設定」「実行」が画面外へ出る。**scrollできないので、noticeが
「ルールを直せ」と言っている当のルールへ到達できない。広幅では代わりに右ペインの
`RuleBuilderView`が切れ、トークン追加バーが隠れる。

**これは`dev`が明示的に持っていた保証を代替なしで外した退行である。**
`RenameWarningPanel.detailMaxHeightFor()`は画面高の32%を上限にし、超過分をscrollへ
送っていた(doc: 「**画面を警告で埋めない**」)。集約帯を消したときに、帯と一緒に
**この上限も消していた**。

**P1-2: N-9 は閉じていない。** `task.md`とPR本文の両方が「件数が増えても一覧の
取り分が変わらない → N-9 がここで閉じる」と書いていたが、前半(**file件数**に対する
不変性)が真なだけである。N-9 の主語は**画面占有**で、置換先は**別の変数(原因の数 ×
文字倍率)で同じ画面占有を起こす**。さらに根拠に挙げた`row_presentation_test.dart`の
3つのtestWidgetsは**すべて`onEditRule`を渡していない**ので、測っている構成に
`RuleWarningNotice`が存在しない。**N-15-1(「widgetが無いから通る」)と同じ空振り**を
自分でもう一度作っていた。

P2-1(受け入れ証拠「すべての種別が併発しても行の警告が2行に収まる」を textScaler 1.0
でしか検査していない。2.0 では語尾が切れる。ただし**種別は両方読める**ので
REQ-009 (1) は破れていない)→ 記述へ文字倍率の範囲を書き足す。
P2-2(広幅で`preview`が1フレームに2回評価される。docに明記済み・受容可能)→
引き受け先候補は`T09`。

reviewerが足したmutation Z-A〜Z-Dは4件ともKILLEDだったが、**Z-A(noticeを8倍の高さに
する)のKILLEDは偶発である。**落ちたのは高さを主張するtestではなく、
`empty_rule_test.dart`の行を探すtestが「noticeが伸びて行がviewportから押し出された」
ために `row-warning` を見つけられなかったものである。**占有を直接主張するassertionは
どこにも無い**(`dev`には`detailMaxHeightFor`を固定するunit testが3本あり、このdiffで
削除されている)。

**規約により、独立reviewが合計3回FAILしたのでこのtaskを`blocked`にし、人間へ
選択肢を返す。**記録の誤り(P1-2・P2-1)だけ先に直し、実装は選択を待つ。

### 選んだ置き場所(要求ではない)

**005 revision 8.0 は場所を課さない。** 下は`T15`の設計指針と参考designに沿って
このtaskが決めたものである。

| 005 REQ-009 | 何を | どこへ |
|---|---|---|
| (1) 種別が一覧を見た状態で分かる | 短い一文(`RowWarningView`) | **行**の変更後名のすぐ下 |
| (2) 変わらない説明を件数ぶん繰り返さない | **種別だけ**(`RuleWarningNotice`) | **ルールを変更する操作のそば**。狭幅=ルール設定button内「命名ルール」見出しの右、広幅=右ペインの上 |
| 同 | 原因ごとの説明(`warningDetailCausesKey`の節) | **詳細dialogの中**。常設しない |
| (3) 全件と説明を読める | ファイルごとの全件(`warningDetailFilesKey`の節) | 同じdialog。**ヘッダの件数**と**行の警告**の両方から開く |

**常設側が説明ではなく種別なのは、占有を定数にするためである**(案D。下記)。
説明は原因(トークン)ごとに1つなので**トークンの数だけ増える**が、種別は
`桁不足`と`基準日時なし`の**2つしかない**。

**広幅と狭幅で導線が違う。** `RuleBuilderWorkspace`は幅 840dp で分かれ、広幅では
`onEditRule`を渡さないので**下部バーにルール設定の導線が無い**。広幅のルール編集は
右ペインの`RuleBuilderView`なので、そちらへ同じ`RuleWarningNotice`を描いた。
**片方だけ描くと、もう片方のlayoutで説明が行き場を失う**(M177がこれを殺す)。

#### attempt 4 — 実装は通り、記録が3度目の同じ形で落ちた

**案Dはreviewerのprobeで独立に裏が取れた。** `configure-rule` buttonの高さは
原因2/3/5/10本で1pxも動かず(320/360dp × `textScaler` 1.0/1.3/2.0/3.0)、
**隠れた第三の伸び方は見つからなかった** — reviewerはルールの長さ(トークン19個・
長い固定文字12個)、file件数、localeを当たったが、どれも常設側を伸ばさない。
`dev`比では、320dp×3.0で181px出ていた水平overflowが**全構成で0件**になっており、
`T10`の N-8b を閉じた判断も裏が取れた。空ルールでは詳細へ到達する経路が
残っていないことも総当たりtapで確認された。

**FAILの理由はP1-1、記録である。** PR本文がN-9閉鎖の根拠として
「320〜731dp × `textScaler` 1.0/1.3/2.0 で、**いずれも**`onEditRule`を渡した
製品経路で検査している」と書いていたが、

- **320dpは占有testが使っていなかった**(`pumpWithCauses`は360と731だけ)。
- **file件数の不変を測る`pumpList`は`onEditRule`を渡していなかった** —
  attempt 3 のP1-2とまったく同じ空振りを、別のtestでもう一度作っていた。

主張の中身(320dpでも原因の数で変わらない)はreviewerのprobeで真だと確認されたが、
**それを押さえるtestが無かった。**

**同じ形の記録の欠陥が3回続いた**(attempt 2 のP1-1、attempt 3 のP1-2、今回)。
規約どおり解き方を変える。**これまでは指摘されるたびに文を実態へ合わせていたが、
それだと「書いた範囲」と「検査した範囲」が別々に管理され続ける。**今回は逆向きに、
**主張が真になるように検査の側を広げた**(320×640を占有testへ足し、`pumpList`へ
`onEditRule`を渡した)。そのうえでPR本文からは幅と倍率の列挙をやめ、**test名を
指す**形にした。範囲の正本をtestのparameter listに一本化し、散文が独自に範囲を
主張できないようにする。

その他: P2-1(広幅の右ペインが`RuleWarningNotice`を無条件の`Padding`で包み、
種別0件のとき死んだ12pxが残る。広幅横持ちの既存overflowを実測で12px悪化させて
いた)→ 余白をwidget側へ移した。M200が対照 / P2-2(testのコメントがこのPRの
閉じた N-8b を現存扱い)→ N-8b′へ書き換え / P2-3(002 specのVER-001/VER-002が
REQ-015の検証先に`test/spec_002_file_list/`を挙げているのに、そこに`warnings`を
見るassertionが1つも無かった。実体は005側)→ 例18〜21のunit検証を
`preview_rows_test.dart`へ置いた / P2-4(`textScaler` 3.0の取り分が「対象外」に
未開示)→ `T10`へ **N-8b″** として渡した / P2-5(buttonの作り直しで literal
「ルールを編集」が消え、`005:T09`・`005:T05`のmanual手順と
`emulator-verification.md`が照合できなくなっていた)→ 3か所を新しいbuttonの
形へ更新した。**既存taskの受け入れを変える修正を所有taskへ接続する**規約に当たる。

**reviewerが足したmutationは、等価と判定した1件を除いて取り込んだ。**
Z-A〜Z-D・Z-F・Z-G を M194〜M199 とした。Z-G は M192(折り返し無制限)より弱い
対照なので落とさずに残す。**Z-E(`showWarningDetail`の`ruleIsEmpty`を無視する)は
等価mutant** — 呼び出し側2つはどちらもガードされていて`true`で到達せず、仮に
到達しても空ルールにはトークンが無いので説明は常に空である。**この引数は現状
deadであり、testで固定することは原理的にできない。**防御として残す。

**安全網の穴 H-1(広幅の占有を測るtestが1つも無い)は、受容可能と判定されたが
閉じた。** reviewerの判定は「通り抜ける失敗がlayout退行で、条件2に当たらない」で
正しいが、widget test 数行で閉じるので受容しなかった。**何をどの範囲で押さえて
いるかは`warning_display_test.dart`の`広幅でも占有が原因の数に依らず、警告が
無ければ余白も出ない`を読むこと**(下の「占有の主張を散文で持たない」を見よ)。

#### attempt 5 — 実装は840構成で裏が取れ、記録が4度目の同じ形で落ちた

**実装は独立に確認された。** reviewerのprobe(7画面 × `textScaler` 4段 × 原因0〜10本 ×
file 0〜1000件 = 840構成)で、**overflow 0件・一覧0px 0件・下部バーの画面外 0件・
常設側の切り詰め 0件**。320×640・`textScaler` 3.0 でも原因2/3/5/10本の一覧高は
すべて 85.0 で一致した。`dev`にあった8構成のoverflowはすべて消えている。
広幅では警告0件のとき器の先頭が 0.0・高さ 800.0 で、**死んだ余白は実際に1pxも無い**。

**FAILの理由はP1-1、記録である。**「警告が無ければ余白も出ない」を test名・
test内コメント・`task.md`・PR本文の4か所で主張していたが、実際のassertionは
`findsNothing` と「警告があるほうが取り分が小さい」という**相対比較**だけだった。
**相対比較では、呼び出し側が`Padding`で包み直しても両方が同じだけずれて通る** —
reviewerのmutation **Y-A**(attempt 4 のP2-1の退行そのもの)が実際にすり抜けた。
器の先頭と高さを**絶対値**で固定し、Y-A を **M201** として取り込んだ。M200(余白を
落とす向き)の反対向きで、**両方が要る。**

Y-D(下余白だけを増やす)も SURVIVED した。左右上の3辺しか見ておらず、残る1辺で
占有を増やす退行がすり抜ける。reviewerは「受容可能」と判定したが assertion 1行で
閉じるので受容せず、**M202** として取り込んだ。**4辺すべてを見る。**

P2-1(`preview_rows_test.dart` の `未選択の item も自分の警告を持つ(選択状態で
ゲートしない)` が、assertionは両方`isEmpty`で名前と食い違っていた)→ `validate`は
選択を写した複製しか見ないので、この性質は**原理的に成立しえず検査もできない**。
検査している内容へ改名し、理由をコメントへ残した。reviewerのmutation Y-C が
SURVIVED したのはこの等価性のためである。**例18〜21の4本はspecを正しく写している**
ことも確認された。
P2-2(PR本文の「いずれも`onEditRule`を渡した」が広幅の1本に当てはまらない。
広幅は設計上渡さない)→ 狭幅3本と広幅1本を分けて書いた。
P2-3(コメント段落の重複)→ 1つにした。

**Z-E(`showWarningDetail`の`ruleIsEmpty`を無視する)を等価mutantとした判定は
reviewerに支持された。** 到達しないことと、到達しても結果が同じことの2重の等価性で
ある。取り込まない。

### 案Dで何が変わったか(実装の記録)

| | attempt 3 まで | 案D |
|---|---|---|
| 常設側の中身 | 原因ごとの説明(**トークンの数だけ増える**) | **種別だけ**(`桁不足`/`基準日時なし`。最大2つ) |
| 狭幅の置き場所 | 下部バーの手前へ積んだ独立した子 | **ルール設定button内**「命名ルール」見出しの右 |
| 広幅の置き場所 | 右ペイン上部 | 同じ(中身だけ有界化) |
| 説明の置き場所 | 常設側 | **詳細dialogの「ルールの問題」節** |
| 占有 | 原因の数 × 文字倍率で青天井 | 原因の数に**依らない**。種別1→2の段差が1行で止まる |

`_RuleButton`を参考designの2行(`[✎] 命名ルール / <設定中のルール> [編集]`)へ
作り直した。**「命名ルール」見出しの右の空きが、開発者が指した場所である。**
設定中のルールは`describeRuleSummary`(=`describeToken`を`+`で連結した最小形)で、
`maxLines: 1` + 省略記号。designどおり伸びない。

**見出しと種別は`Wrap`である。**幅が足りないときに切り詰めると種別が読めなくなる —
ヘッダで2回作った退行と同じ形になる。次の行へ落ちても、種別は最大2つなので
増える高さは1行ぶんで止まる。

`showWarningDetail`は2つの節を持つようになった。**原因ごとの説明**
(`warningDetailCausesKey`)と**ファイルごとの全件**(`warningDetailFilesKey`)である。
節にkeyを与えたのは、testが両者を混ぜて数えないためである — 全件側は件数ぶん
並んでよく、原因側は原因の数だけしか無い。

ルールが空ならbuttonは`変更する名前を設定する`の主役表示のままで、種別も出さない
(005 REQ-020)。

### 判定を変えていない

001 の`validate`にも`autoResolve`にも触れていない。`presentWarnings`と
`describeWarning`はそのままで、**実行前確認dialog(`T14`が持つ)は同じ提示単位を
使い続ける**。行に出さない重複(REQ-021 規則2)も判定からは消さず、詳細には出す。

### 行データが警告を持つ(002 REQ-015)

`RowView.warnings`を足し、`warningTargetOf`が`null`を返す警告(連番の桁不足)は
載せない。`rows`と`warnings`は同じ検証から作れるので`preview`へまとめた
(別々に呼ぶと 001 の検証が2回走る)。

### mutation 実行の失敗と、その扱い(2026-09-01)

**1回目の実行はM200 SURVIVED・M177 SKIPPEDだった。**どちらも本物である。
M200(広幅の余白を落とす)は、広幅のtestが「警告が出れば取り分が減る」までしか
見ておらず余白そのものを主張していなかったので殺せなかった。M177は P2-1 で
`Padding` の包みを外したため`find`が対象を指さなくなっていた。両方直した。

**2回目の実行結果は破棄した。**止めたはずの1回目のrunnerが生きたまま2回目を
起動し、**2つが同じfileを書き換え合って互いの復元を壊していた。**5件がSKIPPEDと
報告されたが、実装が変わったからではなく、working treeへ他方のmutationが
適用されたままだったためである(`git diff`で M182・M183・M188・M189 の適用を確認)。
**「対象が見つからなかった」と「testが落ちなかった」を区別するのがこの検査の
要点なので、汚染された表は報告に使わない。**復元し、runnerが1つも生きていない
ことを確かめ、`flutter test` = PASS(743) を確認したうえで単独で再実行した。
下の出力が3回目の単独実行のものである。

### mutation の生の出力

```text
command: flutter test
ID | STATUS | FILE | NOTE | DETAIL
--- | --- | --- | --- | ---
M173 | KILLED | lib/ui/file_list/rename_warning_view.dart | 008:T16 行から警告の種別が読めなくなる(005 REQ-009 (1)の「警告があることだけを示して種別を隠さない」に反する) | exit 1
M174 | KILLED | lib/ui/file_list/rename_warning_view.dart | 008:T16 ルールが空でも行へ警告を出す(005 REQ-020。廃止した帯のkeyでは検出できない穴) | exit 1
M175 | KILLED | lib/ui/file_list/rename_warning_view.dart | 008:T16 原因の説明を該当ファイルの件数ぶん繰り返す(005 REQ-009 (2)) | exit 1
M176 | KILLED | lib/ui/file_list/rename_warning_view.dart | 008:T16 空名の行にも重複を出す(005 REQ-021 規則2。改名されないfileの重複は生じない) | exit 1
M177 | KILLED | lib/ui/rule_builder/rule_builder_workspace.dart | 008:T16 広幅(2ペイン)で原因の説明を配り忘れる — 広幅は下部バーにルール設定の導線が無いので行き場を失う | exit 1
M178 | KILLED | lib/ui/file_list/file_list_view.dart | 008:T16 行の警告を sortMode でゲートする — 002 REQ-013 が縛るのは日時表示の強調だけで、ルール文脈の警告は対象外(N-15-2) | exit 1
M179 | KILLED | lib/ui/file_list/file_list_view.dart | 008:T16 行の警告から詳細を開けなくする(005 REQ-009 (3)の入口の一方) — 対照として置く | exit 1
M180 | KILLED | lib/ui/file_list/rename_warning_view.dart | 008:T16 行の警告を1行へ切り詰める — 併発時に後ろの種別が読めなくなる(005 REQ-009 (1))(独立reviewが追加) | exit 1
M181 | KILLED | lib/ui/file_list/rename_warning_view.dart | 008:T16 行で同じ種別を件数ぶん繰り返す — 日時トークンが2本だと同じ文言が2回並ぶ(独立reviewが追加) | exit 1
M182 | KILLED | lib/ui/file_list/rename_warning_view.dart | 008:T16 件数を提示単位ではなく001の生の件数で数える — 詳細に並ぶ件数と食い違う(独立reviewが追加) | exit 1
M183 | KILLED | lib/ui/file_list/file_list_view.dart | 008:T16 狭幅でルール設定button内の原因の提示を配り忘れる — M177(広幅)の対照(独立reviewが追加。T16でbutton内へ移設) | exit 1
M184 | KILLED | lib/ui/file_list/file_list_controller.dart | 008:T16 対象fileを持たない桁不足を全行へ載せる(002 REQ-015 例19)(独立reviewが追加) | exit 1
M185 | KILLED | lib/ui/file_list/file_list_controller.dart | 008:T16 行の警告を別インスタンスで引き当てる — validateは選択を写した複製を見るのでidentityがずれる(独立reviewが追加) | exit 1
M186 | KILLED | lib/ui/file_list/file_list_view.dart | 008:T16 ヘッダを Wrap から Row へ戻す — 幅が足りないとき次の行へ落とせず、はみ出すか切り詰めるしかなくなる(独立reviewが見つけたP1の型) | exit 1
M187 | KILLED | lib/ui/file_list/rename_warning_view.dart | 008:T16 空名の行で基準日時不明を結果へ畳まず別立てで出す(005 REQ-021 規則1)(独立reviewが追加) | exit 1
M188 | KILLED | lib/ui/file_list/file_list_view.dart | 008:T16 選択件数を折り返さず切り詰める — `1000 / 1…` のように総数を誤読できる(独立reviewが見つけたP1) | exit 1
M189 | KILLED | lib/ui/file_list/rename_warning_view.dart | 008:T16 常設側を種別ではなく警告1件ごとに出す — 原因の数とfile件数で伸び、一覧と下部バーを押し出す(独立review attempt 3 のP1-1の型) | exit 1
M190 | KILLED | lib/ui/file_list/rename_warning_view.dart | 008:T16 説明そのものを常設側へ戻す — 原因の数×文字倍率で伸びて一覧が0pxになる(独立review attempt 3 のP1-1そのもの) | exit 1
M191 | KILLED | lib/ui/file_list/rename_warning_view.dart | 008:T16 詳細dialogから原因ごとの説明を落とす — 常設側が種別だけなので、どのトークンが何桁必要かを読める場所が無くなる(005 REQ-009 (2)) | exit 1
M192 | KILLED | lib/ui/file_list/file_list_view.dart | 008:T16 設定中のルールの要約を折り返させる — ルールが長いとbuttonが伸びて一覧を削る(参考designは1行・省略記号) | exit 1
M193 | KILLED | lib/ui/file_list/file_list_view.dart | 008:T16 見出しと警告を Row に並べる — 幅が足りないとき次の行へ落とせずはみ出す(ヘッダで2回作った退行の型) | exit 1
M194 | KILLED | lib/ui/file_list/rename_warning_view.dart | 008:T16 詳細dialogの原因の節を該当file件数ぶん繰り返す — 005 REQ-009 (2) の付け替え先をwidget側で外す(独立review attempt 4 が追加) | exit 1
M195 | KILLED | lib/ui/file_list/rename_warning_view.dart | 008:T16 詳細dialogのファイルごとの節を種別あたり1件へ間引く — 005 REQ-009 (3)「全件」(独立review attempt 4 が追加) | exit 1
M196 | KILLED | lib/ui/file_list/file_list_view.dart | 008:T16 作り直した2行buttonからルール編集の入口keyを落とす — 005 REQ-020 の導線(独立review attempt 4 が追加) | exit 1
M197 | KILLED | lib/ui/file_list/file_list_view.dart | 008:T16 空ルールの主役表示と通常表示を入れ替える — 005 REQ-019 / REQ-020(独立review attempt 4 が追加) | exit 1
M198 | KILLED | lib/ui/file_list/file_list_view.dart | 008:T16 ルールが空でもヘッダに件数を出す — 001は空名と重複を返すので「問題なし」は誤りになる(005 REQ-020)(独立review attempt 4 が追加) | exit 1
M199 | KILLED | lib/ui/file_list/file_list_view.dart | 008:T16 ルール要約を2行まで許す — ルールの長さという第三の変数でbuttonが伸びる。M192(折り返し無制限)より弱い対照として残す(独立review attempt 4 が追加) | exit 1
M200 | KILLED | lib/ui/file_list/rename_warning_view.dart | 008:T16 広幅の原因の提示から余白を落とす — 対照。余白をwidget側が持つのは、種別0件でSizedBox.shrinkを返すときに外側のPaddingだけが残るのを防ぐため(独立review attempt 4 のP2-1) | exit 1
28 mutations: 28 KILLED, 0 SURVIVED, 0 SKIPPED
```

**引き受けた安全網の穴は両方とも殺した。** N-15-1 は M174、N-15-2 は M178 である。
受容ではなく検査で閉じた。

### 置き換えたtest

| 元 | どう付け替えたか |
|---|---|
| `warning_display_test.dart` 帯の`Text`の数が`警告件数 + 1` | **提示単位の数を数えるのをやめた**(帯が無い)。REQ-009 の3つへ組み替え、種別が行から読めること・説明が1つであること・詳細に全件あることを検査する |
| 同 `作成日時が不明`が2件ぶん | 行では**種別**が2行に出て、**説明はまとまりに1つ**であることへ付け替えた(繰り返しが消えたことが要求になった) |
| 同 説明が常設側に1つ(`_inRuleNotice`) | 案Dで説明が詳細dialogへ移ったので、**dialogの原因の節**(`warningDetailCausesKey`)で数える形へ付け替えた。節にkeyを与え、**ファイルごとの全件**(`warningDetailFilesKey`)と混ぜて数えない。30件でも節の中は見出し1+説明1、トークン2本なら見出し1+説明2。**弱めていない** — 常設側には種別が最大2つしか無いことを別に検査する |
| `empty_rule_test.dart` 1行の`Text.data`が結果と原因の両方を含む | **行は結果だけ**・**詳細に結果と原因がまとまって1件**、へ分けた |
| 同 REQ-020 を`renameWarningsKey`の不在で押さえる | **廃止するkeyに依存しない形**へ(行の警告の不在・説明の不在・**件数labelそのものの不在**)。ルールが空のときは「問題なし」も出さない(P2-10)ので、`warningCountKey`が`findsNothing`であることを見る。M174が殺す |
| `row_presentation_test.dart` 帯の高さ(T07の(i)) | 帯が無くなったので、**file件数が増えても一覧の取り分が変わらない**ことへ置き換えた。**これだけでは N-9 を閉じていなかった**(独立review attempt 3 のP1-2) — N-9 の主語は画面占有で、置換先は**原因の数 × 文字倍率**という別の変数で同じ占有を起こしたうえ、この3つのtestは`onEditRule`を渡しておらず測っている構成に原因の提示が存在しなかった。案Dの実装とあわせて、**`onEditRule`を渡した製品経路**で「原因2→3→5→10本で一覧の高さが1pxも動かない」と「種別1→2の段差が1行で収まる」を足し、**ここで N-9 を閉じた** |

## Current state / handoff

- Last checkpoint: 独立review attempt 5 の**P1-1とP2×3を修正**。余白を4辺すべて絶対値で固定し、reviewerのmutation Y-A/Y-D を M201/M202 として取り込んだ(どちらもKILLED)。占有の主張を散文から落とした。`flutter test` = PASS(743) / `analyze` = PASS / `format` = PASS
- Blocker category: なし
- Waiting for: 人間の判断(reviewを続けるか)
- Requested action: なし
- Evidence revision: `asdd/008-ui-alignment/T16-implement-row-level-warnings`(PR #161、Draft)
- Next Agent action: 人間の判断を待つ。続ける場合は独立review attempt 6 を起動する。PASS後に`manual-verification.md`をcurrent revisionへ合わせてdry-runし、Android実機の狭幅表示(**原因が複数ある状態**と**文字サイズ最大**を含む)を依頼する

### 人間の選択(2026-08-31): **案D — ルール設定buttonへ載せる**

3案(A 上限とscroll / B 常設を1行の要約へ / C 常設側を別taskへ)を返したところ、
開発者が**4つめ**を挙げた — **参考designのルール設定button内に出す**。採用する。

**この案は`T15`が私へ申し送っていたものである。**`T15`の`task.md`(下部バーの所有)に
こうある。

> 参考designはルール設定buttonの中に「命名ルール」の見出しと設定中のルールの2行を持ち、
> **見出しの右にスペースがある。開発者はそこへ出す案を挙げた**(2026-08-29)。
> `T16`はこれを**design土台として扱い、離れる場合は理由を`task.md`へ書く**。

**私はこの申し送りを使わず、独立した`RuleWarningNotice`を新設し、離れた理由も
書かなかった。**AGENTS.mdが要求する手順を踏んでいない。**P1-1(占有が青天井)の遠因は
ここである** — 土台にはボタンという**既に有界な器**があったのに、可変長のものを置ける
新しい器を作った。

#### 何をするか

| | 狭幅 | 広幅 |
|---|---|---|
| ルール変更の導線 | 下部バーの`_RuleButton` | 右ペインの`RuleBuilderView` |
| 原因の提示 | **buttonの「命名ルール」見出しの右**へ、**種別だけ** | 右ペイン上部へ、同じ種別だけ |
| 原因ごとの説明 | **詳細dialogの節へ移す**(常設しない) | 同左 |
| 詳細dialogの入口 | ヘッダの件数 / 各行の警告(**変更なし**) | 同左 |

**種別は最大2つで固定である** — `桁不足`と`基準日時なし`(`warningKindLabel`)。ルール由来の
警告はこの2種別しか無い。`重複`と`空の名前`はfile単位なので行に出たままで、ここへは来ない。
**原因(トークン)の数にも文字倍率にも依らない**ので、占有が青天井になる形が構造ごと消える。

**ルールが空なら出さない**(005 REQ-020)。buttonは`変更する名前を設定する`の主役表示のまま。

#### design土台へ戻す(離れていた点の是正)

`T16`以前の`_RuleButton`は1行の`OutlinedButton.icon`「ルールを編集」で、**参考designの2行の形に
なっていない**。designは次である。

```text
[✎] │ 命名ルール          ← 小さいラベル。右に空きがある
    │ {{ ruleSummary }}   ← 設定中のルール。1行・省略記号つき   [ 編集 ]
```

**この見出しの右の空きが、開発者が指した場所である。**空きを作るために button を design の
2行の形へ作り直す。**開発者の選択(2026-08-31)により`T16`へ含める。**

- 設定中のルールの1行要約を新設する。**`describeToken`を連結した最小形**にとどめ、
  余白・字体は`T10`、文言の作り込みは`T14`に残す。
- `T15`は「`T16`が持つのはバーへ**警告を載せる部分だけ**」としていた。**buttonの作り直しは
  その範囲を超える**ので、ここへ記録して範囲を広げる。実行buttonの振る舞い、ルール設定
  sheetの開き方は動かさない。

#### 検査で押さえること

- **占有が原因の数と文字倍率で変わらない**ことを、`onEditRule`を渡した構成
  (= 狭幅の製品経路)と広幅の両方で**直接**主張する。attempt 3 のP1-2で空振りした形
  (`onEditRule`を渡さずに測る)を繰り返さない。**具体的な幅・倍率・件数はここへ
  書かない** — 下を見よ。
- 種別が最大2つであること、ルールが空なら出ないこと(REQ-020)、原因ごとの説明が
  詳細dialogから読めること(REQ-009 (2)(3))。

#### 占有の主張を散文で持たない(2026-09-01、attempt 5 の後)

**同じ形の記録の欠陥が4回続いた**(attempt 2 のP1-1、attempt 3 のP1-2、attempt 4 の
P1-1、attempt 5 のP1-1)。いずれも「散文が主張した検査範囲」と「実際のassertion」が
ずれていた形である。attempt 4 で「文を実態へ合わせるのをやめ、主張が真になるよう
検査を広げる」へ変えたが、**広幅側へ適用し漏れて5回目が出た。**

**解き方をもう一段変える。占有・余白について、`task.md`とPR本文は範囲を主張しない。**
幅・文字倍率・件数・原因の本数は**testのparameter listだけが持つ**。散文はtest名を
指すにとどめる。人手で2か所を同期させる限りこの形は再発するので、同期の必要そのものを
無くす。

| 主張 | 正本 |
|---|---|
| 狭幅で占有が原因の数に依らない / 種別1→2の段差 / file件数で変わらない | `row_presentation_test.dart` の該当3本 |
| 広幅で占有が原因の数に依らない / 警告が無ければ余白も出ない | `warning_display_test.dart` の `広幅でも占有が…` |
| ヘッダの切り詰めが起きない | `row_presentation_test.dart` の `狭幅でも文字を大きくしても、ヘッダの数字が消えない` |
| `textScaler` 3.0 の取り分 | 検査しない。`T10` の N-8b′ / N-8b″ が持つ |

