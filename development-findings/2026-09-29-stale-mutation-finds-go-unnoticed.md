# mutationの`find`がコードの変更で古くなっても、誰も気づかない

- 観測日: 2026-09-29
- 観測した場所: `008:T44`(トークンの設定を参考デザインのダイアログへ)で`tool/mutations.json`を追随させていたとき

## 観測

`008:T44`で`lib/ui/rule_builder/`の3ファイルを変えるとき、そのファイルを対象にする既存のmutationの`find`がまだ一致するかを調べた。すると**`M242`・`M256`が一致しなかった**。原因は`014:T04`で`showTokenEditor`の呼び出しに引数(`itemCount`)を足したことで、そのときに`find`を追随させていなかった。

- `014:T04`の所有側は、自分が足したmutation(`M497`〜`M509`)だけを範囲付きで回した。**変更した箇所を守る既存のmutation**(AGENTS.md「所有task側も同じ絞り方で回してよい」の対象)を洗い出さなかった。
- 独立review(attempt 1・2)も、疑わしいものと自分の対照だけを回す規約どおりで、`M242`・`M256`は回していない。
- `mutation_check.py`は一致しないものを`SKIPPED`と出すが、**回さなければ出ない**。

表全体を同じ方法で調べると、**他のtaskの16件も一致していなかった**(2026-09-29、`dev`@`9806d96`に`008:T44`の差分を載せた状態):

```text
M116 0 lib/data/file_source/android_storage_browser.dart
M178 0 lib/ui/file_list/file_list_view.dart
M257 0 lib/ui/file_list/file_list_view.dart
M264 0 lib/ui/file_list/file_list_view.dart
M298 0 lib/ui/file_list/file_list_view.dart
M305 0 lib/ui/file_list/file_list_view.dart
M306 0 lib/ui/file_list/file_list_view.dart
M314 0 lib/ui/file_list/file_list_view.dart
M317 0 lib/ui/file_list/file_list_view.dart
M324 0 lib/ui/file_list/file_list_view.dart
M342 0 lib/ui/file_list/file_list_view.dart
M355 0 lib/ui/file_list/file_list_view.dart
M357 0 lib/ui/file_list/file_list_view.dart
M358 0 lib/ui/file_list/file_list_view.dart
M392 2 lib/ui/file_list/rename_warning_view.dart   ← 2箇所に一致(mutation_check は1回を要求する)
M448 0 lib/ui/file_list/file_list_view.dart
```

(数字は一致した回数。`file_list_view.dart`は`008:T42`・`T43`などで大きく変わっている。)

## 影響

- 一致しないmutationは**何も守っていない**のに、表の上では守っているように見える。
- 表を全件で回す人はいない(1件ごとにfull testで20分前後かかるため、範囲付きで回す規約にした)。そのため、古くなったことが検出されるきっかけが無い。

## 改善先

- **検査を足す**: `tool/mutations.json`のすべての`find`が、対象ファイルに**ちょうど1回**一致することを見るtest(例: `test/tooling/repo_checks_test.dart`へ1件)。testは読み込みと文字列の数え上げだけなので速く、CIの`flutter test`で毎回走る。一致しなくなった変更はその場でFAILする。
- 既存の16件は、それぞれの所有task(`find`の`note`にある)の意図を読んで追随させるか、守る対象が消えたなら理由を付けて外す。
- 手順への入力: `run-plan`の「所有task側も同じ絞り方で回してよい」は、**変更したファイルを`file`に持つ既存のmutationの`find`がまだ一致するか**を確かめることを含む、と明記する。上の検査があれば手順に頼らずに済む。

`008:T44`では、自分が触った3ファイルの35件がすべて1回一致することを確かめ、`M242`・`M256`を追随させた(task.mdに記録)。残る16件と検査の追加は、開発者の判断を仰いでからtaskにする。

## 経過

- 2026-09-29: 開発者が「新しいtaskとして、CIで検出するtestを足してから16件を直す」と決めた。`008:T46`として登録した。
- 2026-09-30: `008:T46`で閉じた。
  - **検査**: `tool/check_mutation_finds.py`を`test/tooling/repo_checks_test.dart`から呼び、CIの`flutter test`で毎回走らせる。判定は`mutation_check.py`と同じく`occurrences`(省略時1)との一致回数。直す前の表で落ちることを確かめた。
  - **観測の訂正**: 上の表の`M392`(2箇所)は`occurrences: 2`を持ち、2箇所の置換を意図している。古くなっていたのは15件だった(上の「ちょうど1回」の数え方が`occurrences`を見ていなかった)。
  - **15件の扱い**: `M116`は守る対象(近道)が`008:T12`で取り下げられたので外した。14件は今のコードへ追随させた。詳細と生出力は[`008:T46`のtask.md](../specs/008-ui-alignment/tasks/T46-mutation-find-check/task.md)。
  - 手順(`run-plan`の「変更したファイルを`file`に持つ既存のmutationの`find`」の明記)は、この検査がCIで閉じるので加えない。
