# 独立reviewerが container の中から `docker compose` で検証しようとして BLOCKED になった

- 観測日: 2026-09-30
- 観測した場所: `008:T47` の差分review attempt 2(`gpt-6-luna`、`codex-container exec`)

## 観測

reviewer は「指摘なし・前回のP2は閉じた」と確認したうえで、`flutter test` と `python3 tool/check_mutation_finds.py` を **`docker compose -f compose.ai.yml run --rm ai-dev <command>` 経由で** 実行しようとし、`docker: command not found` で実行できず **BLOCKED** を返した。

- AGENTS.md は「非対話の検証は既定で `docker compose -f compose.ai.yml run --rm ai-dev <command>` を使う」と書いている。
- しかし Agent も reviewer も**既に `AI_SANDBOX=1` の container の中**で動いており、そこには `docker` が無い(docker.sock も無い。`codex-container` がそれを確かめてから起動する)。同じ task の attempt 1・3・4 と、`008:T02` の reviewer は直接実行していた。reviewer の読み方で結果が変わる。
- 2026-09-29 にも、reviewer の検証が sandbox の中で終わらず BLOCKED になったことがある(所有Agentが同じ HEAD で流し直して SELF-CHECK とした)。

## 影響

- 判断に関わる指摘が無いのに BLOCKED が返り、所有Agentが SELF-CHECK で補う手間と、review の連鎖の記録の複雑さが増えた。
- 所有Agentが気づかなければ、reviewを数え直す(FAIL の累計に近い扱いをする)おそれがある。

## 改善の候補

- AGENTS.md の「非対話の検証」の節に、**「既に `AI_SANDBOX=1` の container の中なら、検証は直接実行する(`docker` は無い)」**を書き足す。`AGENTS.md` の変更は auto-merge の対象外なので、人間の確認で入れる。
- それまでの運用: reviewer への prompt に「検証は docker を使わず worktree で直接実行する」を必ず書く(`008:T47` の attempt 3 以降で実施し、BLOCKED は起きていない)。

## 対応

- `008:T47` の task.md の「引き継ぎメモ」に運用を書いた。AGENTS.md の書き足しは未実施(人間の判断待ち)。
