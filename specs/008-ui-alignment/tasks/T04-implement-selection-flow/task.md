# T04 選択と除去の導線を実装する

## 目的

`T03`で承認された仕様どおり、選択と除去を混同しない導線にする。

## 入力と依存

- `T03`で承認された002/004 spec。
- `docs/design/Bulk Renamer.html`。**適用する画面範囲は一覧の行と読み込みbarに限る**。

## 変更範囲

- 行の×の廃止と、除去の新しい導線。
- 「すべて外す」の改名と、必要なら配置。
- 002/004の仕様由来testの更新と追加。

### 行widgetの分担(T07・T09と共有する)

`lib/ui/file_list/file_list_view.dart`の行は、**T04が操作(×の廃止、除去の導線、checkboxとの関係)**、**T07が情報階層と静的layout**、**T09がmode別描画**を持つ。判断が割れたらT07の情報階層を優先する。表は[`T07のtask.md`](../T07-row-and-warning-presentation/task.md)にある。

### `file_source_bar.dart`の分担(T08と共有する)

`すべて外す`(`clear-files-button`)、`ファイルを選ぶ`(`pick-files-button`)、種類chip(`file-kind-*`)、複数folder警告(`multi-folder-warning`)は**すべて`lib/ui/file_source/file_source_bar.dart`の同じbarにある**。T04とT08が同じfileへ入るので、分担を先に固定する。

- **T04が持つのは`clear-files-button`だけ**(文言と、必要なら配置)。
- **barそのものの構成・読み込み導線・場所の提示・複数folder警告はT08が持つ。**
- T04が先に着手した場合、`clear-files-button`以外へ触らない。T08が先に着手した場合、`clear-files-button`の文言は現状のまま残し、T04で改名する。

**どちらが先でも成立する**ようにこの分担を切ってある。依存edgeにしないのは、T04が`T03`の仕様承認待ちで、T08を不必要に止めたくないためである。

### `T03`から渡される入力(2026-08-29)

- **「n/n件を選択」の置き場所。** 開発者は`T07`の実機確認時に「並び順buttonや警告より下へ
  移したい」と述べた。**checkboxを残す形を`T03`が選んだ場合**の配置としてここで扱う。
  checkbox自体を廃止する案も`T03`の論点にあるので、**`T03`の承認前にこの配置を実装しない**。

## 引き受けた: 「すべて外す」の置き場所(`008:T08` から。2026-09-18)

実機確認で開発者が「**すべて外すボタンは後の実装で消えるとは思うが、こちらも『〇/〇件を選択』の帯と
同じ階層に置くべき**」と述べた。`T08` が3通り試したが、件数の帯は 320dp・文字倍率1.3 で余白が無く、
**label付きでも icon だけでも `008:T16` の保証(件数が多くても一覧を覆わない / 狭幅で数字が消えない)が
壊れる**。開発者の判断で**いまは読み込み帯に置いたまま**とし、見直しをこのtaskへ送った。

- このtaskは削除導線(左swipe)と「すべて外す」の**文言**を持つ。**置き場所もここで決める。**
- 置き場所を件数の帯にするなら、**その帯の作りを組み直す**必要がある(警告の件数chipを別行へ固定する等)。
  `008:T16` の保証を壊さないことを widget test で示すこと。
- **無くす**選択肢もある(開発者は「後の実装で消えるとは思う」と述べている)。その場合は
  004 REQ-006(一覧を空にする)への到達経路を別に用意すること。

## 受け入れ証拠

- 新しい除去導線で一覧から消え、checkboxの状態とは独立であることをwidget testで検査する。
- 改名した名前のbuttonが、checkboxの全解除と別の操作であることをtestで検査する。
- 004の読み込み契約(置き換え・cancel・警告)が壊れていないことを既存testの継続PASSで確認する。
- `flutter test` / `flutter analyze` / `dart format --output=none --set-exit-if-changed .` がPASS。
- [`manual-verification.md`](manual-verification.md)で、除去が誤操作になりにくいかを実機で確認する。
- exact rangeの独立reviewがPASSする。

## 作業記録

- 2026-08-12 / plan作成時に定義。

## Current state / handoff

- Last checkpoint: plan作成時に定義しただけ。未着手
- Blocker category: dependency
- Waiting for: `T03`の仕様更新と人間の再承認
- Requested action: なし
- Evidence revision: `dev@ea1dd04`
- Next Agent action: `T03`承認後にclaimし、test-firstで実装する
