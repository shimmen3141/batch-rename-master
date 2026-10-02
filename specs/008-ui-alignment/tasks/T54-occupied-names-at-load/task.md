# T54 読み込んだ時点でフォルダの名前を調べ、一覧の警告に読み込んでいないファイルとの重複を出す

## 目的

いまは、読み込んでいないファイル(フォルダにもともとある同名)との重複が、**実行buttonを押したとき**に初めて
一覧の警告へ現れる。読み込んだ時点でフォルダの名前を調べ、**実行buttonを押す前から**一覧と詳細に出す。

## 受領した要望(2026-10-03 JST)

`T53` の実機確認1回目で、開発者が「実行buttonを押す前(ルール設定時点？)に調べることは可能ですか」と尋ねた。
回答(可能・仕様の変更は不要・別 task を推奨)を受けて、開発者が「新しい task として登録したい」とした。
あわせて懸念として「ダウンロードやスクリーンショットだと、フォルダに数千件の既存ファイルが存在する場合もある。
全て探索するのにどれぐらいの時間がかかるか」を挙げた。

## 現状(`dev`@`0e58f25`)

- 占有名は `RenameExecutionController.prepare`(実行の要求時。005 REQ-028)だけが `collectOccupiedNames`
  (OP-005)で取り、`FileListController.setOccupiedNames` へ渡す。読み込みでは取らない。
- 保存しているのは「フォルダの名前 − **その時点の選択とルール**で改名されるファイルの現在名」である。そのため、
  取ったあとに**選択やルールを変えると一覧の警告がずれる**(例: 選んでいなかった `b.jpg` を選び `b→c`、`a→b`
  にすると、占有名に残った `b.jpg` と `a` の目標がぶつかり、ありもしない重複が出る)。実行時は取り直すので
  実害は一覧の表示だけ。
- Android の名前の列挙(`AndroidFileSource.listNames`)は `Directory.list` で名前だけを読み、ファイルごとの
  `stat` はしない。**app 内の file browser(`AndroidStorageBrowser.list`)がフォルダを開くときと同じ操作**である。
  SAF の経路(`SafFileSource.listNames`)は列挙できず、常に失敗を返す。

## 方針(着手時に確かめる)

- **フォルダの名前の一覧そのもの**を folder ごとに保存し、占有名(一覧 − 改名される選択ファイルの現在名。OP-005)は
  **評価のたびに**引き算する。上の「選択・ルールを変えるとずれる」も同時に直る。
- 取るのは**読み込んだとき**(folder ごとに1回)と、**改名の実行・元に戻した後**。ルールを変えるたびには取らない
  (一覧はルールで変わらない)。実行の要求時の取り直し(REQ-028)はそのまま残す。
- 取得は非同期で、一覧の表示と操作を止めない。取れるまで・取れなかったときは今と同じ(占有名なしで評価。REQ-028 が許す)。
- 影響する所: 読み込みの流れ、`FileListController`、`removal_undo.dart`(占有名の同一性に依存)、`prepare`。
- **仕様の変更は要らない見込み**(REQ-028「一覧の警告はより前に取得した占有名で評価してよい」)。着手時に 005 の
  REQ-026 / REQ-028 / OP-005 と照合し、要るなら開発者の承認を取る。

## 所要時間の懸念(2026-10-03 JST の見積もり)

- container(Linux、ローカルの disk)で 5000 件のフォルダを `Directory.list` で名前だけ読むと **10〜60ms**。
  ファイルごとに `stat` まですると約 0.7 秒(今の列挙はしない)。
- Android の共有ストレージ(`/sdcard`)は FUSE 越しで、これより数倍遅い見込み。**実機では未計測。**
- **今も同じ量の列挙を、利用者が file browser でそのフォルダを開くたび、と実行の要求のたびに行っている。**
  読み込み時に1回足すだけで、新しい種類の負荷ではない。
- 受け入れで、エミュレータに数千件のフォルダを作って計測する(下)。

## 受け入れ証拠(案)

- unit / widget test: 読み込み後、実行を要求する前に、読み込んでいない同名との重複が一覧と詳細に出る。選択・ルールを
  変えても占有名がずれない(上の `b.jpg` の例で偽の重複が出ない)。取得失敗・未取得は今と同じ。実行後・元に戻した後に
  取り直す。実行の要求時の取り直し(REQ-028)は変わらない。
- `flutter test` / `flutter analyze` / `dart format` が PASS。mutation を足して範囲付きで KILLED を確かめる。
- 実機: 数千件(例: 5000 件)のフォルダから数件を読み込み、一覧の表示が止まらないこと、警告が出るまでの時間を計測する。
- 独立review(開発者の指定で当面は Sonnet)。

## 作業記録

日付は JST(container の時計は UTC なので、commit の時刻とは日付がずれることがある)。


