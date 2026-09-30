# T02 並び順controlを実装する

## 目的

`T01`で承認された仕様どおり、並び順を現在の状態が見える一つのcontrolにし、連番の有無に関わらず手動並び替えできるようにする。

## 入力と依存

- `T01`で承認された002 spec。
- **REQ-011の警告の配置**(`T01`が決めた。仕様にはしない — 008 plan 2026-08-29「案B」): 並び順の表示の**右の空き**に短く出し、入りきらないとき(狭幅・文字の拡大)は次の行へ回す。今の`_CreatedAtFallbackBanner`(一覧の上の帯)から移す。文言の全文(何件を更新日時で代替したか)は失わない。
- `docs/design/Bulk Renamer.html`の並び順control。**適用する画面範囲は一覧上部の並び順controlに限る**(下部の実行バーは005:T09の成果なので動かさない)。
- 現行実装: `lib/ui/file_list/file_list_view.dart`のsort chip、`lib/ui/file_list/file_list_controller.dart`の`manualOrderMatters`。

## 変更範囲

- 横並びchipを、現在の状態を示すcontrolへ置き換える。
- `manualOrderMatters`によるdrag handleとcustomの出し分けを廃止する。
- 昇順・降順(T01の決定に従う)。
- 002の仕様由来testの更新と追加。

### 引き受けた残余risk(`008:T07`から)

- **N-8a**: 文字サイズを最大にすると、現行の横並びsort chipが画面外へはみ出し、
  **一部を選べなかった**と開発者が報告した(2026-08-29のAndroid emulator確認)。
  **到達不能ではない** — barは`SingleChildScrollView(Axis.horizontal)`なので水平scrollすれば
  届く(`file_list_view.dart`の`_SortBar`)。**欠陥は「はみ出していることに気づけない」ほう**
  である。このtaskがchipをドロップダウンへ置き換える(plan.md 2026-08-05の決定)ので、
  **置き換え後の形で「文字サイズ最大でもすべての並び順へ到達でき、隠れた選択肢があることが
  分かる」ことを検査する**こと。現行のchipを直す作業は要らない。

## 受け入れ証拠

- 連番トークンが無いルールでもdrag handleが出て並び替えられ、並び順の表示が「カスタム」へ変わることをwidget testで検査する。
- 各sort keyの選択と、昇降(採用する場合)が状態へ反映されることをtestで検査する。
- 002 REQ-011/013(作成日時ソート時だけ強調)が壊れていないことを既存testの継続PASSで確認する。
- `flutter test` / `flutter analyze` / `dart format --output=none --set-exit-if-changed .` がPASS。
- [`manual-verification.md`](manual-verification.md)で実機の操作感を確認する。
- exact rangeの独立reviewがPASSする。

## 作業記録

- 2026-08-12 / plan作成時に定義。
- 2026-09-30 / 着手は Claude Opus 5.5。branch `asdd/008-ui-alignment/T02-implement-sort-control`、起点`dev`@`158b2be`。

### 開発者の決定(2026-09-30)

- **昇順・降順の選び方**: 3案(8項目のメニュー / keyのメニュー＋隣の向きボタン / 4行＋行内の向きボタン)を尋ね、**8項目のメニュー**(推奨案)を採った。keyと向きの組8つを1つのメニューへ並べ、どの状態へも1回で行け、選べるものが全部見える。向きは利用者の言葉で示す(名前 A→Z / Z→A、日時 古い順 / 新しい順、サイズ 小さい順 / 大きい順)。表示は「⇅ 並び順: 名前 A→Z」、手で並べると「⇅ 並び順: カスタム」。メニューに「カスタム」は出さない(002 REQ-003)。

## Current state / handoff

- Last checkpoint: 着手し、昇降の選び方を開発者が決めた(2026-09-30)
- Blocker category: なし
- Waiting for: なし
- Next Agent action: test-firstで状態層(初期・読み込み直し・昇降・取り消しの戻し)を実装し、次に並び順controlを置き換える
