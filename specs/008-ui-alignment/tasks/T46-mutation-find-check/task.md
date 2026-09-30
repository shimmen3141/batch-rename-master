# T46 mutationのfindがコードと一致することをCIで検出し、古くなった16件を直す

## 目的

`tool/mutations.json`の各mutationの`find`が、対象ファイルに**ちょうど1回**一致することをCIで毎回確かめ、コードの変更で古くなった(何も守っていない)mutationをその場で検出できるようにする。そのうえで、今古くなっている16件を直す。

## 出所

[finding](../../../../development-findings/2026-09-29-stale-mutation-finds-go-unnoticed.md)(`008:T44`で観測)。開発者の決定(2026-09-29、原文): 「「古くなったmutation 16件」の扱いは、新しいtaskとして、CIで検出するtestを足してから16件を直すようにしてください。」

## 範囲

1. **先にtestを足す**: `tool/mutations.json`を読み、各`find`が`file`にちょうど1回一致することを見るtest(例: `test/tooling/repo_checks_test.dart`)。一致しないものを`id`・一致回数つきで列挙して落ちる。testは読み込みと数え上げだけで速い。**足した時点で16件によって落ちることを確かめる**(testが本物であることの証拠)。
2. **16件を直す**: それぞれの`note`にある所有taskの意図を読み、今のコードで同じ退行を表す`find`/`replace`へ追随させる。守る対象そのものが無くなったものは、理由を付けて外す(task.mdへ記録)。追随させたものは範囲付きで回してKILLEDを確かめる(`SURVIVED`は全件で確かめ直す)。
3. 手順への反映: findingの「改善先」に、この検査で閉じたことを追記する。

## 対象外

- mutationの意図そのものの見直し(追随・除外の判断に必要な範囲だけ読む)。

## 受け入れ証拠

- 検査のtestが、直す前の表で16件を列挙して落ち、直した後は通る(生出力を記録)。
- 直した各mutationの範囲付きmutation_checkの生出力。full `flutter test`・analyze・format。
- 独立review。

## 作業記録

着手は Claude Opus 5.5(2026-09-30)。branch `asdd/008-ui-alignment/T46-mutation-find-check`、起点`dev`@`b771831`。

### 検査(`5e6d052`・`da0a672`)

- `tool/check_mutation_finds.py`を足し、`test/tooling/repo_checks_test.dart`の`checks`へ登録した(既存の2つの検査と同じ形。CIの`flutter test`が毎回走らせる)。
- 判定は、ASDD pluginの`mutation_check.py`と同じにした。`occurrences`(省略時1)との一致回数を、byte列で数える。pluginはCIに無いので、同じ判定をproject側に置く。
- **16件ではなく15件だった**: `M392`は`occurrences: 2`を持ち、2箇所の置換を意図している(noteにも書かれている)。findingの表は「ちょうど1回」で数えていた。
- 直す前の表で落ちること(`flutter test test/tooling/repo_checks_test.dart`、`5e6d052`の時点。`da0a672`の後は`M392`が消えて15件):

```text
00:08 +2 -1: mutationのfindの一致 — `python3 tool/check_mutation_finds.py` が PASS する [E]
  FAIL: M116 0 lib/data/file_source/android_storage_browser.dart
  FAIL: M178 0 lib/ui/file_list/file_list_view.dart
  FAIL: M257 0 lib/ui/file_list/file_list_view.dart
  FAIL: M264 0 lib/ui/file_list/file_list_view.dart
  FAIL: M298 0 lib/ui/file_list/file_list_view.dart
  FAIL: M305 0 lib/ui/file_list/file_list_view.dart
  FAIL: M306 0 lib/ui/file_list/file_list_view.dart
  FAIL: M314 0 lib/ui/file_list/file_list_view.dart
  FAIL: M317 0 lib/ui/file_list/file_list_view.dart
  FAIL: M324 0 lib/ui/file_list/file_list_view.dart
  FAIL: M342 0 lib/ui/file_list/file_list_view.dart
  FAIL: M355 0 lib/ui/file_list/file_list_view.dart
  FAIL: M357 0 lib/ui/file_list/file_list_view.dart
  FAIL: M358 0 lib/ui/file_list/file_list_view.dart
  FAIL: M392 2 lib/ui/file_list/rename_warning_view.dart
  FAIL: M448 0 lib/ui/file_list/file_list_view.dart
  16 of 505 mutation(s) の find が ちょうど1回一致しない(数字は一致した回数)。 ...
00:08 +2 -1: Some tests failed.
```

