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

## 検証結果(2026-09-22。`lib/`は`37bd08e`)

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

## 独立review

**reviewerのmodelは`gpt-5.6-luna`**(開発者指定。実装はClaude Opus 5で行っており、AGENTS.mdの既定
「実装より一段軽いもの」とも一致する)。

- attempt 1: `2df2cff..98c440e`、phase=implementation — **FAIL**。
  - **P1(成果物の欠陥)**: `task.md`が full regression を「960 PASS」と記録していたが、実際は `959 pass / 1 fail`
    だった。**原因は手動確認の手順書へ、004 REQ-018が正本とする path を literal で書き写したこと**で、
    `tool/check_normative_terms.py`(full regressionに含まれる)が落ちていた。**960 PASSを測ったのは
    手順書を書く前で、記録が現実と一致していなかった。** → 文言をREQ ID参照(004 REQ-018)へ置き換え、
    **full regressionを測り直して960 PASSを確認した。**
  - **P2(成果物の欠陥)**: 対象revisionの記録が`2fae34f` / `37bd08e` / branch HEADで割れていた。
    → **「`lib/`が`37bd08e`と同一であること」**という形に統一した。記録だけのcommitを足しても揺れない。
  - 仕様に対する過不足、REQ-016〜020の維持、`soleLocation`の`failure`時の判断、related 184 PASS、
    analyze、format、mutation 6件KILLED、workspace checkは**いずれも妥当と確認された**。

- attempt 2: `2df2cff..d383ff7` — **FAIL**。
  - **P1(成果物の欠陥)**: **同じ違反を`task.md`自身が持っていた** — attempt 1 の指摘を記録するときに、
    004 REQ-018が正本とする path を literal で書いてしまい、full regression がまた `959 pass / 1 fail` になっていた。
    **「直した」と書いた本文が、同じ規則を破っていた。** → literal をやめて REQ ID で参照する形に変え、
    **full regression を測り直した。**
  - **P2(成果物の欠陥)**: handoffの `Next Agent action` が実装前のまま「実装する」だった。→ 現在地に合わせた。
  - REQ-015〜020の実装、mutation 6件KILLED、related 184 PASS、analyze、format、workspace check、
    `lib/`が`37bd08e`と同一であることは**いずれも再確認された**。

**この型(規範文言の書き写し)は`008:T11`でも2回続けてFAILしている。** 今回は**手順書と、その修正を記録した
task.md自身**で連続して踏んだ。`tool/check_normative_terms.py`は literal 一致を見るので、
**記録を書き換えたあとに full regression を回し直せば必ず捕まる** — その一手を省かないこと。
経緯は[`development-findings/2026-09-22-shortcut-removal-stale-copies-across-handoff-docs.md`](../../../../development-findings/2026-09-22-shortcut-removal-stale-copies-across-handoff-docs.md)へ追記した。

- attempt 3: `2df2cff..3b23896` — **PASS**(implementation phase)。P0〜P3の指摘なし。
  reviewerが自分で再実行した結果は `check_normative_terms` PASS / related 184 PASS / full 960 PASS /
  analyze PASS / format PASS / mutation 6件 KILLED・0 SURVIVED / workspace check PASS。
  **未確認領域はAndroid buildと実機の見え方だけ**で、宣言どおり手動確認が引き受ける。

- final-evidence attempt 1: `2df2cff..d6d164d` — **BLOCKED(成果物の欠陥なし)**。
  - `37bd08e`以後の差分は`android/.gitignore`(ignore規則)だけで、**`lib/`・dependency・build設定は変わっていない**
    — manual証拠のidentityは保たれていると確認された。
  - reviewer自身の再実行: full 960 PASS / analyze PASS / format PASS / normative terms 0 violations / workspace check PASS。
  - 1件端末の入口を残余riskとして受容した判断は、安全網の穴のFAIL条件に当たらないと確認された。
  - **BLOCKEDの理由はPRとCIがまだ無いこと**(`task.json`の`pullRequest`が`null`、required CI・branch protection・
    review threadを確認できない)。reviewerが記録した「`origin/dev`が祖先でない」は、fetch前の古いrefで測った値で、
    `git fetch`後に`git merge-base --is-ancestor origin/dev HEAD`で**祖先であることを確かめた**。
  - `compose.ai.yml`の未commit変更は人間のもので、rangeにも含まれず、reviewerも触っていない。

- final-evidence attempt 2: `2df2cff..609b64f` — **BLOCKED(P0/P1・安全網の穴なし)**。PR #185は非Draft・HEAD一致・
  `CLEAN`/`MERGEABLE`、CI `check` pass、未解決thread 0、full 960 PASS / analyze / format / normative / workspace check PASS、
  manual identity保持、環境側のcommitはsandbox・secret境界の変更に当たらない、と確認された。
  **BLOCKEDの理由はauto-merge 7条件のうち2つを満たすと確定できないこと**で、成果物の欠陥ではない。
  - 条件1: `task.json`の`issue`が`null`。**実装Agentの見解**: 条件は「一意であること」で、AGENTS.mdはIssueを
    共有編集を始めるtaskだけに作るとしているので、Issueが無いこと自体は違反ではないと読む。ただし読みが割れるので人間へ返す。
  - 条件5: 1件端末の入口の実機証拠を開発者の判断で省略した。残余riskとしての受容は整合と判定されたが、
    **「必須UI・実機証拠がそろっている」とは言えないので、Agentの自己判断でのmergeはしない。**
  - **開発者の決定(2026-09-22)**: 条件1(Issue無し)と条件5(1件端末の実機証拠の省略)を**受容してmergeする**と判断した。
    **Agentの自己判断でのmergeではない。** merge直前のHEAD `e4dc8e6` でCI `check` は pass、`CLEAN`/非Draft。


