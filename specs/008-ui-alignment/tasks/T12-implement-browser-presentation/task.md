# T12 app内file browserの提示を実装する

## 目的

`T11`で承認された004 specの変更を実装し、あわせて**U3(上へ戻る矢印の向き)**を直す。

## 入力と依存

- **`T11`で承認された004 spec**(入口 U1・近道 U2)。**2026-09-22に開発者が再承認した** — `specs/004-file-source/spec.md`の「008:T11 由来の更新」節が正本。要点は次の3つ。
  1. **保存場所が1つだけなら一覧を挟まず、その保存場所のrootから始まる**(REQ-015、must)。複数なら一覧から始まる。
  2. **複数あるときは、browserを閉じずに別の保存場所へ切り替えられる**(REQ-015、must)。**1つだけのときにその導線を出すかは自由**(自由節)。一覧を開き直したときに列挙し直すかも自由。
  3. **近道は取りやめる**(REQ-015からmustを外した)。**見分けを直すのではなく、近道そのものを出さない。** `knownShortcutNames`・`StorageBrowserPort.shortcuts`・`browser-shortcut-*`が不要になる。
- **観測の出所**: [`013:T07`のtask.md](../../../013-safe-android-rename/tasks/T07-implement-android-file-browser/task.md)
  「受領したUIの改善点」の U1・U2・U3。
- 現行実装: `lib/ui/file_source/storage_browser_view.dart`、
  `lib/data/file_source/storage_browser.dart`、`lib/data/file_source/android_storage_browser.dart`。
- `013:T07`の`task.md`の宣言表(**何をこの環境で機械検証し、何を`013:T08`が引き受けるか**)。
  同じ境界がこのtaskにも当てはまる。

## 変更範囲

- `storage_browser_view.dart` の**近道の撤去**とfolder・fileの提示、保存場所の入口(1件なら一覧を挟まない)と切り替え導線。
- `storage_browser.dart` / `android_storage_browser.dart` の `shortcuts` と `knownShortcutNames` の撤去。**portから操作を1つ減らすので、fakeとtestも合わせる。**
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

- `T11`が承認した要求を widget test で検査する。**最低でも次の3つ**: 保存場所1件でrootから始まること、複数件で一覧から始まり閉じずに切り替えられること、**既知の名前のfolderが1回しか並ばないこと**(近道の撤去)。
- **`013:T07`が入れた既存testが継続PASSする** — `test/spec_004_file_source/`(browserの階層・
  選択・注記・保存場所の列挙)。**要求が変わった分だけを変え、残りを弱めない。**
- **`tool/mutations.json` の `M105` / `M109` / `M117` を新しい要求へ合わせる。** `M109`(近道を保存場所の始まり以外でも出す)は**対象が消える**ので、**近道の撤去そのものを守るmutation**(例: 既知の名前のfolderを二重に並べる)へ置き換える。`M105`/`M117`が守るrootの上限は**要求が変わっていない**ので弱めない。
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

- 2026-08-25 / `013:T07`のAndroidエミュレータ確認(U1・U2・U3)を受けて定義。
- 2026-09-22 / `T11`が004 specの変更の再承認を得た。**依存は外れた。** `covers`へ`004:REQ-015`・`004:REQ-020`を記入した。

## Current state / handoff

- Last checkpoint: 未着手。**`T11`が2026-09-22に承認されたので着手できる。**
- Blocker category: なし
- Waiting for: なし
- Requested action: なし
- Evidence revision: `dev@180ab77`（T37のdrag/全選択実装を含む）。004 specの変更は`T11`のbranchにある。
- Next Agent action: 保存場所入口(1件ならroot・複数なら一覧と切り替え)・**近道の撤去**・U3の戻る矢印・U6の空folderを一つの確認単位で実装する。**U3だけを先に出さない。** T37のdrag/全選択を維持し、選択解除・画面を閉じる導線はT39へ渡す。
