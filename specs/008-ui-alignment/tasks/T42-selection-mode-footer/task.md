# T42 除去の選択モードの操作をフッターへ移す

## 目的

リネーム画面の**除去のための選択モード**(002 REQ-018)で、いま画面上部の帯に置いている「外す」buttonと説明の吹き出しをやめ、**フッターに「戻る」と「外す」を置く**。

## 受領した要望(2026-09-28、原文)

> リネーム画面で選択モードに入った時、外すボタンと説明吹き出しを画面上部の帯に配置してフッターは非表示にしていましたが、フッターに「戻る」ボタンと「外す」ボタンを配置するように修正したいです。

観測の出所は`008:T25`のエミュレータ確認のやりとり(開発者の改善案)。

## 入力と既存taskとの境界

- 002 REQ-018(選択モード): モード中に**選択件数**・**選択したitemを外す操作(0件では実行できない)**・**モードをやめる操作**を提示する。**置き場所と文言は縛っていない**(002 specの「視覚デザインは非規範」)。
- 今の形を決めたtask: `T27`(定義)・`T28`(実装)・`T29`(見せ方: 上部の帯の`×`・`〇件選択中`・外すアイコン・ケバブ)・`T30`(帯の高さと外すアイコンの説明の吹き出し)・`T31`(長押しdragでの複数選択。**選択開始時にフッターが消える分の末尾余白**を確保している)。
- `T25`の通知の置き場(`ToastHost`): モード中はフッターが無いので、通知は領域の下端近くに出る。**モード中もフッターを出すなら、通知はそのフッターの上へ出る**(置き場の仕組みはそのまま効く)。

## 決めること(着手時に開発者へ一問ずつ確かめる)

- 上部の帯に残すもの: `×`(モードをやめる)・`〇件選択中`・外すアイコン・ケバブ(「すべて選択」など)のうち、**どれをフッターへ移し、どれを帯に残すか**。「戻る」はモードをやめる操作(`×`と同じ)か。
- 説明の吹き出し(`T30`)をやめるか、フッターの「外す」へ移すか。「外す」を文字のbuttonにするなら吹き出しの役目(ファイルは削除されないことの説明)をどう残すか。
- 「外す」の見せ方: 危険色(赤)か、件数を含めた文言(例:「2件を外す」)か。0件のときの無効表示。
- `T31`のフッターが消える前提(末尾余白)との整合。

## 決定(2026-09-28)

