# T39 app内browserの選択・戻る導線を実装する

## 目的

T38で承認されたbrowserの選択・一括解除・戻る導線をAndroid app内browserに実装する。T37の範囲選択とT12の保存場所入口・戻る表示を保ち(**近道は2026-09-22の`T11`で取りやめたので維持対象ではない**)、利用者が「選択を解除する」と「リネーム画面へ戻る」を取り違えない画面にする。

## 依存と境界

- T38: 仕様・状態表・開発者承認。
- T12: 同じbrowser画面の入口(保存場所が1件ならroot・複数なら一覧と切り替え)、**近道の撤去**、戻る矢印、空folderの提示。
- T37: 長押しdragと全選択の基盤。
- Android app内browserだけが対象。desktopのOS pickerとrename判定、権限、ファイル変更は対象外。
- T38が決める前に見た目や選択の意味を確定・実装しない。

## machine検証範囲と引き受け先

- widget test: **`T38`の操作状態表の行をそのまま検査する** — 保存場所の一覧 / root(複数) / root(1件) / 下位folder / 空folderの各行で、header左(`←`の有無と行き先 / 選択中は`×`)・header中央(保存場所名 / 「N件選択中」)・**常に右端にあるケバブ**・パンくず・footer(「リネーム画面に戻る」「確定」の有効条件)が表のとおりであること。あわせて**一括解除**(004 REQ-020。`×`とケバブの両方から実行でき、**選択0件では解除が提示されない**)、**folder移動で選択が解除される**こと、file行のcheckbox配置と選択表示、folderが全選択の対象外であること、T37のdrag回帰。
- semantics widget test: 戻る、一括選択、一括解除の操作名とactionを区別する。
- **Androidエミュレータ**(2026-09-23 開発者の決定で物理端末から変更。下の「人間の決定」): 上記の見え方、マウスでの選択・解除、TalkBackの読み上げと操作(system imageにあれば)、狭幅と長い場所名。T39が引き受ける。**物理端末に固有の差は見ない。**
- **`T12`から引き受けた残余risk(2026-09-22)**: 保存場所が**1件**の端末で、browserが一覧を挟まずrootから始まること(004 REQ-015)。`T12`はエミュレータにSDカードがあり観測できなかった(widget testとmutation `M109`では固定済み)。**物理端末がSDカードを持たないなら、入口の見え方を1項目足す。** 持つなら観測できないことを記録する。
- desktopはOS picker経路のためmanual対象外。

## 受け入れ証拠

- T38が承認された仕様と状態表に対応するwidget testがPASSし、T12/T37関連testを弱めずPASSする。
- 必要なmutationがKILLED。format/analyze/full test/workspace check PASS。
- **Androidエミュレータ**のmanual確認PASS(2026-09-23の決定)。exact rangeの独立review PASS。review modelは開発者指定の`gpt-6-luna`。
- design土台との差分: **`docs/design/Bulk Renamer.html`にはapp内browserの画面が無い**(2026-09-23に確認。「保存場所」「ファイルを選ぶ」「リネーム画面に戻る」のいずれも出てこない)。適用する画面範囲は無く、離れた点も無い。提示は`T38`の操作状態表だけに従った。

## T38からの引き渡し(2026-09-23)

**仕様は承認済み** — 004 REQ-020へ一括解除が入った(`specs/004-file-source/spec.md`の「008:T38 由来の更新」節)。
`task.json.covers`へ`004:REQ-020`を記入した。**提示の決定は`T38`の操作状態表が正本で、ここへ複製しない。**

実装で落としてはいけない点だけを挙げる。

- **`×`は画面を閉じない。** 選択中だけ出て、**全解除だけ**を意味する。画面を閉じるのは**footer左下の「リネーム画面に戻る」**で、
  未確定の選択は捨て、rename画面の既存状態は保つ(004 REQ-001/008の`Cancelled`のまま)。
