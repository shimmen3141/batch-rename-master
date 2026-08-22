#!/usr/bin/env python3
"""規範の範囲が、規範の場所の外へ書き写されていないかを検査する。

`013:T03` で「REQ 行の範囲を『自由とする点』『決定表』『他 task の仕様被覆表』へ
書き写し、REQ を直しても写した側が古いまま残る」という指摘が、独立review 3回連続で
出た。構造検査も lint も test もこの不一致を検出しない — どれも自然文だからである。

そこで prose の規律に依存するのをやめ、**書ける場所を機械が判定できる条件へ変えた**。

- `owned`: その語は owner file の REQ / INV / VER / OP 行と代表例の行にだけ書ける。
  他 file では `allow` に挙げたものだけ。
- `forbidden`: 差し替えた古い言い回し。どこにも残っていてはならない。

`allow` に挙がるのは「事実の出所」(一次資料の要約、ADR)と「日付つきの記録」
(review の経緯)である。当時の記述を残すことに意味があるものだけを通す。

検査対象と語は `tool/normative_terms.json` が持つ。project-native の道具であり、
ASDD plugin 側の共有 script ではない。
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

CONFIG = Path("tool/normative_terms.json")

# 規範の行(REQ-001 / INV-002 / VER-003 / OP-004 …)と代表例の行(1 / 26b …)。
# どちらも markdown の表の1行目セルで見分ける。
NORMATIVE_ROW = re.compile(r"^\|\s*(REQ|INV|VER|OP|SM|CON)-\d+\s*\|")
EXAMPLE_ROW = re.compile(r"^\|\s*\d+[a-z]?\s*\|")


def is_writable_row(line: str) -> bool:
    return bool(NORMATIVE_ROW.match(line) or EXAMPLE_ROW.match(line))


def files_to_scan(config: dict) -> list[Path]:
    found: list[Path] = []
    for pattern in config["scan"]:
        found.extend(Path().glob(pattern))
    excluded = set()
    for pattern in config.get("exclude", []):
        excluded.update(Path().glob(pattern))
    return sorted({p for p in found if p not in excluded and p.is_file()})


def main() -> int:
    if not CONFIG.exists():
        print(f"ERROR: {CONFIG} がありません", file=sys.stderr)
        return 2
    config = json.loads(CONFIG.read_text(encoding="utf-8"))
    paths = files_to_scan(config)
    if not paths:
        print("ERROR: 検査対象の file が1つも見つかりません", file=sys.stderr)
        return 2

    violations: list[str] = []

    for entry in config.get("owned", []):
        term = entry["term"]
        owner = entry["owner"]
        allowed = set(entry.get("allow", []))
        if not Path(owner).exists():
            violations.append(f"[owned] {term}: owner file が存在しません: {owner}")
            continue
        for path in paths:
            name = path.as_posix()
            text = path.read_text(encoding="utf-8")
            for number, line in enumerate(text.split("\n"), start=1):
                if term not in line:
                    continue
                if name == owner:
                    if not is_writable_row(line):
                        violations.append(
                            f"{name}:{number}: `{term}` を規範の行の外へ書いています。"
                            f"REQ / INV / VER / OP 行か代表例の行にだけ書けます"
                        )
                elif name not in allowed:
                    violations.append(
                        f"{name}:{number}: `{term}` は {owner} が正本です。"
                        f"ここへ書き写さず、REQ ID で参照してください"
                    )

    for entry in config.get("forbidden", []):
        phrase = entry["phrase"]
        allowed = set(entry.get("allow", []))
        for path in paths:
            name = path.as_posix()
            if name in allowed:
                continue
            text = path.read_text(encoding="utf-8")
            for number, line in enumerate(text.split("\n"), start=1):
                if phrase in line:
                    violations.append(
                        f"{name}:{number}: 差し替え済みの言い回し `{phrase}` が残っています。"
                        f"{entry['reason']}"
                    )

    owned = len(config.get("owned", []))
    forbidden = len(config.get("forbidden", []))
    if violations:
        for v in violations:
            print(f"FAIL: {v}")
        print(
            f"\n{len(violations)} violation(s). "
            f"scanned {len(paths)} file(s), {owned} owned term(s), {forbidden} forbidden phrase(s)."
        )
        return 1

    print(
        f"PASS: {len(paths)} file(s), {owned} owned term(s), "
        f"{forbidden} forbidden phrase(s), 0 violations."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