### 15件の扱い(`26a6184`)

表の書き換えはscriptで行い、書き戻した後に読み直して照合した(各`find`が1回一致し、置換で中身が変わること)。

| 扱い | mutation | 理由 |
|---|---|---|
| 外した | `M116` | 守っていた近道(`shortcuts`)は`008:T12`(`37bd08e0`)でコードから撤去され、004 REQ-015からも取り下げられた(2026-09-22に再承認)。守る対象が無い |
| 字下げ・整形の追随(置換の意味は同じ) | `M178`・`M257`・`M264`・`M317`・`M355`・`M357`・`M358` | `008:T31`で一覧を`Listener`で包み、1段深くなった |
| 同上 | `M448` | `008:T42`で通常のフッターの面が`colors.bar`になった |
| 仕組みの変更に追随 | `M298`・`M314`・`M342` | `008:T31`でモードを抜ける処理が`_exitRemovalMode()`(範囲選択の片付け + `exit`)になった。`M314`・`M342`は片付け(`_dragSelection.finish()`)を残し、モードを抜けることだけを落とす |
| 同上 | `M305` | `008:T31`で行の長押しは範囲選択の開始`_startDragSelection`になり、`onLongPressEnter`が無くなった。長押しでモードへ入る`_selection.enter()`を落とす形へ移した |
| 同上 | `M306` | 長押しした行を選ぶのは`DragSelectionController.start`の`session.visit`になった(`lib/ui/common/drag_selection_controller.dart`。004 REQ-020のapp内browserと共有する箇所) |
| 同上 | `M324` | モード中の長押しも`_startDragSelection`を通る。`if (!_selection.selecting)`を`if (true)`にすると、`enter`が選択を捨てて長押しした1件へ巻き戻る |

各noteへ「**008:T46で`find`を追随させた**」と理由を足した。

### mutation

範囲付き(`flutter test test/spec_002_file_list test/spec_004_file_source test/spec_005_rename_exec`、14件)の生出力(noteは省いた):

```text
M178 | KILLED | lib/ui/file_list/file_list_view.dart | exit 1
M257 | KILLED | lib/ui/file_list/file_list_view.dart | exit 1
M264 | KILLED | lib/ui/file_list/file_list_view.dart | exit 1
M298 | KILLED | lib/ui/file_list/file_list_view.dart | exit 1
M305 | KILLED | lib/ui/file_list/file_list_view.dart | exit 1
M306 | KILLED | lib/ui/common/drag_selection_controller.dart | exit 1
M314 | SURVIVED | lib/ui/file_list/file_list_view.dart | exit 0: the tests passed with the mutation applied
M317 | KILLED | lib/ui/file_list/file_list_view.dart | exit 1
M324 | KILLED | lib/ui/file_list/file_list_view.dart | exit 1
M342 | SURVIVED | lib/ui/file_list/file_list_view.dart | exit 0: the tests passed with the mutation applied
M355 | KILLED | lib/ui/file_list/file_list_view.dart | exit 1
M357 | KILLED | lib/ui/file_list/file_list_view.dart | exit 1
M358 | KILLED | lib/ui/file_list/file_list_view.dart | exit 1
M448 | KILLED | lib/ui/file_list/file_list_view.dart | exit 1
14 mutations: 12 KILLED, 2 SURVIVED, 0 SKIPPED
```

**SURVIVEDの2件を全件で確かめ直したとき、足した検査の欠陥が見つかった(`1742e6c`で直した)**。表の`command`(当時は`flutter test`)で回すと2件ともKILLEDになった。原因はmutationの効き目ではない。mutationを当てるとその`find`がファイルから消えるので、`check_mutation_finds.py`自身が落ちていた。**この検査を含めて回すと、どのmutationも必ずKILLEDになる**。そこで表の`command`を`flutter test --exclude-tags tooling`にした(`repo_checks_test.dart`は`@Tags(['tooling'])`)。

- 既存のmutationで、toolingの検査が落とすことを当てにしているものは無い(noteを検索した)。
- CIの`flutter test`は今までどおりtoolingも含めて走る。
- 検査のdocstringに、範囲を絞るときも`test/tooling`を含めないことを書いた。