- **選択中は`←`が消える**(同じ位置を`×`と共有する)。**これは`T38`が受け入れた代償**で、不具合ではない。
  選択したまま上へ移動する手段は**`T40`(パンくずのtap移動)**が入ってから成立する。
- **ケバブは常に右端**。「すべて選択」は常設、「**選択をすべて解除**」は**1件でも選択があるときだけ**出す。
- **現在地の帯はパンくずの表示だけ**を作る。**tapによる移動は`T40`**であって、このtaskでは作らない。
- file行のcheckboxは`T29`へ揃える(右端・円・アクセント色)。選択済み行の面色も揃える。

> **2026-09-23 の注記**: 下の段落はT38からの引き渡し時点の指示である。**manualは開発者の決定でAndroidエミュレータへ変わった**(下の「人間の決定」)。現行の手順は`manual-verification.md`が正本。

**manual確認の手順は着手前に具体化する** — `T37`のエミュレータ完了の例外を自動適用せず、Android物理端末で
何を見るかを`manual-verification.md`へ書いてから人間へ依頼する。**`T12`から引き受けた残余risk(保存場所が1件の端末の入口)も
同じ手順書へ入れる**(端末がSDカードを持たない場合)。

## 実装の記録(2026-09-23)

実装は Claude Opus 5.5。起点は `dev@0fd66d1`、branch `asdd/008-ui-alignment/T39-implement-browser-selection-navigation`。

- `lib/ui/file_source/storage_browser_view.dart`: `AppBar`の`leading`を`←`(親folder / 保存場所の一覧)と`×`(全解除)で共有し、**暗黙の戻るを出さない**(`automaticallyImplyLeading: false`)。中央は保存場所名 /「N件選択中」/「ファイルを選ぶ」。右端のケバブに「すべて選択」(常設・押せないときは無効)と「選択をすべて解除」(選択があるときだけ)。現在地の帯はパンくず(表示だけ。末尾側へ寄せる)。footerは「リネーム画面に戻る」(暗い背景・シアンの枠と文字)と「確定」を**状態表の全行**に出す。file行は右端・円・`selectionMark`のcheckboxと`selectedSurface`の面(`T29`と同じtoken)で、名前とcheckboxを1つのsemantics nodeにした。folder行は右端に`›`を付け、checkboxを持たない。
- `lib/data/file_source/storage_browser.dart`: `breadcrumbOf`(純関数)。各区切りがfolderのpathを持つので、**`T40`はこれをtap先に使える**。rootの外は名指ししない。
- **システムバックはcodeを足さずに成立している** — route を pop して`null`を返す既定の振る舞いが「リネーム画面に戻る」と同じである(widget testで固定)。
- 既存keyの`browser-cancel`は「リネーム画面に戻る」へ、`browser-select-all`はケバブの項目へ移した。`browser-current-location`(現在地の文字列)と`browser-selected-count`(footerの件数)は、状態表に対応する置き場が無くなったので消した(header中央の`browser-title`とパンくずが引き継ぐ)。

### 自動検証

- `flutter test test/spec_004_file_source/storage_browser_view_test.dart`: 51件 PASS。**状態表の各行**(保存場所一覧 / root(複数)0・一部・全件 / root(1件)0・一部・全件 / 下位folder 0・一部・全件 / 空folder)を`_expectRow`で表の列どおりに検査する。ほかに`×`とケバブの解除が画面を閉じないこと、folder移動で選択が解除され`←`側へ戻ること、システムバック、ケバブと`←`/`×`の位置、semanticsの操作名(戻る・全解除・画面を閉じる)と実行、T29へ揃えたcheckbox、folder行、パンくずの純関数。T12/T37の既存testは**同じ保証を新しい導線で見る形に書き換えただけで、assertionを削っていない**(選択中は`←`が無いので、「移動で解除」は下位folderへ入る経路で見る)。
- `flutter test`: 977件 PASS。`flutter analyze`: No issues。`dart format --output=none --set-exit-if-changed .`: 0 changed。

