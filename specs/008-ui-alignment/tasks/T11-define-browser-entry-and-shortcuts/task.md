# T11 app内file browserの入口と近道の提示を定義する

## 目的

`013:T07`のAndroidエミュレータ確認で開発者が挙げた**U1(入口)**と**U2(近道の見分け)**を、004 specの
要求として定義し、**人間の再承認を得る**。実装は`T12`が行う。

> **2026-09-22に決着した。** U1は「1つだけなら一覧を挟まない」をmustにし、U2は**近道そのものを取りやめた**。
> **以下の「論点」節は着手前の整理であり、現在の要求ではない** — 正本は`specs/004-file-source/spec.md`の
> REQ-015と「008:T11 由来の更新」節、決定と理由はこのfileの「2026-09-22 の決定と、要求の増減」である。

**これは仕様変更である。** 独立reviewは「近道を★で示すこと」を004 REQ-015違反では
ないと判定した — REQ-015が課すのは「実在する既知の場所への近道を**示し**、そこから
階層を辿れる」ことまでで、**近道の並べ方・選択の示し方は004 specが「自由とする点」へ
明示している**([`004 spec`](../../../004-file-source/spec.md)の該当節)。したがって
「近道だと**認識できる**こと」を要求にしたいなら、**REQ-015そのものを変える**必要がある。

## 入力と依存

- **観測の出所**: [`013:T07`のtask.md](../../../013-safe-android-rename/tasks/T07-implement-android-file-browser/task.md)
  「受領したUIの改善点」の U1・U2(2026-08-25、`sdk_gphone16k_x86_64`でのAndroidエミュレータ確認)。
- 004 spec の REQ-015・REQ-017 と代表例 22 / 26d / 26e。**REQ-017(絞り込まない)は
  変えない** — 近道と同名のfolderが下にも並ぶのはこの要求の必然である。
- 現行実装: `lib/ui/file_source/storage_browser_view.dart`(近道は`browser-shortcut-*`の
  `ListTile`+`Icons.star_outline`、実体は`browser-folder-*` / `browser-file-*`)、
  `lib/data/file_source/storage_browser.dart`(`knownShortcutNames`、実在確認)。
- 008 plan の方針「**仕様を変えるものは、仕様更新taskと実装taskを分ける。承認前に実装を
  始めない**」。

## 論点(2026-09-22に決着。着手前の整理として残す)

### 前提が変わった(2026-08-26、`013:T12`)

**保存場所が2つ並ぶ構成をAndroidエミュレータで確認した。** `013:T07` の実装は `/storage` を
列挙しており、**app からは `EACCES` で1件も取れなかった** — つまり U1 が観測されたときの
画面は「常に内部ストレージ1件」だった。`013:T12` が `StorageManager.getStorageVolumes()`
へ差し替え、**Androidエミュレータで `内部共有ストレージ` と `SDCARD` の2件が並ぶことを確認した**
(2026-08-26)。

**したがって U1 の判断材料が変わっている。**

- 「保存場所が1つしかない」のは**もはや常態ではない**。SD カードを挿している端末では2件になる。
- **抜き差しで件数が変わる。** 1件のとき一覧を挟まない設計にするなら、**挿した後にどう見えるか**
  (開き直せば2件になる)を決める必要がある。
- 保存場所の名前は**端末が決める**(`getDescription()`)。`内部共有ストレージ` `SDCARD` のように、
  こちらが固定文字列で出していたものとは違う。

### U1: 保存場所が1つしかないとき、一覧を挟まずに中へ入る

現在の REQ-015 は「browser は**保存場所の一覧**から始まり」を **must** で要求している。
SDカード・USBが並ぶ端末があるためだが、**内部共有ストレージしか無い端末では1件の一覧を
1回押させるだけ**になる。

**決めること。**

- 保存場所が1つのときに一覧を出さずに入る、を要求にするか、実装の自由にするか。
- **保存場所を選び直す導線を残すか。** 現在は root で `browser-locations`(SDカードの絵)
  が出る(代表例26d「rootでは上位へ戻る操作は無いか無効」に合わせた形)。1つしか無い
  端末でこれを出す意味はあるか。
- **後からSDカードを挿した場合**にどう見えるか(browserを開き直せば2件になる)。

### U2: 近道と実体のfolderの区別が読み取れる

開発者の観測は「**★を通常のファイルだと思った**」である。近道(★)・folder(📁)・
file(checkbox)が同じ列に並び、しかも**同名のfolderが下にも出る**。

**決めること。**

- **そもそも要求を足すか。** 現在のREQ-015でも「近道を示す」は満たしており、
  **`T12`の実装裁量だけで見分けを直せる**(approved specへの追加が1つ減る)。
  「読み取れること」を将来のreviewやtestで守りたいときだけ要求にする価値がある。
  **この案を最初に人間へ出すこと**(AGENTS.md「そもそもここまでやる必要があるか」)。
