# T09 「写真・動画」から読み込んだ一覧の読み込み元を示し、選択済みで開き直す

## 目的

一覧が読み込み元を持ち、「写真・動画」から読み込んだ一覧では帯に「写真・動画」を示し、選択画面を一覧の状態で開き直せるようにする(`008:T24` の申し送り)。

## 入力と依存

- 004 REQ-021(読み込み元が browser のときだけ)・REQ-024、002 REQ-021(`reselectFiles` の並び)・REQ-018(選択モード中は出さない)。代表例 61〜64・66。
- `T07` の選択画面(選択の初期値を受け取れるようにする)。

## 変更範囲

- `lib/ui/file_source/`(帯・入口)、`lib/ui/file_list/`(必要なら)、`lib/data/file_source/`、`test/`。

## 受け入れ条件

- [ ] 「写真・動画」から読み込んだ一覧では、帯が「写真・動画」を示し、REQ-021 の browser の入口は出ない(代表例 64)。
- [ ] 一覧から選択画面を、一覧にあるファイルを選択済みにして、全件・絞り込み無しで開き直せる。確定は置き換えで、並びは 002 REQ-021(代表例 61・62)。
- [ ] 改名した後に開き直すと、改名後のファイルが選択済みで始まる(代表例 63)。
- [ ] 「すべて」で読み込み直すと、帯と入口が browser の規則に戻る(代表例 66)。
  - 証拠: widget test、端末の manual。
- [ ] 独立review が PASS。

## machine検証範囲と引き受け先

- machine: 読み込み元の持ち方と切り替わり、帯の文言、入口の出し分け、初期値の照合。
- 端末(この task の manual): 改名後の照合(MediaStore の新しい path)、実際の開き直し。

## 作業記録

- 2026-10-05 `T05` が spec(004 REQ-011・012・016・021〜024)の承認を受けて足した。
- 端末の manual が要る。`manual-verification.md` は実装のときに書き、`task.json` の `manualVerification` に入れる。

- 2026-10-06 着手(branch `asdd/010-photo-video-source/T09-media-picker-source-and-reopen`、base `3fdf76b`)。

## Current state / handoff

- Last checkpoint: 着手(branch `asdd/010-photo-video-source/T09-media-picker-source-and-reopen`、base `3fdf76b`)
- Blocker category: なし
- Evidence revision: なし
- Next Agent action: 読み込み元の持ち方・帯・入口・選択画面の初期選択を実装し、widget test を足す
