# 手動確認: browserのファイル行のpreview

**この手順書は`T13`の実装後に completed させる。** 現時点では観測する対象と、
使い回す手順だけを置く。

## 使う端末と準備

**`013:T07`の手順書をそのまま使う** —
[`specs/013-safe-android-rename/tasks/T07-implement-android-file-browser/manual-verification.md`](../../../013-safe-android-rename/tasks/T07-implement-android-file-browser/manual-verification.md)
の `## 0.`(対象buildの見分け)と `## 準備するファイル`(PowerShellでfixtureを置く)を
先に実行する。**ここへ書き写さない。**

**このtaskでは、preview の対象になるfixtureが追加で要る。** 実装後に具体化するが、
少なくとも次を含める。

- **本物の画像**(`013:T07`のfixtureは中身が文字列の`.jpg`なので、previewの確認には
  使えない)。
- 中身のあるテキストfile。
- **binaryだがテキスト拡張子のfile**(誤って中身を出さないこと)。
- **件数の多いfolder**(速度の観測)。

## 観測する対象(実装後に手順へ具体化する)

- 画像・テキストのpreviewが出ること。
- **previewを出せないfileが、隠れたり並び替わったりしない**こと(004 REQ-017)。
- 件数の多いfolderを開いたときの**速度と、スクロールの引っかかり**。
- 端末の発熱・メモリ(可能なら)。

## 報告

結果は会話で自由に書いてよい。決まった書式は不要である。