| 論点 | 決定 | 決定者 |
|---|---|---|
| 配置 | **帯 = `×`(やめる)・`〇件選択中`・ケバブ**。**フッター = 「← 戻る」(やめる。`×`と同じ動き)と「N件を外す」**。外すアイコンは帯から消す。**やめる操作は上(`×`)と下(戻る)の2か所**になる | 開発者 |
| 説明の吹き出し(`T30`) | **やめる**。代わりに**フッターに説明を常設**する。削除と取り違える不安をモード中ずっと打ち消す | 開発者 |
| 説明の文言(2026-09-28、manual 1回目) | 「**選択したファイルをリネームリストから外します。ファイルは削除されません。**」(当初は「リネームリストから外します。…」) | 開発者 |
| フッターの余白(同。manual 1回目の指摘「不自然な余白」) | **案A: 部品を揃える**(3案から選んだ。ほかは「上下2段の全幅button」「大きさの固定をやめる」)。狭幅では説明を**命名ルールのカードと同じ形のカード**(左に四角いアイコン、見出しと太字の2行)にし、下段の「戻る」「N件を外す」をリネームbuttonと同じ高さにする。**通常のフッターの段(Androidでは更新日時の切り替えもある)の分だけ高さが余る分は、説明が伸びて埋める**(中身は縦の中央)。広幅(命名ルールのカードが無い)では説明は1行 | 開発者(案A) / Agent(余りを埋める作り) |
| 説明の文字の拡大 | **1.5倍まで**。長くなった文言が狭幅・最大の文字で何行にも折り返し、フッターが画面の上側を押し出した。**文字は削らない**。操作(戻る・外す)の文字は抑えない | Agent |
| 通常のフッターが無い画面 | 揃える相手が無いので大きさを揃えず、モード中だけ自然な高さのモードのフッターを出す(揃える仕組みを通すと、大きい文字で高さを大きく見積もりすぎた) | Agent |
| 「N件を外す」の色 | **シアン(アクセント)の塗り**、0件では押せない(灰)。赤は削除を連想させるため | 開発者 |
| 「戻る」の形 | app内browserの「← リネーム画面へ」(`008:T39`)と同じ、暗い背景にシアンの枠と文字 | Agent(既存の形に揃える) |
| **フッターの大きさ**(2026-09-28、作業中に受領) | **通常のフッターと選択モードのフッターの大きさを固定する**(「フッターの大きさは固定してください」)。**2つを重ねて高い方に揃える**(`IndexedStack` + `IntrinsicHeight`)ので、画面幅(desktopでは通常のフッターがリネームだけ)や文字の大きさでどちらが高くなっても、モードの出入りで大きさが変わらない | 開発者(固定) / Agent(作り方) |
| **ヘッダーとフッターの色**(2026-09-29、manual 2回目の要望) | **上下とも固定の`#2E2B38`**(開発者がスポイトした色。紫がかった色でよいとの指定)。以前はヘッダーの地がフッターと同じ`#15181D`で、一覧をスクロールしたときだけFlutter既定のsurface tintでヘッダーが明るく紫がかっていた。ヘッダーはスクロールでも変わらない固定の色にする(3案から選んだ: 両方を固定 / ヘッダーはそのままでフッターだけ / フッターだけ中立の灰)。app内browserのフッターも同じ色にする | 開発者 |
| `T31`の末尾余白 | **外す**。フッターの大きさが変わらないので一覧の表示域も変わらず、選択を始めたときに行が跳ばない。以前はフッターが消える分を末尾余白で補っていた(最初は「高さの差を補う」と決めたが、固定の決定で不要になった) | Agent |

## machine検証範囲と引き受け先

- **CIで閉じる**: widget test(下の「自動検証」)とmutation。
- **このtaskのmanual**: エミュレータでの見た目と操作([`manual-verification.md`](manual-verification.md))。

## 実装の記録(2026-09-28)

実装は Claude Opus 5.5。起点は`dev`@`ea4741a`、branch `asdd/008-ui-alignment/T42-selection-mode-footer`、code `8e4f130`。

- `lib/ui/file_list/file_list_view.dart`:
  - 帯(`_HeaderBar`)から外すアイコンと吹き出しへの受け渡し(`hintLink`)を外した。`×`・件数・ケバブは残る。
  - 選択モードのフッター`_RemovalModeBar`: 説明(`removalModeNoteText`)、「← 戻る」(`removalModeBackKey`。`_exitRemovalMode`)、「N件を外す」(`removalModeRemoveKey`をこちらへ移した。0件で`null`)。面と区切り線は通常のフッターと同じ。
  - `_FixedFooter`: 通常のフッターと選択モードのフッターを`IndexedStack`で重ね、`IntrinsicHeight`で高い方に揃える。見えていない側はoffstage(描画・操作・finderの対象外)。通常のフッターが無い画面(ルールも実行も無い)ではモード中だけモードのフッターを出す。**→ 独立review attempt 2 のP2で「通常のフッターが大きさを決める」形へ変えた(下の「attempt 2 の後」)。**
  - `T31`の末尾余白(`_selectionViewportBottomPadding`)とフッターの高さの測定を外した。
- 吹き出し(`lib/ui/file_list/removal_hint.dart`)とそのtest(`test/spec_002_file_list/removal_hint_test.dart`)を削除した。**残る機能のtestは含まれていなかった**(13件すべて吹き出しの表示・位置・閉じ方・フェード)。`header_metrics.dart`と`file_source_bar.dart`の吹き出しへの言及を直した(帯の高さを保つ`T30`の要望1はそのまま)。
- 002 specは変えていない(REQ-018は置き場所と文言を縛らない)。

### 自動検証

