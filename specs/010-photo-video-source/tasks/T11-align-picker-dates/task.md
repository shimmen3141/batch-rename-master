# T11 「写真・動画」の選択画面の日付を作成日時に揃え、決め方を ⓘ で説明する

## 目的

選択画面の並び順と見出しの日付を、`DATE_TAKEN` が無い item について読み込んだ後の作成日時(004 REQ-010)と同じにする。題名の横の ⓘ で、並び順と日付の決め方を説明する。

`T07` の端末確認で、ダウンロードした古い写真が選択画面では今日の見出しに並び、読み込むと作成日時が中身の撮影日(2008 年)になった。開発者は「直感的でない」とし、作成日時は変えずに選択画面を揃えると決めた(plan.md の「人間の決定」2026-10-05)。

## 入力と依存

- [/workspace/specs/004-file-source/spec.md](/workspace/specs/004-file-source/spec.md) REQ-022(この task で差分を入れる)、REQ-010(作成日時の順位)、「010:T11 由来の更新」(説明の文言)。
- `T06`・`T07`: MediaStore の一覧の port(`media_library.dart`)と選択画面(`media_picker_view.dart`)。今は MediaStore に並べさせて少しずつ受け取っている。
- `T02`: 中身の日時を読む `readContentCreatedAt`(JPEG・HEIC・MP4・MOV)。
- 端末の観測: Chrome でダウンロードした古い写真(EXIF に時差の記録なし)は `datetaken=NULL`(`T07` の実機確認)。

## 進め方

1. 004 の spec 差分(REQ-022、代表例 67〜69、「010:T11 由来の更新」)の承認を得る。
2. 実装: 全件の日付(と並びに要る列)を先に受け取り、`DATE_TAKEN` が無い item だけ中身の日時を読んで、app の側で並べる。ⓘ とダイアログを足す。
3. test・mutation・独立review・端末の manual。

## 変更範囲

- `specs/004-file-source/spec.md`、`android/app/src/main/kotlin/.../MainActivity.kt`(一覧の照会)、`lib/data/file_source/media_library.dart`、`lib/ui/file_source/media_picker_view.dart`、`test/`、この task の `manual-verification.md`。

## 受け入れ条件

- [x] 004 の spec 差分を開発者が承認している(2026-10-05、「承認します。続けてください。」)。
- [x] `DATE_TAKEN` が無く中身に日時を持つ item は、中身の日時の見出しに、その順で並ぶ(代表例 67)。中身にも日時が無ければ `DATE_ADDED`(代表例 68)。`DATE_TAKEN` がある item は従来どおり。
  - 証拠: unit / widget test(port を差し替える)、端末の manual(ダウンロードした古い写真)。
- [x] 種類とアルバムの絞り込み、選択の保持、範囲 drag・全選択・解除・確定は従来どおり動く。
- [x] 題名の横の ⓘ でダイアログが開き、開発者の文言を示す。閉じても選択と絞り込みは変わらない(代表例 69)。
- [x] 独立review が PASS(attempt 1)。

## machine検証範囲と引き受け先

- machine: 日付の決め方(`DATE_TAKEN` → 中身 → `DATE_ADDED`)と並び順、中身を読むのが `DATE_TAKEN` の無い item だけであること、ダイアログの文言と選択が変わらないこと。
- 端末(この task の manual): Kotlin の照会、実際の写真で並ぶ見出し、開く速さ、ダイアログの見た目。

## 作業記録

- 2026-10-05 開発者の決定(案1・A・A・A)を受けて足した。branch `asdd/010-photo-video-source/T11-align-picker-dates`(base `537c8d2`)。004 の spec 差分を書いた(承認待ち)。
- ダイアログの見た目(仕様では自由): 既存のダイアログと同じ地と角丸、題の左に ⓘ、2つの場合をそれぞれ一段明るい角丸の枠に入れ、左端に細い色の帯と小さなアイコン(ファイル・端末)、例は枠の中で小さく薄い色の箇条書き、下に「閉じる」。

### 実装(`6086f77`)

