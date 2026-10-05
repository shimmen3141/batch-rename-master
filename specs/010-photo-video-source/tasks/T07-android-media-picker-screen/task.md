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

## Current state / handoff

- Last checkpoint: verification(実装 `f9f9790`、test `b6cde20`)。machine の検証と mutation が PASS
- Blocker category: なし
- Evidence revision: `f9f9790`(`lib/`・`android/` はこれ以後変わっていない)
- Next Agent action: 独立review(base `4f1d75c`..head)を起動する。PASS なら manual を依頼する
