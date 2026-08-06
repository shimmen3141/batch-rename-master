#!/usr/bin/env python3
"""plan.md の機械可読部分を書き・読むための共有ヘルパー。

ASDD では plan.md は「LLM が書く散文」と「スクリプトがパースする台帳」の二重の性格を持つ。
台帳部分(タスク表・状態・ログ)を LLM が手書きすると書式がドリフトするため、**台帳の書き込みは
すべてこのスクリプトが行う**。LLM に残すのは判断(どのタスクを選ぶか、実装、verifier 判定)と、
タスク詳細の散文だけ。

サブコマンド:

  読む:
    eligible <plan>        依存が全て done の pending タスクを列挙(承認ゲート等は適用しない)
    coverage [<plan>...]   仕様 ↔ 計画 ↔ 検証実体 の被覆を照合する
    brief <plan> <Tn>      verifier へ渡す判定材料(受け入れ条件 + 参照仕様の原文)を組み立てる
    index                  specs/README.md を全 plan.md から再生成する

  書く:
    claim <plan> <Tn>      状態を in_progress にし、着手ログを追記する
    done  <plan> <Tn>      状態を done/blocked にし、完了ログを追記する
    log   <plan> <Tn>      任意の1行をタスクのログへ追記する
    migrate <plan>         旧書式(仕様列なし・末尾の作業ログ節)を現行書式へ移行する

plan.md のタスク表の書式は project_plan_to_issues.py と共有する。変更時は両方を同期する
(CONTRIBUTING「変更時チェックリスト」)。
"""

from __future__ import annotations

import argparse
import datetime as _dt
import json
import re
import sys
from pathlib import Path
from typing import Callable, Iterable, Optional

ID_ROW_RE = re.compile(r"^\|\s*((?:REQ|INV|OP|SM|NFR|CON|VER)-[0-9A-Za-z_-]+)\s*\|")
# 「対象外・未定義とする点」等に書く送り先。`→ 008-ui-polish` / `-> 008-ui-polish`
OUTLET_RE = re.compile(r"(?:→|->)\s*([0-9]{3}-[A-Za-z0-9_.-]+)")
NO_OUTLET_MARK = "意図的に不要"
OUTLET_SECTIONS = ("対象外・未定義とする点", "この機能だけでは未完成な点")


# --------------------------------------------------------------------------- #
# 表の最小パース
# --------------------------------------------------------------------------- #
def _split_row(line: str) -> list[str]:
    inner = line.strip().strip("|")
    return [p.strip().replace("\\|", "|") for p in re.split(r"(?<!\\)\|", inner)]


def _cell(value: str) -> str:
    """表セルに入れる値のパイプをエスケープする。"""
    return value.replace("|", "\\|")


def _join_row(cells: Iterable[str]) -> str:
    return "| " + " | ".join(_cell(c) for c in cells) + " |"


def _is_separator(cells: list[str]) -> bool:
    return all(set(c) <= {"-", ":", ""} for c in cells)


def _comment_blocks(lines: list[str]) -> list[list[str]]:
    """行範囲から HTML コメントを <!-- 〜 --> のブロック単位で取り出す(複数行対応)。"""
    blocks: list[list[str]] = []
    i = 0
    while i < len(lines):
        if "<!--" in lines[i]:
            block = [lines[i]]
            while "-->" not in lines[i] and i + 1 < len(lines):
                i += 1
                block.append(lines[i])
            blocks.append(block)
        i += 1
    return blocks


def _flatten(blocks: list[list[str]]) -> list[str]:
    return [ln for block in blocks for ln in block]


def task_table(lines: list[str]) -> tuple[Optional[int], list[str], list[int]]:
    """「## タスク一覧」の表から (ヘッダ行番号, ヘッダセル, データ行番号) を返す。"""
    in_table = False
    header_idx: Optional[int] = None
    header: list[str] = []
    rows: list[int] = []
    for i, line in enumerate(lines):
        stripped = line.strip()
        if stripped.startswith("## タスク一覧"):
            in_table = True
            continue
        if not in_table:
            continue
        if stripped.startswith("##"):
            break
        if not stripped.startswith("|"):
            continue
        cells = _split_row(line)
        if header_idx is None:
            header_idx, header = i, cells
            continue
        if _is_separator(cells):
            continue
        if cells and re.fullmatch(r"T\d+", cells[0].strip()):
            rows.append(i)
    return header_idx, header, rows


