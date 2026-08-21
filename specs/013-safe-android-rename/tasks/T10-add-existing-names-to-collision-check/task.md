# T10 対象folderの占有名を衝突判定へ入れる

## 目的

001の衝突判定が見ている「既存の名前」を、**アプリへ読み込まれたfileの名前**から**占有名**へ広げる。

**占有名 = 対象folderの実在entry名 − この実行で改名される選択fileの現在名。** REQ-022で除外されたfileの現在名は改名されないので**含める**(005 contract revision 4の用語)。

## なぜ必要か

001の重複判定は、最終名集合を「未選択の現在名 ∪ 選択の生成後名」で作る(001 spec)。**これはアプリへ読み込まれたfileだけである。** 対象folderには、利用者が読み込んでいないfileもある。

現状では、**読み込んでいないfileと同じ名前になる改名を、実行前に検出できない**。005 contract revision 4はこれをREQ-004・REQ-026で塞ぐと定めたので、占有名を供給する経路が要る。

**これは005 ADR-002の中心にある変更である。** 事前検出が効かなければ、衝突は実行時の`nameConflict`まで持ち越され、原子的no-replaceが無い環境では取りこぼす。

## 入力と依存

- 005 contract revision 4(approved。REQ-004、REQ-011、REQ-023〜027)。
- **`T11`の実装**(`rename_execution.dart`の`executePlan`が`occupiedNames`を受け取る形になっている)。**このtaskはその供給元を作る** — 現状は既定の空mapが渡っており、**REQ-026とREQ-027はまだ効いていない**。
- 001の`validate` / `autoResolve`と`contracts/behavior-contract.json`(001が正本)。
- 004のfile source(実在entry名を供給する側)。

## 変更範囲

- **001**: 最終名集合の定義へ**占有名**を加える。**実在名をそのまま加えてはならない** — 選択file自身の現在名が入り、`IMG_0001..0100`を1つずらす改名でほぼ全件に` (n)`が付く(005:T04のreview attempt 1のP0)。**001は純粋Dartでfilesystemを触らない**ので、占有名は入力として受け取る。001 specとcontractの改訂・再承認を伴う。
- **`validate`だけでなく`autoResolve`も占有名を避ける**(005 contract REQ-026)。警告だけを占有名で出して解決を占有名抜きで行うと、確認した目標名が占有名と衝突したまま実行へ渡る。
- **004**: 対象folderのentry名を列挙して供給する。004 specの改訂を伴う(`T03`と範囲が重なるので着手時に調整する)。
- **005**: 004から受け取った実在名から**占有名を作って**001の検証へ渡す(005 contract `scope.in`)。

## 決めること

- **占有名をいつ取るか。** 読み込み時か、実行の確認直前か、両方か。古い一覧で判定すると、事前検出をすり抜ける。
- **複数folderに跨る選択でどう扱うか。** 衝突はfolderごとにしか起きないので、folder単位で持つ必要がある。
- ~~列挙できないfolderがあったときの扱い~~ **決着済み**: 005 contract **REQ-027** — そのfolderを含む実行を行わず、理由を提示する。**「取得できなかった」を「衝突が無い」と読まない。**
- ~~複数folderに跨る選択でどう扱うか~~ **決着済み**: 占有名はfolderごと(005 contractの用語)。**folderを跨いで混ぜない。**
- **契約の`open_questions` OQ-002(REQ-027のSM-001遷移)、OQ-003(`occupiedNames`の全域性)、OQ-004(`folder`の同一性判定と正規化の責務)、OQ-006(001の横断判定をfolder単位へ揃えるか)をこのtaskで決める。** OQ-002/OQ-003は`T11`から移した — どちらも占有名の供給元が要る。
- **契約をrevision 5へ更新する範囲。** `T11`が決着させたOQ-001(試行上限=8)、OQ-005(生存名の一時名を「計画が使う一時名すべて」へ広げる)、**OQ-007(REQ-025の自己衝突を一時名経由で確かめる)**は、**実装が契約と食い違う状態**で`dev`に入っている。`T10`が自分のOQを決めた時点で、**両者をまとめてrevision 5として契約へ戻す**(人間の承認が要る)。

## 受け入れ証拠