- `removal_selection_mode_test.dart`に`008:T42`のgroupを足した(6件): フッターに「戻る」「N件を外す」と説明が出て帯に外すアイコンが無く`×`は残り、「外す」がシアンの塗り / 「戻る」でモードをやめ一覧は変わらない / 「N件を外す」で外れ取り消しの通知が出てモードを抜ける / **フッターの大きさと一覧の下端がモードの出入りで変わらない(スマホ幅の構成 = ルール設定+リネーム、desktop幅の構成 = リネームだけ。どちらも画面は360px幅で試す)** / 見えていない側のフッターは見つからない。
- 既存testの書き換え: 外すbuttonの型(`IconButton` → `FilledButton`。0件で`onPressed == null`は同じ) / 件数の文言のtestでtooltipの代わりに「1件を外す」と説明(「削除されません」を含む)を見る / 帯へ入った長押しdragのtestは、モード中もフッターが出る分だけ画面を高くして以前と同じ一覧の表示域で測る(420→520。assertionは変えていない)。
- `flutter test`: 1011件PASS(吹き出しのtest 13件を削除、6件追加)。`flutter analyze`: No issues。`dart format`: 0 changed。

### mutation

**外したもの(24件)**: 吹き出し(`removal_hint.dart`)を対象にしていた`M351`、`M352`、`M353`、`M363`、`M364`、`M365`、`M366`、`M367`、`M389`、`M371`、`M372`、`M373`、`M374`、`M378`、`M379`、`M380`、`M383`、`M384`、`M385`、`M386`、`M387`、`M388`と、帯の外すアイコン・吹き出しの`M350`・`M354`。**対象のcodeが開発者の決定で無くなった**ため(吹き出しの「削除されません」を守っていた`M353`は、フッターの説明の`M459`が引き継ぐ)。

**移したもの**: `M308`(0件でも外せる → フッターの「外す」)、`M331`(モード中も通常の帯を出す → 重ねたフッターの出し分け)、`M397`(`T31`の行が跳ばない保証 → 末尾余白ではなくフッターの大きさの固定)、`M448`(区切り線 → モードのフッターにも同じ行ができたので通常のフッターの行に絞った)。**新設**: `M457`(「外す」を赤にする)・`M458`(「戻る」が効かない)・`M459`(説明から「削除されません」を落とす)。

`command`を`flutter test test/spec_002_file_list`へ絞って11件を回した:

```text
M293 | KILLED | lib/ui/file_list/removal_undo.dart | 取り消しが一覧を戻さない | exit 1
M307 | KILLED | lib/ui/file_list/file_list_view.dart | 長押しに依存しない入口を落とす | exit 1
M308 | KILLED | lib/ui/file_list/file_list_view.dart | 0件でも外すbuttonを押せる(findを移した) | exit 1
M331 | KILLED | lib/ui/file_list/file_list_view.dart | モード中も通常の帯を出す(findを移した) | exit 1
M335 | KILLED | lib/ui/file_list/file_list_view.dart | ケバブのすべて選択を効かなくする | exit 1
M397 | KILLED | lib/ui/file_list/file_list_view.dart | フッターの大きさを固定しない(行が跳ぶ。findを移した) | exit 1
M442 | KILLED | lib/ui/file_list/removal_undo.dart | 除去の通知を残し続ける | exit 1
M448 | SURVIVED | lib/ui/file_list/file_list_view.dart | フッターの上端の区切り線を消す | exit 0: the tests passed with the mutation applied
M457 | KILLED | lib/ui/file_list/file_list_view.dart | 「N件を外す」を赤にする | exit 1
M458 | KILLED | lib/ui/file_list/file_list_view.dart | フッターの「戻る」が効かない | exit 1
M459 | KILLED | lib/ui/file_list/file_list_view.dart | 説明から「削除されません」を落とす | exit 1
11 mutations: 10 KILLED, 1 SURVIVED, 0 SKIPPED
M448 | KILLED | lib/ui/file_list/file_list_view.dart | (全件のcommandで再実行) | exit 1
1 mutations: 1 KILLED, 0 SURVIVED, 0 SKIPPED
```

(NOTEは要約。`M448`のtestは`spec_005`にあり、絞った範囲の外だった。全件で確かめ直してKILLED。触ったfileで`find`が一致しないのは`dev`時点からの既存13件だけ。)

## manual確認の結果