def parse_tasks(text: str) -> list[dict]:
    """タスク表から {tn, name, deps, spec, status} を返す。"""
    lines = text.splitlines()
    header_idx, header, rows = task_table(lines)
    if header_idx is None:
        return []
    tasks: list[dict] = []
    for r in rows:
        row = dict(zip(header, _split_row(lines[r])))
        deps_raw = row.get("依存", "").strip()
        deps = [] if deps_raw in ("", "-") else [d.strip() for d in deps_raw.split(",") if d.strip()]
        spec_raw = row.get("仕様", "").strip()
        specs = [] if spec_raw in ("", "-") else [s.strip() for s in spec_raw.split(",") if s.strip()]
        tasks.append({
            "tn": row.get("ID", "").strip(),
            "name": row.get("タスク", "").strip(),
            "deps": deps,
            "spec": specs,
            "status": row.get("状態", "").strip(),
        })
    return tasks


def header_field(text: str, label: str) -> str:
    m = re.search(rf"^-\s*{re.escape(label)}\s*[:：]\s*(.+)$", text, re.MULTILINE)
    if not m:
        return ""
    return re.sub(r"<!--.*?-->", "", m.group(1)).strip()  # 行末の HTML コメントを除去


def background_summary(text: str) -> str:
    grab = False
    for line in text.splitlines():
        if line.strip().startswith("## 背景・目的"):
            grab = True
            continue
        if grab:
            if line.strip().startswith("##"):
                break
            if line.strip():
                return re.sub(r"\s+", " ", line.strip())[:60]
    return ""


def derived_plan_status(header_status: str, tasks: list[dict]) -> str:
    """計画の進行状態をタスクから導出する。

    人間が持つのは draft → approved の承認ゲートだけで、in_progress / done は導出値。
    (旧書式の in_progress / done ヘッダは approved と同じに扱い、導出結果で上書きする)
    """
    if header_status == "draft" or not header_status:
        return header_status or "draft"
    if not tasks:
        return "approved"
    if all(t["status"] == "done" for t in tasks):
        return "done"
    if any(t["status"] in ("in_progress", "done", "blocked") for t in tasks):
        return "in_progress"
    return "approved"


# --------------------------------------------------------------------------- #
# plan.md への書き込み
# --------------------------------------------------------------------------- #
def set_task_status(text: str, tn: str, status: str) -> tuple[str, str]:
    """タスク表の状態セルを書き換える。戻り値は (新しい本文, 旧状態)。"""
    lines = text.splitlines()
    header_idx, header, rows = task_table(lines)
    if header_idx is None:
        raise ValueError("タスク一覧の表が見つからない")
    if "状態" not in header or "ID" not in header:
        raise ValueError("タスク表に ID / 状態 列が無い")
    id_i, st_i = header.index("ID"), header.index("状態")
    for r in rows:
        cells = _split_row(lines[r])
        if len(cells) <= max(id_i, st_i) or cells[id_i].strip() != tn:
            continue
        old = cells[st_i].strip()
        cells[st_i] = status
        lines[r] = _join_row(cells)
        return "\n".join(lines) + "\n", old
    raise KeyError(f"{tn} がタスク表に無い")


def _task_section(lines: list[str], tn: str) -> tuple[Optional[int], int]:
    """`### Tn: ...` 節の (見出し行番号, 節の終端行番号) を返す。"""
    start: Optional[int] = None
    for i, line in enumerate(lines):
        if re.match(rf"^###\s+{re.escape(tn)}\b", line.strip()):
            start = i
            break
    if start is None:
        return None, -1
    end = len(lines)
    for j in range(start + 1, len(lines)):
        if re.match(r"^##\s|^###\s", lines[j]):
            end = j
            break
    while end > start + 1 and not lines[end - 1].strip():
        end -= 1
    return start, end


def append_task_log(text: str, tn: str, entry: str) -> str:
    """タスク詳細の `- ログ:` へ1行追記する(無ければ作る)。

    ログを plan.md 末尾の単一セクションではなくタスク節ごとに置くことで、
    別タスクのブランチ同士が同じ行を触らなくなる(追記どうしの衝突を構造的に消す)。
    """
    lines = text.splitlines()
    start, end = _task_section(lines, tn)
    if start is None:
        raise KeyError(f"{tn} のタスク詳細(### {tn})が無い")
    log_i: Optional[int] = None
    for j in range(start + 1, end):
        if re.match(r"^-\s*ログ\s*[:：]", lines[j].strip()):
            log_i = j
            break
    if log_i is None:
        lines.insert(end, "- ログ:")
        lines.insert(end + 1, f"  - {entry}")
    else:
        insert_at = log_i + 1
        while insert_at < end and re.match(r"^\s{2,}-\s", lines[insert_at]):
            insert_at += 1
        lines.insert(insert_at, f"  - {entry}")
    return "\n".join(lines) + "\n"


