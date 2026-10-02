# T54 読み込んだ時点でフォルダの名前を調べ、一覧の警告に読み込んでいないファイルとの重複を出す

## 目的

いまは、読み込んでいないファイル(フォルダにもともとある同名)との重複が、**実行buttonを押したとき**に初めて
一覧の警告へ現れる。読み込んだ時点でフォルダの名前を調べ、**実行buttonを押す前から**一覧と詳細に出す。

## 受領した要望(2026-10-02)

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

## 所要時間の懸念(2026-10-02 の見積もり)

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

- 2026-10-02 / 起票。開発者の懸念(数千件のフォルダの所要時間)に、container での計測と見積もりで答えた(上の「所要時間の懸念」)。
- 2026-10-02 / 開発者「008:T54 に着手してください。方針に沿いつつ、できれば効率的な方法で実装してください」。`in_progress` にした。
- 2026-10-02 / 実装(`c29cfde`)。
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
- 2026-10-02 / 範囲付き mutation(`flutter test` を `folder_names_sync_test.dart`・`occupied_names_test.dart`・
  `file_list_view_test.dart` に絞った。background で全 spec を回すと session がメモリ不足で2回止められたため)。
  1回目に **M664 が SURVIVED**: 取れたときは結果を入れること自体が一覧の変更通知になるので、最後の見直しが無くても
  再問い合わせが走る。**取れなかったときは通知が無く、問い合わせ中の改名を取りこぼす** — その test が無かった。
  test を足し(`20eb3b1`)、M664 を流し直して KILLED。`flutter test` 1198 PASS。

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
M664 | SURVIVED(1回目) | lib/ui/file_list/folder_names_sync.dart | 008:T54 問い合わせ中に起きた改名を取りこぼす ... | exit 0: the tests passed with the mutation applied
M665 | KILLED | lib/ui/file_list/folder_names_sync.dart | 008:T54 作った時点の一覧を問い合わせない ... | exit 1
14 mutations: 13 KILLED, 1 SURVIVED, 0 SKIPPED
M664 | KILLED | lib/ui/file_list/folder_names_sync.dart | 008:T54 問い合わせ中に起きた改名を取りこぼす ... | exit 1(`20eb3b1` で再実行)
```

## Current state / handoff

- Last checkpoint: 実装と自動検証(`20eb3b1`)。独立reviewを依頼する
- Blocker category: none
- Evidence revision: `20eb3b1`
- Next Agent action: 独立review(Sonnet、`0e58f25..HEAD`)を起動し、PASS なら実機確認を依頼する
