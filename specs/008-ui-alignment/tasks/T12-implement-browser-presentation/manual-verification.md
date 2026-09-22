# 手動確認: app内file browserの提示

**この手順書は`T12`の実装後に completed させる。** 現時点では観測する対象と、
使い回す手順だけを置く。

## 使う端末と準備

**`013:T07`の手順書をそのまま使う** —
[`specs/013-safe-android-rename/tasks/T07-implement-android-file-browser/manual-verification.md`](../../../013-safe-android-rename/tasks/T07-implement-android-file-browser/manual-verification.md)
の次の2つを先に実行する。**ここへ書き写さない**(書き写すと、片方を直したときにもう
片方が古くなる)。

- `## 0. いま動いているのが、このタスクのビルドか確かめる`
- `## 準備するファイル`(PowerShellでfixtureを置く)

## 観測する対象(実装後に手順へ具体化する)

- **U1**: 「すべて」を押したときに最初に出る画面。**保存場所が1つの端末で一覧を挟まず、その保存場所の
  rootの中身が出ること**(004 REQ-015)。**保存場所が2つ以上ある端末では一覧から始まり、browserを
  閉じずに別の保存場所へ切り替えられること**(同)。1件の端末で選び直しの導線を出すかは自由なので、
  **出ていないことを不具合としない**。
- **U2**: **近道(★)が出ないこと。** Download・DCIM・Pictures・Documents・Movies・Musicが
  **一覧の中に1回だけ**並び、同じfolderが二重に出ないこと(2026-09-22に`T11`が近道を取りやめた。
  004 REQ-015)。
- **U3**: 上へ戻るアイコンの向き。

## 報告

結果は会話で自由に書いてよい。決まった書式は不要である。
