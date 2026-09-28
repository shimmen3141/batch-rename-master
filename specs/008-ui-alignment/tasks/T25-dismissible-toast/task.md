# T25 通知(toast)を自分で閉じられるようにする

## 目的

一時的に出る通知(`SnackBar`)を、**利用者が邪魔だと思ったときに消せる**ようにする。

## 受領した要望(2026-09-18、原文)

> 一時的に表示されるトーストは、ユーザが邪魔だと思ったときに消せたほうが良いと思うので、右上に円と×マーク（円はトーストの枠から少しはみ出してもよい。一部重なるぐらいのイメージ）で閉じられるようにしたいです。

観測の出所は `008:T03` の承認時のやりとり。

## 入力と依存

- 現行の通知の出どころ:
  - `lib/ui/file_source/file_source_bar.dart` — 読み込みの失敗(`file-source-error`。004 REQ-008)、
    複数folder警告(`multi-folder-warning`。004 REQ-012)、未実装の種類(`file-kind-unimplemented`。004 REQ-011)
  - `008:T04` が新しく出す**除去の取り消し**(002 REQ-017)
  - 他にも `SnackBar` を出す箇所があれば同じ扱いにする(着手時に洗い出す)
- **`T04` と同じ画面に出る。** どちらが先でもよいが、**取り消しの通知もこの形に揃える**。

## 変更範囲

- 通知を1か所で組み立てる共有の入口(widget または helper)を作り、**右上に閉じる操作**を置く。
- 既存の通知をすべてその入口へ寄せる。
- **文言・発火条件・重大度の色は変えない。** 004 REQ-008/011/012 と 002 REQ-017 が課す
  「何を伝えるか」は触らず、変えるのは**閉じられるかどうか**だけである。

## 先に決めること

- **閉じる操作と「元に戻す」の関係。** 002 REQ-017 の取り消しは通知の中にある。
  閉じる操作が同じ通知に同居するので、**押し間違いで取り消しを失わない**配置にする
  (円と×は右上、取り消しは本文側)。
- **見た目の作り方。** `SnackBar` の外へはみ出す円は `Stack` + `clipBehavior: Clip.none` で作る。
  はみ出し方が狭幅・大きい文字で崩れないことを機械で固定する(`008:T16`/`T08` と同じ格子)。
- **accessibility**: 閉じる操作に tooltip / semantics label を付ける。
- 自動で消えるまでの時間を変えるか(変えないのが既定)。

## 決定(2026-09-28)

**開発者の依頼で、閉じる操作に加えて通知の見た目をdesign土台(`docs/design/Bulk Renamer.html`のtoast)へ寄せる。** 上の「変更範囲」にある「重大度の色は変えない」は、**見せ方を変える**ことをこの決定で置き換える(何を伝えるか・いつ出すか・重大度の区別そのものは変えない)。

| 論点 | 決定 | 決定者 |
|---|---|---|
| 重大度の見せ方 | **全通知を同じ暗いカードにし、重大度は先頭のアイコンと左端の細い色帯で示す**(成功 = ✓緑 / エラー = !赤 / 案内 = i青)。今の赤・青の全面背景はやめる。色だけに頼らずアイコンの形でも区別する | 開発者 |
| 形と位置 | 下から浮いたカード(左右14・下18の余白、角丸13、`#1a1f26`相当の面、薄い枠線と影)。design土台のとおり | Agent(design土台) |
| 閉じる操作 | 右上の円と×。**カードの角へ一部重なる**(要望のとおり)。押せる範囲はカードの外側の余白に確保し、当たり判定を失わない。tooltip「通知を閉じる」 | 開発者(要望) / Agent(作り方) |
| 「元に戻す」 | design土台のシアンを薄く敷いたpill。**本文側(右端の×とは別の位置)**に置き、押し間違いで取り消しを失わない | Agent(design土台) |
| 自動で消えるまでの時間 | **変えない**(改名の取り消しは005 REQ-007の5秒、それ以外はFlutterの既定) | Agent(既定) |
| 各通知の重大度 | 成功: 改名の結果(失敗を含まないとき)・除去・元に戻した結果(失敗を含まないとき)。エラー: 今の赤の通知(読み込みの失敗、複数folder、実在名を取得できない、権限が無い2種)と、失敗を含む改名・元に戻した結果。案内: 今の青の通知(未実装の種類)と「一覧が変わったため、取り消せませんでした」(何も失っていない) | Agent |

