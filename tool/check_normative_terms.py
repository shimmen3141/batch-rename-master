#!/usr/bin/env python3
"""規範の範囲が、規範の場所の外へ書き写されていないかを検査する。

`013:T03` で「REQ 行の範囲を『自由とする点』『決定表』『他 task の仕様被覆表』へ
書き写し、REQ を直しても写した側が古いまま残る」という指摘が、独立review 3回連続で
出た。構造検査も lint も test もこの不一致を検出しない — どれも自然文だからである。

そこで prose の規律に依存するのをやめ、**書ける場所を機械が判定できる条件へ変えた**。

- `owned`: その語は owner file の**代表例の節の表**と、どこであれ規範の行
  (REQ / INV / VER / OP / SM / CON)にだけ書ける。他 file では `allow` に
  挙げたものだけ。
- `forbidden`: 差し替えた古い言い回し。どこにも残っていてはならない。

`allow` は **file 全体**と**節を限った許可**の2種類を取る。

- 文字列 = その file 全体("事実の出所" — 一次資料の要約、ADR)
- `{"file": ..., "section": "## 作業記録"}` = その節の中だけ("日付つきの記録" —
  review の経緯。当時の記述を残すことに意味がある)

**file 単位の allow を安易に足さないこと。** `013:T03` の independent review
attempt 4 は、実装Agent が自分の task file を file 単位で allow へ入れ、その中の
索引表に生きた書き写しを1件通していたことを見つけた(**自己免罪**)。節を限った
許可があるのはこのためである。

## この検査で捕まらないもの(限界。PASS を「書き写しは無い」と読まないこと)

- **要求の"強さ"。** `REQ-018(改名できない旨)` のような断定は、登録した literal を
  含まないので検出できない。attempt 3 の指摘は「範囲 + 強さ」の両方だったが、
  検査が見るのは範囲側の literal だけである。
- **literal を持たない REQ の範囲。** REQ-016「同一フォルダ内」や REQ-011
  「文書を出さない」のように、日本語の言い回ししか無い要求は登録できない。
- **表記ゆれ。** `Android/data`(先頭スラッシュ無し)や全角は別の文字列である。
- **検査するのは `specs/**/*.md` と `specs/**/contracts/*.json` だけ。** `lib/`(UI 文言や
  コメント)、`docs/`、`AGENTS.md`、**PR 本文**は見ない。`T07` の実装者が最初に読むのは PR と
  `lib/` である。**契約 JSON を対象へ足したのは 2026-09-02(`008:T17`)** — revision の意味を
  書いた `revision_history` の中で、差し替え済みの主張が2回続けて生き残ったためである
  (独立review attempt 1 の P1-1 / attempt 2 の P1-A)。**PR 本文は依然として範囲の外にある。**

したがってこの検査は**書き写しの一部を機械的に止める**ものであって、書き写しが
無いことを保証しない。review はこの限界の外側を見る必要がある。

検査対象と語は `tool/normative_terms.json` が持つ。project-native の道具であり、
ASDD plugin 側の共有 script ではない。
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

CONFIG = Path("tool/normative_terms.json")

# 規範の行(REQ-001 / INV-002 / VER-003 / OP-004 …)。どの節にあっても書ける。
NORMATIVE_ROW = re.compile(r"^\|\s*(REQ|INV|VER|OP|SM|CON)-\d+\s*\|")
# 代表例の行(1 / 26b …)。**代表例の節の中でだけ**「書ける行」とみなす。
EXAMPLE_ROW = re.compile(r"^\|\s*\d+[a-z]?\s*\|")
EXAMPLE_HEADING = re.compile(r"^#{2,4}\s+代表例\s*$")
HEADING = re.compile(r"^#{1,6}\s+")


def annotate(text: str) -> list[tuple[str, bool, str]]:
    """各行へ (行, 代表例の節の中か, 直近の `## ` 見出し) を付ける。"""
    rows: list[tuple[str, bool, str]] = []
    in_example = False
    section = ""
    for line in text.split("\n"):
        if HEADING.match(line):
            # 見出しに入るたびに代表例の区間を閉じ、必要なら開き直す。
            in_example = bool(EXAMPLE_HEADING.match(line))
            if line.startswith("## "):
                section = line.strip()
        rows.append((line, in_example, section))
    return rows


def is_writable_row(line: str, in_example: bool) -> bool:
    if NORMATIVE_ROW.match(line):
        return True
    return in_example and bool(EXAMPLE_ROW.match(line))


def allowance(entry: dict, name: str) -> tuple[bool, str | None]:
    """(この file に許可があるか, 節を限る場合はその見出し)。"""
    for item in entry.get("allow", []):
        if isinstance(item, str):
            if item == name:
                return True, None
        elif item.get("file") == name:
            return True, item.get("section")
    return False, None


def files_to_scan(config: dict) -> list[Path]:
    found: list[Path] = []
    for pattern in config["scan"]:
        found.extend(Path().glob(pattern))
    excluded: set[Path] = set()
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

    annotated = {p.as_posix(): annotate(p.read_text(encoding="utf-8")) for p in paths}
    violations: list[str] = []

    for entry in config.get("owned", []):
        term = entry["term"]
        owner = entry["owner"]
        if not Path(owner).exists():
            violations.append(f"[owned] {term}: owner file が存在しません: {owner}")
            continue
        for name, rows in annotated.items():
            allowed, only_section = allowance(entry, name)
            for number, (line, in_example, section) in enumerate(rows, start=1):
                if term not in line:
                    continue
                if name == owner:
                    if not is_writable_row(line, in_example):
                        violations.append(
                            f"{name}:{number}: `{term}` を規範の行の外へ書いています。"
                            f"規範の行(REQ / INV / VER / OP)か、代表例の節の表にだけ書けます"
                        )
                elif not allowed:
                    violations.append(
                        f"{name}:{number}: `{term}` は {owner} が正本です。"
                        f"ここへ書き写さず、REQ ID で参照してください"
                    )
                elif only_section is not None and section != only_section:
                    violations.append(
                        f"{name}:{number}: `{term}` はこの file の "
                        f"`{only_section}` の中でだけ書けます(いまは "
                        f"`{section or '(見出しの外)'}`)。日付つきの記録以外へ書き写さないでください"
                    )

    for entry in config.get("forbidden", []):
        phrase = entry["phrase"]
        for name, rows in annotated.items():
            allowed, only_section = allowance(entry, name)
            for number, (line, _in_example, section) in enumerate(rows, start=1):
                if phrase not in line:
                    continue
                if allowed and (only_section is None or section == only_section):
                    continue
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
            f"scanned {len(paths)} file(s), {owned} owned term(s), "
            f"{forbidden} forbidden phrase(s)."
        )
        return 1

    print(
        f"PASS: {len(paths)} file(s), {owned} owned term(s), "
        f"{forbidden} forbidden phrase(s), 0 violations."
    )
    print(
        "注意: この検査は登録した literal の一致だけを見る。"
        "要求の強さ(断定 / 注記)や、literal を持たない REQ の範囲の書き写しは検出できない。"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