- 読み込んでいないfileと同じ名前になる改名が、**実行前に警告として出る**ことをtestで検査する(005 spec 例25)。
- **`a→b`, `b→c`のような入れ替えで警告が出ない**ことをtestで検査する(005 spec 例25b)。**この検査が無いと、P0の再発を検出できない。**
- **他に警告が無くても、占有名との衝突だけで確認を経る**ことをtestで検査する(005 contract REQ-026、SM-001の直行経路)。
- **REQ-022で除外されたfileの現在名との衝突は警告として出る**ことをtestで検査する(005 spec 例25c)。
- `autoResolve`が返す名前が占有名と衝突しないことをtestで検査する。
- 001が占有名を**入力として**受け取り、filesystemに依存しないままであることをtestで検査する(INV-004 副作用なし)。
- **実在名を取得できないfolderがあると、そのfolderを含む実行を行わず理由を提示する**ことをtestで検査する(REQ-027、005 spec例25e)。
- **別folderの同名とは衝突しない**ことをtestで検査する(REQ-026、005 spec例25d)。
- `folder`の同一性判定(別表記の同一folderが分割されないこと)をtestで検査する(OQ-004)。
- 001の既存contract testが継続PASSする。
- `flutter test` / `flutter analyze` / `dart format --output=none --set-exit-if-changed .` がPASS。
- **契約をrevision 5へ更新し、人間の承認を得ている。** OQ-001・OQ-004・OQ-005・OQ-006の決着を反映する。**`T11`の実装が契約より広い状態を放置しない** — 契約を読んで実装する次のAgentが、実装を「契約違反」として狭め直す。
- exact rangeの独立reviewがPASSする。

## 決めたこと(2026-08-20)

「決めること」への回答。**正本は契約側**(005 contract revision 5 の `open_questions` と各 REQ、001 contract、004 spec)。ここは索引である。

| 論点 | 決着 | 反映先 |
|---|---|---|
| 占有名をいつ取るか | **実行を要求した時点で取り直す。** 一覧の警告表示にはより古い取得結果を使ってよいが、確認の要否と自動解決の入力は要求時のものを使う。要求時の取得で新たに警告が生じたら確認の経路へ入る | 005 **REQ-028**(新設)、SM-001 |
| 複数folderに跨る選択 | 決着済み(revision 4)。占有名はfolderごと。**folderを跨いで混ぜない** | 005 用語 `占有名` |
| 列挙できないfolder | 決着済み(revision 4)。REQ-027。そのfolderを含む実行を行わない | 005 **OP-005**(新設)、SM-001 遷移 |
| **OQ-002** REQ-027の操作とSM遷移 | **OP-005 `collectOccupiedNames` を新設**し、SM-001 へ `idle --requestExecute[取得できないfolderがある]--> idle` と forbidden trace を追加。idle→confirming / idle→running の guard にも「対象folderの実在名をすべて取得できた」を入れた | 005 contract |
| **OQ-003** `occupiedNames`の全域性 | **OP-001 / OP-002 の事前条件**にした。key欠損は事前条件違反であり「占有名が空」として黙って通さない | 005 contract |
| **OQ-004** `folder`の同一性と正規化 | **004 に置く**(004 **REQ-013** 所属folderハンドル)。005 も 001 も等値だけで判定し、**ハンドル文字列からfolderを導出しない** | 004 spec、005 用語 `folder`、001 用語 `folder` |
| **OQ-006** 001の判定範囲 | **folder単位へ揃える**(2026-08-20 開発者決定)。004 T7 OQ-3 の「001の判定範囲は変更しない」を明示的に取り消す | 001 REQ-007/010/012/015・INV-003・用語「最終名集合」 |
| **OQ-001 / OQ-005 / OQ-007 / OQ-008** | `T11` の決着をそのまま契約へ戻した(実装が契約より広い状態を解消) | 005 REQ-023 / REQ-025 / 用語 `生存名` / OP-004 / INV-005 |
| `T03` との順序 | **`T10` が先。** どちらも 004 spec を触るが、`T10` はポートへ `listNames` と所属folderハンドルを足すだけで、種類の選択・選択UI・導線には触れない | plan.md |

## 作業記録

- 2026-08-14 / 005 ADR-002(衝突は採番で回避する)を受けて定義。preflightを削除した`T09`の代わりに置く**わけではない** — `T09`はpreflightの実行制御で、こちらは事前検出の入力を正すtaskである。
- 2026-08-20 / 着手。`T03`より先に進めると決めた。OQ-006を開発者へ確認し「folder単位へ揃える」で決着。001 contract + spec、004 spec、005 contract revision 5 + spec を改訂した。
- 2026-08-20 / 実装。004が実在名と所属folderハンドルを供給し、005が占有名を組み立て、001がfolderごとの最終名集合で判定・解決する経路を通した。`handle`文字列からfolderを導出する暫定実装(`defaultFolderOf`)は削除した。
- 2026-08-20 / 受け入れ証拠のtestを追加(402 → 460件)。**この追加で実装の不具合を1件見つけた** — `executePlan`が`occupiedNames`の全域性を**再採番のときにしか**確かめておらず、通常の実行ではkey欠損が素通りしていた。実ファイルへ触る前の検査へ移した。
- 2026-08-21 / **mutation runnerを並走させ、適用中のmutation(M14)をそのままcommitしていた**ことに気づき、`ebeb92d`で戻した。REQ-023 / OQ-008の保護が無効なまま入っていた。経緯は[finding](../../../../development-findings/2026-08-21-concurrent-mutation-runners-committed-a-mutation.md)。cleanなbaselineで取り直した結果が下の表である。