### 1回目(2026-09-28、Androidエミュレータ、debug、code `8e4f130`)

開発者の報告(会話):「確認事項は問題ありませんでしたが、フッターに不自然な余白ができてしまいます」。1〜5は問題なし。

| 指摘 | 対応 |
|---|---|
| フッターに不自然な余白ができる | 原因: 大きさを通常のフッター(命名ルールのカード・Androidでは更新日時の切り替え・リネーム)に揃えるので、低いモードのフッターに高さが余っていた。**案A(開発者が選んだ)**: 説明を命名ルールと同じ形のカードにし、余った高さはカードが伸びて埋める(`9e836f4`・`450e0c9`)。`M460` |
| 文言を「選択したファイルをリネームリストから外します。ファイルは削除されません。」へ | 変えた。`M459`を追随 |

**1回目の結果は`8e4f130`のbuildに対するもので、再利用しない。** 2回目の対象は`7801591`(当初`450e0c9`としたが、manual前に独立review attempt 2 のP2でcodeを変えた)。

### 2回目(2026-09-29、Androidエミュレータ、debug、code `7801591`)

開発者の報告(会話):「動作は確認できました」。1〜5は問題なし。要望が2件:

| 要望 | 対応 |
|---|---|
| フッターの色をヘッダー(「一括リネーム」)と同じぐらい明るく | 上の決定表のとおり`#2E2B38`に固定(`3e721fa`)。`M467`〜`M471` |
| 「更新日時を一覧の並び順にずらす」を設定ボタン内のオプションへ移したい | **このtaskでは行わない(Agentの推奨。3回目の報告時に開発者が別taskと決めた)**。移すとフッターの高さが変わる。狭幅(命名ルール+リネーム)は今の作りのままで部品がちょうど揃う(testの「命名ルール + リネーム」構成)。広幅(desktop)は通常のフッターがリネームだけになり、今の作りでは選択モードの説明が出なくなる(入る高さが無い構成の判定)ので、移すtaskで広幅の説明の置き方も決める必要がある |

**2回目の結果は`7801591`のbuildに対するもので、色を変えた`3e721fa`へは再利用しない。** 3回目の対象は`3e721fa`。

### 3回目(2026-09-29、Androidエミュレータ、debug、code `3e721fa`)

開発者の報告(会話):「エミュレータ確認は完了しました」。1〜6(6. = ヘッダーとフッターの色)に指摘なし。**PASS**。`3e721fa`以後、`lib/`・`hook/`・`src/`・依存・build設定に差分は無い(以後は`tool/mutations.json`と記録だけ)。

更新日時ずらしの移動は**別taskにする**(2026-09-29 の開発者の決定)。置き場は既存の命名ルールのボタンではなく、**ヘッダーなどに足す新しい歯車のボタン**の中のオプション。`008:T43`として登録する(T42のmerge後)。

**手順の誤り(記録)**: `9e836f4`は、full testの1件(`load_affordance_test`の「狭い画面と大きい文字でも帯の高さが変わらない」)が落ちたままcommitした。commandがtestの結果でcommitを止めていなかった。`450e0c9`で直し(通常のフッターが無い画面では大きさを揃えない、説明の文字の拡大を1.5倍まで)、以後はtestの結果を見てからcommitする。`9e836f4`単体は検証済みのcheckpointではない。

### manual 1回目の後の mutation

`command`を`flutter test test/spec_002_file_list test/spec_005_rename_exec test/spec_004_file_source/load_affordance_test.dart`へ絞った生出力:

