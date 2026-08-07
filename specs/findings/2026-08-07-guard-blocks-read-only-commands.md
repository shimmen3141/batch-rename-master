# 承認ゲートが、承認済み仕様を「読むだけ」のコマンドも差し戻す

- **症状**: 承認済み契約のパスを引数に含むだけの**読み取り専用コマンド**が PreToolUse で差し戻された。実際に止められたもの:

  ```
  python3 <plugin>/skills/create-verifiable-spec/scripts/spec_lint.py \
      specs/005-rename-exec/contracts/behavior-contract.json --strict
  python3 -c "import json; c = json.load(open('specs/005-rename-exec/contracts/behavior-contract.json')); print(c['status'])"
  ```

  どちらも1バイトも書き込まない。ガードはコマンド文字列に承認済み仕様のパスが現れたかどうかだけを見ており、書き込みかどうかを区別していない。
- **どこで**: run-plan の T1 完了処理(承認後に lint と status を確認しようとしたところ)。**スイート自身が案内している検査コマンド**(`spec_lint --strict`)が、承認直後に実行できなくなる。
- **その場の回避**: 状態の確認は Read ツールで行い、lint は再実行しなかった(契約の編集ごとに PostToolUse の `contract_lint_hook` が同じ lint を走らせており、Edit が差し戻されなかったことが PASS の証拠になるため)。パスをワイルドカードに書き換えれば通るが、それはガードの迂回にあたるので採らなかった。
- **提案**: コマンドが書き込みの形をしているかで絞る。具体的には、リダイレクト(`>`・`>>`・`tee`)、破壊的なフラグ(`sed -i`・`mv`・`cp`・`rm`)、`open(..., "w"/"a")` や `write_text`・`json.dump` の出現を条件に加える。少なくとも `spec_lint.py`(スイート自身の検査コマンド)は素通りさせたい。誤検出を許す設計思想は理解できるが、**承認済みの仕様を検査できなくなるのは目的に反する**。

## 関連して: 順序の落とし穴

`status` を `approved` にした**後**に spec.md や plan.md を直そうとすると、同じ機能ディレクトリの成果物として差し戻される。承認を反映するときは **spec.md・plan.md を先に直し、`status` の変更を最後に置く**のが正しい順序。今回はこれを誤り、`draft` に戻す → 直す → `approved` に戻す、という正規手順で回復した。skill 側の手順に「承認の反映は status を最後に」と一行あると踏まなくて済む。