| 通知の位置(2026-09-28、manual 1回目の指摘) | **フッター(ルール設定とリネームのbutton)の少し上**(8px)に出す。フッターが無い画面(除去の選択モードなど)ではdesign土台の下18px。**作り方は通知の置き場(`ToastHost`)**: 一覧とフッターを含む領域に内側の`ScaffoldMessenger`/`Scaffold`を持たせ、フッターを`bottomNavigationBar`にする。浮いた通知はScaffoldが毎frameフッターの上へ置き(表示中に高さが変わっても追随)、領域の幅に収まる(2ペインでも右ペインを覆わない)。置き場の外(読み込みbar)の通知も置き場へ送る。**最初はフッターの高さをグローバルに受け渡して`SnackBar`の余白にしたが、独立review attempt 2 のP1 2件でやめた** | 開発者(位置) / Agent(作り方) |
| 通知の面の色(同) | **一覧の行(`surfaceElevated`)より一段明るい`#262C36`**、枠線は白16%。同じ色だと暗い背景と行に埋もれて見づらかった | 開発者(明るく) / Agent(値) |
| フッターの区切り線(同。**通知とは別だがこのtaskで入れる**) | フッターの上端にdesign土台と同じ区切り線(白8%、`colors.border`)を入れる。一覧との境目が読めなかった | 開発者 |

**design土台との差分**: 土台のtoastは成功(✓)だけを示している。エラー・案内を同じ形へ広げ、閉じる×を足した(土台に無い)。

## 通知の出どころ(着手時の洗い出し、2026-09-28)

| 場所 | 通知 |
|---|---|
| `lib/ui/file_list/file_list_view.dart` | 改名の結果(元に戻すあり)、実在名を取得できない、改名・元に戻すの権限が無い(2種)、元に戻した結果 |
| `lib/ui/file_list/removal_undo.dart` | 除去の取り消し(元に戻すあり)、取り消せなかった |
| `lib/ui/file_source/file_source_bar.dart` | 未実装の種類、読み込みの失敗、複数folderの警告 |

## 受け入れ証拠

- すべての通知に閉じる操作が出て、押すと消える(widget test)。
- 取り消しを持つ通知で、閉じる操作と取り消しが**別の当たり判定**である。
- 狭幅・大きい文字ではみ出しや切り詰めが起きない。
- 実機で、円の重なり方が意図どおりに見える(`manual-verification.md`)。

## 実装の記録(2026-09-28)

実装は Claude Opus 5.5。起点は`dev`@`78352cf`、branch `asdd/008-ui-alignment/T25-dismissible-toast`、code `a207dae`。

- `lib/ui/common/app_toast.dart`: 通知の唯一の入口`showAppToast`と`AppToastCard`。`SnackBar`(floating、透明、余白0)の中に暗いカード(`surfaceElevated`、角丸13、薄い枠線と影、左右14・下18)を描く。重大度は先頭のアイコン(✓ / i / !)と左端3pxの色帯。**閉じる円は、カードの外側に取った余白(14px)の中へ置き、カードの右上の角へ一部重ねる** — 親の範囲の外は押せないため、はみ出した部分も当たり判定に入れる。当たり判定は32px四方で、tooltip「通知を閉じる」。**操作(「元に戻す」)があるときはカードの右の余白を広げ、閉じる円の当たり判定と重ねない。** 操作を押すと通知を下げてから操作する。
- **10件の通知**(`file_list_view.dart` 5件、`removal_undo.dart` 2件、`file_source_bar.dart` 3件。上の「通知の出どころ」)をすべて寄せた。keyと文言は変えていない。**除去の通知は`persist: true`** — 以前は`SnackBarAction`付きの`SnackBar`で、Flutterの既定により自動では消えなかった。それを保つ。改名の結果は以前どおり`undoWindow`(5秒)で消える。
- 重大度の割り当ては上の決定表のとおり。改名・元に戻した結果は、失敗を含むときだけエラーにする。

### 自動検証

- 新規`test/spec_002_file_list/app_toast_test.dart`(10件): 閉じる円で消える、支援技術から「通知を閉じる」で押せる、重大度3種のアイコン・色帯・面の色、「元に戻す」と閉じる円が別の当たり判定で閉じても取り消さない、「元に戻す」が1回だけ走り通知が下がる、既定は自動で消えpersistは残る、閉じる円がカードの角へ一部重なりはみ出した部分も押せる、320px幅・文字1.6倍でoverflowせず×と「元に戻す」が重ならない。
- 既存testへ足したもの: 除去の通知が成功の見せ方で自動では消えず、閉じても取り消さない(`file_list_view_test.dart`)。複数folderの警告がエラー、未実装の種類が案内(`ui_entry_test.dart`)。改名の結果と元に戻した結果が成功、**失敗を含む改名の結果がエラー**(`warning_confirmation_results_test.dart`)。
- 実装中に見つけて直したもの: 閉じる円の当たり判定と「元に戻す」が数px重なっていた(testが検出)。
- `flutter test`: 1007件PASS。`flutter analyze`: No issues。`dart format`: 0 changed。

