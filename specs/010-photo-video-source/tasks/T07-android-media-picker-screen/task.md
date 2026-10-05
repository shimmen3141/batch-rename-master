# T07 Android の「写真・動画」の選択画面を作る

## 目的

Android の種類の選択を「写真・動画」「すべて」にし、「写真・動画」で選択画面を開いて、選んだ写真・動画を読み込めるようにする。
日のまとめ選択は `T08`、読み込み元と開き直しは `T09`。

## 入力と依存

- 004 REQ-011(Android の種類)・REQ-012(選択画面からは警告しない)・REQ-022・REQ-023(見出しのまとめ選択は除く)。代表例 27・54〜57・60・65。
- `T06` の一覧の port。読み込んだファイルの `FileEntry` は app 内 browser と同じ作り方(作成日時 ①②③、所属 folder、場所)。
- **画面の形の想定**(spec では自由。2026-10-05 に開発者へ示した案): 上部に戻る・題名・⋮(全選択・すべて解除)、その下に「すべてのアルバム ▾」(押すと下からアルバムの一覧)と
  「すべて|写真|動画」の切り替え、日付の見出しの下にサムネイルの格子、下部に選択件数と確定。今の app 内 browser の上下の形に揃える。開発者が別の形を選んだら従う。

## 変更範囲

- `lib/ui/file_source/`(種類・選択画面)、`lib/data/file_source/`(読み込み)、`test/`、この task の `manual-verification.md`。

## 受け入れ条件

- [ ] Android の種類が「写真・動画」「すべて」の2つになる(代表例 27)。
- [ ] 選択画面が全件で開き、見出しの下に格子で並び、種類とアルバムで絞れ、絞り込みを変えても選択が保たれる(代表例 54・55)。
- [ ] 押す・長押しの範囲 drag・全選択・すべて解除が REQ-023 のとおり動き、見えていない選択も確定に含まれる(代表例 56・57・60)。
- [ ] 確定で一覧が置き換わり、複数フォルダの警告は出ない(代表例 56)。
- [ ] adb で置いたファイルは選択画面に並ばず、「すべて」の browser では並ぶ(代表例 65。MediaStore だけを照会するので追加の判定は作らない)。
  - 証拠: widget test、端末の manual(カメラ・スクリーンショット・ダウンロードで fixture を作る。adb で置かない)。改名後も新しい名前で並ぶことを manual で見る。
- [ ] 独立review が PASS。

## machine検証範囲と引き受け先

- machine: 選択の規則(押す・範囲・全選択・解除・絞り込みをまたぐ保持)、種類の一覧、確定の結果、警告を出さないこと。
- 端末(この task の manual): 実際の写真・動画が並ぶこと、サムネイル、スクロールと drag の操作感、改名後に新しい名前で並ぶこと。

## 作業記録

- 2026-10-05 `T05` が spec(004 REQ-011・012・016・021〜024)の承認を受けて足した。
- 端末の manual が要る。`manual-verification.md` は実装のときに書き、`task.json` の `manualVerification` に入れる。
- 2026-10-05 着手(branch `asdd/010-photo-video-source/T07-android-media-picker-screen`、base `4f1d75c`)。開発者の指示「いったんあなたの案で進めてください」により、画面の形は上の想定で作った。実装 `f9f9790`、test の補強 `b4a5732`・`b6cde20`。

### 作ったもの

- 種類: [/workspace/lib/ui/file_source/file_kind.dart](/workspace/lib/ui/file_source/file_kind.dart) を「写真・動画」「文書」「すべて」にした(Android は文書を除く2つ)。
  - **desktop の「写真・動画」は `T10` まで「（未実装）」として示し、押すと案内を出す**(読み込みはしない)。選択画面を持つかは source の型(`MediaPickSource`)で決め、帯は platform を見ない。
