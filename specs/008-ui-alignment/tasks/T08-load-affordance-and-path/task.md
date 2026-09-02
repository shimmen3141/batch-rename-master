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
- 場所の**全体側**の提示(いま何がどこから入っているか)。
- 複数folder警告の出し方。**通常経路で起きる**ことが分かったので、例外的な警告として出し続けるかを含めて見直す。

### 2026-09-02に受領した改善要望(11・12)

観測の出所は[`T16`のtask.md](../T16-implement-row-level-warnings/task.md)の
「受領したUIの改善要望(2026-09-02、原文)」。**このtaskが引き受ける。**

- **要望11**: 「各行にファイルの場所を書く必要はないと思った。既に選択できるのは同じフォルダの
  ファイルのみになっているはずなので、ヘッダー付近に選択中のフォルダ名を一度表示すればよいはず
  (参考designもそうなっている)。**『ファイルを選ぶ』は『別フォルダへ』とし**、将来的に同ファイル
  から追加できるボタンが実装されたときに使い分けられるようにする。ファイルが選択されていない
  ときは、『別フォルダへ』の表記を『ファイルを選ぶ』に変更する。」

  参考designは `folderLabel: loaded ? '内部ストレージ / DCIM / Camera' : '未選択'` と
  `pickLabel: loaded ? '別フォルダへ' : 'フォルダを選択'` を持つ。**文言は開発者の指定
  (『別フォルダへ』/『ファイルを選ぶ』)を優先する。**

- **要望12**: 「もし画像や動画でフォルダをまたぐ場合も、ヘッダーには『画像ファイル』
  『動画ファイル』のように具体的なフォルダ名を表示せずに提示すれば良さそう。ただ、この場合は
  各行には属しているフォルダ名1つだけ(ScreenShootやVideoなど)を表示したほうが良いかも。」

  **004 REQ-012(複数folder警告)との関係を確かめること。** Androidでは`013:T03`の
  REQ-016により選択が同一folder内に限られ、この警告は発火しない(下の「Androidの前提が
  変わった」)。**folderをまたぐのがdesktopだけなのか、Androidの種類選択でも起きるのかを
  実装から確認してから決める。**

**行から場所を外すことは`T18`(行の結果表示)と範囲が隣り合う。** `T18`は場所の**縦位置**を
動かすところまでを持ち、**場所を消すか・folder名だけにするかはこのtaskが決める。**
後に着手した側が先の結果に合わせる。

### T07との分担(場所の提示)

行ごとの「場所(元folder)」は**T07が持つ**(行のサブ情報の一部)。T08が持つのは**一覧全体として何がどこから入っているか**の提示である。両方が同じ情報を別の場所へ二重に出さないよう、**後に着手した側が先の結果に合わせる。**

**T07が先の場合**: 行側が確定しているので、T08は重複しない粒度を選ぶ。
**T08が先の場合**: 全体側を先に置き、T07が行側の粒度をそれに合わせる。T07の`task.md`にもこの分担を書いてある。

依存edgeにしないのは、どちらが先でも成立し、かつ両方とも他taskの承認を待たないためである。

### `file_source_bar.dart`の分担(T04と共有する)

**T08がbarの構成・読み込み導線・場所の提示・複数folder警告を持つ。** **種類選択のbottom sheet(`file_source_bar.dart:192`)もT08が持つ** — **導線の一部なのでT08が確定させ、`T14`(modalの文言と見せ方)は文言だけを後から合わせる**(2026-08-25)。`T14`の表にも同じ分担を書いてある。 `clear-files-button`(「すべて外す」)の文言だけはT04が持つ。T08が先に着手した場合、この文言は現状のまま残す。詳細は[`T04のtask.md`](../T04-implement-selection-flow/task.md)。

### Androidの前提が変わった(2026-08-22 / `013:T03`)

**下の「先に解く設計上の食い違い」はdesktopにだけ当てはまる。** `013:T03`が004 specへREQ-016を足し、**Androidのapp内file browserでは選択が同一folder内に限られる**ようになった(folderを移動すると選択が解除される)。したがってAndroidでは:

- **「選択中のfolder」が存在する**(常に1つ)。「無い状態が通常」ではない。
- **複数folder警告(004 REQ-012)は発火しない。** 「通常経路で起きる」もdesktopの話になった。
- 種類は「画像」「動画」「すべて」の3つで、**「文書」が無い**(REQ-011)。

**着手前に[`013:T03`のtask.md](../../../013-safe-android-rename/tasks/T03-define-android-file-browsing/task.md)と004 specのREQ-011・REQ-015〜019を読むこと。** platformで提示を分けるか、両方に成り立つ形にするかを決める必要がある。

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