### mutation

T25で足した`M438`〜`M444`と、通知を寄せたことで字下げが変わり`find`を追随させた既存7件(`M39`、`M293`、`M294`、`M296`、`M299`、`M300`、`M302`)を、関連test(`app_toast_test`、`file_list_view_test`、`ui_entry_test`、`spec_005_rename_exec`、`removal_selection_mode_test`、`load_affordance_test`)へ絞って回した:

```text
M438 | KILLED | lib/ui/common/app_toast.dart | 閉じる円を押しても通知が消えない | exit 1
M439 | KILLED | lib/ui/common/app_toast.dart | 操作があっても右を空けない | exit 1
M440 | KILLED | lib/ui/common/app_toast.dart | エラーを成功の色で示す | exit 1
M441 | KILLED | lib/ui/file_list/file_list_view.dart | 失敗を含む改名の結果を成功の見せ方で出す | exit 1
M442 | KILLED | lib/ui/file_list/removal_undo.dart | 除去の通知を自動で消す | exit 1
M443 | KILLED | lib/ui/file_source/file_source_bar.dart | 複数folderの警告を案内の見せ方にする | exit 1
M444 | KILLED | lib/ui/common/app_toast.dart | 「元に戻す」を押しても通知を下げない | exit 1
M39 | KILLED | lib/ui/file_list/file_list_view.dart | REQ-027の理由提示を除去(find追随) | exit 1
M293 | KILLED | lib/ui/file_list/removal_undo.dart | 取り消しが一覧を戻さない(find追随) | exit 1
M294 | KILLED | lib/ui/file_list/removal_undo.dart | 取り消しで並びが変わる(find追随) | exit 1
M296 | KILLED | lib/ui/file_list/removal_undo.dart | 取り消しで占有名を戻さない(find追随) | exit 1
M299 | KILLED | lib/ui/file_list/removal_undo.dart | 控えが古くなっていても戻す(find追随) | exit 1
M300 | KILLED | lib/ui/file_list/removal_undo.dart | 並び順の種別を見ない(find追随) | exit 1
M302 | KILLED | lib/ui/file_list/removal_undo.dart | 占有名の取り直しを見ない(find追随) | exit 1
14 mutations: 14 KILLED, 0 SURVIVED, 0 SKIPPED
```

(NOTEは要約。T25が触ったfileのmutationで`find`が一致しないものは、上の7件を追随させた後、`dev`の時点で既に一致していなかった13件(`M178`など。`008:T39`で報告済み)だけである。)

## machine検証範囲と引き受け先

- **CIで閉じる**: 上の自動検証。
- **このtaskのmanual**: エミュレータでの見た目(円の重なり方、色帯、カードの浮き方)と閉じる操作の手触り([`manual-verification.md`](manual-verification.md))。
- 「一覧が変わったため、取り消せませんでした」・実在名を取得できない・読み込みの失敗・複数folderの警告は、エミュレータで出しにくいのでmanualでは見ない(形は共通の入口で同じ。重大度の割り当てはwidget testとmutationで固定した)。

## manual確認の結果

### 1回目(2026-09-28、Androidエミュレータ、debug、code `a207dae`)

開発者の報告(会話):「確認事項についてはすべて確認できましたが、UIデザインは改善したいです」。**0〜5はPASS**(閉じる操作・重大度・「元に戻す」・自動で消えるまでの時間・大きい文字)。デザインについての指摘:

| 指摘 | 対応(`1005f11`) |
|---|---|
| 通知が画面下部に出て、リネームのbuttonなどと干渉して押しにくい。フッターの少し上へずらしたい | フッターの上に8pxの隙間で出す(`1005f11`で高さの受け渡し → `aa78f2a`で通知の置き場へ作り直した)。`M446`・`M449`〜`M451` |
| 通知の色が背景と同化して見づらい。参考デザインのように明るいトーンにしたい | 面を`#262C36`、枠線を白16%へ。`M447` |
| (通知とは別)フッターの境界に参考デザインのような明るい区切り線を入れたい | フッターの上端に白8%の線。`M448` |

**1回目の結果は`a207dae`のbuildに対するもので、再利用しない。** 2回目の対象は`aa78f2a`。 2回目は0〜5に、位置・色・区切り線の確認を足して通して見る。

