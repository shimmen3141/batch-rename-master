# T02 並び順controlを実装する

## 目的

`T01`で承認された仕様どおり、並び順を現在の状態が見える一つのcontrolにし、連番の有無に関わらず手動並び替えできるようにする。

## 入力と依存

- `T01`で承認された002 spec。
- **REQ-011の警告の配置**(`T01`が決めた。仕様にはしない — 008 plan 2026-08-29「案B」): 並び順の表示の**右の空き**に短く出し、入りきらないとき(狭幅・文字の拡大)は次の行へ回す。今の`_CreatedAtFallbackBanner`(一覧の上の帯)から移す。文言の全文(何件を更新日時で代替したか)は失わない。
- `docs/design/Bulk Renamer.html`の並び順control。**適用する画面範囲は一覧上部の並び順controlに限る**(下部の実行バーは005:T09の成果なので動かさない)。
- 現行実装: `lib/ui/file_list/file_list_view.dart`のsort chip、`lib/ui/file_list/file_list_controller.dart`の`manualOrderMatters`。

## 変更範囲

- 横並びchipを、現在の状態を示すcontrolへ置き換える。
- `manualOrderMatters`によるdrag handleとcustomの出し分けを廃止する。
- 昇順・降順(T01の決定に従う)。
- 002の仕様由来testの更新と追加。

### 引き受けた残余risk(`008:T07`から)

- **N-8a**: 文字サイズを最大にすると、現行の横並びsort chipが画面外へはみ出し、
  **一部を選べなかった**と開発者が報告した(2026-08-29のAndroid emulator確認)。
  **到達不能ではない** — barは`SingleChildScrollView(Axis.horizontal)`なので水平scrollすれば
  届く(`file_list_view.dart`の`_SortBar`)。**欠陥は「はみ出していることに気づけない」ほう**
  である。このtaskがchipをドロップダウンへ置き換える(plan.md 2026-08-05の決定)ので、
  **置き換え後の形で「文字サイズ最大でもすべての並び順へ到達でき、隠れた選択肢があることが
  分かる」ことを検査する**こと。現行のchipを直す作業は要らない。

## 受け入れ証拠

- 連番トークンが無いルールでもdrag handleが出て並び替えられ、並び順の表示が「カスタム」へ変わることをwidget testで検査する。
- 各sort keyの選択と、昇降(採用する場合)が状態へ反映されることをtestで検査する。
- 002 REQ-011/013(作成日時ソート時だけ強調)が壊れていないことを既存testの継続PASSで確認する。
- `flutter test` / `flutter analyze` / `dart format --output=none --set-exit-if-changed .` がPASS。
- [`manual-verification.md`](manual-verification.md)で実機の操作感を確認する。
- exact rangeの独立reviewがPASSする。

## 作業記録

- 2026-08-12 / plan作成時に定義。
- 2026-09-30 / 着手は Claude Opus 5.5。branch `asdd/008-ui-alignment/T02-implement-sort-control`、起点`dev`@`158b2be`。

### 開発者の決定(2026-09-30)

- **昇順・降順の選び方**: 3案(8項目のメニュー / keyのメニュー＋隣の向きボタン / 4行＋行内の向きボタン)を尋ね、**8項目のメニュー**(推奨案)を採った。keyと向きの組8つを1つのメニューへ並べ、どの状態へも1回で行け、選べるものが全部見える。向きは利用者の言葉で示す(名前 A→Z / Z→A、日時 古い順 / 新しい順、サイズ 小さい順 / 大きい順)。表示は「⇅ 並び順: 名前 A→Z」、手で並べると「⇅ 並び順: カスタム」。メニューに「カスタム」は出さない(002 REQ-003)。