直した後、全件(`flutter test --exclude-tags tooling`)で確かめ直した生出力:

```text
M314 | SURVIVED | lib/ui/file_list/file_list_view.dart | exit 0: the tests passed with the mutation applied
M342 | SURVIVED | lib/ui/file_list/file_list_view.dart | exit 0: the tests passed with the mutation applied
2 mutations: 0 KILLED, 2 SURVIVED, 0 SKIPPED
```

- `M342`: noteにある期待どおり(等価mutant。防御の重複)。
- `M314`: 同じ構造の等価mutantになっていた。`008:T29`で足した片付けがあるためである。外した候補が一覧から消えると、次のframeの後で`retain`が選択を0件にし、モードを抜ける。この片付けは`M345`が守る。差は1 frameのちらつきだけで、安全網の穴のFAIL条件(2)(データ損失など)に当たらない。**M342と同じ防御の重複として残し**、noteへ記録した(残余riskとして受容。引き受け先のtaskは無い — 保証そのものは`retain`とそれを守る`M345`が持つ)。**→ この受容は取りやめた。** 独立review attempt 1 のP2を受けてtestを足し、`M314`はKILLEDになった(下の「独立review」)。
- 検証: `python3 tool/check_mutation_finds.py` PASS(504件)、`flutter test` 1083件PASS、`flutter analyze`・`dart format` PASS。

## 独立review

既定のreviewerは`gpt-6-luna`(開発者指定)。

- attempt 1: `b771831..0e6afbf`(全範囲、implementation) — **PASS**(P2 2件)。reviewerのmodelは`gpt-6-luna`。確認された点: 判定がplugin(`occurrences`・byte列)と一致しCIで走ること、`M392`を古くないとした判断、`M116`を外した根拠、追随14件のfind/replaceが各noteの意図を表すこと、`M314`/`M342`のSURVIVEDの理由。`check_mutation_finds` PASS(504件)、full test 1083件・analyze・format・`check specs`・`git diff --check` PASS。範囲付きmutation(`M314`・`M342`)は2件SURVIVED。
  - **P2(成果物の欠陥)**: 表の`command`の`--exclude-tags tooling`は、AGENTS.mdの「`command`は全件のまま置く」と文言が合わない。→ **直さない。** その規約の理由は「表は一つのcommandしか持てず、001のコア判定やdataのmutationも同じ表にある」、つまり**振る舞いのtestを特定のspecへ絞らない**ことにある。外したのは`@Tags(['tooling'])`のrepositoryの検査だけで、振る舞いのtestはすべて残る。一方、toolingを含めると、mutationを当てた時点で`find`の一致の検査が落ち、**どのmutationも必ずKILLEDになる**。これは全件で回す意味を失わせる。AGENTS.mdの文言の整理は人間の判断(このtaskはAGENTS.mdを変えない)。
  - **P2(M314)**: reviewerは「外した後に一時的に選択モードが残る」と読んだが、それはmutationを当てたときだけで、製品のコードは`_removeMarked`ですぐ抜ける。ただし、すぐ抜けることをtestが見ていないのは事実だった。→ `767eb00`で、外した直後の最初のframeを見るtest(`removal_selection_mode_test.dart`「外した直後の最初の frame でモードを抜けている」)を足した。`M314`はKILLEDになり、noteを「閉じた」へ直した。`M342`はnoteどおりの等価mutantのまま(一覧が空になるので、同じframeで描画も畳まれる)。生出力(`flutter test test/spec_002_file_list/removal_selection_mode_test.dart`):

```text
M314 | KILLED | lib/ui/file_list/file_list_view.dart | exit 1
M342 | SURVIVED | lib/ui/file_list/file_list_view.dart | exit 0: the tests passed with the mutation applied
2 mutations: 1 KILLED, 1 SURVIVED, 0 SKIPPED
```

  - 検証: full `flutter test` 1084件PASS、analyze・format・`check_mutation_finds` PASS。

## Current state / handoff

- Last checkpoint: 独立review attempt 1 PASS(P2 2件)。1件は直さない理由を記録し、1件はtestを足して閉じた。full test 1084件PASS(2026-09-30)
- Blocker category: none
- Evidence revision: `767eb00`以降(test・表のnote・記録)
- Next Agent action: `0e6afbf..HEAD`の差分reviewを依頼する(testを足したため)