## 独立review

**reviewerのmodelは`gpt-6-luna`**(開発者指定。実装はClaude Opus 5.5)。

- attempt 1: `78352cf..f954f96`(全範囲、implementation) — **PASS**(P2が2件)。10件の通知の集約、文言・発火条件・自動で消えるまでの時間の維持(除去の通知の`persist`はFlutterの既定がactionの有無に従うことをSDKで確認)、重大度の割り当て、閉じる円と「元に戻す」の別の当たり判定、閉じる操作が取り消しを呼ばないこと、はみ出した円の押下、狭幅・大きい文字、design土台との差分の記録、testを弱めていないこと、full test 1007件PASSを確認された。reviewerの範囲付きmutation 5件(M438・M439・M442・M444と対照1件)はKILLED。
  - **P2(成果物の欠陥)**: task.mdが通知を「9か所」と書いていたが、実際は10件。→ 件数と内訳を直した。
  - **P2(成果物の欠陥)**: manualのfixture準備で、同名のフォルダが既にあった場合に、後片付けの「消してよい」が既存のフォルダを誤って消す余地を残していた。→ 既にあって止まった場合は後片付けで消さないことを明記した。
  - reviewerの対照(閉じる円で「元に戻す」を実行する)を`M445`として取り込んだ。
  - **SELF-CHECK**(AGENTS.mdの差分review): P2を閉じる差分は`specs/`と`tool/mutations.json`(対照の追加)だけで、`lib/`・`test/`・依存・build設定は変えていない。再reviewは起動しない。

- attempt 2: `f954f96..bd38890`(差分) — **FAIL**(このtaskで1回目)。色・枠線・区切り線は決定表と一致、閉じる・「元に戻す」・自動で消える時間・重大度に回帰なし、testを弱めていない、full test 1010件PASS、は確認された。
  - **P1(成果物の欠陥)**: 通知を出した時点のフッターの高さで`SnackBar.margin`を固定していたので、**表示中にフッターの高さが変わっても追随しない**。
  - **P1(成果物の欠陥)**: 通知はアプリ全体の`ScaffoldMessenger`から出るので、**desktopの2ペインでは左のフッターで持ち上げたカードが右ペインにも重なる**。
  - → **解き方を変えた**(同じ枠組みに条件を足しても2件とも解けない): 一覧とフッターの領域に通知の置き場(`ToastHost`、内側の`ScaffoldMessenger`/`Scaffold`)を持たせ、フッターを`bottomNavigationBar`にした(`aa78f2a`)。高さの受け渡し(`ToastFooter`/`toastBottomInset`)は廃止した。表示中の高さの変化・2ペイン・置き場の外からの通知をwidget testで固定した。
  - reviewerの対照(実測高に24px足す)を、置き場の形へ移して`M451`として取り込んだ。**最初はSURVIVEDした** — testが隙間の期待値を定数から取っていたため。決定の値(8px)を直接書くよう直してKILLED。

- attempt 3: `bd38890..66ee22c`(差分) — **PASS、指摘なし**。attempt 2のP1 2件(表示中のフッター高の変化に追随しない、2ペインで右ペインを覆う)は**閉じた**と確認された(testが直接検査している)。内側Scaffoldによる一覧・フッター・除去の選択モード・`PopScope`の構成、`_hosts`の登録と解除、`replaceCurrent`・閉じる・「元に戻す」が選ばれた送り先に効くこと、app内browserのrouteから置き場へ送る製品経路が無いこと、`find`の追随が意味を変えていないこと(特に`M331`)、記録の一致、full test 1013件PASSを確認された。reviewerの範囲付きmutation 5件(M331・M446・M449〜M451)はKILLED。

### manual 1回目の指摘への対応(`1005f11`)の mutation

`command`を`flutter test test/spec_002_file_list/app_toast_test.dart test/spec_005_rename_exec/warning_confirmation_results_test.dart`へ絞り、今回足した4件と、同じfileの閉じる操作を守る2件を回した:

```text
M438 | KILLED | lib/ui/common/app_toast.dart | 閉じる円を押しても通知が消えない | exit 1
M439 | KILLED | lib/ui/common/app_toast.dart | 操作があっても右を空けない | exit 1
M446 | KILLED | lib/ui/common/app_toast.dart | フッターの高さを無視して下端から出す | exit 1
M447 | KILLED | lib/ui/common/app_toast.dart | 通知の面を一覧の行と同じ色に戻す | exit 1
M448 | KILLED | lib/ui/file_list/file_list_view.dart | フッターの上端の区切り線を消す | exit 1
M449 | KILLED | lib/ui/common/app_toast.dart | フッターが高さを知らせない | exit 1
6 mutations: 6 KILLED, 0 SURVIVED, 0 SKIPPED
```

