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
| 説明の吹き出し(`T30`) | **やめる**。代わりに**フッターのbuttonの上へ小さな説明を常設**する(「リネームリストから外します。ファイルは削除されません。」)。削除と取り違える不安をモード中ずっと打ち消す | 開発者 |
| 「N件を外す」の色 | **シアン(アクセント)の塗り**、0件では押せない(灰)。赤は削除を連想させるため | 開発者 |
| 「戻る」の形 | app内browserの「← リネーム画面へ」(`008:T39`)と同じ、暗い背景にシアンの枠と文字 | Agent(既存の形に揃える) |
| **フッターの大きさ**(2026-09-28、作業中に受領) | **通常のフッターと選択モードのフッターの大きさを固定する**(「フッターの大きさは固定してください」)。**2つを重ねて高い方に揃える**(`IndexedStack` + `IntrinsicHeight`)ので、画面幅(desktopでは通常のフッターがリネームだけ)や文字の大きさでどちらが高くなっても、モードの出入りで大きさが変わらない | 開発者(固定) / Agent(作り方) |
| `T31`の末尾余白 | **外す**。フッターの大きさが変わらないので一覧の表示域も変わらず、選択を始めたときに行が跳ばない。以前はフッターが消える分を末尾余白で補っていた(最初は「高さの差を補う」と決めたが、固定の決定で不要になった) | Agent |

## machine検証範囲と引き受け先

- **CIで閉じる**: widget test(下の「自動検証」)とmutation。
- **このtaskのmanual**: エミュレータでの見た目と操作([`manual-verification.md`](manual-verification.md))。

## 実装の記録(2026-09-28)

実装は Claude Opus 5.5。起点は`dev`@`ea4741a`、branch `asdd/008-ui-alignment/T42-selection-mode-footer`、code `8e4f130`。

- `lib/ui/file_list/file_list_view.dart`:
  - 帯(`_HeaderBar`)から外すアイコンと吹き出しへの受け渡し(`hintLink`)を外した。`×`・件数・ケバブは残る。
  - 選択モードのフッター`_RemovalModeBar`: 説明(`removalModeNoteText`)、「← 戻る」(`removalModeBackKey`。`_exitRemovalMode`)、「N件を外す」(`removalModeRemoveKey`をこちらへ移した。0件で`null`)。面と区切り線は通常のフッターと同じ。
  - `_FixedFooter`: 通常のフッターと選択モードのフッターを`IndexedStack`で重ね、`IntrinsicHeight`で高い方に揃える。見えていない側はoffstage(描画・操作・finderの対象外)。通常のフッターが無い画面(ルールも実行も無い)ではモード中だけモードのフッターを出す。
  - `T31`の末尾余白(`_selectionViewportBottomPadding`)とフッターの高さの測定を外した。
- 吹き出し(`lib/ui/file_list/removal_hint.dart`)とそのtest(`test/spec_002_file_list/removal_hint_test.dart`)を削除した。**残る機能のtestは含まれていなかった**(13件すべて吹き出しの表示・位置・閉じ方・フェード)。`header_metrics.dart`と`file_source_bar.dart`の吹き出しへの言及を直した(帯の高さを保つ`T30`の要望1はそのまま)。
- 002 specは変えていない(REQ-018は置き場所と文言を縛らない)。

### 自動検証

- `removal_selection_mode_test.dart`に`008:T42`のgroupを足した(6件): フッターに「戻る」「N件を外す」と説明が出て帯に外すアイコンが無く`×`は残り、「外す」がシアンの塗り / 「戻る」でモードをやめ一覧は変わらない / 「N件を外す」で外れ取り消しの通知が出てモードを抜ける / **フッターの大きさと一覧の下端がモードの出入りで変わらない(スマホ幅とdesktop幅)** / 見えていない側のフッターは見つからない。
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

## 独立review

**reviewerのmodelは`gpt-6-luna`**(開発者指定。実装はClaude Opus 5.5)。

## Current state / handoff

- Last checkpoint: 実装とmachine検証が済んだ(2026-09-28、code `8e4f130`)。
- Blocker category: なし(`T25`は2026-09-28にdone)。
- Waiting for: 独立review attempt 1(全範囲)。その後エミュレータのmanual。
- Requested action: なし。
- Evidence revision: 起点は`dev`@`ea4741a`。
- Next Agent action: review → manual依頼 → 結果を記録 → merge判断。