- 2026-10-03 / 起票。開発者の懸念(数千件のフォルダの所要時間)に、container での計測と見積もりで答えた(上の「所要時間の懸念」)。
- 2026-10-03 / 開発者「008:T54 に着手してください。方針に沿いつつ、できれば効率的な方法で実装してください」。`in_progress` にした。
- 2026-10-03 / 実装(`c29cfde`)。
  - **実在名と引く集合を分けた**(`lib/data/rename_exec/occupied_names.dart`): `freedNamesByFolder`(改名で空く名前。OP-005 の
    引く集合)を切り出し、`collectOccupiedNames` はそれで引く(振る舞いは同じ)。`OccupiedNamesReady.folderNames` に引く前の
    実在名も載せる。
  - **一覧は引く前の実在名を持つ**(`FileListController.folderNames` / `setFolderNames` / `updateFolderNames`。旧
    `occupiedNames` / `setOccupiedNames` を置き換えた)。評価のたびに `displayOccupiedNames` で引く。**効率**: 返すのは
    選択ファイルの生成後名と一致する名前だけ(001 の `validate` が占有名で見るのはそこだけ)なので、数千件の実在名を
    評価のたびに数え直さない。選択・ルールを変えても空く名前がずれない(「現状」の `b.jpg` の例。test で固定)。
  - **読み込み時に取る**(`lib/ui/file_list/folder_names_sync.dart` の `FolderNamesSync`。`main.dart` で一覧に付ける)。
    一覧の変更を見て、**実在名をまだ持っていない folder**(読み込み・読み込み直し)と、**読み込んだファイルに前回無かった
    名前が現れた folder**(改名の実行・元に戻した)だけを非同期で問い合わせる。選択・ルール・並び順・除去では問い合わせ
    ない。取れなかった folder は名前が変わるまで繰り返さない(SAF)。同じ folder を同時に二重に問い合わせない。
  - `prepare`(REQ-028 の取り直し)は引く前の実在名を一覧へ渡すように変えた。除去の取り消し(`removal_undo.dart`)は
    実在名を控えて戻す。
  - test: `test/spec_005_rename_exec/folder_names_sync_test.dart`(新規)。既存 test の `setOccupiedNames` / `occupiedNames`
    は名前の置き換えだけ(値の意味は変わらない — 渡していた名前に読み込んだファイルの名前は含まれていない)。
  - 検証(`c29cfde`): `flutter analyze` No issues、`dart format` 0 changed、`flutter test` 1197 PASS、`check_mutation_finds.py` PASS(609件)。
- 2026-10-03 / 範囲付き mutation の1回目(`c29cfde`)。**この回の表は証拠として使わない**(下の訂正)。
  - **M664 が SURVIVED**: 取れたときは結果を入れること自体が一覧の変更通知になるので、最後の見直しが無くても再問い合わせが
    走る。**取れなかったときは通知が無く、問い合わせ中の改名を取りこぼす** — その test が無かった。test を足した(`20eb3b1`)。
- 2026-10-03 / **記録の訂正**(別セッションの調査による。[finding](../../../../development-findings/2026-10-03-runaway-mutation-exhausted-host-memory.md))。
  - 以前ここに「background で全 spec を回すと **session がメモリ不足で2回止められた**」と書いたのは**誤り**だった。実際には
    **mutation M662 が test を無限ループさせ**、`flutter_tester` が膨らみ続けて **Windows ホストのコミットメモリを枯渇させ、
    WSL2 VM ごと Docker が止まった**(2026-10-03 03:13 / 04:23 JST の2回)。範囲を3本の test に絞っても、M662 が入っていれば
    同じことが起きる — 原因は実行範囲ではなく mutation そのものだった。
  - **M662 の「KILLED | exit 1」は検出ではなかった。** M662(`_failed.add(folder);` の削除)を当てると、失敗した folder を
    即座に問い合わせ直し続ける。偽の供給元が `Future.value` で即座に返すので連鎖は microtask だけで回り、timer が発火しない
    — `pumpEventQueue` も test の timeout も timer なので test は落ちない。1回目の生出力の時刻(20:02:50 UTC = 05:02:50 JST)は、
    別セッションが暴走した `flutter_tester` を止めた直後で、**exit 1 はその停止による**と見るのが妥当である。同じ実行の
    M663〜M665 も、ホストが swap で詰まっている間に走った可能性がある。
  - **対応**(finding の対応案1。`04f862a`): test の偽の供給元に**問い合わせの上限**
    (`_callLimit` = 100。超えたら完了しない Future を返して連鎖を断つ)を置き、呼び出し回数の assertion で落ちるようにした。
    例外を投げる供給元にも同じ上限を置いた(例外は `FolderNamesSync` が取れなかった扱いにするので、投げても連鎖は止まらない)。
    実装側に再問い合わせの上限を持たせる案(対応案2)は採らない — 製品の振る舞いは `_failed` で正しく止まり、仕様にも
    回数の上限は無い。**残余risk**: `_failed` への記録だけが再問い合わせの歯止めである構造は、将来この行を消す変更を
    test が有限時間で検出できる(上の上限)ことで受ける。引き受け先: 008:T54(この構造の所有 task。独立review attempt 1 の P3)。
  - M662 を手で当てて `timeout 120` で test を流し、**3秒で3件が落ちる**ことを確かめた(暴走しない)。
  - 14件を流し直した(前面、`timeout 590`、**全体で139秒**)。command は `flutter test` を `folder_names_sync_test.dart`・
    `occupied_names_test.dart`・`file_list_view_test.dart` に絞ったもの:

```text
M30 | KILLED | lib/data/rename_exec/occupied_names.dart | 占有名から「改名される選択fileの現在名」を除く処理を除去(例25bのP0再発)。**`008:T ... | exit 1
M40 | KILLED | lib/ui/rename_exec/rename_execution_controller.dart | 取り直した占有名を一覧の警告表示へ反映しない(REQ-026 / REQ-028)。**`008:T ... | exit 1
M43 | KILLED | lib/data/rename_exec/occupied_names.dart | 対象folderをREQ-022の除外後へ狭める(独立review 1回目のP1-1再発)。**`0 ... | exit 1
M296 | KILLED | lib/ui/file_list/removal_undo.dart | 008:T04 取り消しで占有名を戻さない ... | exit 1
M299 | KILLED | lib/ui/file_list/removal_undo.dart | 008:T04 控えが古くなっていても戻す ... | exit 1
M302 | KILLED | lib/ui/file_list/removal_undo.dart | 008:T04 占有名の取り直しを見ない ... | exit 1
M658 | KILLED | lib/data/rename_exec/occupied_names.dart | 008:T54 一覧の占有名から改名で空く名前を引かない ... | exit 1
M659 | KILLED | lib/ui/file_list/file_list_controller.dart | 008:T54 引く前の実在名をそのまま占有名にする ... | exit 1
M660 | KILLED | lib/ui/file_list/folder_names_sync.dart | 008:T54 改名で名前が変わっても問い合わせ直さない ... | exit 1
M661 | KILLED | lib/ui/file_list/folder_names_sync.dart | 008:T54 読み込み直しで捨てられた実在名を取り直さない ... | exit 1
M662 | KILLED | lib/ui/file_list/folder_names_sync.dart | 008:T54 取れなかった folder を覚えない ... | exit 1
M663 | KILLED | lib/ui/file_list/folder_names_sync.dart | 008:T54 問い合わせ中に一覧から無くなった folder の結果も入れる ... | exit 1
M664 | KILLED | lib/ui/file_list/folder_names_sync.dart | 008:T54 問い合わせ中に起きた改名を取りこぼす ... | exit 1
M665 | KILLED | lib/ui/file_list/folder_names_sync.dart | 008:T54 作った時点の一覧を問い合わせない ... | exit 1
14 mutations: 14 KILLED, 0 SURVIVED, 0 SKIPPED
```


- 2026-10-03 / **実機確認(build: `lib/` が `20eb3b1`、Android エミュレータ)**。開発者「動作について、すべて問題ありませんでした。
  重複の警告は1秒も待たずにすぐに表示されました」。手順0〜4の全項目 OK。**5002 件のフォルダで、「重複」が出るまで1秒未満**
  (「所要時間の懸念」の見積もりと一致)。
  - 同じ確認の中で、無関係な不具合を1件受領した(自由テキスト `same ` の末尾の空白でルール設定buttonのチップが
    「BOTTOM OVERFLOWED BY 1.00 PIXELS」)。T54 の範囲外として別に扱う。
- **SELF-CHECK**: `93932f2..HEAD` は `specs/` だけ(review・handoff・実機確認の記録)。`lib/`・`test/`・`tool/` に差分なし。

### 独立review

reviewer は Sonnet 5(Agent tool、`model: sonnet`。2026-10-03 の開発者の指定「レビューはいったんsonnetにやらせる」)。実装は Claude Opus 5.5。
占有名(データ保護)に触れる task には実装と同等以上を使う既定(AGENTS.md)と食い違うが、開発者の指定に従う。

- (数えない)`0e58f25..06ad35f` の review は、M662 の暴走の件で依頼側が途中で止めた。
- Review attempt 1: `0e58f25..93932f2` — **PASS** — 未解決 P0/P1 なし
  - 確認できた点: 実行の可否と自動解決(REQ-026 / REQ-028)は不変で、一覧用の値は実行経路へ漏れない。`displayOccupiedNames` は
    OP-005 と同じ引き方で、生成後名と一致する名前だけを返す最適化は `validate` の重複判定と等価。`FolderNamesSync` の時機・失敗・
    二重防止・置き換え・dispose・`main.dart` の配線、除去の取り消し、test の書き換え、記録の訂正、manual は current code と一致。
  - reviewer の検証: `flutter analyze` No issues、`flutter test` 1198 PASS、範囲付き mutation 14件 KILLED(M662 を含め完走)。
  - **P3**: 残余risk に引き受け先の task ID が無い → 「引き受け先: 008:T54」を足して閉じた(記録だけの差分。SELF-CHECK)。
- 連鎖: `0e58f25..93932f2` PASS → 以後の記録だけの差分は SELF-CHECK。

## Current state / handoff

- Last checkpoint: 実機確認 OK(`20eb3b1`)。task を `done` にし、PR #211 を merge する
- Blocker category: none
- Evidence revision: `20eb3b1`
- Next Agent action: なし(done)