- 読み込み: `MediaPickSource`([/workspace/lib/data/file_source/file_source.dart](/workspace/lib/data/file_source/file_source.dart))と `AndroidFileSource.pickMedia`。所属 folder はファイルごとの親 folder、作成日時の補い方は browser と同じ、消えたファイルは落とす。帯は選択画面からの読み込みで**複数フォルダの警告を出さない**(REQ-012)。
- 選択画面: [/workspace/lib/ui/file_source/media_picker_view.dart](/workspace/lib/ui/file_source/media_picker_view.dart)
  - header: 選択中だけ `×`(見えていない選択も含めて全解除)・題名(「写真・動画」/「N件選択中」)・⋮(すべて選択・選択をすべて解除)。その下に「すべてのアルバム ▾」(下から一覧)と「すべて|写真|動画」。日付の見出しの下にサムネイルの格子(動画は再生時間)。footer に「← リネーム画面へ」と「確定」(1件以上で押せる)。**app 内 browser の形に揃えた。**
  - 少しずつ読む(1回 120件、末尾に近づいたら続き)。「すべて選択」は**今の絞り込みの残りを読み切ってから**足し、読み切れなければ足さない。
  - 一覧・アルバムを取れなかったときは「無い」と別に理由を示し、一覧は読み直せる。
  - サムネイルは同時に6件までに絞って頼み、画面の間は覚えておく。
- 範囲 drag: [/workspace/lib/ui/common/drag_selection_controller.dart](/workspace/lib/ui/common/drag_selection_controller.dart) に `displayOrder` を足し、渡すと**表示順で開始から指の下までの範囲**を選ぶ(格子では指が通った item だけでは REQ-023 にならない)。渡さない1列の一覧(002・browser)は従来どおり。
- 場所の名前: `displayPathOf` を [/workspace/lib/data/file_source/storage_browser.dart](/workspace/lib/data/file_source/storage_browser.dart) へ移し、composition root が選択画面の確定後に親 folder ごとに「保存場所名 + root からの相対」を覚える(REQ-009)。
- **`docs/design/Bulk Renamer.html` にはこの画面が無い。** 土台は app 内 browser(`008:T38` の形)で、そこから離れた点は無い。

### この task の後に残る中間の状態(`T08`・`T09` が変える)

- 日付の見出しは押せない(`T08`)。
- 選択画面から読み込んだ後、帯は folder 名か「複数のフォルダ」を示し、一覧の開き直しの入口は REQ-021 の browser のものが出る(`T09` が「写真・動画」と選択画面の開き直しにする)。

### 検証(実装 `f9f9790`、test `b6cde20`)

- `flutter test`: PASS(+1322、`f9f9790` 時点。以後は test の補強だけ)。related: `media_picker_view_test`(+17)・`ui_entry_test`・`android_file_source_test`・`storage_browser_view_test`・`platform_source_test` PASS。`flutter analyze`: No issues。`dart format`: PASS。`check_normative_terms.py`: PASS。`check_mutation_finds.py`: PASS(687)。
- mutation: 足した M728〜M743 と、`find` を追随させた M104・M119・M120 を回した。範囲を `flutter test test/spec_004_file_source/media_picker_view_test.dart test/spec_004_file_source/ui_entry_test.dart test/spec_004_file_source/android_file_source_test.dart test/spec_004_file_source/storage_browser_view_test.dart` に絞った18件:

```text
M104 | SURVIVED | platform_file_source.dart | AndroidでもOSピッカーを使う …
M119 | KILLED | storage_browser_view.dart | 表示用の場所を辿ったfolderではなくrootへ紐づける …
M120 | KILLED | storage_browser_view.dart | 表示用の場所を一切知らせない …
M728 | KILLED | file_source_bar.dart | 010:T07 写真・動画の選択画面からの読み込みでも複数フォルダの警告を出す
M729 | KILLED | file_source_bar.dart | 010:T07 「写真・動画」でも browser(pickFiles)を開く
M730 | KILLED | file_source_bar.dart | 010:T07 選択画面を持たない source でも「写真・動画」を対応済みとして見せる
M731 | KILLED | android_file_source.dart | 010:T07 選択画面の所属 folder を最初のファイルの folder に揃える
M732 | KILLED | android_file_source.dart | 010:T07 選択画面を閉じたのを空の確定にする
M733 | KILLED | media_picker_view.dart | 010:T07 絞り込みを変えると選択を捨てる
M734 | KILLED | media_picker_view.dart | 010:T07 すべて選択で読み切れなくても読んだ分だけ選ぶ
M735 | KILLED | media_picker_view.dart | 010:T07 すべて解除で見えている選択だけを外す
M736 | KILLED | media_picker_view.dart | 010:T07 確定で見えている選択だけを返す
M737 | KILLED | media_picker_view.dart | 010:T07 0件でも確定できる
M738 | KILLED | media_picker_view.dart | 010:T07 格子の drag を指が通った item だけにする
M739 | KILLED | media_picker_view.dart | 010:T07 種類の切り替えを絞り込みに渡さない
M740 | KILLED | media_picker_view.dart | 010:T07 今年以外の見出しにも年を出さない
M741 | KILLED | media_picker_view.dart | 010:T07 日ごとに見出しを分けない
M742 | SURVIVED | drag_selection_controller.dart | 010:T07 範囲 drag で戻ると drag 前から選択済みの item も外す
18 mutations: 16 KILLED, 2 SURVIVED, 0 SKIPPED
```

  - M742: **test の穴**。drag で戻る先が drag 前の選択(p3)を範囲の外へ出さない位置だった。戻る先を p2 にして(`b4a5732`)、`media_picker_view_test` で回し直した: `M742 | KILLED`、`1 mutations: 1 KILLED`。
  - M104: 落とす test(`platform_source_test`)が絞った範囲の外にあるだけ。全件(`flutter test --exclude-tags tooling`)で回し直した: `M104 | KILLED`、`1 mutations: 1 KILLED`。
  - M743(Android の source に選択画面を渡さない)を `b6cde20` で足し、`platform_source_test` で: `M743 | KILLED`、`1 mutations: 1 KILLED`。