```text
M308 | KILLED | lib/ui/file_list/file_list_view.dart | 0件でも外すbuttonを押せる | exit 1
M331 | KILLED | lib/ui/file_list/file_list_view.dart | モード中も通常の帯を出す | exit 1
M397 | KILLED | lib/ui/file_list/file_list_view.dart | フッターの大きさを固定しない | exit 1
M448 | KILLED | lib/ui/file_list/file_list_view.dart | フッターの上端の区切り線を消す | exit 1
M457 | KILLED | lib/ui/file_list/file_list_view.dart | 「N件を外す」を赤にする | exit 1
M458 | KILLED | lib/ui/file_list/file_list_view.dart | フッターの「戻る」が効かない | exit 1
M459 | KILLED | lib/ui/file_list/file_list_view.dart | 説明から「削除されません」を落とす(find追随) | exit 1
M460 | SKIPPED | lib/ui/file_list/file_list_view.dart | 説明が余った高さを埋めない | matched 0 time(s), expected 1
M461 | KILLED | lib/ui/file_list/file_list_view.dart | 説明の文字の拡大を抑えない | exit 1
9 mutations: 8 KILLED, 0 SURVIVED, 1 SKIPPED
M460 | KILLED | lib/ui/file_list/file_list_view.dart | (findを今の形に合わせて単独で再実行) | exit 1
1 mutations: 1 KILLED, 0 SURVIVED, 0 SKIPPED
```

(NOTEは要約。`M460`は最初の形(`Expanded`→`Flexible`)がカードの`alignment`のため等価mutantで一度SURVIVEDし、伸ばす枠を外す形に直した。その後、説明の置き場を文字の拡大の抑えで包んだので`find`がずれてSKIPPED → 合わせてKILLED。full test 1013件PASS。追加したtest: 説明のカードが余った高さを埋め空きを残さない(命名ルール+リネーム、命名ルール+更新日時の切り替え+リネーム))

## 独立review

**reviewerのmodelは`gpt-6-luna`**(開発者指定。実装はClaude Opus 5.5)。

- attempt 1: `ea4741a..89b1c08`(全範囲、implementation) — **PASS**(P2が1件)。決定表・002 REQ-017/018との一致、`_FixedFooter`のoffstage側が操作・semantics・finderの対象外であること、`ToastHost`との関係、吹き出しの削除で残る保証を失っていないこと、testの書き換えが保証を弱めていないこと、mutationの整理の妥当性、manualの具体性、full test 1011件PASSを確認された。reviewerの範囲付きmutation 7件(M308・M331・M397・M448・M457〜M459)はKILLED。
  - **P2(安全網の穴)**: 「desktop幅」と名付けた高さ固定のtestは、画面を360px幅のまま通常のフッターの中身(リネームだけ)を変えて試しており、2ペインの配置そのものは通していない。**受容する**: 幅がフッターに効くのは中身(ルール設定の有無)だけで、それはtestが再現している。`_FixedFooter`は幅に依らず`IntrinsicHeight`で高い方に揃える。FAIL条件(データ損失等)に当たらない。引き受け先のtaskは無い(desktopはmanualの対象外 — エミュレータで確認する方針)。記録上の呼び方を「desktop幅の構成」に正確にした。
  - **SELF-CHECK**: この対応は記録(`specs/`)だけ。
- attempt 2: `89ba6b1..dd7e3be`(差分、manual 1回目の指摘への対応) — **PASS**(P2が2件)。
  - **P2(成果物の欠陥)**: 「高い方に揃える」は、モードのフッターの方が高くなる構成(広幅 = 切り替え+リネーム、ルールが空 = ルール設定が低いbutton)で**通常のフッターに空きを作る**。manual 1回目で直した「不自然な余白」を、通常のフッター側へ移しただけになる。→ `7801591`で直した(下)。
  - **P2(成果物の欠陥)**: 手順書が説明の文字の拡大の上限(1.5倍)を「仕様どおり」と書いていたが、specの要求ではなくAgentの判断である。→ 手順書を直した(Agentの判断と明記)。
