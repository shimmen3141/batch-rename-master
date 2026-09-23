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
- Android物理端末: 上記の見え方、手での選択・解除、TalkBackの読み上げと操作、狭幅と長い場所名。T39が引き受ける。
- **`T12`から引き受けた残余risk(2026-09-22)**: 保存場所が**1件**の端末で、browserが一覧を挟まずrootから始まること(004 REQ-015)。`T12`はエミュレータにSDカードがあり観測できなかった(widget testとmutation `M109`では固定済み)。**物理端末がSDカードを持たないなら、入口の見え方を1項目足す。** 持つなら観測できないことを記録する。
- desktopはOS picker経路のためmanual対象外。

## 受け入れ証拠

- T38が承認された仕様と状態表に対応するwidget testがPASSし、T12/T37関連testを弱めずPASSする。
- 必要なmutationがKILLED。format/analyze/full test/workspace check PASS。
- Android物理端末のmanual確認PASS。exact rangeの独立review PASS。review modelは開発者指定のluna。
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

**T39の範囲外で観測したこと**: `tool/mutations.json`の`M116`・`M178`・`M257`・`M264`・`M298`・`M305`・`M306`・`M314`・`M317`・`M324`・`M342`・`M355`・`M357`・`M358`は、**`dev@0fd66d1`の時点で既に`find`が対象fileに見つからない**(`file_list_view.dart`と`android_storage_browser.dart`で、T39は触っていない)。全件実行では`SKIPPED`になり、守っていたつもりの保証が検査されていない。所有taskの追随が要る。

## 独立review

**reviewerのmodelは`gpt-6-luna`**(2026-09-23に開発者がこのsessionで指定。実装はClaude Opus 5.5)。
**これまでの記録(`T38`・このtaskの登録時)は`gpt-5.6-luna`だった** — 開発者の新しい指定に従い、食い違いとしてここへ残す。

## Current state / handoff

- Last checkpoint: 実装とmachine検証が済んだ(2026-09-23)。状態表の全行のwidget test、full regression、format/analyze、browser関連mutation 32件KILLED。`manual-verification.md`を物理端末向けに具体化した(`T12`の残余riskの入口を含む)。
- Blocker category: なし。
- Evidence revision: `lib/`は`073b354`。base は`dev@0fd66d1`。
- Waiting for: 独立review(`gpt-6-luna`)。その後、Android物理端末のmanual確認。
- Requested action: なし(review後に manual を依頼する)。
- Next Agent action: 独立reviewを`gpt-6-luna`で行う → Draft PR → manual依頼。**パンくずのtap移動は作らない**(`T40`)。
