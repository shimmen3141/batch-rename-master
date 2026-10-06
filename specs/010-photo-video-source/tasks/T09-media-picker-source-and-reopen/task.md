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

- 2026-10-06 着手(branch `asdd/010-photo-video-source/T09-media-picker-source-and-reopen`、base `3fdf76b`)。 実装 `40f3ab4`。

### 作ったもの

- [/workspace/lib/ui/file_source/list_origin.dart](/workspace/lib/ui/file_source/list_origin.dart): 読み込み元(`ListOrigin`: browser・写真・動画の選択画面・desktop の OS の選択画面)を一覧とは別の値で持つ(`ListOriginState`)。読み込み帯が一覧を置き換える**直前**に記録し、**一覧が空の間は読み込み元が無い**(`current` が `null`)。
- [/workspace/lib/ui/file_source/file_source_bar.dart](/workspace/lib/ui/file_source/file_source_bar.dart): 読み込み・開き直しのたびに読み込み元を記録する。読み込み元が選択画面なら帯は「写真・動画」(写真のアイコン)。一覧の先頭の行から呼ばれる開き直しを、読み込み元で振り分ける(選択画面なら `_reopenMediaPicker`、そうでなければ今までの `_reopenSameFolder`)。選択画面の開き直しも、権限の確認・`reselectFiles`(002 REQ-021)・`Cancelled`・`Failed` の通知を folder の開き直しと同じにした。
- [/workspace/lib/ui/file_list/file_list_view.dart](/workspace/lib/ui/file_list/file_list_view.dart): 読み込み元が選択画面なら、先頭の行は**所属 folder の数に依らず**「写真・動画」と「＋ 追加」を出す(REQ-021 の folder の入口は出さない)。選択モード中は「＋ 追加」を隠す(行は残す)。`onReopenFolder` を `onReopen` へ改名した(`rule_builder_workspace.dart` も)。
- [/workspace/lib/ui/file_source/media_picker_view.dart](/workspace/lib/ui/file_source/media_picker_view.dart): `initialSelection` で選択済みのまま始める(絞り込みの初期値は全件のまま)。**一覧を読み終えたら、並ばない初期選択を外す**(MediaStore から見えなくなったものが確定に残らない)。**読み終えるまでは確定できない**。
- `MediaPickSource.pickMedia({selected})` と `MediaPicker` の typedef に初期選択を通した(`AndroidFileSource`、`main.dart`)。

### Agent が決めた点(spec の「自由とする点」の範囲)

- **読み込み元は一覧とは別の値で持つ。** 一覧(002 の controller)は読み込み元を知らなくてよく、帯と一覧の先頭の行が読む。
- **除去の取り消し(002 REQ-017)で空の一覧を戻すと、読み込み元も戻る。** REQ-024 は読み込み元を「最後に一覧を置き換えた読み込み」と定め、「空になると無くなる」とする。取り消しは読み込みではないので、最後に置き換えた読み込みは変わらない、と読んだ(空の間は `null`)。取り消して戻した写真・動画の一覧の帯が「複数のフォルダ」になり入口が消えるほうが、利用者には不自然である。
- **読み込み元が無い一覧(デモの初期値)は、今までどおり REQ-021 の規則で入口を出す。** 読み込み元が browser でないと REQ-021 の入口を出さない、を字義どおり当てはめると、デモの一覧で既存の振る舞いが変わる。デモは製品の読み込み経路に載らない。
- 一覧から開き直したときに、読み終えるまで「確定」を押せなくした(読み終える前の選択には並ばないものが残っているため)。

### 検証(`40f3ab4`)

- `flutter test`: PASS(+1368、exit 0)。related: `media_picker_reopen_test` PASS(+15。代表例 56・61〜64・66、選択モード、空になったとき・取り消したとき、空の確定、失敗、権限)、`media_picker_view_test` PASS(+30。うち REQ-024 の4件)、`android_file_source_test`(初期選択の受け渡し1件を追加)。`flutter analyze`: No issues。`dart format`: PASS。`check_mutation_finds.py`: PASS(715)。
- mutation: `find` を追随させた M166・M672〜676・M682・M683・M737 と、足した M765〜M777。範囲 `flutter test test/spec_004_file_source`(22件)で回し、SURVIVED の M166 だけ全件(`flutter test --exclude-tags tooling`)で回し直した。

