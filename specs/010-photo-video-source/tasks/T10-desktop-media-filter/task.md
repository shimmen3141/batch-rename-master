# T10 desktop の「写真・動画」で OS のファイル選択画面を写真・動画に絞り込む

## 目的

desktop の種類を「写真・動画」「文書」「すべて」にし、「写真・動画」で OS のファイル選択画面を写真と動画のファイルに絞り込んで開く。

## 入力と依存

- 004 REQ-011(desktop)。代表例 13・28。絞り込みの手段(MIME 型・拡張子)は自由。
- 今の「文書」と同じ仕組み(`DesktopFileSource.pickFiles(mimeTypes:)`)。Windows の選択画面が MIME 型だけで絞れるかを確かめ、だめなら拡張子を使う。

## 変更範囲

- `lib/ui/file_source/file_kind.dart`、`lib/data/file_source/desktop_file_source.dart`、`test/`。

## 受け入れ条件

- [ ] desktop の種類が「写真・動画」「文書」「すべて」の3つになる(代表例 28)。
- [ ] 「写真・動画」で、写真と動画のファイルに絞った選択画面が開き、選んだファイルを読み込める(代表例 13)。
  - 証拠: unit / widget test。Windows の実際の絞り込みは開発者の確認(host)。
- [ ] 独立review が PASS。

## machine検証範囲と引き受け先

- machine: 種類の一覧、渡す絞り込みの値、読み込みの結線。
- 別 OS(開発者の Windows での確認): 実際の選択画面の絞り込み。

## 作業記録

- 2026-10-05 `T05` が spec(004 REQ-011・012・016・021〜024)の承認を受けて足した。
- 2026-10-06 着手(branch `asdd/010-photo-video-source/T10-desktop-media-filter`、base `5d7d2d8`)。 実装 `c2238e5`。

### 調べたこと

- `file_selector` の Windows 実装(`file_selector_windows` 0.9.3+5 の `_typeGroupsFromXTypeGroups`)は、**拡張子を持たない絞り込みを `ArgumentError` で断る**(MIME 型は使わない)。Linux は MIME 型・拡張子のどちらでも絞れる。
- したがって**今までの「文書」(MIME 型だけを渡す)は、Windows では選択画面が開かず失敗していたはず**である。コードから判断したもので、Windows では観測していない — 開発者の Windows での確認(手順3)で確かめる。

### 作ったもの

- [/workspace/lib/data/file_source/desktop_file_source.dart](/workspace/lib/data/file_source/desktop_file_source.dart): MIME 型ごとの拡張子の表(`extensionsByMimeType`)を持ち、選択画面へ**MIME 型と拡張子を一緒に**渡す(`typeGroupsFor`)。`FileSource` の port(`pickFiles(mimeTypes:)`)は変えない — Windows の制約は desktop の adapter の中で閉じる。
- [/workspace/lib/ui/file_source/file_kind.dart](/workspace/lib/ui/file_source/file_kind.dart): 「写真・動画」の MIME 型を `image/*`・`video/*` にした。説明を `descriptionFor(mediaPicker:)` にし、選択画面を持たない source(desktop)では「写真・動画のファイルから選ぶ」と出す(Android の「撮影日の新しい順に…」は desktop では開かないものを示すため)。
- [/workspace/lib/ui/file_source/file_source_bar.dart](/workspace/lib/ui/file_source/file_source_bar.dart): desktop の「写真・動画」を「（未実装）」として案内する経路を外し、「文書」と同じく絞り込んだ選択画面から読み込む。REQ-012 の複数フォルダの警告は desktop の「写真・動画」でも出る(spec のとおり)。

### 決めた点

- **「文書」にも拡張子を渡す。** REQ-011 は「文書系の MIME に絞り込む」とし、手段は自由である(「自由とする点」)。Windows で絞り込める形にするのは同じ要求を満たすためで、要求は変えていない。
- **M730 を `tool/mutations.json` から外した。** M730 は「選択画面を持たない source(desktop)でも『写真・動画』を対応済みとして見せる」変異で、`T07` が「desktop は `T10` まで未対応として示す」を守るために置いた。`T10` でその振る舞い自体を spec(REQ-011)どおり無くしたので、守る対象が無い。desktop の「写真・動画」の説明は M780・M781 が守る。
- `T09` の独立review の残余 risk(P3-1: 開き直しの入口は `FolderReopenSource` のときだけ出す)を見直した。desktop の source は `MediaPickSource` を持たず、OS の選択画面は選択の初期値を持てない(REQ-021 と同じ理由)ので、desktop に開き直しの入口が無いことは spec どおりである。受容のままでよい。

### 検証(`c2238e5`)

- `flutter test`: PASS(+1377、exit 0)。related: `desktop_media_filter_test`(新規。代表例 13・14・28、Windows が受け付ける形、MIME 型の拡張子の網羅、説明)、`ui_entry_test`(「未実装」の test を desktop の「写真・動画」の読み込みと REQ-012 の警告の2件へ置き換えた)。`test/spec_004_file_source` PASS(+369)。`flutter analyze`: No issues。`dart format`: PASS。`check_mutation_finds.py`: PASS(719)。
- mutation(足した M778〜M782。範囲 `flutter test test/spec_004_file_source`):

```text
command: flutter test test/spec_004_file_source
M778 | KILLED
M779 | KILLED
M780 | KILLED
M781 | KILLED
M782 | KILLED
5 mutations: 5 KILLED, 0 SURVIVED, 0 SKIPPED
```

- **未実施**: Windows の build と実際の選択画面(AI container は Linux)。開発者の Windows での確認が引き受ける(手順は [manual-verification.md](/workspace/specs/010-photo-video-source/tasks/T10-desktop-media-filter/manual-verification.md))。

## Current state / handoff

- Last checkpoint: implementation(`c2238e5`)。自動検証 PASS
- Blocker category: なし
- Evidence revision: `c2238e5`
- Next Agent action: 独立review attempt 1 を依頼する