- **選択の印**(2026-09-30、実装中の指定): メニューで選んでいる項目の印は、**ファイルを選ぶときと同じ丸いチェックボックス**にし、選ばれたら円をシアンで、チェックを背景色で塗る。→ 一覧の選択モード(`removal_selection`)と読み込み画面(`storage_browser_view`)の印は既に同じ設定(円・`selectionMark`・`onPrimary`)だったので、**共通の部品`SelectionCheckbox`(`lib/ui/common/selection_checkbox.dart`)へ寄せ、3か所で使う**ようにした。チェックの色は既存の印と同じ`onPrimary`(#05252B。背景色 #0A0B0D に近い暗い色)で、3か所の見た目を揃えることを優先した。

### 実装(`ed7a0bf`)

| 002 spec | 実装 | test |
|---|---|---|
| REQ-001 初期は名前の昇順 | `FileListController` の初期化で名前の昇順に並べる | `sort_order_test` 例1d、`controller_test` REQ-001 |
| REQ-002 昇順・降順、降順も安定 | `SortDirection`、`comparatorFor(mode, direction)` が比較を反転(列を反転しない) | 例1b・1c |
| REQ-003 custom は選べない | `setSortMode(custom)` は `ArgumentError`。メニューにカスタムを出さない | `sort_order_test`、`manual_order_test` |
| REQ-008 読み込み直しで当てはめ | `setFiles` が並び順を当て、`custom` なら名前の昇順へ | 例22〜24 |
| REQ-011/013 向きを問わず | 判定は `sortMode == createdAt` のまま(向きを見ない) | 例26、`created_at_sort_view_test` |
| REQ-017 取り消しは並び順も戻す | 状態層に `restoreFiles(entries, sortMode:, sortDirection:)` を足し、`removal_undo` は並び順も控えて戻す。控えが古いかの判定に向きも加えた | 例25(状態層・widget)、降順の取り消し |
| REQ-018 モード中はつまみを出さない | 変えていない(並び順のcontrolはモード中も出す) | `removal_selection_mode_test` 代表例17 |
| REQ-019 つまみはルールに関わらず | `manualOrderMatters` と `showDragHandle` を廃止 | 例16(連番なしで並べて「カスタム」) |
| REQ-020 1か所で読めて全部選べる | `_SortBar` を `⇅ 並び順: 名前 A→Z ▾` と8項目の `PopupMenuButton` へ。文字2.0で最後の項目まで届く | `manual_order_test` REQ-020・N-8a |
| REQ-020 実行後は並べ直さない | `replaceItems` は変えていない(並べ直さない) | 例27 |

- **REQ-011 の警告の配置**(`T01` の決定): 一覧の上の帯(`_CreatedAtFallbackBanner`)をやめ、並び順の表示と同じ `Wrap` に短い注記「⚠ 作成日時不明の N 件は更新日時で代替」を置いた。入りきらなければ次の行へ回る。件数と代替したことは残した。test は「表示の右に出る」「320幅・文字2.0で次の行へ回り、はみ出さない」。
- **参考デザインから離れた点**: 土台は横並びの chip(元の名前順・作成日時順・サイズ順・カスタム順)で昇降を持たない。ドロップダウン・昇降・カスタムを選べないことは開発者の決定 (e)(2026-08-05)と `T01` の 002 spec による。キーの表示名を「元の名前順」から「名前」へ変えた(向きの語「A→Z」と並べるため)。

### 既存testの改訂(承認済みの仕様の変更に追随したもの)

以前の振る舞いを検査していたtestを、新しい 002 spec に合わせて書き換えた。**assertionを緩めたものは無い** — 期待値を新しい仕様の値へ変えたか、前提(初期の並び)を明示した。

- `controller_test`: 初期が入力順・`custom` → 名前の昇順・`name`。`custom` の指定 → `ArgumentError`。
- `manual_order_test`: REQ-014(連番が無いと出さない)を REQ-019・REQ-020 の検査へ書き換えた。
- `created_at_sort_test`: 警告しないソートの列挙から `custom` の指定を外し、手で並べた `custom` で検査。昇降の両方を回す。
- `created_at_sort_view_test` / `file_list_view_test`: chip のタップをメニューの選択へ。取り消しが古い控えを断る test は、**向きだけ変える**形にした(向きの判定を検査するため)。
- `preview_rows_test` / `warning_detail_scope_test`: 入力順が表示順になる前提だったので、`reorder` / 名前の降順で同じ並びを作った。
- `removal_selection_mode_test`: 印を `SelectionCheckbox` で探す。「カスタム順」chip の検査を「並び順のcontrolは出る」へ。モード中に並べ替わらないことの検査は `sortMode` が初期の `name` のままであることで見る。
- `warning_confirmation_results_test`: 「→」の数で結果行を数えていたので、表示「名前 A→Z」を拾わないよう「 → 」(空白付き)で数える。
- `working_set_test`(**004**): 「選択結果の順が表示順・初期ソートは custom」→「名前の昇順」。**004 REQ-007 はこの変更と食い違っている**(下)。

### 004 spec との食い違い(2026-09-30 再承認済み)

**004 REQ-007(must・承認済み)は「表示順は選択結果の順で、初期ソートは `custom`」と定めていて、`T01` が変えた 002 REQ-001 / REQ-008 と食い違う。** `T01` は 004 の OQ-2 には追記したが REQ-007 と D-3 を直し漏らした。`working_set_test` が落ちて見つかった([finding](../../../../development-findings/2026-09-30-spec-update-missed-counterpart-requirement-in-other-plan.md))。

- 開発者が承認した 002 の意図(読み込み直後は名前の昇順)に合わせて実装を進め、**004 spec の訂正案**(REQ-007・D-3・自由とする点。「008:T02 由来の更新」)を書いた。
- **2026-09-30 に開発者が 004 spec の訂正を再承認した**(回答「004 specの訂正は承認します」)。004 spec の Status と節見出しを承認済みにした。
- **チェックの色**: 既存の印と同じ `onPrimary`(暗いシアン)のままでよい、と開発者が確認した(2026-09-30)。

### mutation

`tool/mutations.json` を追随させた。`python3 tool/check_mutation_finds.py` → `PASS: 518 mutation(s)`。

- `find` を追随させた: M291・M293・M294・M299・M300・M309・M325・M328・M343・M368・M414(つまみの枠が常に出る、取り消しが `restoreFiles` で戻す、向きの判定、選択の印の共通部品化)。
- **外した: M310**(モード中も「カスタム順」chip を出す)— chip そのものが無くなり、REQ-003 でカスタムは選べない。守る対象が無い。モード中の並び順の提示は REQ-018 が許している。
- 足した: M548〜M562(初期の並び、読み込み直しの当てはめ、custom の戻し、降順の無視・列の反転(対照)、custom の指定、降順の警告、取り消しの並び順と向き、実行後の並べ直し、印、降順の欠落、警告の配置、連番なしのつまみ)。

**範囲付きで回した**(26件 = `find` を追随させた11件 + 足した15件。AGENTS.md の絞り方。表を作業用へcopyし `command` を差し替えた): `flutter test test/spec_002_file_list test/spec_004_file_source test/spec_005_rename_exec`、対象 `ed7a0bf`。

```text
26 mutations: 25 KILLED, 1 SURVIVED, 0 SKIPPED
ERROR: M300 SURVIVED
```

- **M300(並び順のキーを見ない)が SURVIVED。** 取り消しが古い控えを断る test を「向きだけ変える」形へ書き換えたので、**キーだけが変わる場合**を検査する test が無くなっていた。→ 「キーだけを変えた後の取り消しも、並びを戻さない」(サイズが同じなのでサイズ順にしても順序・向きが変わらない)を `file_list_view_test` へ足した(`86ea96a`)。M300 だけを回し直した: `flutter test test/spec_002_file_list`、対象 `86ea96a`。

```text
M300 | KILLED | lib/ui/file_list/removal_undo.dart | ... | exit 1
1 mutations: 1 KILLED, 0 SURVIVED, 0 SKIPPED
```

### 実機確認 2回目(2026-09-30、対象 `b3a9f06`)と、それを受けた変更

- 開発者の指定: 「ケバブの右に余白ができてしまっているので、詰めてください。また、これによって『並び順:』の文字が入らなくなったのであれば、詰めた後に『並び順:』が入るか試してください。入るなら入れなおしてください。『3件の問題』の先頭にあるiマークも警告マークにそろえてください。さらに、『3件の問題　詳細』のように太字・下線をつけた『詳細』の文字を追加し、押せることをわかりやすくしてください。(『詳細』の文字以外を押してもモーダルは開く)」。008 plan の「人間の決定」へ記録した。
- **余白の原因**: 並び順を `Flexible` で包んでいたので、行の幅の半分を取り置いて使わず、余りがケバブの右に空いていた(幅 411・文字 1.0 で 62px。widget test で実測)。加えて、ケバブの tap target(48)が中のアイコン(20)より広く、左と同じ padding(8)ではアイコンの右に 22px 残っていた。
- 実装(`4932a39`):
  - 帯の右の padding を 2 にし(`headerBarRightPadding`)、ケバブのアイコンの右端を左の件数と同じ 16px にした。tap target は 48 のまま。
  - 並び順は `Expanded` + 右寄せで残りの幅を使い、ケバブに接する。
  - **件数の欄は自分の幅を使う(上限は帯の40%)。** 初めは並び順に帯の65%を上限として与えたが、幅 320・文字 1.3・200 件で**件数が切れた**(`row_presentation_test`「ヘッダの数字が消えない」が落ちた。008:T16 の N-9 の保証)。そこで件数を先に確保し、並び順は残りを使う形へ変えた。
  - **「並び順:」は1行に入るときだけ付ける**(文字の幅を測って決める)。付けたまま行数を縛らずに折り返すと、幅 320・文字 3.0 で帯が縦に伸びて一覧がはみ出した(`load_affordance_test` が落ちた)。widget test の書体(1文字が正方形)で測ると、幅 411・文字 1.0 では「並び順: 作成日時 新しい順」まで入り、幅 360 では「並び順: 名前 Z→A」は入るが作成日時の長い表示は入らない。**実機の書体は test より幅が狭いので、実際にはもっと入る。**入らないときは「名前 A→Z」だけで最大2行、それでも入らなければ省略記号。
  - 「N 件の問題」の印を `error_outline`(i に見える)から `warning_amber_rounded` へ。後ろに太字・下線の「詳細」(`warningDetailLinkKey`)。バナーの行(`warningCountRowKey`)全体を押せるようにした(警告0件の行は押しても開かない)。
- testを足した: 「並び順:」は入るときだけ(幅 411・文字 1.0 で付く、幅 320・文字 2.0 で付かない)、ケバブの右の余白が左と同じで並び順がケバブに接する(幅 320/360/411)、警告マークと太字・下線の「詳細」・行の右端を押して開く、警告0件では「詳細」が無く押しても開かない。N-8a の test は幅 320・文字 2.0 なので「並び順:」の無い表示を見る形へ直した。
- mutation: M188・M258・M334・M338 の `find` を追随させた。**M186(件数の欄の `Wrap` を `Row` へ戻す)を外した** — 件数の欄は `Wrap` をやめて1つの `Text` にした(子が1つになった)。切り詰めない保証は M188 と新しい M568 が守る。M564〜M571 を足した(右の余白、`Flexible` へ戻す、「並び順:」を付けない/常に付ける、件数の欄を削らせる、印、下線、行を押しても開かない)。`check_mutation_finds.py` → `PASS: 525`。
- 範囲付きで回した(追随・追加した12件): `flutter test test/spec_002_file_list test/spec_004_file_source test/spec_005_rename_exec`、対象 `4932a39`。

```text
M188 / M258 / M334 / M338 / M564〜M571 すべて KILLED
12 mutations: 12 KILLED, 0 SURVIVED, 0 SKIPPED
```

### 実機確認 3回目(2026-09-30、対象 `4932a39`)と、それを受けた変更

- 開発者の指定(原文の要約): 「N件の問題」と作成日時の行で**警告マークの位置と、マークと文の間の余白がずれている**ので作成日時の行に合わせる。「N件の問題」と「詳細」の間を広げ、「詳細」の下線を太くして少し下にずらす(簡単でなければそのままでよい)。「N件の問題」は「**リネーム: N件の問題**」、作成日時の行は「**並び順: 作成日時不明のN件は更新日時で代替しています**」にする。1〜3のそれ以外(余白、「並び順:」、行のどこを押しても開く等)への指摘は無かった。008 plan の「人間の決定」へ記録した。
- **ずれの原因**: 件数の行だけ、押せる範囲(`InkWell`)の内側に横 4px の余白があり、印が 13(作成日時の行は 14)、印と文の間が 4(同 8)だった。
- 実装(`bba23bd`):
  - 印の大きさと、印と文の間を共通の値にした(`bannerIconSize` = 14、`bannerIconGap` = 8)。件数の行の横の余白を外した。
  - 「リネーム: 」をバナーの件数の文言にだけ付けた(詳細を開いたときの見出しは「N 件の問題」のまま)。作成日時の行に「並び順: 」を付けた。
  - 「詳細」の前を 14 に広げた。下線は文字の装飾をやめ、**文字の下に引いた線**(太さ 1.5、文字から 2 離す)にした。
  - 「詳細」は件数の文言と `Wrap` で並べ、入らないときは次の行へ回す。同じ行へ詰めたままだと、幅 320・文字 2.0・1000 件で「リネーム: 1000 件の問題」が切れた(`row_presentation_test`「ヘッダの数字が消えない」が落ちた。008:T16 の N-9)。
- testを足した・直した: 2つの行の印の左端・大きさ・印と文の間が一致すること、「並び順: 」「リネーム: 」の文言、「詳細」の線の太さ・離れ・前の余白。`warning_detail_scope_test` の件数の文言を「リネーム: 82 件の問題」へ。
- mutation: M219・M570 を作り直した(件数の文言の切り詰め / 線を消す)。M572〜M576 を足した(印の大きさ、印と文の間、「リネーム:」、「並び順:」、「詳細」の前の余白)。`check_mutation_finds.py` → `PASS: 530`。
- 範囲付きで回した(作り直した・足した・関わる9件): `flutter test test/spec_002_file_list test/spec_005_rename_exec`、対象 `bba23bd`。

```text
M188 / M219 / M569 / M570 / M572〜M576 すべて KILLED
9 mutations: 9 KILLED, 0 SURVIVED, 0 SKIPPED
```

### 独立review

reviewerは`gpt-6-luna`(開発者指定)。AGENTS.md の既定は「実装より一段軽いmodel」、判定・データ保護に触れるtaskは「同等以上」だが、開発者の指定を優先した(記録)。

- **attempt 1**: `158b2be..3b2bd0d`(全範囲) — **PASS**(P3 2件)。確認された点: REQ-001/002/003/008/011/013/017/018/019/020 と代表例1b〜1e・16・17・22〜27、取り消しが控えの古さ(項目の同一性と順序・キー・向き・占有名)を見て無断で置き換えないこと、既存testの改訂がassertionを緩めていないこと、M310の除去とM548〜M562の追加。reviewerが回したmutation(M300・M550・M551・M553・M556・M557)は `6 KILLED, 0 SURVIVED, 0 SKIPPED`、`check_mutation_finds.py` 518件 PASS。`flutter test` 1107 PASS・`flutter analyze`・format PASS。
  - P3(成果物の欠陥): `working_set_test.dart` のコメントが 004 REQ-007 を「再承認待ち」としていた → 「同日に再承認済み」へ直した。
  - P3(成果物の欠陥): 004 spec の末尾に余分な空行(`git diff --check`) → 削った。
  - test のコメントの変更は `test/` の差分なので、「記録だけの差分」の SELF-CHECK には当たらない。差分reviewを attempt 2 とする。
- **attempt 2**: `3b2bd0d..6b6c64c`(差分review) — **PASS**(指摘なし)。reviewerは`gpt-6-luna`。前回のP3 2件が閉じたこと、差分が触った3 fileに前回までとの食い違いが無いことを確認。`flutter test` 1107 PASS、`git diff --check 158b2be..6b6c64c` PASS。
- 連鎖: `158b2be..3b2bd0d` PASS → `3b2bd0d..6b6c64c` PASS。`6b6c64c..085f11b` は記録だけ。
- **attempt 3**: `085f11b..83d4775`(差分review。実機確認1回目の配置の指定) — **PASS**(指摘なし)。reviewerは`gpt-6-luna`。開発者の指定、005 REQ-009 (3)・REQ-020、008:T33、002 REQ-011/018/020 が壊れていないこと、testの改訂、M561の除去とM563の追加を確認。`flutter test` 1109 PASS・analyze・format・`git diff --check` PASS。reviewerが回したmutation 6件 KILLED。
- 連鎖: `158b2be..3b2bd0d` → `3b2bd0d..6b6c64c` → (記録) → `085f11b..83d4775`、いずれも PASS。
- **attempt 4**: `ef1ae09..098a4c1`(差分review。実機確認2回目の指定) — **PASS**(指摘なし)。reviewerは`gpt-6-luna`。開発者の指定、008:T16 N-9、005 REQ-009 (3)(4)、008:T33、002 REQ-018/020、testの改訂(`.first` は件数の文言へ限定しただけ)、M186の除去とM564〜M571を確認。`flutter test` 1113 PASS・analyze・format・`git diff --check` PASS。reviewerが回したmutation 12件 KILLED。
- 連鎖: `158b2be..3b2bd0d` → `3b2bd0d..6b6c64c` → (記録) → `085f11b..83d4775` → (記録 `83d4775..ef1ae09`) → `ef1ae09..098a4c1`、いずれも PASS。

### 実機確認 1回目(2026-09-30、対象 `6b6c64c`)と、それを受けた変更

- 開発者の結果: **動作はすべて問題なかった**(1〜5)。そのうえで配置の指定を受けた: 「並び順の場所はケバブの左に配置したい。並び順だけがある帯は削除してください」。
- 作成日時の警告の置き場所を尋ねた(3案: 必要なときだけ帯 / 並び順の表示に⚠ / 件数の横)。回答は**「必要なときだけ帯」**に次の補足: 上の帯には件数・並び順・ケバブの3つを置き、「正常にリネームできます」「3件の問題」「作成日時不明の3件は更新日時で代替しています」のような状態のメッセージは、帯の下にメッセージバナーとしてまとめる。バナーは上の帯と区別できるよう色を付ける。メッセージの追加・削除で高さが急に変わらないよう、アニメーションで滑らかに変える。008 plan の「人間の決定」へ記録した。
- **`T01` の配置の決定(警告は並び順の表示の右)はこれで置き換わった。** 002 spec は置き場所を縛っていない(REQ-020)ので spec は変えない。
- 実装(`b3a9f06`):
  - 並び順だけの帯(`_SortBar`)を消し、`_SortControl` を上の帯(`_HeaderBar`)のケバブの左へ置いた。文字の拡大では折り返す(`Flexible`、2行まで)。帯で幅を詰めるため**表示から「並び順:」を外した**(`⇅ 名前 A→Z ▾`。意味は ⇅ と tooltip「並び順を変える」、読み上げ「並び順: 名前 A→Z」が持つ)。
  - 上の帯から件数表示(`WarningCountView`)を外し、帯の下の `_MessageBanner` へまとめた: ルール未設定(`RuleNotConfiguredBanner`、情報色)・準備完了/N件の問題(肯定色/危険色、押すと全件の詳細)・作成日時の代替(危険色、全文「作成日時不明の N 件は更新日時で代替しています」)。行ごとに意味の色を薄く敷く。`AnimatedSize`(200ms)で高さを変える。
  - **選択モード中も件数のメッセージを出す**ようにした。以前はヘッダの中でモード中に隠していたが、バナーに移ると、隠した瞬間に一覧が1行ぶん上へずれる(`removal_selection_mode_test`「行の読み始めが動かない」が落ちて分かった)。
- testの改訂:
  - `row_presentation_test`「警告が1件も無いときと比べても一覧の取り分が変わらない」→「一覧が削られるのはバナーの1行だけ」。**件数に依存しない**こと(警告2件と30件で同じ)は別のtestがそのまま見る。メッセージが無いときにバナーが0になるのは開発者の指定(増減をアニメーションする)による。
  - `manual_order_test`: 表示の文言から「並び順:」を外した。「並び順はケバブの左にあり、件数と同じ1行。準備完了はその下のバナー」を足した。
  - `created_at_sort_view_test`: 「表示の右に出る」→「帯の下のバナーに出る」、「高さが途中の値を経て変わる」を足した。
- mutation: M198・M258・M390・M559・M560 の `find` を追随させた。**M561(警告を並び順の表示の下へ出す)を外した** — 守っていた配置の決定そのものが置き換わった。**M563(バナーの高さを一度に変える)を足した。** `check_mutation_finds.py` → `PASS: 518`。
- 範囲付きで回した(追随・追加した6件): `flutter test test/spec_002_file_list test/spec_005_rename_exec`、対象 `b3a9f06`。

```text
M198 KILLED / M258 KILLED / M390 KILLED / M559 KILLED / M560 KILLED / M563 KILLED
6 mutations: 6 KILLED, 0 SURVIVED, 0 SKIPPED
```

## Current state / handoff

- Last checkpoint: 実機確認3回目の指定を実装 `bba23bd`(flutter test 1114 PASS・analyze・format・mutation 9件 KILLED)
- Blocker category: なし
- Waiting for: なし
- Requested action: なし
- Evidence revision: `bba23bd`
- Next Agent action: 差分review(attempt 5、`04526e7..HEAD`)を起動し、PASS後に実機確認4回目を依頼する