- 足すなら、要求を「近道であることが**読み取れる**」までにするか、示し方まで決めるか。
  **008の既定は前者**(判定や体裁を規範にしない)。
- 候補: 見出しで束ねる / アイコンを変える / 現在地の下に横並びのchipとして出す /
  近道をやめて保存場所の一覧側へ移す。**どれを採るかは`T12`の裁量にできる**が、
  「読み取れる」を何で確かめるかは仕様側で決める必要がある(widget testで観測できる形)。

## 変更範囲

- `specs/004-file-source/spec.md` の REQ-015 と代表例。**REQ-016 / REQ-017 / REQ-018 は
  変えない。**
- 変更後、`T12`の`task.json.covers`へ対象REQ IDを書く(008 plan の方針)。

**`005` contract と `013` のREQは触らない。** 提示だけの変更で、改名の判定・権限・
データ保護は動かさない。

## 受け入れ証拠

- 004 spec の REQ-015 の変更案と、追加・変更した代表例。**変更前後で何が要求として
  増減したかを`task.md`へ書く。**
- **人間の再承認を得ている**(004 spec は approved のため)。
- `python <asdd-plugin>/scripts/workspace.py check specs` がPASS。
- `T12`の`covers`が埋まっている。
- 実装は行わない。`lib/`に差分を出さない。

## 他taskへの申し送り


### 2026-08-29 に受け取った入力の移管

folder内の全選択と長押し+drag範囲選択は、2026-09-21に`T36`(仕様) / `T37`(実装)へ昇格した。入力手段と選択意味がU1/U2とは別で、T11自身が単独task相当と記録していたため、T11/T12へ混ぜない。

**空folderの文言は`T12`へ回した**(提示だけで004を変えないため)。**pickerでのpreviewは
`T13`が既に持っている。**

- **`013:T07`が置いた mutation が REQ-015 の現在の形を固定している** — `M105`(rootより
  上へ辿れる)、`M109`(近道を保存場所の始まり以外でも出す)、`M117`(rootでも「上へ」を
  出す)。**要求が変わるなら`tool/mutations.json`の該当行も新しい要求へ合わせる**
  (消さない)。実際に手を入れるのは`T12`である。

## 作業記録

- 2026-08-25 / `013:T07`のAndroidエミュレータ確認(U1・U2)を受けて定義。開発者が「U1〜U5をすべてtask化
  する」と決定した。
- 2026-09-22 / 着手。`013:T07`のU1・U2の原文、004 spec REQ-015〜020と自由節、現行実装
  (`storage_browser_view.dart` / `storage_browser.dart` / `android_storage_browser.dart`)を読み、
  状態表と選択肢を開発者へ出した。**同日、004 specの変更が再承認された。**

## 2026-09-22 の決定と、要求の増減

### 調べて分かったこと(決定の根拠)

- **近道は通常のfolderと実装上の違いが無い。** 実体は `保存場所のroot/<既知の名前>` で
  (`android_storage_browser.dart`の`shortcuts`)、**保存場所のrootの画面だけ**に出る
  (`storage_browser_view.dart`の`_enter`)。行き先は同じ画面に並ぶ同名folderと**同一path**である。
  **タップ数を1つも減らしていない** — 減るのはrootのfolderが多いときのscrollだけで、
  一覧は「folderが先、名前順」なのでDCIM・Documents・Downloadは元々上に来る。
- **近道が入った理由は利用者の利便ではない。** `013:T03`の決定表が根拠で、
  [ADR-002](../../../013-safe-android-rename/decisions/ADR-002-android-rename-storage-boundary.md)が
  `MANAGE_EXTERNAL_STORAGE`のPlay審査で permitted uses の **File management** へ寄せる手段として
  「単なるfile選択画面ではなく**folderとfileを管理する導線**として作る」ことを挙げていた。
  **ADR-002自身が「それでinvalid usesを外れる保証は無い」と書いており、審査は未提出である。**
- **`_backToLocations`は再列挙しない。** 保存場所の列挙は`initState`の一度だけなので、
  後から挿したSDカードは**browserを開き直すまで並ばない**。この点は要求にせず自由とした。

### 決定

| 論点 | 決定 | 却下した案と理由 |
|---|---|---|
| U1 入口 | **保存場所が1つだけなら一覧を挟まず、その保存場所のrootから始まる**をmustにする | 「実装の自由にする」は、1手減ったことをtestで守れず将来の変更で黙って戻る。「変えない」は選択肢が1つの画面を押させ続ける |
| 選び直しの導線 | **複数あるときだけ**「閉じずに切り替えられる」をmustにする。1件のときに出すかは自由 | 「常に要求」は、1件の端末に「押しても1件」の空振りの導線が残り、U1で消したものが別の形で戻る |
| U2 近道 | **近道そのものをやめる**(REQ-015からmustを外す) | 「見分けを要求にする」「示し方まで決める」は、同じfolderが2回出ること自体を残す。開発者の違和感の本体はそこだった |