# --------------------------------------------------------------------------- #
# eligible(純粋)
# --------------------------------------------------------------------------- #
def eligible_tasks(plan_text: str, status_lookup: Callable[[str], str]) -> tuple[list[dict], list[str]]:
    """依存が全て done の pending タスクを row 順で返す。戻り値は (eligible, diagnostics)。

    status_lookup(ref) -> status。ref は同一計画内の "Tn" か、機能横断の "<slug>.Tn"。
    承認ゲート・blocked・中断回収は適用しない(run-plan の判断)。
    解決できない依存(存在しない Tn / slug = typo・未作成の疑い)は diagnostics に出す。
    """
    tasks = parse_tasks(plan_text)
    own = {t["tn"]: t["status"] for t in tasks}
    out: list[dict] = []
    diagnostics: list[str] = []
    for t in tasks:
        if t["status"] != "pending":
            continue
        ok = True
        for dep in t["deps"]:
            st = own.get(dep) if "." not in dep else status_lookup(dep)
            if not st:
                diagnostics.append(f"{t['tn']}: 依存 {dep} を解決できない(存在しない? plan/タスク名を確認)")
                ok = False
                break
            if st != "done":
                ok = False
                break
        if ok:
            out.append({"tn": t["tn"], "name": t["name"], "spec": t["spec"]})
    return out, diagnostics


# --------------------------------------------------------------------------- #
# 仕様の読み取り(Light: spec.md / Strict: contracts/behavior-contract.json)
# --------------------------------------------------------------------------- #
def parse_light_spec(md: str) -> dict:
    """spec.md の表から ID を拾う。表の列順に依存しすぎない緩いパース。"""
    ids: dict[str, str] = {}          # id -> 原文(行の要旨)
    must: set[str] = set()
    verifications: list[dict] = []
    for line in md.splitlines():
        m = ID_ROW_RE.match(line)
        if not m:
            continue
        cells = _split_row(line)
        ident = cells[0].strip()
        rest = [c.strip() for c in cells[1:]]
        ids[ident] = " / ".join(c for c in rest if c)
        if ident.startswith("REQ-") and any(c == "must" for c in rest):
            must.add(ident)
        if ident.startswith("VER-"):
            # | ID | 種別 | 成果物パス | 対象 |
            artifact = rest[1] if len(rest) > 1 else ""
            covers_raw = rest[2] if len(rest) > 2 else ""
            verifications.append({
                "id": ident,
                "type": rest[0] if rest else "",
                "artifact": artifact,
                "covers": [c.strip() for c in re.split(r"[,、/]", covers_raw) if c.strip()],
            })
    return {"ids": ids, "must": must, "verifications": verifications, "level": "Light"}


def parse_strict_contract(contract: dict) -> dict:
    ids: dict[str, str] = {}
    must: set[str] = set()
    verifications: list[dict] = []
    for group in ("requirements", "invariants", "operations", "state_machines",
                  "quality_attributes", "implementation_constraints"):
        for item in contract.get(group, []):
            if not isinstance(item, dict) or not item.get("id"):
                continue
            ident = str(item["id"])
            ids[ident] = str(item.get("statement") or item.get("name") or "")
            if group == "requirements" and item.get("priority") == "must":
                must.add(ident)
    for item in contract.get("verification", []):
        if not isinstance(item, dict) or not item.get("id"):
            continue
        ident = str(item["id"])
        ids[ident] = str(item.get("artifact", ""))
        verifications.append({
            "id": ident,
            "type": str(item.get("type", "")),
            "artifact": str(item.get("artifact", "")),
            "covers": [str(c) for c in item.get("covers", []) if isinstance(c, str)],
        })
    return {"ids": ids, "must": must, "verifications": verifications, "level": "Strict"}


def load_spec(plan_dir: Path, spec_header: str) -> Optional[dict]:
    """計画ヘッダの `- 仕様:` に従って仕様を読む。仕様なしなら None。"""
    if not spec_header or spec_header.startswith("なし"):
        return None
    if "Strict" in spec_header:
        path = plan_dir / "contracts" / "behavior-contract.json"
        if not path.is_file():
            return {"ids": {}, "must": set(), "verifications": [], "level": "Strict", "missing": str(path)}
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            return {"ids": {}, "must": set(), "verifications": [], "level": "Strict",
                    "error": f"{path}: JSON が壊れている({exc.msg})"}
        parsed = parse_strict_contract(data)
        parsed["status"] = str(data.get("status", ""))
        parsed["path"] = str(path)
        return parsed
    path = plan_dir / "spec.md"
    if not path.is_file():
        return {"ids": {}, "must": set(), "verifications": [], "level": "Light", "missing": str(path)}
    md = path.read_text(encoding="utf-8")
    parsed = parse_light_spec(md)
    parsed["status"] = header_field(md, "Status")
    parsed["path"] = str(path)
    parsed["markdown"] = md
    return parsed


