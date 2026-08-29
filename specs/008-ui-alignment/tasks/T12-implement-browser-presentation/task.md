# T12 app内file browserの提示を実装する

## 目的

`T11`で承認された004 specの変更を実装し、あわせて**U3(上へ戻る矢印の向き)**を直す。

## 入力と依存

- **`T11`で承認された004 spec**(入口 U1・近道の見分け U2)。**承認前に着手しない。**
- **観測の出所**: [`013:T07`のtask.md](../../../013-safe-android-rename/tasks/T07-implement-android-file-browser/task.md)
  「受領したUIの改善点」の U1・U2・U3。
- 現行実装: `lib/ui/file_source/storage_browser_view.dart`、
  `lib/data/file_source/storage_browser.dart`、`lib/data/file_source/android_storage_browser.dart`。
- `013:T07`の`task.md`の宣言表(**何をこの環境で機械検証し、何を`013:T08`が引き受けるか**)。
  同じ境界がこのtaskにも当てはまる。

## 変更範囲

- `storage_browser_view.dart` の近道・folder・fileの提示と、保存場所の入口。
- **U3**: 上へ戻るアイコンを `Icons.arrow_upward` から `Icons.arrow_back` 相当へ。
  **`browser-up` のkeyとtooltipの意味は変えない**(testが参照している)。
- 必要なら `storage_browser.dart` の純関数(入口の決定)。
- **U6**: **空のfolderを開いたときに何も出ない。** 開発者が2026-08-29の`T07`実機確認で
  挙げた。「読み込み中」「開けなかった」「空」の3つが**同じ見た目(何も無い)**になるので、
  `ファイルはありません。`のような文言を出す。**004の要求は変えない** — REQ-017は
  「直下のentryを絞り込まずに出す」ことだけを課しており、0件のときの提示は自由である。
  `browser-listing-failed`(開けなかった)と**別のkey**にして、両者をtestで区別すること。

**改名の判定・権限・データ保護は動かさない。** 004 REQ-016 / REQ-017 / REQ-018 と、
005・013 のREQはそのままである。

## 受け入れ証拠

- `T11`が承認した要求を widget test で検査する。**「近道だと読み取れる」を何で観測するかは
  `T11`が決めた形に従う。**
- **`013:T07`が入れた既存testが継続PASSする** — `test/spec_004_file_source/`(browserの階層・
  選択・注記・保存場所の列挙)。**要求が変わった分だけを変え、残りを弱めない。**
- **`tool/mutations.json` の `M105` / `M109` / `M117` を新しい要求へ合わせる。**
  `013:T07`がREQ-015の現在の形を固定するために置いたもので、**消さずに更新する**
  (AGENTS.md「独立reviewが足したmutationは実装側へ取り込む。対照として置いたものも
  落とさない」)。`python <asdd-plugin>/scripts/mutation_check.py tool/mutations.json --root .`
  の生出力を報告へ貼る。
- `flutter test` / `flutter analyze` / `dart format --output=none --set-exit-if-changed .` がPASS。
- [`manual-verification.md`](manual-verification.md)でAndroid実機の見え方を確認する。
  **`013:T07`のmanualの手順0(対象buildの見分け)と準備(PowerShell)をそのまま使えるので、
  書き起こさずlinkする。**
- exact rangeの独立reviewがPASSする。

## 作業記録

- 2026-08-25 / `013:T07`の実機確認(U1・U2・U3)を受けて定義。

## Current state / handoff

- Last checkpoint: 定義しただけ。未着手
- Blocker category: なし
- Waiting for: `T11`の承認
- Requested action: なし
- Evidence revision: `dev@ae59859`
- Next Agent action: `T11`が承認されてから着手する。**U3だけを先に出さない** — 同じ画面を
  2回manual確認することになる