## 手動確認の準備で見つかった、環境側の不具合(2026-09-22)

hostの`flutter run`が、共有された`android/local.properties`の`flutter.sdk`(container内のFlutterのpath)を
参照して失敗した。**`compose.ai.yml`が作業ディレクトリを共有しているため、container内で`flutter`を
1回動かすだけで書き換わる**(container内で再現した)。**T12の実装とは無関係の環境側の問題である。**

- その場の対処: 書き換わったfileを削除した(git ignoreされた生成物で、hostのFlutterが作り直す)。
- 再発防止: `scripts/clear-container-local-properties.sh`を足した(`dev`へ入れ、このbranchへ取り込んだ)。
- **残っている人間の作業**: Claude Codeのhook登録(Agentからは自己変更ガードで拒否された)と、
  compose側の根本対応。内容は
  [`development-findings/2026-09-22-container-flutter-rewrites-android-local-properties.md`](../../../../development-findings/2026-09-22-container-flutter-rewrites-android-local-properties.md)。
- **手動確認の対象buildは変わっていない** — `lib/`は`37bd08e`と同一のままである。

## 手動確認の受領(2026-09-22、1回目)

環境: **Androidエミュレータ**(開発者報告)。対象build: `lib/`が`37bd08e`と同一。

| 手順 | 結果 |
|---|---|
| 1 入口(U1) | **未確認。** エミュレータには**SDカードが出る**ため、保存場所は2件になり、「1件だから一覧を挟まない」側は観測できない。**これは不具合ではなく、REQ-015が定める複数件の振る舞いである。** 未観測なのは**1件の端末の入口**と、**複数件での切り替え**(手順1の後半)である |
| 2 近道(U2) | **確認できた** |
| 3 上へ戻る矢印(U3) | **確認できた** |
| 4 空のfolder(U6) | **確認できた** |
| 5 T37の回帰 | **確認できた** |

**残りの確認**は次の2つに絞られる。

1. **複数件での切り替え**(手順1の後半): 一覧 → 内部ストレージ → rootで保存場所を選び直す → SDカード。
   **エミュレータでそのまま観測できる**(REQ-015の「複数あるときは閉じずに切り替えられる」)。
2. **1件の端末の入口**: SDカードを持たないAVD(またはSDカードを外した端末)が要る。
   **widget testでは固定済み**(`保存場所が1つだけのときは一覧を挟まず、rootの中身が出る` / mutation `M109`)。
   実機側が取れない場合は**残余risk**として受け入れ、引き受け先を記録する。

## 手動確認の受領(2026-09-22、2回目)と残余risk

環境: Androidエミュレータ(SDカードあり。保存場所は2件)。対象build: `lib/`が`37bd08e`と同一。

| 項目 | 結果 |
|---|---|
| A 複数保存場所での切り替え(手順1の後半) | **確認できた** — 一覧から始まり、rootの選び直しでbrowserを閉じずに一覧へ戻り、SDカードへ切り替えられる |
| B 保存場所が1件のときの入口 | **開発者の判断で省略**(SDカード無しのAVDが要るため) |

**手順1〜5のうち、Bを除くすべてを受領した。**

### 残余risk(受容)

| risk | 分類と根拠 | 引き受け先 |
|---|---|---|
| **保存場所が1件の端末で、実機上も一覧を挟まずrootから始まるか**は観測していない | **安全網の穴**(実装は正しいと機械検証で閉じている)。widget test `保存場所が1つだけのときは一覧を挟まず、rootの中身が出る` とmutation `M109`(KILLED)で固定済み。**AGENTS.mdの3条件のうち「このprojectのCIで閉じられる」は既に満たされている** — 残るのは実機の見え方だけで、実機・emulatorを要するのでCIでは閉じられない。FAIL条件に当たらないので受容する | **`008:T39`**(同じbrowser画面の実装で、**Android物理端末**のmanualを持つ)。SDカードを持たない端末なら入口の観測を足す |

受容はtask所有Agentとして記録する(AGENTS.md)。**開発者はBの省略を2026-09-22に判断した。**

### 同じrangeに入った環境側のcommit

手動確認の準備で見つかった環境側の不具合(container内のFlutterが`android/local.properties`を書き換える)への対処が、
`dev`経由でこのbranchへ入っている(`755041b` / `09a98f4`)。加えて`5456aa9`はこのbranch上で直接commitした同じ対処の続きである。
**いずれも`lib/`・`test/`を触っていない**ので、T12の実装と手動確認の対象buildには影響しない。

## Current state / handoff

- Last checkpoint: 実装・機械検証・implementation review PASS・**手動確認の受領**まで完了(`lib/`は`37bd08e`)。1件端末の入口は残余riskとして`T39`へ渡した。
- Blocker category: なし
- Waiting for: **開発者のmerge判断**(auto-merge条件1・5を満たすと確定できないため)。
- Requested action: なし
- Evidence revision: **`lib/`が commit `37bd08e` と同一であること**(base `dev@2df2cff`)。branch `asdd/008-ui-alignment/T12-implement-browser-presentation` のHEADはこれを満たす — `37bd08e`以後のcommitは記録だけである。**`lib/`を動かさずに手動確認を待つ。**
- Next Agent action: final-evidence phaseの独立reviewを回し、PASSならPRを作ってCIを通し、auto-merge条件を確かめる。選択解除・画面を閉じる導線と、1件端末の入口の実機観測は`T39`へ渡す。
