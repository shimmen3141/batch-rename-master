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

## Current state / handoff

- Last checkpoint: 未着手
- Blocker category: なし
- Evidence revision: なし
- Next Agent action: 着手時に `in_progress` へ変え、branch を作る