### mutation

`tool/mutations.json`へ`M407`〜`M418`を足し、`find`が消えた`M117`・`M402`を追随させた。browser関連(`storage_browser_view.dart`・`storage_browser.dart`)の32件を`command: flutter test`(全件)のまま実行した生出力:

```text
M105 | KILLED | lib/data/file_source/storage_browser.dart | 保存場所のrootより上へ辿れるようにする | exit 1
M106 | KILLED | lib/data/file_source/storage_browser.dart | 書き込める場所でも注記を出す | exit 1
M107 | KILLED | lib/data/file_source/storage_browser.dart | 注記を一切出さない | exit 1
M108 | KILLED | lib/ui/file_source/storage_browser_view.dart | folderを移動しても選択を残す | exit 1
M109 | KILLED | lib/ui/file_source/storage_browser_view.dart | 保存場所が1つだけでも一覧を挟む | exit 1
M117 | KILLED | lib/ui/file_source/storage_browser_view.dart | rootでも「上へ」を出す(findを追随) | exit 1
M119 | KILLED | lib/ui/file_source/storage_browser_view.dart | 表示用の場所をrootへ紐づける | exit 1
M120 | KILLED | lib/ui/file_source/storage_browser_view.dart | 表示用の場所を一切知らせない | exit 1
M121 | KILLED | lib/data/file_source/storage_browser.dart | [対照] /Android直下で注記を出さない | exit 1
M151 | KILLED | lib/ui/file_source/storage_browser_view.dart | 保存場所の欠落を画面に出さない | exit 1
M156 | KILLED | lib/ui/file_source/storage_browser_view.dart | [対照] 注記から理由を落とす | exit 1
M159 | KILLED | lib/ui/file_source/storage_browser_view.dart | 画面側でportの例外を受けない | exit 1
M162 | KILLED | lib/ui/file_source/storage_browser_view.dart | 画面側が例外を黙って空にする | exit 1
M400 | KILLED | lib/ui/file_source/storage_browser_view.dart | 全選択へfolderを混ぜる | exit 1
M401 | KILLED | lib/ui/file_source/storage_browser_view.dart | 全選択へ近道を混ぜる | exit 1
M402 | KILLED | lib/ui/file_source/storage_browser_view.dart | 全選択を実行できなくする(findを追随) | exit 1
M403 | KILLED | lib/ui/file_source/storage_browser_view.dart | dragの復路で今回追加したfileを解除しない | exit 1
M404 | KILLED | lib/ui/file_source/storage_browser_view.dart | 既知の名前のfolderを二重に並べる | exit 1
M405 | KILLED | lib/data/file_source/storage_browser.dart | 列挙できていなくても「1つだけ」とみなす | exit 1
M406 | KILLED | lib/ui/file_source/storage_browser_view.dart | 空と開けなかったfolderを同じ見た目にする | exit 1
M407 | KILLED | lib/ui/file_source/storage_browser_view.dart | `×`で画面を閉じる | exit 1
M408 | KILLED | lib/ui/file_source/storage_browser_view.dart | 「選択をすべて解除」を選択0件でも出す | exit 1
M409 | KILLED | lib/ui/file_source/storage_browser_view.dart | 「選択をすべて解除」が何も解除しない | exit 1
M410 | KILLED | lib/ui/file_source/storage_browser_view.dart | 下位folderで選択中も`←`を残す | exit 1
M411 | KILLED | lib/ui/file_source/storage_browser_view.dart | 選択0件でも「確定」を押せる | exit 1
M412 | KILLED | lib/data/file_source/storage_browser.dart | パンくずがrootより上を名指しする | exit 1
M413 | KILLED | lib/ui/file_source/storage_browser_view.dart | 「すべて選択」を常に有効にする | exit 1
M414 | KILLED | lib/ui/file_source/storage_browser_view.dart | checkboxを円にしない | exit 1
M415 | KILLED | lib/ui/file_source/storage_browser_view.dart | 選択済みの行の面を染めない | exit 1
M416 | KILLED | lib/ui/file_source/storage_browser_view.dart | 暗黙の戻るを出す | exit 1
M417 | KILLED | lib/ui/file_source/storage_browser_view.dart | `×`を押しても選択が残る | exit 1
31 mutations: 31 KILLED, 0 SURVIVED, 0 SKIPPED
M418 | KILLED | lib/ui/file_source/storage_browser_view.dart | file行の名前とcheckboxを別々のsemantics nodeにする | exit 1
1 mutations: 1 KILLED, 0 SURVIVED, 0 SKIPPED
```