full test 1010件PASS。触ったfileのmutationで`find`が一致しないのは、`dev`時点から一致しない既存13件だけである。

### attempt 2 のFAIL後の作り直し(`aa78f2a`)の mutation

`command`を`flutter test test/spec_002_file_list test/spec_005_rename_exec test/spec_004_file_source/ui_entry_test.dart`へ絞り、置き場に関わるもの(`M446`・`M449`は`find`を入れ替え、`M450`・`M451`を新設)と、作り直しで`find`がずれて追随させたもの(`M307`・`M308`・`M331`・`M335`・`M397`は一覧を置き場で包んだ字下げ・整形、`M438`・`M444`・`M445`は送り先を`target`にしたため)、同じfileの既存の取り消し・除去の保証(`M293`・`M299`・`M439`・`M442`・`M447`・`M448`)を回した:

```text
M293 | KILLED | lib/ui/file_list/removal_undo.dart | 取り消しが一覧を戻さない | exit 1
M299 | KILLED | lib/ui/file_list/removal_undo.dart | 控えが古くなっていても戻す | exit 1
M307 | KILLED | lib/ui/file_list/file_list_view.dart | 長押しに依存しない入口を落とす(find追随) | exit 1
M308 | KILLED | lib/ui/file_list/file_list_view.dart | 0件でも外すbuttonを押せる(find追随) | exit 1
M331 | KILLED | lib/ui/file_list/file_list_view.dart | モード中も下部の帯を出す(findを書き直し) | exit 1
M335 | KILLED | lib/ui/file_list/file_list_view.dart | ケバブのすべて選択を効かなくする(find追随) | exit 1
M397 | KILLED | lib/ui/file_list/file_list_view.dart | 選択開始時の末尾余白を除く(find追随) | exit 1
M438 | KILLED | lib/ui/common/app_toast.dart | 閉じる円を押しても通知が消えない(find追随) | exit 1
M439 | KILLED | lib/ui/common/app_toast.dart | 操作があっても右を空けない | exit 1
M442 | KILLED | lib/ui/file_list/removal_undo.dart | 除去の通知を自動で消す | exit 1
M444 | KILLED | lib/ui/common/app_toast.dart | 「元に戻す」を押しても通知を下げない(find追随) | exit 1
M445 | KILLED | lib/ui/common/app_toast.dart | [対照] 閉じる円で「元に戻す」を実行する(find追随) | exit 1
M446 | KILLED | lib/ui/common/app_toast.dart | フッターとの隙間の指定を外す(find入れ替え) | exit 1
M447 | KILLED | lib/ui/common/app_toast.dart | 通知の面を一覧の行と同じ色に戻す | exit 1
M448 | KILLED | lib/ui/file_list/file_list_view.dart | フッターの上端の区切り線を消す | exit 1
M449 | KILLED | lib/ui/common/app_toast.dart | 置き場へ送らず呼び出し側のmessengerへ出す(find入れ替え) | exit 1
M450 | KILLED | lib/ui/common/app_toast.dart | 置き場を登録しない | exit 1
M451 | SURVIVED | lib/ui/common/app_toast.dart | [対照] フッターとの隙間を24pxにする | exit 0: the tests passed with the mutation applied
18 mutations: 17 KILLED, 1 SURVIVED, 0 SKIPPED
M451 | KILLED | lib/ui/common/app_toast.dart | (testを決定の値で検査するよう直して単独で再実行) | exit 1
1 mutations: 1 KILLED, 0 SURVIVED, 0 SKIPPED
```

(NOTEは要約。full test 1013件PASS。触ったfileで`find`が一致しないのは`dev`時点からの既存13件だけ。)

## Current state / handoff

- Last checkpoint: 独立review attempt 3 PASS(2026-09-28)。エミュレータのmanual 2回目を待つ。
- Blocker category: 人間のmanual確認(Androidエミュレータ、2回目)。
- Waiting for: [`manual-verification.md`](manual-verification.md)の0〜6の結果(code `aa78f2a`)。
- Requested action: 人間がhostでworktree `.worktrees/008-T25-dismissible-toast`から`flutter pub get` → `flutter run`し、手順書を実行して結果を知らせる。
- Evidence revision: 起点は`dev`@`78352cf`。
- Next Agent action: review → manual依頼 → 結果を記録 → merge判断。