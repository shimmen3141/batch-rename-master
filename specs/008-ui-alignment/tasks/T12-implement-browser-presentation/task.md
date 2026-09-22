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
- 2026-09-22 / 実装した(`37bd08e`)。**machine検証の範囲と、引き受け先を先に宣言する** —
  この環境で閉じられるのは**widget test / 純関数 / mutation / analyze / format / full regression**までで、
  **Android実機の見え方とAndroid buildは`manual-verification.md`(このtask)が引き受ける**
  (AI containerにAndroid SDKが無い)。宣言の外側の指摘は安全網の穴として扱う。

## 実装した内容(2026-09-22)

| 変更 | 何が観測できるようになったか |
|---|---|
| `storage_browser.dart` | `shortcuts`と`knownShortcutNames`を**portごと撤去**。代わりに純関数`soleLocation`を追加 — **保存場所がちょうど1つで、かつ列挙の`failure`が無いときだけ**その保存場所を返す |
| `android_storage_browser.dart` | `shortcuts`の実装を撤去 |
| `storage_browser_view.dart` | ①保存場所が1つだけなら**一覧を挟まずrootへ入る** ②**保存場所が2つ以上のときだけ**切り替え導線(`browser-locations`)を出す ③近道の行(`browser-shortcut-*`)と区切り線を撤去 ④上へ戻るアイコンを`arrow_upward`→**`arrow_back`**(U3。keyとtooltipは不変) ⑤空のfolderに**`browser-listing-empty`**を出す(U6。`browser-listing-failed`とは別key) |

**`failure`があるときは1件でも一覧を出す**のは、「1つだけ」と言い切れないうえに、
**取れなかったことを知らせるnoticeが一覧の側にある**ためである(`013:T08`の実機観測 —
装着しているSDカードが並ばないことに誰も気づけなかった)。**004 specはこの場合を定めていない**ので、
要求を足さずに実装の判断として置き、mutation `M405`で固定した。

## 検証結果(2026-09-22、`37bd08e`)

| 検証 | 結果 |
|---|---|
| related test `flutter test test/spec_004_file_source` | **184 PASS** |
| full regression `flutter test` | **960 PASS** |
| `flutter analyze` | **No issues found!** |
| `dart format --output=none --set-exit-if-changed .` | **PASS** |
| mutation(範囲を絞った表) | **6件すべてKILLED**(下に生出力) |
| Android build | **未実施**(AI containerにAndroid SDKが無い) |
| Android実機の見え方 | **未実施**([`manual-verification.md`](manual-verification.md)で依頼する) |

### mutationの生出力

`tool/mutations.json`の`command`は全件(`flutter test`)のまま置き、**回すものだけを作業用のpathへcopyして
`test/spec_004_file_source`へ絞った**(AGENTS.md)。`SURVIVED`は出ていないので全件での確かめ直しは要らない。

```console
$ python3 <asdd-plugin>/scripts/mutation_check.py <作業用の表> --root .
command: flutter test test/spec_004_file_source
ID | STATUS | FILE | NOTE | DETAIL
--- | --- | --- | --- | ---
M105 | KILLED | lib/data/file_source/storage_browser.dart | 保存場所のrootより上へ辿れるようにする(/storageや/へ到達経路ができる。004 REQ-015) | exit 1
M109 | KILLED | lib/ui/file_source/storage_browser_view.dart | 保存場所が1つだけでも一覧を挟む(004 REQ-015は1つだけのときrootから始まると定めている。近道の撤去にともないM109を置き換えた。008:T12) | exit 1
M117 | KILLED | lib/ui/file_source/storage_browser_view.dart | rootでも「上へ」を出す(004 代表例26d「上位へ戻る操作は無いか無効」。attempt 1 のP2-2) | exit 1
M404 | KILLED | lib/ui/file_source/storage_browser_view.dart | 既知の名前のfolderを一覧の先頭へ二重に並べる(近道の復活。004 REQ-015は近道を要求せず、同じfolderが2回出ることがU2の混乱の本体だった。008:T12) | exit 1
M405 | KILLED | lib/data/file_source/storage_browser.dart | 保存場所を列挙できていなくても「1つだけ」とみなす(取れなかったnoticeを飛ばして中へ入る。004 REQ-015 / 013:T08の実機観測。008:T12) | exit 1
M406 | KILLED | lib/ui/file_source/storage_browser_view.dart | 空のfolderと開けなかったfolderを同じ見た目にする(013:T07のU6。008:T12) | exit 1
6 mutations: 6 KILLED, 0 SURVIVED, 0 SKIPPED
```

**`M109`は消さずに置き換えた**(近道の対象が消えたため、REQ-015の新しい要求である「1つだけなら一覧を挟まない」を守る形にした)。
`M105`/`M117`が守るrootの上限は要求が変わっていないので、そのまま残した。**`M404`〜`M406`は今回足した対照である。**

## Current state / handoff

- Last checkpoint: 実装と機械検証まで完了(`37bd08e`)。**Android実機の手動確認と独立reviewが残っている。**
- Blocker category: なし
- Waiting for: なし
- Requested action: なし
- Evidence revision: `37bd08e`(branch `asdd/008-ui-alignment/T12-implement-browser-presentation`、base `dev@2df2cff`)。**このcommitを動かさずに待つ。**
- Next Agent action: 保存場所入口(1件ならroot・複数なら一覧と切り替え)・**近道の撤去**・U3の戻る矢印・U6の空folderを一つの確認単位で実装する。**U3だけを先に出さない。** T37のdrag/全選択を維持し、選択解除・画面を閉じる導線はT39へ渡す。