(NOTEは長いので要約した。STATUSとDETAILは生出力のまま。対象commitは`073b354`、M418は`073b354`のlibに対して実行。)

**manual 1回目の修正後(`30be394`)** — browser関連39件を`command: flutter test`(全件)で実行した生出力のうち、追随・追加した分と集計:

```text
M406 | KILLED | lib/ui/file_source/storage_browser_view.dart | 空のfolderと開けなかったfolderを同じ見た目にする(013:T07のU6。008:T12)。**008:T39で空の表示を一覧の外(中央)へ移したので`find`を追随させた** | exit 1
M420 | KILLED | lib/ui/file_source/storage_browser_view.dart | 008:T39 パンくずを右寄せに戻す(帯の幅いっぱいに詰めない) — 2026-09-23のエミュレータ確認で左寄せを求められた | exit 1
M421 | KILLED | lib/ui/file_source/storage_browser_view.dart | 008:T39 パンくずの`›`を薄い`textMuted`に戻す — 2026-09-23のエミュレータ確認で見づらいとされた | exit 1
M422 | SURVIVED | lib/ui/file_source/storage_browser_view.dart | 008:T39 パンくずの帯にheaderと同じ面の色を敷く — headerの一部に見える(2026-09-23のエミュレータ確認) | exit 0: the tests passed with the mutation applied
M423 | KILLED | lib/ui/file_source/storage_browser_view.dart | 008:T39 footerで「確定」との間に`Spacer`を戻す — 「リネーム画面へ」が半分の幅になり文言が切れる(2026-09-23のエミュレータ確認) | exit 1
M424 | KILLED | lib/ui/file_source/storage_browser_view.dart | 008:T39 空のfolderの文言を上端に寄せる — 2026-09-23のエミュレータ確認で画面中央を求められた | exit 1
ERROR: M422 SURVIVED
M425 | KILLED | lib/ui/file_source/storage_browser_view.dart | 008:T39 深い階層でパンくずを先頭側に寄せる — 現在のfolder(末尾)が見えなくなる | exit 1
39 mutations: 38 KILLED, 1 SURVIVED, 0 SKIPPED
M422 | KILLED | lib/ui/file_source/storage_browser_view.dart | (test修正後に単独で再実行) | exit 1
1 mutations: 1 KILLED, 0 SURVIVED, 0 SKIPPED
```

**2回目の修正後(`2cf0e09`)** — AGENTS.mdの方針(2026-09-23 開発者承認: 所有taskも関連testへ絞り、SURVIVEDだけ全件で確かめ直す)に従い、`command`を`flutter test test/spec_004_file_source/storage_browser_view_test.dart`へ絞り、パンくずに関わる4件だけを回した生出力(54秒):

```text
M420 | KILLED | lib/ui/file_source/storage_browser_view.dart | パンくずを右寄せに戻す | exit 1
M422 | KILLED | lib/ui/file_source/storage_browser_view.dart | パンくずの帯にheaderと同じ面の色を敷く | exit 1
M425 | KILLED | lib/ui/file_source/storage_browser_view.dart | 深い階層でパンくずを先頭側に寄せる | exit 1
M426 | KILLED | lib/ui/file_source/storage_browser_view.dart | パンくずのマウスでの横送りを外す | exit 1
4 mutations: 4 KILLED, 0 SURVIVED, 0 SKIPPED
```

