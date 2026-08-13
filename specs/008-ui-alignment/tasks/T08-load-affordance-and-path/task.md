# T08 読み込み導線と場所の提示を整える

## 目的

「どこから読み込むか」「いま何がどこから入っているか」が画面から読み取れるようにする。参考designの(c)にあたる。

## 入力と依存

- `specs/history/asdd-0.x-discovery.md`の(c)「読み込み導線・パス表示の作り込み(「フォルダを選択 / 別フォルダへ」)」。
- 参考design `docs/design/Bulk Renamer.html`の読み込み帯。
- 現行実装: `lib/ui/file_source/file_source_bar.dart`。種類chip(`file-kind-*`)と`ファイルを選ぶ`(`pick-files-button`)、複数folder警告(`multi-folder-warning`)を持つ。
- 004 spec(読み込み契約)と決定D-2。**契約は変えない。**
- `development-findings/2026-08-12-documentsui-type-chip-crosses-folders.md`。

## 変更範囲

- 読み込みbuttonの文言と、読み込み済みのときの再読み込み導線。
- 場所(元folder)の提示。行のサブ情報(T07)と重複させず、どちらが何を担うかを決める。
- 複数folder警告の出し方。**通常経路で起きる**ことが分かったので、例外的な警告として出し続けるかを含めて見直す。

### 先に解く設計上の食い違い

参考designは「フォルダを選択 / 別フォルダへ」という**folder単位のmodel**を前提にしている。しかし004は決定D-2で**file複数選択**を採っており、さらにAndroidのDocumentsUIは種類chipがfolderを横断する(上記finding)。**現実には「選択中のfolder」が存在しない状態が通常**である。

したがってdesignの文言をそのまま写さない。folderを選んだかのように見せる導線は、実際の挙動と食い違う。**004の契約に正直な提示**を設計し、`task.md`へ根拠を書く。

## 受け入れ証拠

- 読み込み前・読み込み後・複数folderが混ざった状態のそれぞれで、導線と場所の提示が意図どおりであることをwidget testで検査する。
- 004の既存testが継続PASSする(読み込み契約を変えていない)。
- `flutter test` / `flutter analyze` / `dart format --output=none --set-exit-if-changed .` がPASS。
- [`manual-verification.md`](manual-verification.md)でAndroid実機とWindows desktopの導線を確認する。
- exact rangeの独立reviewがPASSする。

## 作業記録

- 2026-08-13 / 人間の判断で(a)〜(d)を008の対象へ入れた際に定義。

## Current state / handoff

- Last checkpoint: 定義しただけ。未着手
- Blocker category: なし
- Waiting for: なし
- Requested action: なし
- Evidence revision: `dev@ea1dd04`
- Next Agent action: 他taskと独立に着手できる。先に「選択中のfolderが無い状態が通常」を前提にした提示を決める
