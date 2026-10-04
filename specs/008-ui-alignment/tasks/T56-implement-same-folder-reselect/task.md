# T56 一覧の先頭のfolder行から同じfolderを開き直す導線を実装する

## 目的

`T26` で承認された 004 REQ-021(同じ folder を一覧の状態を初期値にして開き直す)と 002 REQ-021(確定したときの並び)を
実装する。入口は一覧の先頭の folder 行に置く(`T26` の人間の決定)。

## 仕様の正本

- [`specs/004-file-source/spec.md`](../../../004-file-source/spec.md) の REQ-015 / REQ-021、代表例 36〜43、「008:T26 由来の更新」節。
- [`specs/002-file-list/spec.md`](../../../002-file-list/spec.md) の `reselectFiles`、REQ-021、代表例 28〜31、「008 T26 由来の更新」節。
- 提示の決定と経緯: [`T26`](../T26-define-picker-state-restore/task.md) の「開発者の決定」。ここへ複製しない。

## 範囲

- 002: `FileListController.reselectFiles`(置き換え・全件選択・同一ハンドルの集約は `setFiles` と同じ。並びだけ REQ-021)。
- 004: browser を「所属 folder を表示し、指定したハンドルを選択済み」で開ける入口。確定は `reselectFiles` へ結線する。
  folder が無い・列挙できないときは browser に入らず一覧無変化で理由を示す。
- 一覧: **所属 folder が1つ**のとき、一覧の先頭に細い folder 行(folder 名と右端の `＋ 追加`)を出す。スクロールしても先頭に残す。
  行全体のタップでは開かない(`T24` の折りたたみのために空ける)。除去の選択モード中・場所を持たない一覧(demo data)・desktop では出さない。
- 読み込み時と同じく、確定後に占有名を取り直す(`T54`。`setFiles` と同じ経路に載せる)。
- 対象外: 複数 folder を束ねる表示(`T24`)、上部の帯の変更(帯との名前の重複は manual で見て判断する)。

## design 土台との照合

`docs/design/Bulk Renamer.html` には folder 行が無い。**離れる点**: 一覧の先頭に folder 行を足す。理由: `T26` の人間の決定
(004 REQ-021 の入口)。帯・行・下部の帯の配置は変えない。

## machine検証範囲と引き受け先

- unit: `reselectFiles` の代表例 28〜31、`setFiles` の REQ-008(custom → 名前の昇順)が変わらないこと。
- widget: 代表例 36〜43(初期の選択、足す・外す・Cancelled・別 folder へ移る・改名後のハンドル・folder 消失・「別フォルダへ」は保存場所から)。
  folder 行の出る条件(1 folder / 選択モード中 / demo data)と、行全体のタップで開かないこと。
- mutation で上の判定が KILLED になることを確かめる。
- **Android エミュレータ**: folder 行の見え方、sticky、帯との重複の見え方、実ファイルでの開き直しと確定。この task が引き受ける。

## 受け入れ証拠

- 上の test が PASS し、既存の test を弱めない。format / analyze / full test / workspace check PASS。
- mutation の生出力。
- エミュレータでの manual 確認 PASS(`manual-verification.md` は着手時に作り、`task.json` へ書く)。
- exact range の独立 review PASS。

## 実装で決めた点(提示の細部。spec は縛らない)

- **folder 行は一覧の外(警告の帯と一覧の間)に置く。** スクロールしても先頭に残る(sticky と同じ見え方)。
  `T24` で束ねる表示にするときは一覧の中へ移す。
- **選択モード中は行を残し、`＋ 追加` だけを隠す**(描かない・押せない・読み上げない。場所は取る)。範囲の節では
  「選択モード中は出さない」と書いたが、行ごと消すと一覧が跳ねる(`T30` の帯と同じ理由)ので、入口だけを隠す。
  004 REQ-021 が課すのは「入口を出さない」ことで、これを満たす。
- **desktop では行ごと出さない**(入口が無い行は帯と重複するだけ)。判定は platform ではなく、source が
  `FolderReopenSource` かどうかで行う(composition root)。
- **demo data**: 2 folder なので行は出ない。選択モードで片方の folder の分を全部外すと1 folder になり行が出るが、
  `demo:` の folder は実在しないので、`＋ 追加` は browser を開かずに「フォルダが見つかりません」を出す(代表例 42 と同じ経路)。
  範囲の節の「demo data では出さない」からの差で、実在しない folder の扱いとして正しいので受け入れる。
- 開き直しの処理(権限の確認・失敗の通知)は**読み込み帯が持ち**、folder 行は `SameFolderReopen` を経由して呼ぶ
  (013 REQ-001〜004 の説明が帯の位置に出るように)。

## 作業記録

日付は JST。

- 2026-10-03 / 着手・実装(`29d77d3`)。検証: `flutter analyze` No issues、`dart format` 0 changed、
  `flutter test`(full)は tooling の find 一致だけ FAIL → 既存 mutation 7件(M85/M89/M104/M166/M397/M550/M598)の
  `find` を前後の行を含めて一意にし、`test/tooling` PASS。T56 の mutation M669〜M681 を足した。
- 2026-10-03 / 検証(`29d77d3`): `flutter test`(full)**1236 PASS**、`check_mutation_finds.py` PASS(625件)。
  mutation は範囲を絞った command で、**今回足した M669〜M681 と find を追随させた7件の計20件**を回した:

```text
Command: flutter test test/spec_002_file_list test/spec_004_file_source test/spec_005_rename_exec test/spec_013_android_rename test/spec_003_rule_builder
M85 | KILLED | M89 | KILLED | M104 | KILLED | M166 | KILLED | M397 | KILLED | M550 | KILLED | M598 | KILLED
M669 | KILLED | lib/ui/file_list/file_list_controller.dart | 開き直しの確定を setFiles と同じにする
M670 | KILLED | lib/ui/file_list/file_list_controller.dart | 新しく入った item を名前の昇順に並べない
M671 | KILLED | lib/ui/file_list/file_list_controller.dart | custom で前の item の値を残す
M672 | KILLED | lib/ui/file_source/file_source_bar.dart | 帯の開き直しが reselectFiles を使わない
M673 | KILLED | lib/ui/file_source/file_source_bar.dart | 開き直す前に権限を確かめない
M674 | KILLED | lib/ui/file_source/file_source_bar.dart | 一覧の状態を初期値に渡さない
M675 | KILLED | lib/ui/file_list/file_list_view.dart | 選択モード中も「＋ 追加」を出す
M676 | KILLED | lib/ui/file_list/file_list_view.dart | 開き直せない画面(desktop)にも folder 行を出す
M677 | KILLED | lib/ui/file_source/same_folder_reopen.dart | 所属 folder が2つでも入口を出す
M678 | KILLED | lib/ui/file_source/storage_browser_view.dart | 起点を無視して保存場所から始める
M679 | KILLED | lib/ui/file_source/storage_browser_view.dart | folder に無い path も選択に数える
M680 | KILLED | lib/data/file_source/android_file_source.dart | folder が無くても browser を開く
M681 | KILLED | lib/data/file_source/storage_browser.dart | 保存場所の root より下の folder を含むと判定しない
20 mutations: 20 KILLED, 0 SURVIVED, 0 SKIPPED
```

- **残余risk(安全網の穴。受容)**: composition root(`main.dart`)が `onReopenFolder` に `_reopen.call` を渡す結線と
  `_reopenInBrowser` が `initialFolder` / `initialSelection` を渡す結線は、test が通らない(`main.dart` を pump する
  test が無い)。通り抜ける失敗は「入口が出ない / 選択済みで開かない」で、データ損失・無断置換・偽の成功・権限・互換性の
  いずれでもない。引き受け先: この task の manual(手順 1・2)。
- 代表例 42(folder の消失)は manual に入れない(エミュレータで folder を消す操作が手間で、
  `android_file_source_test` と `same_folder_reopen_test` が経路を固定している)。

### 独立review

reviewer は Sonnet 5(Agent tool、`model: sonnet`。開発者の指定)。実装は Claude Opus 5.5。
権限(013 REQ-004)に触れる task には実装と同等以上を使う既定(AGENTS.md)と食い違うが、開発者の指定に従う。

- Review attempt 1: `ca12916..da6efd7` — **PASS** — P0/P1 なし。P2 が2件
  - 確認できた点: 004 REQ-021 / REQ-015・002 REQ-021・代表例 36〜43 と実装の突き合わせ、開く直前の権限確認、folder 消失時に
    browser を開かないこと、desktop の除外(型で判定)、選択モード中の入口の隠し方、占有名の取り直しと除去の取り消しの既存の安全策が
    効くこと。`flutter test` 1236 PASS・analyze・format・workspace check、mutation 20件を再現(20 KILLED)。
  - P2-1(安全網の穴): `RuleBuilderWorkspace` が `onReopenFolder` を一覧へ渡す結線(狭幅・広幅)が test に守られていない。
    reviewer の対照 REV1 が SURVIVED → 結線の widget test(狭幅・広幅)を足し、REV1 を **M682**、広幅側を **M683** として
    表へ取り込んだ(`de9714c`)。範囲付き(`same_folder_reopen_test.dart` と `test/spec_003_rule_builder`)で **2 KILLED**。
  - P2-2(成果物の欠陥・記録): 代表例 41(改名後のハンドルで開き直す)の専用 test が無いのに検証範囲に書いていた →
    `same_folder_reopen_test.dart` に専用 test を足した(`de9714c`)。
  - 閉じたあとの検証: `flutter test` **1239 PASS**、analyze No issues、format 0 changed、`check_mutation_finds.py` PASS(627)。
- Review attempt 2(差分): `da6efd7..da379ef` — **PASS** — 指摘なし。P2-1・P2-2 が test と mutation で閉じたことを確認
  (M682/M683 を再現して 2 KILLED、`flutter test` 1239 PASS、`check_mutation_finds.py` 627 PASS)。
- 連鎖: `ca12916..da6efd7` PASS → `da6efd7..da379ef` PASS。以後の記録だけの差分は SELF-CHECK。
- 残余risk の更新: `RuleBuilderWorkspace` の結線は上で test に入った。残るのは `main.dart` の結線だけ(作業記録の残余risk のとおり)。

### 実機確認(2026-10-04)

- 対象: `lib/` が `29d77d3` と同一の build(branch HEAD `b2e93ba`。`git diff --stat 29d77d3 HEAD -- lib hook src pubspec.yaml pubspec.lock android` が空)
- 実施: 開発者(Android エミュレータ)。手順 0〜6
- 結果: **OK**(「確認事項について、動作は問題ありませんでした」)
- 帯と folder 行の名前の重複・見た目: 「UIについては改善の余地がありそうですが、今のところは思いつかないのでひとまずOK」。
  今は直さない。
- 開発者から出た案: 「＋ 追加」一つで足すことも外すこともできるなら、一覧の**除去のための選択モード**(002 REQ-018)は
  要らないのではないか(出し入れする場所と、改名される一覧を見る場所を分けられる)。この task の範囲外の仕様変更なので、
  ここでは記録だけにする。

## Current state / handoff

- Last checkpoint: 実機確認 OK(2026-10-04、`29d77d3` の build)。review 連鎖 `ca12916..da379ef` PASS、以後は記録だけ
- Status: done
- Next Agent action: なし(PR #214 を ready にして merge する)