(NOTEは要約。他の35件はパンくずの帯のscroll設定に触れないので、`30be394`での結果から変わらない。)

`M422`のSURVIVEDは、testが`Container.decoration`だけを見ていたため(`Container(color:)`は色を`color`に持つ)。`color`も見るよう直した。他の33件(M105〜M419)は1回目と同じくKILLED。

**T39の範囲外で観測したこと**: `tool/mutations.json`の`M116`・`M178`・`M257`・`M264`・`M298`・`M305`・`M306`・`M314`・`M317`・`M324`・`M342`・`M355`・`M357`・`M358`は、**`dev@0fd66d1`の時点で既に`find`が対象fileに見つからない**(`file_list_view.dart`と`android_storage_browser.dart`で、T39は触っていない)。全件実行では`SKIPPED`になり、守っていたつもりの保証が検査されていない。所有taskの追随が要る。

## 人間の決定

| 日付 | 論点 | 決定 | 決定者 |
|---|---|---|---|
| 2026-09-23 | footerの文言 | **「← リネーム画面へ」**(`←`付きで短くする)。`T38`の「リネーム画面に戻る」は通常の文字サイズでも「リネーム画面...」と切れていた。画面を閉じる唯一の導線という意味は変えない | 開発者 |
| 2026-09-23 | パンくずの見せ方 | **左寄せ**。headerの一部に見せず**一覧の上**に置く。`›`を濃くする。**一覧と一緒には流さない**(REQ-015「現在地を常に示す」を守るためAgentが選んだ) | 開発者(流さない点はAgent) |
| 2026-09-23 | 空のfolderの文言 | **一覧の領域の中央**に出す | 開発者 |
| 2026-09-23 | TalkBack(manual 10) | **skip**。エミュレータではダブルタップが効かず使えなかった。操作名と実行はwidget test(semantics)とmutation `M418`等で固定済み | 開発者 |
| 2026-09-23 | manual確認の環境 | **Androidエミュレータで行う**(「これまでエミュレータを用いてきており、今後もそうするつもり」)。**物理端末の確認は受け入れ証拠から外す。** `T37`の一回限りの例外とは違い、今後の方針として受領した | 開発者 |

### この決定で残る残余risk(task所有Agentが受容する)

| 残余risk | 分類 | 扱い |
|---|---|---|
| **保存場所が1件の端末で、実機上も一覧を挟まずrootから始まるか**(`T12`から引き受けた項目) | **安全網の穴**。widget test `保存場所が1つだけのときは一覧を挟まず、rootの中身が出る`とmutation `M109`(KILLED)で固定済み。エミュレータにSDカードが出るため観測できない。AGENTS.mdの条件3(CIで閉じられる)は既に満たされ、残るのは実機の見え方だけ | **受容する。引き受け先のtaskは無い** — 物理端末を使うtaskが今後できたときに、そこで1項目足す。エミュレータにSDカードが無かった場合は`manual-verification.md`の1で観測する |
| 物理端末に固有の差(指での長押し・dragの感触、TalkBackのジェスチャー、端末ごとの保存場所の構成) | **安全網の穴**(実装の誤りではない。CIでは閉じられない) | 受容する。引き受け先のtaskは無い |
| **TalkBackでの実際の読み上げと操作**(エミュレータで使えずskip) | **安全網の穴**。操作名・tap action・行の1 node化はwidget testで固定済み。実機の読み上げはCIで閉じられない | 受容する。引き受け先のtaskは無い |

## manual確認の結果

### 1回目(2026-09-23、Androidエミュレータ、`lib/`は`073b354`)

開発者の報告(会話):「各確認事項は概ね問題なかった」。そのうえで次を受領した。