### 要求の増減

| | 変更前 | 変更後 |
|---|---|---|
| 入口 | 常に保存場所の一覧から始まる(must) | 複数なら一覧、1つならその保存場所のroot(must) |
| 保存場所の切り替え | 要求なし(実装がrootに出していただけ) | **複数あるときは閉じずに切り替えられる**(must)。1つのときは自由 |
| 近道 | 実在する既知の場所への近道を示す(must) | **要求しない** |
| 近道の示し方 | 自由 | — (対象が無くなった) |
| 全選択の対象(REQ-020) | fileのみ。folder・近道は対象外 | fileのみ。folderは対象外(**意味は不変**) |

**変更したfile**(`git diff fbb19aa..HEAD` と一致させること):

| file | 何を変えたか |
|---|---|
| `specs/004-file-source/spec.md` | REQ-015 / REQ-020 / 代表例22→22・22b・22c・22d / 代表例29 / 自由とする点 / `013:T03`由来の記録・Play policy節・`008:T36`由来の記録への追記 / Status行 / 「008:T11 由来の更新」節 |
| `specs/008-ui-alignment/plan.md` | 対象・全体の受け入れ条件・人間の決定を3行追加 |
| `T11`の`task.json` / `task.md` | status、決定と根拠、増減、残余risk、論点が決着済みである注記 |
| `T12`の`task.json` / `task.md` | `covers`(`004:REQ-015` / `004:REQ-020`)、承認済み要求の引き渡し、`M109`の置き換え指示 |
| `T12`の`manual-verification.md` | U1を新しい入口へ、U2を**近道が出ないことの確認**へ書き換えた(review attempt 1 のP1) |
| `T38`の`task.md` | T11待ちの解除と、近道撤去・新しい入口を前提にした記述(review attempt 1 のP1) |
| `013:T03`の`task.md` | 決定表の「何を見せるか」が2026-08-22時点の決着であることと、現行の正本がREQ-015であることの注記(review attempt 1 のP1) |
| `T39`の`task.md` / `T38`の`task.md`(2回目) / `T26`の`task.md` / `specs/product-map.md` | 近道の維持・test対象・担当範囲の記述を現行REQ-015へ(review attempt 2 のP1) |
| `013:T07` / `013:T12` / `008:T07` / `008:T37` の`manual-verification.md` | 冒頭に同一文面の注記。**記録した結果は書き換えていない**(review attempt 2 のP1) |
| `T12`の`manual-verification.md`(2回目) | 参照先(`013:T07`手順0)の目印のうち現行でないものを明示し、このtaskのbuildの見分けをU1/U2で行うと書いた(review attempt 2 のP1) |
| `development-findings/2026-09-22-shortcut-removal-stale-copies-across-handoff-docs.md` | 同じ型が2回続いたことと、解き方を変えた内容の記録 |

**`lib/`と`test/`に差分は無い。**

### 残したrisk

- **Play審査は未提出で、File managementから外れない保証は無い**(ADR-002の未解決のまま)。近道を外したことが
  その判断へ効く可能性はゼロではない。寄せる働きの主体は**保存場所の列挙・階層の踏破・現在地の提示**である。
  却下された場合の退避はADR-002の「退避の手順」に従う。**このriskは`013`が持ち、このtaskで新設しない。**
- **`M109`の対象が消える。** 近道の撤去を守るmutationへの置き換えは`T12`が行う(消さない)。

## 2026-09-22 仕様変更(T11本体)の独立review

**reviewerのmodelは`gpt-5.6-luna`。** AGENTS.mdの既定は「実装に使ったものより一段軽いもの」で、実装(仕様更新)は
Claude Opus 5で行った。**開発者がlunaを指定したためそれに従い、既定との差をここへ記録する。**

- Review attempt 1: `fbb19aa..82cbf4b`、phase=implementation — **FAIL**。REQ-015の新文面・代表例・自由節・VER-005・
  REQ-016〜020との整合、Play審査riskの記述はいずれも妥当と確認された。落ちたのは**引き渡し資料の写しが古くなる型**である。
  - **P1(成果物の欠陥)**: `T12`の`manual-verification.md`が「近道と実体のfolderを見分けられること」を確認対象に残し、
    `T38`が「近道の見分け」と「保存場所の一覧から始める」を前提に書いており、`013:T03`の決定表が現行仕様の索引として
    近道を挙げたままだった。**T12が誤った前提で実装・manualを行う実害がある。** → 3fileとも現行REQ-015へ更新した。
  - **P2(成果物の欠陥)**: `task.md`の「変更したfile」がexact diffと一致していなかった(`T38`の`task.md`が抜けていた)。
    → 表にして実diffと一致させた。

