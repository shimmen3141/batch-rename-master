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

## Current state / handoff

- Last checkpoint: 登録しただけ(2026-09-29)
- Blocker category: none
- Evidence revision: none
- Next Agent action: 検査のtestを先に足し、16件で落ちることを確かめる