def parse_outlets(md: str) -> list[dict]:
    """「対象外・未定義とする点」等の箇条書きから送り先を拾う。

    各項目は `→ <NNN>-<機能名>` を持つか、`意図的に不要` と書かれていなければならない。
    これがないと「仕様の対象外にしたが、誰も作らない作業」が宙に浮く(FINDINGS の無主地問題)。
    """
    out: list[dict] = []
    section = ""
    for line in md.splitlines():
        stripped = line.strip()
        if stripped.startswith("#"):
            heading = stripped.lstrip("#").strip()
            section = heading if any(s in heading for s in OUTLET_SECTIONS) else ""
            continue
        if not section or not stripped.startswith("-"):
            continue
        body = stripped.lstrip("-").strip()
        if not body or body.startswith("<"):
            continue
        m = OUTLET_RE.search(body)
        out.append({
            "section": section,
            "text": body,
            "dest": m.group(1) if m else None,
            "intentional": NO_OUTLET_MARK in body,
        })
    return out


# --------------------------------------------------------------------------- #
# coverage(仕様 ↔ 計画 ↔ 検証実体)
# --------------------------------------------------------------------------- #
def _artifact_files(root: Path, artifact: str) -> list[Path]:
    """VER の成果物パス(ファイル or ディレクトリ)を実ファイル列に解決する。"""
    if not artifact or artifact in ("-", "n/a"):
        return []
    target = root / artifact
    if target.is_file():
        return [target]
    if target.is_dir():
        return [p for p in sorted(target.rglob("*")) if p.is_file()]
    return []


def coverage_report(plan_path: Path, specs_dir: Path, repo_root: Path) -> dict:
    """1つの計画について、仕様 ↔ 計画 ↔ 検証実体 の被覆を照合する。"""
    text = plan_path.read_text(encoding="utf-8")
    plan_dir = plan_path.parent
    tasks = parse_tasks(text)
    errors: list[str] = []
    warnings: list[str] = []
    notes: list[str] = []

    spec = load_spec(plan_dir, header_field(text, "仕様"))
    if spec is None:
        return {"plan": str(plan_path), "errors": [], "warnings": [], "notes": ["仕様なしの計画(照合対象外)"]}
    if spec.get("error"):
        return {"plan": str(plan_path), "errors": [spec["error"]], "warnings": [], "notes": []}
    if spec.get("missing"):
        return {"plan": str(plan_path), "errors": [],
                "warnings": [f"仕様ファイルが未作成: {spec['missing']}(T1 未着手なら正常)"], "notes": []}

    assigned: dict[str, list[str]] = {}
    for t in tasks:
        for ident in t["spec"]:
            assigned.setdefault(ident, []).append(t["tn"])

    # 1) 計画 → 仕様: 存在しない ID を参照していないか(typo / 削除済み)
    for ident, tns in sorted(assigned.items()):
        if ident not in spec["ids"]:
            errors.append(f"{'/'.join(tns)} が参照する {ident} は仕様に定義が無い(typo か削除済み)")

    # VER は「明示的に割り当てられている」か「覆う対象が全て割り当て済み」なら担当ありとみなす
    # (検証は要件の担当タスクが書くのが既定。仕様列に VER まで並べさせない = 記述量を増やさない)
    def ver_owners(ver: dict) -> Optional[list[str]]:
        if ver["id"] in assigned:
            return assigned[ver["id"]]
        owners: list[str] = []
        for ident in ver["covers"]:
            if ident not in assigned:
                return None
            owners += assigned[ident]
        return owners or None

    ver_owner_map = {v["id"]: ver_owners(v) for v in spec["verifications"]}
    task_status = {t["tn"]: t["status"] for t in tasks}

    # 2) 仕様 → 計画: 担当タスクの無い規範 ID(= 承認したのに誰も実装しない要件)
    for ident in sorted(spec["ids"]):
        if ident in assigned:
            continue
        prefix = ident.split("-")[0]
        if prefix == "VER":
            if ver_owner_map.get(ident) is None:
                errors.append(f"{ident} を担当するタスクが無い(覆う対象も未割当。仕様列に割り当てる)")
        elif ident in spec["must"] or prefix in ("INV", "OP", "SM", "CON"):
            errors.append(f"{ident} を担当するタスクが無い(タスク表の仕様列に割り当てる)")
        elif prefix in ("REQ", "NFR"):
            warnings.append(f"{ident}(must ではない)を担当するタスクが無い")

    # 3) VER → 検証実体: 成果物パスが実在するか / covers の ID がテストから辿れるか。
    #    担当タスクが未完了のうちは未作成が正常なので、note に落として進行中のノイズを避ける
    for ver in spec["verifications"]:
        if ver["type"] == "manual":
            continue
        owners = ver_owner_map.get(ver["id"]) or []
        pending = [tn for tn in owners if task_status.get(tn) != "done"]
        files = _artifact_files(repo_root, ver["artifact"])
        if not files:
            msg = f"{ver['id']} の成果物 '{ver['artifact']}' が存在しない"
            if pending:
                notes.append(f"{msg}(担当 {'/'.join(sorted(set(pending)))} が未完了なら正常)")
            else:
                errors.append(f"{msg}(テストを分割したならパスをディレクトリに広げる)")
            continue
        blob = ""
        for f in files:
            try:
                blob += f.read_text(encoding="utf-8", errors="replace")
            except OSError as exc:  # 読めないファイルは照合対象から外すだけ
                warnings.append(f"{ver['id']}: {f} を読めない({exc})")
        for ident in ver["covers"]:
            if ident in blob:
                continue
            msg = (f"{ver['id']} は {ident} を覆うと宣言しているが、"
                   f"{ver['artifact']} に {ident} が現れない(宣言だけで未検証の疑い)")
            if pending:
                notes.append(msg + " ※担当タスクが未完了")
            else:
                warnings.append(msg)

    # 4) 送り先: 仕様が対象外にした作業が宙に浮いていないか(無主地の検出)
    for outlet in parse_outlets(spec.get("markdown", "")):
        if outlet["intentional"]:
            continue
        if not outlet["dest"]:
            errors.append(f"「{outlet['section']}」の項目に送り先が無い: {outlet['text'][:40]}"
                          f"(`→ <NNN>-<機能名>` か `{NO_OUTLET_MARK}` を書く)")
            continue
        dest_plan = specs_dir / outlet["dest"] / "plan.md"
        if not dest_plan.is_file():
            errors.append(f"送り先 {outlet['dest']} の計画が存在しない: {outlet['text'][:40]}")
            continue
        dest_tasks = parse_tasks(dest_plan.read_text(encoding="utf-8"))
        if not dest_tasks or not all(t["status"] == "done" for t in dest_tasks):
            notes.append(f"利用者から見て未完成: {outlet['text'][:40]} は {outlet['dest']} 待ち")

    return {"plan": str(plan_path), "errors": errors, "warnings": warnings, "notes": notes}


