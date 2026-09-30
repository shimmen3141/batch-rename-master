#!/usr/bin/env python3
"""`tool/mutations.json` の各 mutation の `find` が、対象 file にちょうど1回一致するかを検査する。

`mutation_check.py` は一致しない mutation を `SKIPPED` と出すが、**回さなければ出ない。**
表は1件ごとに full test を流すと20分前後かかるので、所有 task も reviewer も範囲を
絞って回す(AGENTS.md)。そのため、他の task の変更で `find` が古くなった mutation は
何も守っていないのに、表の上では守っているように見え続けた(`008:T44` で16件を観測。
`development-findings/2026-09-29-stale-mutation-finds-go-unnoticed.md`)。

この検査は読み込みと数え上げだけなので速く、`test/tooling/repo_checks_test.dart`
経由で CI の `flutter test` が毎回走らせる。`find` を含む行を変えた変更は、その場で落ちる。

## この検査で捕まらないもの(PASS を「表のmutationはすべて有効」と読まないこと)

- **一致することだけを見る。** 置き換えた結果を test が検出するか(KILLED か)は見ない。
  それは `mutation_check.py` の役目である。
- **一致した箇所が、所有 task の意図した箇所かは見ない。** 同じ字面が別の場所へ移っても
  1回一致していれば通る。
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

TABLE = Path("tool/mutations.json")


def main() -> int:
    if not TABLE.is_file():
        print(f"ERROR: {TABLE} がありません", file=sys.stderr)
        return 2
    mutations = json.loads(TABLE.read_text(encoding="utf-8"))["mutations"]
    if not mutations:
        print(f"ERROR: {TABLE} に mutation が1件もありません", file=sys.stderr)
        return 2

    failures = []
    for m in mutations:
        path = Path(m["file"])
        if not path.is_file():
            failures.append(f"{m['id']} file が無い {m['file']}")
            continue
        count = path.read_text(encoding="utf-8").count(m["find"])
        if count != 1:
            failures.append(f"{m['id']} {count} {m['file']}")

    if failures:
        for f in failures:
            print(f"FAIL: {f}")
        print(
            f"{len(failures)} of {len(mutations)} mutation(s) の find が"
            " ちょうど1回一致しない(数字は一致した回数)。"
            " note の意図を読んで find/replace を今のコードへ追随させるか、"
            "守る対象が無くなったなら理由を記録して外す。"
        )
        return 1
    print(f"PASS: {len(mutations)} mutation(s), すべての find がちょうど1回一致する。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
