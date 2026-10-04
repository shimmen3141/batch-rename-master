# T02 ファイルの中身から撮影日時を読む

## 目的

写真の EXIF と動画に記録された撮影日時を読み、読み込んだ `FileEntry` の作成日時に入れる(Android の app 内 browser と desktop の両方)。
読めないファイルは「不明」のまま。

## 入力と依存

- T01 で承認された 004(と 001・002)の差分。形式・時刻帯・順位はそこが正本。
- 既存の読み込み: `lib/data/file_source/android_file_source.dart`・`desktop_file_source.dart`(今は作成日時を常に `null` で返す)。

## 変更範囲

- 中身を読む部品(新設。package を足すか自前で読むかは実装で決め、task.md へ理由を書く)。
- 上の2つの読み込みの経路。
- 触れない: 001 の判定、改名の実行。

## 受け入れ条件

- [ ] T01 の代表例のうち中身の経路のものが、fixture のファイルを使う test で成り立つ。
  - 証拠: `flutter test` の該当 test、mutation(`tool/mutations.json`)。
- [ ] 読めない・壊れたファイルで読み込み全体が失敗しない(そのファイルが「不明」になるだけ)。
  - 証拠: 壊れた fixture の test。

## 作業記録

## Current state / handoff

- Last checkpoint: 未着手
- Blocker category: none
- Evidence revision: none
- Next Agent action: T01 の承認を待ち、承認された形式の fixture を用意する
