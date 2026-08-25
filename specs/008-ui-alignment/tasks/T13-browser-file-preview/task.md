# T13 browserのファイル行にpreviewを出す

## 目的

`013:T07`の実機確認で開発者が挙げた**U4**を実装する。app内file browserの選択画面で、
**画像やテキストの中身が行から分かる**ようにする。

## 入力と依存

- **観測の出所**: [`013:T07`のtask.md](../../../013-safe-android-rename/tasks/T07-implement-android-file-browser/task.md)
  「受領したUIの改善点」の U4。原文は「ファイルにチェックボックスがあるが、画像や
  テキストのプレビューが表示されるようにしたい」。
- `T12`(同じ画面の行を作り直すため、**後に着手する**)。
- 004 spec REQ-017(絞り込まない)。**previewは絞り込みではない**ので要求とは両立するが、
  「previewを出せなかったfile」を隠したり並べ替えたりしないこと。
- `013 ADR-002` の権限境界。**MediaStoreは使わない**(010 写真・動画sourceの領域であり、
  権限モデルが別)。

## 先に決めること(調査)

**実装方針が決まっていない。着手したらまずここを埋める。**

- **画像**: `dart:io`で読んだbytesから thumbnail を作れるか。**folderに数百件あるときの
  メモリと速度**をどうするか(遅延読み込み、上限、cache)。
- **テキスト**: 先頭何byteを読むか。**binaryを誤ってtextとして出さない**判定をどうするか
  (拡張子で決めるなら、004の「判定を新設しない」方針との関係を書くこと)。
- **読めなかったとき**: previewが無い行と、**読めなかった行**を区別するか
  (`013:T07`が`listNames`で作った「空」と「失敗」の区別と同じ型の論点である)。
- **仕様変更が要るか。** 現在の004 specは行の見せ方を自由としているので、**要求を増やさず
  実装の裁量で収まる見込み**である。収まらないと判断したら`T11`と同じ形で仕様更新taskを
  分ける。

## 変更範囲

- `lib/ui/file_source/storage_browser_view.dart` の file 行。
- 必要なら preview を作る port(**実fileを触る側をUIから分ける** — `013:T07`が
  `StorageBrowserPort`で採った形に合わせる。testが実機に依存しなくなる)。

## 受け入れ証拠

- previewの有無・失敗・大きなfolderでの挙動を widget test / unit test で検査する。
- **`013:T07`が入れた既存testが継続PASSする**(絞り込まないこと、選択が同一folderに
  限られること)。
- `flutter test` / `flutter analyze` / `dart format --output=none --set-exit-if-changed .` がPASS。
- [`manual-verification.md`](manual-verification.md)で実機の見え方と**速度**を確認する。
  **件数の多いfolder**(DCIM等)を対象に含める。
- exact rangeの独立reviewがPASSする。

## 作業記録

- 2026-08-25 / `013:T07`の実機確認(U4)を受けて定義。開発者が「U1〜U5をすべてtask化する」
  と決定した。

## Current state / handoff

- Last checkpoint: 定義しただけ。未着手
- Blocker category: なし
- Waiting for: `T12`(同じ行を作り直すため)
- Requested action: なし
- Evidence revision: `dev@ae59859`
- Next Agent action: `T12`の後に着手する。**先に上の「先に決めること」を埋め、方針を
  `task.md`へ書いてから実装する**(規模が読めていない)