- Kotlin: `media_library` の `page`(絞り込み・`LIMIT`/`OFFSET`)を `list`(写真・動画の全件、`DATE_MODIFIED` を足した)に替えた。並び順の式はアルバムの代表を選ぶのにだけ残した。
- [/workspace/lib/data/file_source/media_library.dart](/workspace/lib/data/file_source/media_library.dart): `MediaLibraryPort.list`、`MediaItem.content`・`modified`・`withContent`、`date` = `DATE_TAKEN` → 中身 → `DATE_ADDED`、`MediaFilter.matches`、`sortedByDate`(新しい順・日時の無いものは最後・同じ日時は id の大きい順)。
- [/workspace/lib/data/file_source/media_content_dates.dart](/workspace/lib/data/file_source/media_content_dates.dart)(新規): `MediaContentDatesPort`、`IsolateMediaContentDates`(別 isolate で `readContentCreatedAt`)、`CachedMediaContentDates`(path と `DATE_MODIFIED` を鍵に、取れなかったことも覚える)、`withDisplayDates`(`DATE_TAKEN` が無い item だけ読む)。
- [/workspace/lib/ui/file_source/media_picker_view.dart](/workspace/lib/ui/file_source/media_picker_view.dart): 全件を受け取り、**並べ終わってから格子を出す**(先に出すと item が別の見出しへ跳ぶ)。絞り込みは app の側(切り替えで取り直さない)。題名の右に ⓘ、`MediaDateHelpDialog`(既存の `DesignDialog`、2つの場合を色の帯とアイコン付きの角丸の枠で)。少しずつ読む処理と「すべて選択」の読み切りは無くなった。
- composition root: `CachedMediaContentDates` を app の寿命で1つ作って渡す。

### 検証(`6086f77`)

- `flutter test`: PASS(+1344、exit 0)。related: `media_picker_view_test`(+22)・`media_library_channel_test`・`media_content_dates_test`(+8、新規)・`platform_channel_names_test`。`flutter analyze`: No issues。`dart format`: PASS。`check_normative_terms.py`: PASS。
- mutation の表: **M717(続きの有無)・M734(すべて選択の読み切り)を外した** — 少しずつ読む作りが無くなり、守る対象が無い。M718〜M721・M724・M733 を今のコードへ追随(M720・M721 は channel へ渡す形から `MediaFilter.matches` の判定へ)。M750〜M757 を足した。`check_mutation_finds.py`: PASS(698)。
- 範囲 `flutter test test/spec_004_file_source/media_picker_view_test.dart test/spec_004_file_source/media_library_channel_test.dart test/spec_004_file_source/media_content_dates_test.dart` で、追随・追加したものと選択画面を守る既存のもの 29件:

```text
M718 | KILLED | 010:T06 一覧の失敗を空の一覧にする **010:T11 で `page`(絞り込みと少しずつ読む)を `list`(全件。絞り込みと
M719 | KILLED | 010:T06 応答なしを空の一覧にする **010:T11 で `page`(絞り込みと少しずつ読む)を `list`(全件。絞り込みと並
M720 | KILLED | 010:T06 種類の絞り込みが効かない(004 REQ-022) **010:T11 で `page`(絞り込みと少しずつ読む)を `li
M721 | KILLED | 010:T06 アルバムの絞り込みが効かない(004 REQ-022) **010:T11 で `page`(絞り込みと少しずつ読む)を `
M722 | KILLED | 010:T06 DATE_ADDED の秒をミリ秒として読む
M723 | KILLED | 010:T06 写真にも再生時間を付ける
M724 | KILLED | 010:T06 並びの日付で DATE_ADDED を優先する **010:T11 で 日付に中身の日時が入ったので追随させた。**
M725 | KILLED | 010:T06 アルバムの失敗を空の一覧にする
M726 | KILLED | 010:T06 名前が無いアルバムに folder の path 全体を見せる
M727 | KILLED | 010:T06 サムネイルの失敗を投げる
M733 | KILLED | 010:T07 絞り込みを変えると選択を捨てる(004 REQ-022) **010:T11 で `page`(絞り込みと少しずつ読む)を 
M735 | KILLED | 010:T07 すべて解除で見えている選択だけを外す(004 REQ-023)
M736 | KILLED | 010:T07 確定で見えている選択だけを返す(004 REQ-023 / 代表例 57)
M737 | KILLED | 010:T07 0件でも確定できる(004 REQ-023 / 代表例 60)
M738 | KILLED | 010:T07 格子の drag を指が通った item だけにする(004 REQ-023 の表示順の範囲)
M739 | KILLED | 010:T07 種類の切り替えを絞り込みに渡さない(004 REQ-022)
M740 | KILLED | 010:T07 今年以外の見出しにも年を出さない
M741 | KILLED | 010:T07 日ごとに見出しを分けない(004 REQ-022)
M744 | KILLED | 010:T07 サムネイルを上限なく覚える(独立review attempt 1 の S-2)
M745 | KILLED | 010:T07 使い直したサムネイルを新しい側へ移さない(古い順に捨てられない)
M746 | KILLED | 010:T07 位置の key を捨てない(独立review attempt 1 の S-1)
M750 | KILLED | 010:T11 DATE_TAKEN がある item の中身も読む(開くのが遅くなる。004 REQ-022)
M751 | KILLED | 010:T11 DATE_TAKEN がある item にも中身の日時を入れる(004 REQ-022)
M752 | KILLED | 010:T11 中身が変わっても(DATE_MODIFIED が変わっても)覚えた日時を使う
M753 | KILLED | 010:T11 取れなかったことを覚えない(開くたびに読み直す)
M754 | KILLED | 010:T11 日時の無い item を先頭に並べる
M755 | KILLED | 010:T11 同じ日時の並びを id の小さい順にする
M756 | KILLED | 010:T11 中身の日時を読まずに並べる(DATE_TAKEN が無い item が DATE_ADDED で並ぶ。004 REQ-022
M757 | SURVIVED | 010:T11 絞り込みを変えても前の絞り込みのまま並べる
29 mutations: 28 KILLED, 1 SURVIVED, 0 SKIPPED
```

  - M757(絞り込みを変えても前の絞り込みのまま並べる)は**等価な mutation**だった。`_changeFilter` は直前の行で `_filter = filter` を代入するので、`_filter.matches` と `filter.matches` は同じ。表から外した(`check_mutation_finds.py` PASS 698)。