## 検証結果

| 種別 | commandと結果 |
|---|---|
| full regression | `flutter test` = **PASS(460件)**。T10着手前は402件 |
| static analysis | `flutter analyze` = **PASS**(No issues found) |
| format | `dart format --output=none --set-exit-if-changed .` = **PASS** |
| ASDD構造 | `python <asdd-plugin>/scripts/workspace.py check specs` = **PASS**(8 plans, 62 tasks) |
| mutation | `python <asdd-plugin>/scripts/mutation_check.py tool/mutations.json --root .` = **42 mutations: 42 KILLED, 0 SURVIVED, 0 SKIPPED** |
| build | **未実施。** AI containerにAndroid SDK / Xcodeが無く実行できない |
| manual | **未実施。** 実機・emulatorでの確認は行っていない |

T10が入れた判定に対応するmutationは**M30〜M42の13件**で、いずれもKILLEDである。

- M30 占有名から「改名される選択fileの現在名」を除く処理を除去(例25bのP0再発)
- M31 列挙失敗を空の占有名として扱う(REQ-027の区別を潰す)
- M32 `validate`が占有名を最終名集合へ入れない(REQ-015)
- M33 `autoResolve`が占有名を避けない(REQ-015 / REQ-026)
- M34 重複判定をfolder横断へ戻す(OQ-006の決着を潰す)
- M35 全域性の違反を例外でなく空集合として通す(OQ-003)
- M36 `executePlan`の全域性検査を除去(OQ-003)
- M37 目標名が占有名と衝突する入力を通す(OP-001の事前条件)
- M38 一時名が占有名を避けない(REQ-004)
- M39 REQ-027の理由提示(どのfolderがなぜ)を除去
- M40 取り直した占有名を一覧の警告表示へ反映しない(REQ-026 / REQ-028)
- M41 `listNames`の失敗を空の列挙結果へ落とす(004 REQ-014)
- M42 folderハンドルの正規化を除去(004 REQ-013 / OQ-004)

## この実装で残る限界

**仕様として認めたもので、不具合ではない。** 承認の判断材料として書く。

- **一覧の警告に占有名が入るのは、実行を要求したあとである。** 読み込み時には実在名を取りに行かない(REQ-028が明示的に許している)。したがって利用者は「一覧に警告が無い → 実行を押す → 確認モーダルが出る」という順で見る。読み込み時にも取りに行く形は004の読み込み経路と008の提示に踏み込むので、T10では入れていない。
- **AndroidではREQ-027により実行が止まる。** SAFは`pickFiles`で1fileずつの読み取り権限しか取らず、親folderを列挙できないため`listNames`が理由付きの失敗を返す。**Androidの実renameはrevision 2以来「安全な未対応」なので新しい制限は作っていない**が、`T07`のapp内file browserが入るまではこの状態である。
- **folderハンドルの正規化が失敗した場合、別表記が別folderへ割れうる。** desktopはsymlinkを解決した絶対pathを使い、解決できないときだけ正規化した絶対pathへ落ちる。割れても占有名が「別folderのもの」として扱われるだけで、実在確認(REQ-025)と実行時の再採番(REQ-023)が残る。

## Current state / handoff

- Last checkpoint: **実装・test・mutationまで完了。** working treeはclean
- Blocker category: **human approval**
- Waiting for: **001 contract(Strict)・004 spec・005 contract revision 5(Strict)の再承認**
- Requested action: 下記3点の承認可否
  1. **005 contract revision 5** — OQ-001〜OQ-008の決着 + REQ-028(占有名の取得タイミング)+ OP-005
  2. **001 contract** — 用語`folder`/`占有名`の追加、最終名集合のfolder単位化、REQ-007/010/012・INV-003の改訂、REQ-015の追加、OP-003/OP-004の引数追加
  3. **004 spec** — REQ-013(所属folderハンドル)・REQ-014(`listNames`)の追加、REQ-012の理由更新
- Evidence revision: branch `asdd/013-safe-android-rename/T10-add-existing-names-to-collision-check` @ `ebeb92d` 以降。base は `dev@c6cbd9a`
- Next Agent action: **exact rangeの独立reviewを起動する**(`dev...HEAD`)。承認をいただけたら各`status`を承認済みへ更新し、PRを作る。**承認前に実装をmergeしない。**