- **未実施**: Android の build(AI container に Android SDK が無い)。

### machine検証範囲と端末に委ねたもの

- machine(上の test): 種類の一覧、選択画面の並び(見出しの下の item・再生時間)、絞り込みと選択の保持、押す・範囲 drag・全選択・解除・確定・閉じる、空と失敗の区別、少しずつ読む範囲、帯の分岐と警告を出さないこと、Android の source の結果。
- 端末(この task の manual): 実際の写真・動画とアルバムが MediaStore から並ぶこと(`T06` の Kotlin の照会・並び順の式・`LIMIT`/`OFFSET`・`loadThumbnail` を含む)、サムネイル、スクロールと drag の操作感、改名後に新しい名前で並ぶこと、adb で置いたファイルが並ばないこと、release build の lint(`T06` の S-1)。

### 独立review

- attempt 1: range `4f1d75c..b753a23`(全範囲)。model: Sonnet(Agent tool の code-reviewer)。実装は Opus で、既定の「一段軽いもの」と開発者の指定(2026-10-02)のどちらとも一致する。**判定 PASS。**
  - 確認できた点: 種類の統合と旧参照の残りが無いこと、帯の分岐(選択画面のときだけ警告を抑え、他の経路は従来どおり)、`DragSelectionController` の既存の利用者(002 の一覧・browser)は `displayOrder` を渡しておらず、1列の方式のロジックは変わっていないこと、`pickMedia` と composition root の結線(場所の名前を覚えてから読み込む順序)、選択の保持・全選択・解除・確定・`_generation` の扱い。reviewer 自身が M104・M119・M120・M728〜M743 の19件を回し直して全件 KILLED、`flutter analyze` も確認した。
  - S-1(P3): 位置の key が絞り込みを変えても捨てられず溜まる。**直した**(`25a19bf`: `DragSelectionController.forgetRows` を足し、絞り込みを変えたら呼ぶ)。
  - S-2(P3): サムネイルを上限なく覚える。**直した**(`25a19bf`: `MediaThumbnailCache` が最近使った 400 件までを覚える)。
  - S-3(P3): 範囲 drag の `indexOf` が指を動かすたびに全件を探す。**直さない。** 数千件でも1回の探索は軽く、操作感は manual の手順5で見る。遅ければこの task で直す。
  - `25a19bf` の検証: `media_picker_view_test` PASS(+19)、`flutter test` PASS(+1325)、`flutter analyze` No issues、`check_mutation_finds.py` PASS(690)。mutation M744〜M746 を足し、範囲 `flutter test test/spec_004_file_source/media_picker_view_test.dart` で回した:

```text
M744 | KILLED | media_picker_view.dart | 010:T07 サムネイルを上限なく覚える
M745 | KILLED | media_picker_view.dart | 010:T07 使い直したサムネイルを新しい側へ移さない
M746 | KILLED | drag_selection_controller.dart | 010:T07 位置の key を捨てない
3 mutations: 3 KILLED, 0 SURVIVED, 0 SKIPPED
```

  - 残余risk: 絞り込みの切り替えで `forgetRows` を**呼ぶこと**は test が見ていない(呼び出しを消しても落ちない)。外れても起きるのはメモリの増加だけで、データ損失・偽の成功などには当たらないので受容する。