### attempt 2 (`fbb19aa..43b3b65`) — **FAIL**。同じ型が2回続いたので解き方を変えた

attempt 1 のP1/P2は閉じたと確認された(変更file表もrangeの実diff 9fileを網羅していると確認された)。
残ったのは**同じ「写しが古くなる型」の別箇所**である。

- **P1(成果物の欠陥)**: `T12`のmanualが**参照している**`013:T07`のmanualに、手順0の見分けの目印
  「最初に出るのは保存場所の一覧」と手順1の「近道が上に出る」が残っていた。**参照元を直しても参照先が古いと
  現行でない期待が復活する。**
- **P1(成果物の欠陥)**: `T39`の`task.md`(近道の維持・test対象)、`T38`の別の行(`folder/shortcut行`)に前提が残っていた。

**AGENTS.mdの「同じ根本原因が修正後も2回続いたら、同じ種類の修正を繰り返さず解き方を変える」に該当する。**
指摘された箇所を追う方法をやめ、**`specs/`配下の全occurrence(`近道` / `shortcut` / `保存場所の一覧`)を
機械的に洗い出して分類し、種類ごとに一度に処理した。** 経緯は
[`development-findings/2026-09-22-shortcut-removal-stale-copies-across-handoff-docs.md`](../../../../development-findings/2026-09-22-shortcut-removal-stale-copies-across-handoff-docs.md)。

| 分類 | 扱い | 対象 |
|---|---|---|
| **現行の指示**(activeなtask・これから使うmanual) | 現行REQ-015へ更新する | `T12`の`task.md`/`manual-verification.md`、`T38`、`T39`、`T26`、`product-map.md`、`008/plan.md`、`013:T03`の決定表 |
| **当時の証拠**(doneしたtaskのmanual) | **結果は書き換えない。** 冒頭へ同一文面の注記を入れ、「入口と近道の期待だけは現行でない。正本は004 REQ-015」と示す | `013:T07`、`013:T12`、`008:T07`、`008:T37`の各`manual-verification.md` |
| **当時の証拠**(doneしたtaskの`task.md`の記録) | **触らない。** 観測・review・決定の記録であって、これから従う指示ではない | `013:T07`、`013:T12`、`008:T36`、`008:T37`の`task.md` |
| **無関係な語** | 触らない | `002 spec`と`008:T27`の「全部空にする近道」(機能としての近道ではない) |

**doneしたtaskの`task.md`を書き換えないのは、それが対象commitに対する証拠のidentityを持つためである**
(AGENTS.md「manual証拠は対象commit以後にcode、dependency、build設定が変わったら再利用しない」)。
**再利用されうる入口はmanualの側なので、注記はそちらへ置いた。**

## 2026-09-22 handoff記録の検査

- これはT11仕様案のreviewではなく、次担当向けhandoff文書のreview。実装・仕様決定は未着手。
- Review attempt 1: `180ab77...27c98d1` — `gpt-5.6-luna` FAIL、P1記録欠陥: T37のエミュレータ報告を「実機」と呼び、物理端末証拠と誤認されうる。
- Review attempt 2: `180ab77...494a701` — `gpt-5.6-luna` FAIL、P1記録欠陥: T11内の「emulatorで...実機で確認」が残存。同種の置換を重ねず、`013:T07`とT37の証拠出所を関連task・plan全体で走査して修正した。
- Review attempt 3: `180ab77...2cfabf9` — `gpt-5.6-luna` PASS。変更したplanと5 taskの証拠呼称・依存・T37の例外・T39の物理端末要件を照合し、未解決P0/P1なし。T11仕様案自体の承認・reviewではない。

## Current state / handoff

- Last checkpoint: **004 specの変更を開発者が再承認した**(2026-09-22)。plan・`T12`への引き渡しまで記録済み。
- Blocker category: なし
- Waiting for: exact rangeの独立review。
- Requested action: なし
- Evidence revision: 起点は`dev@fbb19aa`。branchは`asdd/008-ui-alignment/T11-define-browser-entry-and-shortcuts`。
  `python <asdd-plugin>/scripts/workspace.py check specs` = PASS(8 plans, 92 tasks)。**実装もtestも変えていないので`flutter test`の対象は無い。**
- Next Agent action: 独立reviewがPASSしたら`done`にし、`T12`(実装)と`T38`(選択・戻る導線の仕様)を着手可能として扱う。
  **`T38`は近道が無くなった前提で状態表を作る。**
