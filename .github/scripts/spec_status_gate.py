#!/usr/bin/env python3
"""PR が触った仕様が `draft` のままなら失敗する CI ゲート。

なぜ必要か: PR のマージは「進め方の合意」であって仕様の承認ではない。しかし PR を
マージすると承認したつもりになりやすく、実運用では仕様作成タスク(T1)の PR を
spec が draft のまま統合し、承認を別 PR で後追いする手戻りが起きた。
「approved 化は人間が行う」という規約は散文でしかなく、マージボタンは散文を読まない。

このゲートは「PR で変更された仕様ファイル」だけを見る。既存の draft 仕様(まだ着手して
いない機能)は無関係なので落とさない。

**削除も検査対象**。仕様の廃止は `status: deprecated` で行う手続きであり、ファイルごと消すと
承認済みの正しさの定義が履歴からしか辿れなくなる。削除は読めないので status を解決できず、
「変更が無かった」と見分けがつかない — そのため `git diff --name-status` の状態コードを使う。

使い方:
    python spec_status_gate.py <変更されたファイル...>
    git diff --name-status <base>...HEAD | python spec_status_gate.py
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Callable, Optional

STATUS_RE = re.compile(r"^-\s*Status\s*[:：]\s*(\w+)", re.MULTILINE)
LEVEL_RE = re.compile(r"^-\s*Level\s*[:：]\s*(Light|Strict)", re.MULTILINE)


def contract_path_for(spec_md_path: str) -> str:
    """spec.md と同じ機能ディレクトリの契約パス(規約の配置)。

    区切りは `/` に正規化する。呼び出し側が渡すのは git 由来のパス(`specs/001-a/spec.md`)
    なので、Windows の `\\` に変換すると読み手側の辞書・差分と一致しなくなる。
    """
    return (Path(spec_md_path).parent / "contracts" / "behavior-contract.json").as_posix()


def _contract_status(text: str) -> Optional[str]:
    try:
        data = json.loads(text)
    except json.JSONDecodeError:
        return None
    return str(data.get("status", "")) if isinstance(data, dict) else None


def resolve_status(path: str, read: Callable[[str], str]) -> Optional[tuple[str, str]]:
    """仕様ファイルの承認状態を、規約が定める正本に従って解決する。

    戻り値は (status, 正本のパス)。仕様ファイルでなければ None。

    **Strict では契約(behavior-contract.json)が正本**で、spec.md 側はそれを参照するだけ
    (規約「仕様の承認状態の正本」)。この解決をフックと CI ゲートで共有しないと、
    同じ ASDD 規約に対して2つの実装が別々の判定を出す。
    """
    name = Path(path).name
    if name == "behavior-contract.json":
        try:
            status = _contract_status(read(path))
        except OSError:
            return None
        return (status, path) if status is not None else None
    if name != "spec.md":
        return None
    try:
        text = read(path)
    except OSError:
        return None
    head = "\n".join(text.splitlines()[:20])
    level = LEVEL_RE.search(head)
    if not level:
        return None  # ASDD 由来の spec.md ではない
    if level.group(1) == "Strict":
        contract = contract_path_for(path)
        try:
            status = _contract_status(read(contract))
        except OSError:
            status = None  # 契約が未作成(T1 の途中)なら spec.md 側で判断する
        if status is not None:
            return status, contract
    match = STATUS_RE.search(head)
    return (match.group(1) if match else ""), path


def spec_status(path: str, text: str) -> Optional[str]:
    """テキストだけから status を読む(そのファイル1枚しか無い前提。主にテスト用)。"""
    def read_only_this(target: str) -> str:
        if target != path:
            raise OSError(target)
        return text

    resolved = resolve_status(path, read_only_this)
    return resolved[0] if resolved else None


def is_spec_path(path: str) -> bool:
    return Path(path).name in ("spec.md", "behavior-contract.json")


def parse_change(line: str) -> tuple[str, str]:
    """`git diff --name-status` の1行を (状態コード, パス) にする。

    状態コード無しの素のパス(`--name-only` 出力や引数)は "M" 扱いにする。
    リネーム/コピー(`R100 old new`)は新しい側を見る。
    """
    parts = line.rstrip("\n").split("\t")
    if len(parts) >= 2 and parts[0] and parts[0][0] in "AMDRCTUX":
        return parts[0][0], parts[-1]
    return "M", parts[0]


def gate_changes(changes: list[tuple[str, str]], read: Callable[[str], str]) -> list[str]:
    """変更された仕様を検査する。draft の持ち込みと、仕様ファイルの削除を止める。"""
    problems: list[str] = []
    for code, path in changes:
        if code == "D" and is_spec_path(path):
            problems.append(
                f"{path}: 仕様ファイルが削除されています。仕様の廃止は "
                f"status を `deprecated` にして行い、ファイルは残してください"
                f"(承認済みの正しさの定義が履歴からしか辿れなくなるため)"
            )
    problems += gate([path for code, path in changes if code != "D"], read)
    return problems


def gate(paths: list[str], read: Callable[[str], str]) -> list[str]:
    """draft のまま持ち込まれた仕様を列挙する。"""
    problems: list[str] = []
    seen: set[str] = set()
    for path in paths:
        resolved = resolve_status(path, read)
        if resolved is None:
            continue  # 仕様ファイルでない / PR で削除された
        status, source = resolved
        if source in seen:
            continue  # spec.md と契約の両方が PR に含まれる場合、正本は1回だけ見る
        seen.add(source)
        if status != "approved":
            problems.append(
                f"{source}: Status が '{status or '未記載'}' です。"
                f"仕様の approved 化は人間のレビューを経て行い、そのうえでマージしてください"
            )
    return problems


def main() -> int:
    parser = argparse.ArgumentParser(
        description="PR が触った仕様の承認状態を検査する"
                    "(標準入力は `git diff --name-status` の出力を受け付ける)"
    )
    parser.add_argument("paths", nargs="*", help="変更されたファイルのパス")
    args = parser.parse_args()
    if args.paths:
        changes = [("M", p) for p in args.paths]
    else:
        changes = [parse_change(line) for line in sys.stdin if line.strip()]
    problems = gate_changes(changes, lambda p: Path(p).read_text(encoding="utf-8"))
    for problem in problems:
        print(f"ERROR: {problem}")
    print("FAIL" if problems else "PASS: 変更された仕様はすべて approved(または仕様の変更なし)")
    return 1 if problems else 0


if __name__ == "__main__":
    raise SystemExit(main())