```text
command: flutter test test/spec_004_file_source
M166 | SURVIVED | lib/ui/rule_builder/rule_builder_workspace.dart
M672 | KILLED | lib/ui/file_source/file_source_bar.dart
M673 | KILLED | lib/ui/file_source/file_source_bar.dart
M674 | KILLED | lib/ui/file_source/file_source_bar.dart
M675 | KILLED | lib/ui/file_list/file_list_view.dart
M676 | KILLED | lib/ui/file_list/file_list_view.dart
M682 | KILLED | lib/ui/rule_builder/rule_builder_workspace.dart
M683 | KILLED | lib/ui/rule_builder/rule_builder_workspace.dart
M737 | KILLED | lib/ui/file_source/media_picker_view.dart
M765 | KILLED | lib/ui/file_source/file_source_bar.dart
M766 | KILLED | lib/ui/file_source/file_source_bar.dart
M767 | KILLED | lib/ui/file_source/file_source_bar.dart
M768 | KILLED | lib/ui/file_source/file_source_bar.dart
M769 | KILLED | lib/ui/file_source/file_source_bar.dart
M770 | KILLED | lib/ui/file_source/file_source_bar.dart
M771 | KILLED | lib/ui/file_source/file_source_bar.dart
M772 | KILLED | lib/ui/file_source/list_origin.dart
M773 | KILLED | lib/ui/file_list/file_list_view.dart
M774 | KILLED | lib/ui/file_source/media_picker_view.dart
M775 | KILLED | lib/ui/file_source/media_picker_view.dart
M776 | KILLED | lib/ui/file_source/media_picker_view.dart
M777 | KILLED | lib/data/file_source/android_file_source.dart
22 mutations: 21 KILLED, 1 SURVIVED, 0 SKIPPED

command: flutter test --exclude-tags tooling
M166 | KILLED | lib/ui/rule_builder/rule_builder_workspace.dart
1 mutations: 1 KILLED, 0 SURVIVED, 0 SKIPPED
```

- **未実施**: Android の build(AI container に Android SDK が無い)。

### 独立review

- Review attempt 1: `3fdf76b..a054e51` — PASS — none(P0/P1 なし)。全範囲。model: Sonnet(Agent tool の code-reviewer)。実装は Opus で、既定の「一段軽いもの」と開発者の指定(2026-10-02)のどちらとも一致する。REQ-024・代表例 56・61〜66 への適合、「Agent が決めた点」と仕様の両立、008:T56 の開き直し・REQ-012 の警告・権限の確認を壊していないことを確かめた。reviewer 自身が `flutter test test/spec_004_file_source`(360件)・`flutter analyze`・`dart format`・full `flutter test`(+1368)を回した。
- reviewer が設計した対照(範囲 `flutter test test/spec_004_file_source`。どちらも SURVIVED。**`tool/mutations.json` には入れない** — 今の製品経路では振る舞いが変わらない等価な変異で、入れると毎回 SURVIVED が出る。`T11` の M757 と同じ扱い):
  - REV-A: `list_origin.dart` の `record()` の `if (_last == origin) return;` を消す — 通知が増えるだけで振る舞いは同じ。
  - REV-B: `main.dart` の入口の条件を `_source is FolderReopenSource || _source is MediaPickSource` へ広げる — `AndroidFileSource` が両方を実装するので今は同じ。
- 指摘(どちらも P3。所有 Agent の扱い):
  - P3-1(安全網の穴): `main.dart` の `onReopen` は `FolderReopenSource` のときだけ渡すので、将来「選択画面だけを持ち browser を持たない」source を足すと REQ-024 の入口が出ない。**直さず残余 risk として受容する。** 今そういう source は無く、desktop の「写真・動画」(`T10`)は OS の選択画面で、選択の初期値を持てないので `MediaPickSource` の開き直しにも当たらない。AGENTS.md の3条件の2(データ損失等)に当たらない。引き受け先: そうした source を足す task(今は無い。`T10` で desktop の扱いを決めるときに見直す)。
  - P3-2(記録): review 中も `task.json` が `in_progress` だった。この記録で実機確認待ちの `blocked` へ進めた。

### 実機確認

- 対象: `lib/`・`android/` が `40f3ab4` と同一の build。手順は [/workspace/specs/010-photo-video-source/tasks/T09-media-picker-source-and-reopen/manual-verification.md](/workspace/specs/010-photo-video-source/tasks/T09-media-picker-source-and-reopen/manual-verification.md)。
- attempt 1: 依頼中(2026-10-06)。

## Current state / handoff

- Last checkpoint: evidence。独立review attempt 1 PASS(`3fdf76b..a054e51`)
- Blocker category: manual-evidence
- Evidence revision: `40f3ab4`
- Waiting for: 開発者(Android エミュレータでの実機確認)
- Requested action: [manual-verification.md](manual-verification.md) の手順1〜7を行い、結果を会話で伝える
- Next Agent action: 結果を「実機確認」へ記録する。PASS なら PR を ready にし merge 条件を確かめる。違いがあれば原因を調べて直す