- attempt 3: `dd7e3be..0acb2db`(差分、attempt 2 のP2への対応) — **PASS**(P3が1件)。**reviewerのmodelはClaude Sonnet**: `gpt-6-luna`が利用上限で途中停止したため、開発者の許可(2026-09-28「lunaが使えないなら、claudeのsonnetに続きをやらせてかまいません」)で切り替えた。既定(`gpt-6-luna`の開発者指定)との食い違いとして記録する。attempt 2 のP2 2件が閉じたこと、`Visibility`の既定(`maintainInteractivity`・`maintainSemantics`がfalse)で隠した通常のフッターが操作・semanticsの対象外になること(framework実装で確認)、説明を出さない構成が製品に無いこと、`expectNormalFooterHidden`への書き換えが保証を弱めていないこと、mutationの追随と追加、記録の真偽を確認された。format・analyze PASS、full test 1015件PASS、`workspace.py check specs` PASS。範囲付きmutation 8件(M331・M397・M460・M462〜M464・reviewer設計R1・R2)は7 KILLED・1 SURVIVED(R2、対照)。
  - **P3(安全網の穴)**: モード中に通常のフッターがsemanticsから外れていることを直接見るtestが無い(R2 = `maintainSemantics: true`がSURVIVED)。**受容する**: 実装は既定値で正しく、通り抜ける失敗(TalkBackが隠れたbuttonを読む)はFAIL条件(データ損失・無断置換・偽の成功・権限逸脱・互換性破壊)に当たらない。引き受け先のtaskは無い(TalkBackはmanualの対象外)。
  - reviewerのR1・R2を`M465`・`M466`として`tool/mutations.json`へ取り込んだ(`M466`は対照でSURVIVEDが期待値)。
  - **SELF-CHECK**: 取り込みの差分は`tool/mutations.json`へreviewerの定義をそのまま足したものと記録だけで、`lib/`・`test/`に差分は無い。足した2件はreviewerが実行済み(上の結果)なので、再reviewは起動しない。
  - 連鎖: `ea4741a..89b1c08` PASS → `89ba6b1..dd7e3be` PASS → `dd7e3be..0acb2db` PASS → 以降は記録とmutationの取り込み(SELF-CHECK)。
- attempt 4: `0acb2db..a836246`(差分、manual 2回目の要望でヘッダーとフッターの色を固定) — **PASS**(P3が1件)。reviewerのmodelは`gpt-6-luna`(利用上限が解けたので既定へ戻した)。決定表と実装の一致(`AppColors.bar`・`appBarTheme`・3つのフッター)、`copyWith`/`lerp`の漏れが無いこと、appBarThemeが及ぶのはメイン画面とapp内browserの2つのAppBarで要望と整合すること、トースト(`#262C36`)と区切り線が新しい色の上で読めること、manual 2回目の対象`7801591`と3回目の対象`3e721fa`の区別、手順6.の具体性を確認された。full test 1016件PASS(`docker`がcontainer内に無く`flutter test`を直接実行)。範囲付きmutation 6件(M467〜M471・reviewer設計の対照)は5 KILLED・1 SURVIVED。
  - 実装側で行ったmutation(色の追加時。`command`を`flutter test test/spec_002_file_list/removal_selection_mode_test.dart`へ絞った5件): `M467`〜`M471`すべてKILLED(`5 mutations: 5 KILLED, 0 SURVIVED, 0 SKIPPED`)。
  - **P3(安全網の穴)**: app内browserのフッターの色を直接見るtestが無い(reviewerの対照 = `bar`→`surface`がSURVIVED)。`M472`として取り込み、**全件のcommandでもSURVIVED**を確かめた(`1 mutations: 0 KILLED, 1 SURVIVED, 0 SKIPPED`)。**受容する**: 見た目だけの回帰で、FAIL条件(データ損失・無断置換・偽の成功・権限逸脱・互換性破壊)に当たらない。manual 6.の4.で人間が確認する。引き受け先のtaskは無い。
  - **SELF-CHECK**: この後の差分は`M472`の取り込み(`tool/mutations.json`へreviewerの定義を足しただけ)と記録だけで、`lib/`・`test/`に差分は無い。再reviewは起動しない。
  - 連鎖: … → `dd7e3be..0acb2db` PASS → `0acb2db..a836246` PASS → 以降は記録とmutationの取り込み(SELF-CHECK)。

### attempt 2 の後(`7801591`)