- attempt 2(差分): range `b753a23..d4684da`。model: Sonnet。**判定 PASS、指摘なし。** S-1・S-2 が閉じたこと(`forgetRows` は drag を終えた後・再描画の前に呼ばれ、既存の利用者は呼ばない。LRU は同じ Future を末尾へ移すので取り直しは起きない)、追加の test が本物であること、残余risk の受容の根拠を確かめた。reviewer 自身が `flutter test`(+1325)・`flutter analyze`・`dart format`・`check_mutation_finds.py`(690)・M744〜M746(3 KILLED)を回した。
- attempt 3(差分): range `d4684da..325d514`(実機確認で見つかった警告の不具合の修正)。model: Sonnet。**判定 PASS、指摘なし。** REQ-008・REQ-012 への適合、listener の付け外しの対称、`close()` を呼ぶ条件(表示中 = 先頭だけが build されるので `assert` を踏まない)、追加 test の実効を確かめた。reviewer 自身が `flutter test`(+1330)・`flutter analyze`・`dart format`・M728・M747〜M749(4 KILLED)を回した。

### 実機確認

- 対象: `lib/`・`android/` が `25a19bf` と同一の build(branch HEAD `d4684da` 以降の記録だけの commit を含んでよい)。手順は [/workspace/specs/010-photo-video-source/tasks/T07-android-media-picker-screen/manual-verification.md](/workspace/specs/010-photo-video-source/tasks/T07-android-media-picker-screen/manual-verification.md)。
- attempt 1(2026-10-05、build は `25a19bf` と同じ `lib/`・`android/`): 途中の報告。
  - 手順2: **Chrome でダウンロードした Canon_40D.jpg は「2008年5月30日」ではなく今日の見出しに入った。** 見立て: EXIF の撮影日時に時差が無く、ファイルの更新日時(今日)と大きく離れるため、MediaStore が `DATE_TAKEN` を入れず、`DATE_ADDED`(今日)で並んだ。仕様(004 REQ-022: `DATE_TAKEN`、無ければ `DATE_ADDED`)どおりで、**手順書の期待値の誤り**と見ている。`datetaken` の確認と、扱い(A: 受け入れて期待値を直す・B: 中身を読む・C: 日付不明にまとめる)の判断を開発者に依頼中。
  - 手順外で見つかった不具合: **一覧が複数フォルダのとき、「別フォルダへ」から何も選ばずに戻ると複数フォルダの警告が出て、単一フォルダで選び直しても消えない。** `T07` より前からの不具合(004 REQ-008 / REQ-012)。`6a760fd` で直した([/workspace/development-findings/2026-10-05-multi-folder-warning-on-cancel-and-stale-after-reload.md](/workspace/development-findings/2026-10-05-multi-folder-warning-on-cancel-and-stale-after-reload.md))。
    - 検証: `ui_entry_test` PASS(+26。追加5件)、`flutter test` PASS(+1330、exit 0)、`flutter analyze` No issues、`check_mutation_finds.py` PASS(693)。mutation(範囲 `flutter test test/spec_004_file_source/ui_entry_test.dart`): `M747 | KILLED`・`M748 | KILLED`・`M749 | KILLED`(`3 mutations: 3 KILLED`)。条件が変わった M728 の `find` を追随させ `M728 | KILLED`。
    - 残余risk: 警告が表示待ち(別の残る通知の後ろ)のときは閉じない。そのとき古い警告が後から出うる。データ損失などには当たらず、受容する。
    - **code が変わったので、この後の実機確認は新しい build で行う**(手順1〜8をやり直す)。

## Current state / handoff

- Last checkpoint: evidence。独立review attempt 1 PASS(`4f1d75c..b753a23`)、差分review attempt 2 PASS(`b753a23..d4684da`)
- Blocker category: manual-evidence
- Evidence revision: `6a760fd`
- Waiting for: 開発者(Android エミュレータでの実機確認。`T06` の Kotlin の最初の build を兼ねる)
- Requested action: [manual-verification.md](manual-verification.md) の準備と手順1〜8を行い、結果を会話で伝える
- Next Agent action: 結果を「実機確認」へ記録する。PASS なら PR を作り merge 条件を確かめる。違いがあれば原因を調べて直す