| 項目 | 結果 | 対応 |
|---|---|---|
| パンくず | **右寄せになっている**。headerに含めず一覧の上に出したい。`›`が薄く見づらい | `30be394`で左寄せ・一覧の上の帯(面の色を外した)・`›`を`textSecondary`へ。`M420`〜`M422`・`M425` |
| 空のfolder | 文言を画面中央に出したい | `30be394`で一覧の領域の中央へ。`M424`(`M406`の`find`を追随) |
| footer | 「リネーム画面に戻る」が通常の文字サイズでも「リネーム画面...」と切れる。`←`を付けて「← リネーム画面へ」にしたい | `30be394`。**原因は`Spacer`と幅を分け合う配置**(残りの半分しか使えなかった)で、配置も直した。`M423` |
| 10 TalkBack | 有効にできたが、エミュレータではダブルタップが効かず**skip** | 人間の決定として記録。残余riskへ |
| 9 長い名前のフォルダ | **作られなかった**(`adb push`の出力は5 files、`ls`に長い名前のフォルダが無い) | **手順書の欠陥**: `adb push`は空のフォルダを送らず、`deeper_folder`が空だった。`d.txt`を入れ、残っているfixtureへ足すコマンドも書いた。**9は未実施** |
| 1 入口 | 報告に個別の記載なし(「概ね問題なかった」) | 2回目で確かめる |

### 3回目(2026-09-23、Androidエミュレータ、`lib/`は`2cf0e09`) — **PASS**

開発者の報告(会話):「確認事項について、全て確認できました。」**0〜9のすべてがPASS**(10のTalkBackは2026-09-23の決定で行わない)。
2回目の指摘(9: 深い階層のパンくずをマウスで送れない)は解消した。1の入口も含まれる(エミュレータはSDカードを持つので、保存場所の一覧から始まる側)。
**このmanual証拠は`lib/`が`2cf0e09`のbuildに対応する。** 以後`lib/`・dependency・build設定を変えたら再利用しない。

### 2回目(2026-09-23、Androidエミュレータ、`lib/`は`30be394`)

開発者の報告:「ほぼすべて問題ないことが確認できた」。1回目の指摘(パンくずの左寄せ・位置・`›`、空の表示の中央、「← リネーム画面へ」)は解消した。

| 項目 | 結果 | 対応 |
|---|---|---|
| 9 深い階層のパンくず | **末尾(`deeper_folder`)は見える。左右にスワイプできず、先頭の「内部ストレージ」が見られない** | **実装の不具合(成果物の欠陥)**。Flutterの既定の`ScrollBehavior`は**マウスのドラッグでスクロールしない**。widget testで、タッチでは送れてマウスでは`pixels=0`のままになることを再現した。エミュレータのマウス操作はマウスとして届くと判断した(1回目・2回目で一覧の縦送りは報告されているが、ホイールで行える)。`2cf0e09`で帯の`ScrollConfiguration`をマウスでも送れるようにし、touch/mouseの両方のtestと`M426`を足した |
| 1 入口 | 個別の記載なし | 3回目で確かめる |

**2回目の結果も`30be394`のbuildに対するもので、`2cf0e09`では再利用しない。** `30be394..2cf0e09`の`lib/`差分はパンくずの帯のscroll設定だけだが、3回目も0〜9を通して見る(10は行わない)。

**1回目の結果は`073b354`のbuildに対するもので、`30be394`では再利用しない**(AGENTS.md)。`073b354..30be394`の`lib/`差分はパンくず・空の表示・footerの描画だけで、選択・解除・移動の処理は変えていないが、**2回目は0〜9を通して見る**(10は行わない)。

## 独立review

**reviewerのmodelは`gpt-6-luna`**(2026-09-23に開発者がこのsessionで指定。実装はClaude Opus 5.5)。
**これまでの記録(`T38`・このtaskの登録時)は`gpt-5.6-luna`だった** — 開発者の新しい指定に従い、食い違いとしてここへ残す。