- `_FixedFooter`: **大きさは常に通常のフッターが決める。** 通常のフッターはモード中も`Visibility`(`maintainSize`)で**場所を取ったまま**隠し(描画・操作・semanticsの対象外)、モードのフッターは`Positioned.fill`でその枠に重ねる。通常のフッターは一切変わらない。
- 説明は余った高さを埋め、足りなければ`_FitNote`(`FittedBox`の`scaleDown`)で全体を縮めて収める(文字は削らない)。**説明の入る高さ(間10+最小16)が残らない構成では説明を出さない** — 通常のフッターがリネームだけ(更新日時の切り替えも無い)の場合で、製品の構成(Android・desktopの実行手段は`ModifiedAtWriter`)には無い。
- test: 高さ固定のtestを4構成へ広げた(スマホ幅 = 命名ルール+切り替え+リネーム / 広幅 = 切り替え+リネーム / ルールが空 / リネームだけ)。各構成で**通常のフッターに空きが無い**(上端の部品とリネームがフッターの余白12の位置)、モードの出入りで大きさと一覧の下端が変わらない、はみ出さない、説明が操作の上に収まる(リネームだけでは出ない)を確かめる。「モード中は通常のフッターが見つからない」系の3件は、場所を取ったまま隠す形に合わせて「押せない・`Visibility`が隠している」(`expectNormalFooterHidden`)へ書き換えた(保証は同じ: モード中に通常の帯の操作が出ない)。表示内容のtestは製品と同じ構成(実行手段・切り替えあり)で組む。
- 検証: `flutter test` 1015件PASS、`flutter analyze`・`dart format`PASS。
- mutation: `M331`・`M397`・`M460`の`find`を追随させ、`M462`(説明を出さない判定を外す)・`M463`(説明を縮めない)・`M464`(モードのフッターを枠に重ねず並べる = 「高い方に揃える」へ戻る)を足した。`command`を`flutter test test/spec_002_file_list test/spec_005_rename_exec`へ絞った7件の生出力:

```text
M331 | KILLED | lib/ui/file_list/file_list_view.dart | モード中も通常の帯を出す(find追随) | exit 1
M397 | KILLED | lib/ui/file_list/file_list_view.dart | 隠した通常のフッターが場所を取らない(find追随) | exit 1
M460 | KILLED | lib/ui/file_list/file_list_view.dart | 説明が余った高さを埋めない(find追随) | exit 1
M461 | SURVIVED | lib/ui/file_list/file_list_view.dart | 説明の文字の拡大を抑えない | exit 0: the tests passed with the mutation applied
M462 | KILLED | lib/ui/file_list/file_list_view.dart | 説明の入る高さが無くても説明を出す | exit 1
M463 | KILLED | lib/ui/file_list/file_list_view.dart | 説明を枠に収めない | exit 1
M464 | KILLED | lib/ui/file_list/file_list_view.dart | モードのフッターを枠に重ねず並べる | exit 1
7 mutations: 6 KILLED, 1 SURVIVED, 0 SKIPPED
M461 | KILLED | lib/ui/file_list/file_list_view.dart | (SURVIVEDを全件のcommandで確かめ直した) | exit 1
1 mutations: 1 KILLED, 0 SURVIVED, 0 SKIPPED
```

(NOTEは要約。`M461`を殺すのは範囲外の`test/spec_004_file_source/load_affordance_test.dart`(通常のフッターが無い画面の大きい文字)。`dev`の時点で`find`が合わない既存の14件(`M116`・`M178`〜`M358`)はこのtaskの対象外で、`dev`と同じ。)

## Current state / handoff

- Last checkpoint: PR #194をmerge commitで`dev`へmerge(2026-09-29、`eca7d3d`)。merge条件1〜7を確認した: Draftでない・一意 / 独立reviewの連鎖(`ea4741a..89b1c08`・`89ba6b1..dd7e3be`・`dd7e3be..0acb2db`・`0acb2db..a836246`がPASS、以降はmutationの取り込みと記録のSELF-CHECK) / CI `check` PASS・未解決threadなし / baseは`ea4741a`で最新・競合なし、full test 1016件PASS(code `3e721fa`、以後code差分なし) / manual 3回目が`3e721fa`に対応 / 未解決P0/P1なし(P3 2件は受容済み) / `.github/workflows`・AGENTS.md・sandbox境界の変更なし。
- Blocker category: なし。
- Waiting for: なし。
- Requested action: なし。
- Evidence revision: 起点は`dev`@`ea4741a`、merge `eca7d3d`。
- Next Agent action: なし(done)。更新日時ずらしの移動は`008:T43`。