# --------------------------------------------------------------------------- #
# brief(verifier へ渡す判定材料)
# --------------------------------------------------------------------------- #
def verifier_brief(plan_path: Path, tn: str) -> str:
    """タスク詳細と、受け入れ条件が参照する仕様の原文を1つのブロックにまとめる。

    verifier に仕様を探させないための組み立てを機械化する(渡し忘れると verifier は推測する)。
    """
    text = plan_path.read_text(encoding="utf-8")
    lines = text.splitlines()
    start, end = _task_section(lines, tn)
    if start is None:
        raise KeyError(f"{tn} のタスク詳細(### {tn})が無い")
    task = next((t for t in parse_tasks(text) if t["tn"] == tn), None)
    if task is None:
        raise KeyError(f"{tn} がタスク表に無い")

    parts = [f"# 判定対象: {plan_path.parent.name} {tn}", "", "## タスク詳細(plan.md より)", ""]
    parts += lines[start:end]

    spec = load_spec(plan_path.parent, header_field(text, "仕様"))
    if spec and task["spec"]:
        parts += ["", f"## 参照する仕様の原文({spec.get('path', '')} / status: {spec.get('status', '?')})", ""]
        for ident in task["spec"]:
            body = spec["ids"].get(ident)
            parts.append(f"- **{ident}**: {body}" if body else f"- **{ident}**: (仕様に定義が無い — 要確認)")
        cmds = sorted({v["artifact"] for v in spec["verifications"]
                       if v["type"] != "manual" and set(v["covers"]) & set(task["spec"])})
        if cmds:
            parts += ["", "## 実行すべき検証(仕様の VER 成果物)", ""]
            parts += [f"- {c}" for c in cmds]
        if spec["level"] == "Strict":
            parts += ["", f"- `spec_lint.py {spec.get('path', '')} --strict` が PASS すること"]
    return "\n".join(parts) + "\n"


# --------------------------------------------------------------------------- #
# index(README 再生成)
# --------------------------------------------------------------------------- #
def spec_cell(plan_dir: Path, spec_header: str) -> str:
    """計画ヘッダの `- 仕様:` と実ファイルの状態から README の仕様セルを作る。"""
    if not spec_header or spec_header.startswith("なし"):
        return "-"
    level = "Strict" if "Strict" in spec_header else ("Light" if "Light" in spec_header else "?")
    spec = load_spec(plan_dir, spec_header)
    status = (spec or {}).get("status", "")
    return f"{status} ({level})" if status else f"予定({level})"