- **未実施**: Android の build(AI container に Android SDK が無い)。

### machine検証範囲と端末に委ねたもの

- machine: 日付の決め方と並び順、中身を読むのが `DATE_TAKEN` の無い item だけ、覚え方の鍵、並べ終わるまで格子を出さない、絞り込みと選択、ダイアログの文言と閉じても選択が変わらないこと。
- 端末(この task の manual): Kotlin の `list`、実際の写真で並ぶ見出し(代表例 67)、開く速さ、ダイアログの見た目。

### 独立review

- attempt 1: range `537c8d2..a4e23d7`(全範囲。spec の差分を含む)。model: Sonnet(Agent tool の code-reviewer)。実装は Opus で、既定の「一段軽いもの」と開発者の指定(2026-10-02)のどちらとも一致する。**判定 PASS、指摘なし。**
  - 確認できた点: 実装と承認済みの REQ-022・代表例 67〜69 の一致、ダイアログの文言が仕様と一字一句同じ、isolate へ渡す値が送れる型であること、キャッシュの鍵、`_load` の generation と mounted、並べ終わるまで格子を出さないこと、T07 の対策(位置の key・サムネイルの上限)が残っていること、Kotlin の `page` → `list` に残骸が無いこと、spec・plan・task・mutation の表の記録の整合(M757 が等価であることもコードで確認)。reviewer 自身が `flutter test`(+1344)・`flutter analyze`・`dart format`・`check_mutation_finds.py`(698)・`check_normative_terms.py`・`workspace.py check` と、mutation 28件(28 KILLED)を回した。
- SELF-CHECK: range `a4e23d7..` 以降は `specs/` の記録だけ(review・実機確認の記録、status、PR 番号)。`lib/`・`test/`・`tool/`・`android/`・依存に差分は無く、PASS した判定を書き換えていない。

### 実機確認

- 対象: `lib/`・`android/` が `6086f77` と同一の build。手順は [/workspace/specs/010-photo-video-source/tasks/T11-align-picker-dates/manual-verification.md](/workspace/specs/010-photo-video-source/tasks/T11-align-picker-dates/manual-verification.md)。
- attempt 1(2026-10-05、build は `6086f77` と同じ `lib/`・`android/`): **PASS。** 開発者の報告「確認事項について、問題ありませんでした」。手順1〜5(ダウンロードした古い写真が 2008/5/30 の見出しに並び作成日時も同じ・カメラとスクリーンショットは今日・ⓘ とダイアログ・従来の操作・開く速さ)がすべて期待どおり。
  - 開発者の所感(この task とは無関係): 「別フォルダへ」は画面右上、選択画面・browser の「← リネーム画面へ」は左下にあり、画面を切り替える同じ種類の操作なのに場所が違って一瞬迷う。扱いは会話で相談中(この task の受け入れには影響しない)。

## Current state / handoff

- Last checkpoint: handoff。独立review attempt 1 PASS(`537c8d2..a4e23d7`)、以後は記録だけ(SELF-CHECK)、実機確認 attempt 1 PASS
- Blocker category: なし
- Evidence revision: `6086f77`
- Next Agent action: PR の CI が通れば merge 条件を確かめて merge する
