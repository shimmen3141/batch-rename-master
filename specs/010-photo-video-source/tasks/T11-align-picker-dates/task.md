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
- [ ] `DATE_TAKEN` が無く中身に日時を持つ item は、中身の日時の見出しに、その順で並ぶ(代表例 67)。中身にも日時が無ければ `DATE_ADDED`(代表例 68)。`DATE_TAKEN` がある item は従来どおり。
  - 証拠: unit / widget test(port を差し替える)、端末の manual(ダウンロードした古い写真)。
- [ ] 種類とアルバムの絞り込み、選択の保持、範囲 drag・全選択・解除・確定は従来どおり動く。
- [ ] 題名の横の ⓘ でダイアログが開き、開発者の文言を示す。閉じても選択と絞り込みは変わらない(代表例 69)。
- [ ] 独立review が PASS。

## machine検証範囲と引き受け先

- machine: 日付の決め方(`DATE_TAKEN` → 中身 → `DATE_ADDED`)と並び順、中身を読むのが `DATE_TAKEN` の無い item だけであること、ダイアログの文言と選択が変わらないこと。
- 端末(この task の manual): Kotlin の照会、実際の写真で並ぶ見出し、開く速さ、ダイアログの見た目。

## 作業記録

- 2026-10-05 開発者の決定(案1・A・A・A)を受けて足した。branch `asdd/010-photo-video-source/T11-align-picker-dates`(base `537c8d2`)。004 の spec 差分を書いた(承認待ち)。
- ダイアログの見た目(仕様では自由): 既存のダイアログと同じ地と角丸、題の左に ⓘ、2つの場合をそれぞれ一段明るい角丸の枠に入れ、左端に細い色の帯と小さなアイコン(ファイル・端末)、例は枠の中で小さく薄い色の箇条書き、下に「閉じる」。

## Current state / handoff

- Last checkpoint: spec 差分の承認(2026-10-05)
- Blocker category: なし
- Evidence revision: なし
- Next Agent action: 実装(全件の一覧を受け取り、`DATE_TAKEN` が無い item だけ中身を読んで app の側で並べる。ⓘ とダイアログ)