def collect_features(specs_dir: Path) -> list[dict]:
    features: list[dict] = []
    for plan_path in sorted(specs_dir.glob("[0-9][0-9][0-9]-*/plan.md")):
        text = plan_path.read_text(encoding="utf-8")
        tasks = parse_tasks(text)
        done = sum(1 for t in tasks if t["status"] == "done")
        cross: list[tuple[str, str]] = []
        dep_features: set[str] = set()
        for t in tasks:
            for dep in t["deps"]:
                if "." in dep:
                    dep_features.add(dep.split(".")[0])
                    cross.append((t["tn"], dep))
        features.append({
            "slug": plan_path.parent.name,
            "plan_status": derived_plan_status(header_field(text, "状態"), tasks),
            "spec": spec_cell(plan_path.parent, header_field(text, "仕様")),
            "progress": f"{done}/{len(tasks)}",
            "dep_features": sorted(dep_features),
            "summary": background_summary(text),
            "cross": cross,
        })
    return features


def regenerate_index(readme_text: str, features: list[dict]) -> str:
    """表と機能間依存だけを再生成する。**概要列も plan.md から毎回生成する**(手編集列を持たない)。

    手編集列があると「再生成したから同期済み」と誤認され、かつ並列 PR で必ず衝突する。
    """
    lines = readme_text.splitlines()

    h = next((i for i, l in enumerate(lines)
              if l.strip().startswith("|") and "機能" in l and "概要" in l), None)
    if h is None:
        raise RuntimeError("README にインデックス表のヘッダが見つからない(asdd-setup を先に)")
    sep = h + 1

    i = sep + 1
    table_comments: list[list[str]] = []
    while i < len(lines):
        s = lines[i].strip()
        if s.startswith("|"):
            i += 1
        elif "<!--" in s:
            block = [lines[i]]
            while "-->" not in lines[i] and i + 1 < len(lines):
                i += 1
                block.append(lines[i])
            table_comments.append(block)
            i += 1
        else:
            break
    table_end = i

    new_rows = [
        _join_row([
            f"[{f['slug']}]({f['slug']}/plan.md)", f["plan_status"], f["spec"], f["progress"],
            "、".join(f["dep_features"]) if f["dep_features"] else "-", f["summary"],
        ])
        for f in features
    ]
    cross_bullets = [f"- {f['slug']}.{own_tn} → {dep}"
                     for f in features for own_tn, dep in f["cross"]]

    dep_idx = next((j for j in range(table_end, len(lines))
                    if lines[j].strip().startswith("## 機能間のタスク依存")), None)

    head = lines[:sep + 1] + new_rows + _flatten(table_comments)
    if dep_idx is None:
        result = head + lines[table_end:]
    else:
        dep_end = next((j for j in range(dep_idx + 1, len(lines))
                        if lines[j].strip().startswith("## ")), len(lines))
        dep_comments = _comment_blocks(lines[dep_idx + 1:dep_end])
        body = [lines[dep_idx], ""] + cross_bullets + (["", *_flatten(dep_comments)] if dep_comments else [])
        result = head + lines[table_end:dep_idx] + body + lines[dep_end:]

    return "\n".join(result) + "\n"


# --------------------------------------------------------------------------- #
# migrate(旧書式 → 現行書式)
# --------------------------------------------------------------------------- #
LOG_LINE_RE = re.compile(r"^(?P<date>\d{4}-\d{2}-\d{2}[^/]*)/\s*(?P<tn>T\d+)\s*/\s*(?P<rest>.+)$")