- attempt 1: `0fd66d1..f1526cd` — **FAIL**。
  - **P1(成果物の欠陥)**: `manual-verification.md`のfixture準備が端末の`Download/t39`を**無条件に`rm -rf`していた**。
    利用者の既存フォルダがあれば失われる。→ **確認専用の`Download/asdd-008-t39`へ変え、既にあれば何も置かずに止まる**
    手順にした。端末側で消すのはこのfixtureの`.keep`だけ。後片付けは人間がファイルアプリで行う。
  - 状態表の全行との一致、T40を先取りしていないこと、T12/T37のtestを弱めていないこと、M117/M402の追随とM407〜M418の妥当性、
    T12の残余riskがmanualに入っていることは**確認された**。reviewerの範囲付きmutation 15件はすべてKILLED。
  - reviewerの対照`R-T39-1`(「すべて選択」を押せる状態でも無効にする)を`M419`として`tool/mutations.json`へ取り込んだ。
- attempt 2: `0fd66d1..bebbe74` — **PASS**。P1は閉じた(専用フォルダが既にあれば止まり、端末のファイルを消さない)。
  成果物の欠陥・安全網の穴ともに無し。reviewerの範囲付きmutation 15件(M117・M402・M407〜M419)はすべてKILLED。
  **これはimplementation reviewで、manualの証拠はまだ無い** — manual結果の受領後にfinal-evidenceを確かめる。

- attempt 3: `0fd66d1..86225cd`(implementation + final-evidence) — **FAIL**。
  - **P1(成果物の欠陥)**: `3d5a3ae`が`git add -A`で、`linux/` `macos/` `windows/`の生成plugin registrantから`file_selector`
    (macOSは`shared_preferences`も)の登録を消す差分を含めていた。T39の範囲外のdesktop経路を壊しうる。
    → `e2d4717`で`dev`の内容へ戻した(`git diff 0fd66d1 -- linux macos windows`が空)。**Androidのbuildには入らないfileで、
    3回目のmanual時のhostのworking treeは戻した後の内容だった**ので、manual証拠(`lib/`=`2cf0e09`)は再利用できる。
    経緯は[development finding](../../../../development-findings/2026-09-23-worktree-dart-tool-and-registrants-shared-with-host.md)。
  - **P2(成果物の欠陥)**: 本文の「T38からの引き渡し」に物理端末で行う指示が残っていた。→ 現行はエミュレータである旨の注記を足した。
  - **P2(安全網の穴)**: `M421`の`find`が`2cf0e09`の字下げ変更で一致せず`SKIPPED`になっていた。→ 追随させ、関連testへ絞って
    `M421 | KILLED`(1 mutations: 1 KILLED)。browser関連の他のmutationの`find`は全件一致することを確かめた。
  - 実装変更と開発者の決定・状態表・REQ-015の整合、T40を先取りしていないこと、追加testが本物であること、manual証拠と
    `2cf0e09`の対応、エミュレータ・TalkBack・残余riskの記録、full test 983件PASSは**確認された**。
  - **FAILは累計2回**(attempt 1・3)。次にFAILすればAGENTS.mdに従い`blocked`にして人間へ返す。

## Current state / handoff

- Last checkpoint: **独立review attempt 3(FAIL)の指摘を直した**(2026-09-23、`e2d4717`)。manual 3回目はPASS(`lib/`=`2cf0e09`、以後`lib/`の差分なし)。
- Blocker category: なし。
- Evidence revision: **manualの対象は`lib/`が`2cf0e09`と同一のbuild**(1回目は`073b354`、2回目は`30be394`)。base は`dev@0fd66d1`。
- Waiting for: 独立review attempt 4(`gpt-6-luna`)。
- Requested action: なし。
- Next Agent action: 結果を`task.md`へ記録する。PASSなら **`0fd66d1..HEAD`の独立review(`gpt-6-luna`。`bebbe74`以後の実装変更を含むので、implementationとfinal-evidenceを合わせて見る)**→ PRをready → CI → merge判断。期待と違う点があれば、仕様(`T38`の状態表)との差か実装の不具合かを分けて返す。**パンくずのtap移動は作らない**(`T40`)。
