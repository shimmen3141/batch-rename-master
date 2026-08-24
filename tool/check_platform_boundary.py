#!/usr/bin/env python3
"""OS判定とnative宣言が、決めた境界の外へ漏れていないかを検査する。

`013:T05`で独立reviewが3回連続FAILし、3回とも同じ型だった — 「production が実際に
通る合成を、test が一度も通らない」。原因は個々のtest不足ではなく、**Linux 1環境しか
無いのにDart側へOS分岐を書ける**という構造だった。ADR-003でOS identityをnative境界
(C と `hook/build.dart`)へ閉じ込めると決め、この検査でその決定を固定する。

**原則は「この依存が存在しないこと」を見る。**「この行が存在すること」は format 変更や
変数の導入で壊れ、semantic regression ではなく refactoring を検出してしまうためである。

**例外は `required` だけ**である。Linux 上では**振る舞いで観測できない** platform 分岐
(composition root の `if (Platform.isAndroid) ...`)を固定する手段が他に無いので、
そこだけ行の存在を見る。**代償は承知している** — 意味を変えない書き換えでも落ちる。
だから `required` は増やさず、閉じられるものは `rules`(依存の不在)側で閉じる。

対象と許可は `tool/normative_platform.json` が持つ。project-native の道具であり、
ASDD plugin 側の共有 script ではない。

## この検査で捕まらないもの(PASS を「OS分岐は無い」と読まないこと)

- **文字列一致である。** `const io = Platform; io.isAndroid` のような間接化は見ない。
  `required` も同じで、**同じ意味を別の書き方で満たしても「無い」と判定する**。
  壊れやすさは承知のうえで、Linux 上では振る舞いで観測できない platform 分岐を
  固定する手段が他に無いために置いている。
- **見るのは登録した pattern だけ。** `Platform.is*` と `Platform.operatingSystem` は
  禁止できるが、`Platform.pathSeparator` など他のメンバで OS を判定する書き方は捕まらない。
- **見るのは `lib/**/*.dart` だけ。** test、`tool/`、`hook/build.dart` は対象外。
- **C の `#if defined(__ANDROID__)` は対象外。** あそこは正しい置き場所である。
  C の Android 分岐が実際に動くかは `013:T08` の実機確認が見る。
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

CONFIG = Path("tool/normative_platform.json")


def files_to_scan(config: dict) -> list[Path]:
    found: list[Path] = []
    for pattern in config["scan"]:
        found.extend(Path().glob(pattern))
    return sorted({p for p in found if p.is_file()})


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
    for rule in config["rules"]:
        pattern = rule["pattern"]
        allow = set(rule.get("allow", []))
        # 許可した file が消えていたら、許可も一緒に消す必要がある。
        # 放っておくと「もう存在しない例外」が残り、次の追加を素通しさせる。
        for name in sorted(allow):
            if not Path(name).exists():
                violations.append(
                    f"{CONFIG}: `{pattern}` の allow に、存在しない file が"
                    f"残っています: {name}"
                )
        for path in paths:
            name = path.as_posix()
            if name in allow:
                continue
            for number, line in enumerate(
                path.read_text(encoding="utf-8").split("\n"), start=1
            ):
                # doc comment の中の言及は違反にしない。実際の依存だけを見る。
                if line.lstrip().startswith("///") or line.lstrip().startswith("//"):
                    continue
                if pattern in line:
                    violations.append(
                        f"{name}:{number}: `{pattern}` はここに書けません。"
                        f"{rule['reason']}"
                    )

    # **必ず在る行**の検査。allow(禁止)の逆で、消えたら落ちる。
    # Linux 上では振る舞いで観測できない platform 分岐(composition root)を固定する。
    for rule in config.get("required", []):
        path = Path(rule["file"])
        if not path.exists():
            violations.append(f"{rule['file']}: file がありません")
            continue
        if rule["pattern"] not in path.read_text(encoding="utf-8"):
            violations.append(
                f"{rule['file']}: 必ず在るはずの行がありません: "
                f"`{rule['pattern']}`。{rule['reason']}"
            )

    if violations:
        for v in violations:
            print(f"FAIL: {v}")
        print(
            f"\n{len(violations)} violation(s). "
            f"scanned {len(paths)} file(s), {len(config['rules'])} rule(s), "
            f"{len(config.get('required', []))} required line(s)."
        )
        return 1

    print(
        f"PASS: {len(paths)} file(s), {len(config['rules'])} rule(s), "
        f"{len(config.get('required', []))} required line(s), 0 violations."
    )
    print(
        "注意: この検査は文字列一致で「禁止された依存が無いこと」と"
        "「必ず在る行があること」だけを見る。間接化した OS 判定や、"
        "C 側の platform 分岐は対象外である。"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