def migrate_plan(text: str) -> tuple[str, list[str]]:
    """旧書式の plan.md を現行書式へ移行する。戻り値は (新本文, 実施した変更)。

    1. タスク表に「仕様」列(値は `-`)を挿入する
    2. 末尾の「## 作業ログ」の行を、対応するタスク詳細の `- ログ:` へ移す
    3. ヘッダの状態が in_progress / done なら approved に戻す(進行状態は導出値になったため)
    """
    changes: list[str] = []
    lines = text.splitlines()

    header_idx, header, rows = task_table(lines)
    if header_idx is not None and "仕様" not in header:
        at = header.index("状態") if "状態" in header else len(header)
        targets = [header_idx] + rows
        if header_idx + 1 < len(lines) and _is_separator(_split_row(lines[header_idx + 1])):
            targets.insert(1, header_idx + 1)
        for r in targets:
            cells = _split_row(lines[r])
            if r == header_idx:
                cells.insert(at, "仕様")
            elif _is_separator(cells):
                cells.insert(at, "------")
            else:
                cells.insert(at, "-")
            lines[r] = _join_row(cells) if not _is_separator(cells) else "|" + "|".join(cells) + "|"
        changes.append("タスク表に「仕様」列を挿入した(値は未割当の `-`)")

    text = "\n".join(lines) + "\n"

    def _log_section(source: list[str]) -> Optional[int]:
        # 「未移行」に退避済みの節は再処理しない(移行を冪等にする)
        return next((i for i, l in enumerate(source)
                     if l.strip().startswith("## 作業ログ") and "未移行" not in l), None)

    log_start = _log_section(text.splitlines())
    if log_start is not None:
        lines = text.splitlines()
        log_end = next((j for j in range(log_start + 1, len(lines))
                        if lines[j].strip().startswith("## ")), len(lines))
        moved, kept = 0, []
        for raw in lines[log_start + 1:log_end]:
            body = raw.strip()
            if not body or body.startswith("<!--") or body.startswith("-->"):
                continue
            m = LOG_LINE_RE.match(body.lstrip("-").strip())
            if not m:
                kept.append(raw)
                continue
            entry = f"{m.group('date').strip()} / {m.group('rest').strip()}"
            try:
                text = append_task_log("\n".join(lines) + "\n", m.group("tn"), entry)
                lines = text.splitlines()
                log_start = _log_section(lines) or log_start
                log_end = next((j for j in range(log_start + 1, len(lines))
                                if lines[j].strip().startswith("## ")), len(lines))
                moved += 1
            except KeyError:
                kept.append(raw)
        remainder = lines[:log_start] + (
            ["## 作業ログ(未移行 — 手で振り分ける)", ""] + kept + [""] if kept else []
        ) + lines[log_end:]
        text = "\n".join(remainder).rstrip("\n") + "\n"
        changes.append(f"作業ログ {moved} 行をタスク詳細へ移した" + (f"(未移行 {len(kept)} 行)" if kept else ""))

    status = header_field(text, "状態")
    if status in ("in_progress", "done"):
        text = re.sub(r"^(-\s*状態\s*[:：]\s*)\w+", r"\1approved", text, count=1, flags=re.MULTILINE)
        changes.append(f"ヘッダの状態 {status} → approved(進行状態はタスクから導出されるため)")

    # 状態行の説明コメントが旧語彙のままだと、読んだエージェントが進行状態を書き戻してしまう
    stale = re.compile(r"^(-\s*状態\s*[:：]\s*\w+\s*)<!--[^>]*in_progress[^>]*-->", re.MULTILINE)
    if stale.search(text):
        text = stale.sub(r"\1<!-- draft → approved(人間が変更)。進行状態はタスクから導出される -->", text)
        changes.append("状態行の説明コメントを現行の語彙に更新した")

    return text, changes


# --------------------------------------------------------------------------- #
# CLI
# --------------------------------------------------------------------------- #
def _today() -> str:
    return _dt.date.today().isoformat()


def cmd_index(args: argparse.Namespace) -> int:
    specs = Path(args.specs)
    readme = specs / "README.md"
    if not readme.is_file():
        print(f"ERROR: {readme} が無い。asdd-setup を先に実行", file=sys.stderr)
        return 1
    out = regenerate_index(readme.read_text(encoding="utf-8"), collect_features(specs))
    if args.stdout:
        print(out, end="")
    else:
        readme.write_text(out, encoding="utf-8")
        print(f"index 同期: {len(collect_features(specs))} 機能")
    return 0


def cmd_eligible(args: argparse.Namespace) -> int:
    specs = Path(args.specs)
    plan_text = Path(args.plan).read_text(encoding="utf-8")

    def status_lookup(ref: str) -> str:
        slug, tn = ref.split(".", 1)
        other = specs / slug / "plan.md"
        if not other.is_file():
            return ""
        for t in parse_tasks(other.read_text(encoding="utf-8")):
            if t["tn"] == tn:
                return t["status"]
        return ""

    out, diagnostics = eligible_tasks(plan_text, status_lookup)
    for d in diagnostics:
        print(f"WARNING: {d}", file=sys.stderr)
    if args.json:
        print(json.dumps({"eligible": out, "diagnostics": diagnostics}, ensure_ascii=False))
    else:
        print("\n".join(f"{t['tn']}: {t['name']}" for t in out) if out
              else "(依存を満たす pending タスクなし)")
    return 0


def cmd_coverage(args: argparse.Namespace) -> int:
    specs = Path(args.specs)
    repo_root = Path(args.root)
    plans = [Path(p) for p in args.plans] or sorted(specs.glob("[0-9][0-9][0-9]-*/plan.md"))
    reports = [coverage_report(p, specs, repo_root) for p in plans]
    failed = any(r["errors"] for r in reports)
    if args.json:
        print(json.dumps({"passed": not failed, "reports": reports}, ensure_ascii=False, indent=2))
        return 1 if failed else 0
    for r in reports:
        print(f"--- {r['plan']}")
        for e in r["errors"]:
            print(f"  ERROR: {e}")
        for w in r["warnings"]:
            print(f"  WARNING: {w}")
        for n in r["notes"]:
            print(f"  NOTE: {n}")
        if not (r["errors"] or r["warnings"] or r["notes"]):
            print("  OK")
    print("FAIL" if failed else "PASS")
    return 1 if failed else 0


def cmd_brief(args: argparse.Namespace) -> int:
    print(verifier_brief(Path(args.plan), args.tn), end="")
    return 0


def _write_log(plan: Path, tn: str, status: Optional[str], entry: str) -> None:
    text = plan.read_text(encoding="utf-8")
    if status:
        text, old = set_task_status(text, tn, status)
        print(f"{tn}: {old} → {status}")
    plan.write_text(append_task_log(text, tn, entry), encoding="utf-8")
    print(f"ログ追記: {entry}")


def cmd_claim(args: argparse.Namespace) -> int:
    _write_log(Path(args.plan), args.tn, "in_progress", f"{_today()} / 着手 / 担当: {args.owner}")
    return 0


def cmd_done(args: argparse.Namespace) -> int:
    parts = [_today(), args.result]
    if args.verifier:
        parts.append(f"verifier {args.verifier}(試行{args.attempts})")
    if args.note:
        parts.append(args.note)
    _write_log(Path(args.plan), args.tn, args.result, " / ".join(parts))
    return 0


def cmd_log(args: argparse.Namespace) -> int:
    _write_log(Path(args.plan), args.tn, None, f"{_today()} / {args.text}")
    return 0


def cmd_migrate(args: argparse.Namespace) -> int:
    plan = Path(args.plan)
    new_text, changes = migrate_plan(plan.read_text(encoding="utf-8"))
    if not changes:
        print(f"{plan}: 移行不要(現行書式)")
        return 0
    if args.apply:
        plan.write_text(new_text, encoding="utf-8")
    print(f"{plan}: " + ("適用" if args.apply else "dry-run"))
    for c in changes:
        print(f"  - {c}")
    if not args.apply:
        print("  (--apply で書き込む)")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="plan.md の台帳を読み書きする共有ヘルパー")
    parser.add_argument("--specs", default="specs", help="specs ディレクトリ(既定: specs)")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_idx = sub.add_parser("index", help="specs/README.md を再生成")
    p_idx.add_argument("--stdout", action="store_true", help="書き込まず標準出力に出す")
    p_idx.set_defaults(func=cmd_index)

    p_el = sub.add_parser("eligible", help="依存を満たす pending タスクを列挙")
    p_el.add_argument("plan")
    p_el.add_argument("--json", action="store_true")
    p_el.set_defaults(func=cmd_eligible)

    p_cov = sub.add_parser("coverage", help="仕様 ↔ 計画 ↔ 検証実体 の被覆を照合")
    p_cov.add_argument("plans", nargs="*", help="省略時は specs/ 配下の全計画")
    p_cov.add_argument("--root", default=".", help="成果物パスの基準(既定: カレント)")
    p_cov.add_argument("--json", action="store_true")
    p_cov.set_defaults(func=cmd_coverage)

    p_br = sub.add_parser("brief", help="verifier へ渡す判定材料を組み立てる")
    p_br.add_argument("plan")
    p_br.add_argument("tn")
    p_br.set_defaults(func=cmd_brief)

    p_cl = sub.add_parser("claim", help="タスクを in_progress にし着手ログを書く")
    p_cl.add_argument("plan")
    p_cl.add_argument("tn")
    p_cl.add_argument("--owner", required=True)
    p_cl.set_defaults(func=cmd_claim)

    p_dn = sub.add_parser("done", help="タスクを done/blocked にし完了ログを書く")
    p_dn.add_argument("plan")
    p_dn.add_argument("tn")
    p_dn.add_argument("--result", choices=("done", "blocked"), default="done")
    p_dn.add_argument("--verifier", choices=("PASS", "FAIL"), default=None)
    p_dn.add_argument("--attempts", type=int, default=1)
    p_dn.add_argument("--note", default="")
    p_dn.set_defaults(func=cmd_done)

    p_lg = sub.add_parser("log", help="タスクのログへ1行追記する")
    p_lg.add_argument("plan")
    p_lg.add_argument("tn")
    p_lg.add_argument("text")
    p_lg.set_defaults(func=cmd_log)

    p_mg = sub.add_parser("migrate", help="旧書式の plan.md を現行書式へ移行")
    p_mg.add_argument("plan")
    p_mg.add_argument("--apply", action="store_true")
    p_mg.set_defaults(func=cmd_migrate)

    args = parser.parse_args()
    return int(args.func(args))


if __name__ == "__main__":
    raise SystemExit(main())
