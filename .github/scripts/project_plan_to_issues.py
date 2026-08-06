#!/usr/bin/env python3
"""承認済み plan.md のタスクを GitHub Issue へ投影(projection)する決定的な同期ツール。

方向は plan.md → Issue の一方向。正本は plan.md。Issue は下流の投影。
タスクの identity は Tn(不変)。plan.md の issue 列(#N)を実体ポインタ、Issue 本文の
marker `<!-- asdd:<feature>:Tn -->` をバックアップ照合に使う。

このスクリプトは以下を機械的に行う:
- plan.md のタスク表とタスク詳細をパース
- 既存 asdd Issue(この機能の marker に限定)と突合
- 未リンクのタスク→ Issue 作成 / 内容差分→本文更新 / done→close / 破棄→close
- blocked ラベルの付け外し、依存リンクの解決、issue 番号の plan.md への書き戻し

判断が要る不整合(行 Tn と Issue marker の食い違い= renumber 疑い、参照先 Issue の消失)は
**推測せず flag として報告**し、そのタスクには触れない(呼び出し側の AI/人間が解決する)。

assignee(claim)は run-plan の管轄であり、このスクリプトは一切触らない。

使い方:
    python project_plan_to_issues.py <plan.md> [--apply] [--dry-run] [--json]
既定は dry-run(副作用なし)。--apply で実際に gh を叩く。
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

LABEL = "asdd"
BLOCKED_LABEL = "blocked"
MARKER_RE = re.compile(r"<!--\s*asdd:(?P<feature>[^:]+):(?P<tn>T\d+)\s*-->")


# --------------------------------------------------------------------------- #
# データ構造
# --------------------------------------------------------------------------- #
@dataclass
class Task:
    tn: str
    name: str
    deps: list[str]
    status: str  # pending / in_progress / done / blocked
    issue_num: Optional[int]
    change_target: str = ""
    acceptance: list[str] = field(default_factory=list)


@dataclass
class Issue:
    number: int
    marker_tn: Optional[str]
    state: str  # OPEN / CLOSED
    labels: list[str]
    body: str


@dataclass
class Plan:
    creates: list[str] = field(default_factory=list)          # tn
    links: list[tuple[str, int]] = field(default_factory=list)  # (tn, number) 既存Issueに紐付く
    closes: list[tuple[int, str]] = field(default_factory=list)  # (number, reason) 破棄
    writebacks: list[tuple[str, int]] = field(default_factory=list)  # (tn, number) issue列を埋める
    flags: list[str] = field(default_factory=list)            # 人間/AIが解決すべき不整合


# --------------------------------------------------------------------------- #
# パース(純粋)
# --------------------------------------------------------------------------- #
def feature_slug_from_path(plan_path: Path) -> str:
    """specs/<NNN>-<機能名>/plan.md → <NNN>-<機能名>。"""
    return plan_path.resolve().parent.name


def plan_status(text: str) -> str:
    """plan.md ヘッダの `- 状態: <status>` を返す(承認ゲート用)。"""
    m = re.search(r"^-\s*状態\s*[:：]\s*(\w+)", text, re.MULTILINE)
    return m.group(1) if m else ""


def _split_row(line: str) -> list[str]:
    # エスケープされたパイプ(`\|`)はセル区切りではない。この扱いは run_plan_helper.py と
    # 同一でなければならない(index が概要をエスケープして書くため。CONTRIBUTING 参照)
    inner = line.strip().strip("|")
    return [c.strip().replace("\\|", "|") for c in re.split(r"(?<!\\)\|", inner)]


def parse_plan(text: str) -> list[Task]:
    lines = text.splitlines()
    tasks_by_tn: dict[str, Task] = {}
    order: list[str] = []

    # --- タスク表 ---
    in_table = False
    header: list[str] = []
    for i, line in enumerate(lines):
        if line.strip().startswith("## タスク一覧"):
            in_table = True
            header = []
            continue
        if in_table:
            if line.strip().startswith("##"):
                in_table = False
                continue
            if not line.strip().startswith("|"):
                continue
            cells = _split_row(line)
            if not header:
                header = cells
                continue
            if set(cells) <= {"", "-"} or all(set(c) <= {"-", ":"} for c in cells):
                continue  # 区切り行
            row = dict(zip(header, cells))
            tn = row.get("ID", "").strip()
            if not re.fullmatch(r"T\d+", tn):
                continue
            issue_raw = row.get("issue", "").strip().lstrip("#").strip()
            issue_num = int(issue_raw) if issue_raw.isdigit() else None
            deps_raw = row.get("依存", "").strip()
            deps = [] if deps_raw in ("", "-") else [d.strip() for d in deps_raw.split(",") if d.strip()]
            tasks_by_tn[tn] = Task(
                tn=tn,
                name=row.get("タスク", "").strip(),
                deps=deps,
                status=row.get("状態", "").strip(),
                issue_num=issue_num,
            )
            order.append(tn)

    # --- タスク詳細(### Tn: ...) ---
    detail_re = re.compile(r"^###\s+(T\d+)\s*[:：]?\s*(.*)$")
    current: Optional[str] = None
    section: dict[str, list[str]] = {}
    for line in lines:
        m = detail_re.match(line)
        if m:
            current = m.group(1)
            section[current] = []
            continue
        if current is not None:
            if line.startswith("## "):
                current = None
            else:
                section[current].append(line)

    for tn, body_lines in section.items():
        if tn not in tasks_by_tn:
            continue
        task = tasks_by_tn[tn]
        task.change_target = _extract_field(body_lines, "変更対象")
        task.acceptance = _extract_list(body_lines, "受け入れ条件")

    return [tasks_by_tn[tn] for tn in order]


def _extract_field(lines: list[str], label: str) -> str:
    for line in lines:
        m = re.match(rf"^\s*[-*]\s*{re.escape(label)}\s*[:：]\s*(.*)$", line)
        if m:
            return m.group(1).strip()
    return ""


def _extract_list(lines: list[str], label: str) -> list[str]:
    out: list[str] = []
    capturing = False
    base_indent = 0
    for line in lines:
        m = re.match(rf"^(\s*)[-*]\s*{re.escape(label)}\s*[:：]\s*(.*)$", line)
        if m:
            capturing = True
            base_indent = len(m.group(1))
            if m.group(2).strip():
                out.append(m.group(2).strip())
            continue
        if capturing:
            sub = re.match(r"^(\s*)[-*]\s*\[[ xX]?\]\s*(.*)$|^(\s*)[-*]\s+(.*)$", line)
            if sub and len(line) - len(line.lstrip()) > base_indent:
                text = sub.group(2) or sub.group(4) or ""
                if text.strip():
                    out.append(text.strip())
            elif line.strip() and not line.lstrip().startswith(("-", "*")):
                capturing = False
            elif re.match(r"^\s*[-*]\s*\S+\s*[:：]", line):
                capturing = False
    return out


def parse_issues(issues_json: str, feature_slug: str) -> list[Issue]:
    """gh issue list --json ... の出力を、この機能の marker を持つ Issue に限定して返す。"""
    data = json.loads(issues_json) if issues_json.strip() else []
    result: list[Issue] = []
    for it in data:
        body = it.get("body") or ""
        m = MARKER_RE.search(body)
        marker_feature = m.group("feature") if m else None
        marker_tn = m.group("tn") if m else None
        # この機能の Issue に限定(他機能を絶対に触らない)
        if marker_feature != feature_slug:
            continue
        result.append(
            Issue(
                number=int(it["number"]),
                marker_tn=marker_tn,
                state=str(it.get("state", "")).upper(),
                labels=[lab.get("name", "") for lab in it.get("labels", [])],
                body=body,
            )
        )
    return result


# --------------------------------------------------------------------------- #
# reconcile(純粋・テスト対象の核)
# --------------------------------------------------------------------------- #
def reconcile(tasks: list[Task], issues: list[Issue]) -> Plan:
    plan = Plan()
    issue_by_number = {iss.number: iss for iss in issues}

    # 重複 marker(同じ Tn を持つ Issue が複数)は一意に紐付けられないので保護して報告
    marker_counts: dict[str, int] = {}
    for iss in issues:
        if iss.marker_tn:
            marker_counts[iss.marker_tn] = marker_counts.get(iss.marker_tn, 0) + 1
    duplicate_markers = {tn for tn, c in marker_counts.items() if c > 1}
    issue_by_marker = {iss.marker_tn: iss for iss in issues if iss.marker_tn and iss.marker_tn not in duplicate_markers}
    for tn in sorted(duplicate_markers):
        plan.flags.append(f"marker {tn} を持つ Issue が複数ある(重複)。手で1つに統合を")

    # 重複 Tn(plan.md 側)も一意でないので保護して報告
    tn_counts: dict[str, int] = {}
    for t in tasks:
        tn_counts[t.tn] = tn_counts.get(t.tn, 0) + 1
    duplicate_tns = {tn for tn, c in tn_counts.items() if c > 1}
    for tn in sorted(duplicate_tns):
        plan.flags.append(f"{tn}: plan.md にタスク ID が重複している。Tn は一意にすること")

    task_tns = {t.tn for t in tasks}
    linked_numbers: set[int] = set()
    protected_numbers: set[int] = set()   # flag した Issue は破棄 close から除外

    seen_tns: set[str] = set()
    for task in tasks:
        if task.tn in duplicate_tns:
            continue  # 重複タスクは触らない(flag 済み)
        if task.tn in seen_tns:
            continue
        seen_tns.add(task.tn)
        if task.issue_num is not None:
            iss = issue_by_number.get(task.issue_num)
            if iss is None:
                plan.flags.append(
                    f"{task.tn}: plan は Issue #{task.issue_num} を参照するが該当 Issue が見つからない"
                    f"(削除された? 手で確認を)"
                )
                continue
            if iss.marker_tn is not None and iss.marker_tn != task.tn:
                plan.flags.append(
                    f"{task.tn}: 参照先 Issue #{iss.number} の marker は {iss.marker_tn}(不一致)。"
                    f"採番のし直し(renumber)や取り違えの疑い — Tn は不変が原則。手で確認を"
                )
                protected_numbers.add(iss.number)
                continue
            plan.links.append((task.tn, iss.number))
            linked_numbers.add(iss.number)
        elif task.tn in duplicate_markers:
            continue  # marker 重複で再リンク先を一意に決められない(flag 済み)
        else:
            iss = issue_by_marker.get(task.tn)
            if iss is not None:
                # issue 列は空だが marker で復元できる → 再リンクして番号を書き戻す
                plan.links.append((task.tn, iss.number))
                plan.writebacks.append((task.tn, iss.number))
                linked_numbers.add(iss.number)
            else:
                plan.creates.append(task.tn)

    # 破棄検出: 対応タスクが plan.md に無い Issue。ただし linked / protected / 重複 marker は除外
    for iss in issues:
        if iss.number in linked_numbers or iss.number in protected_numbers:
            continue
        if not iss.marker_tn or iss.marker_tn in duplicate_markers:
            continue
        if iss.marker_tn not in task_tns and iss.state != "CLOSED":
            plan.closes.append((iss.number, f"計画変更により破棄: {iss.marker_tn} が plan.md から削除された"))

    return plan


# --------------------------------------------------------------------------- #
# Issue 本文/状態の期待値(純粋)
# --------------------------------------------------------------------------- #
def issue_title(feature_slug: str, task: Task) -> str:
    return f"[{feature_slug}] {task.tn}: {task.name}"


def issue_body(feature_slug: str, task: Task, tn_to_number: dict[str, int]) -> str:
    dep_parts = []
    for dep in task.deps:
        num = tn_to_number.get(dep)
        dep_parts.append(f"#{num}({dep})" if num else dep)
    dep_line = "、".join(dep_parts) if dep_parts else "なし"
    lines = [
        f"計画: specs/{feature_slug}/plan.md の {task.tn}(この Issue は計画の投影。正本は plan.md)",
        f"依存: {dep_line}",
        "受け入れ条件:",
    ]
    lines += [f"- {a}" for a in (task.acceptance or ["(plan.md のタスク詳細を参照)"])]
    if task.change_target:
        lines.append(f"変更対象: {task.change_target}")
    lines.append(f"<!-- asdd:{feature_slug}:{task.tn} -->")
    return "\n".join(lines)


def desired_closed(task: Task) -> bool:
    return task.status == "done"


def desired_blocked(task: Task) -> bool:
    return task.status == "blocked"


def bodies_differ(current: str, desired: str) -> bool:
    norm = lambda s: "\n".join(l.rstrip() for l in s.strip().splitlines())
    return norm(current) != norm(desired)


# --------------------------------------------------------------------------- #
# 副作用(gh)
# --------------------------------------------------------------------------- #
def gh(args: list[str]) -> str:
    result = subprocess.run(["gh", *args], capture_output=True, text=True, encoding="utf-8")
    if result.returncode != 0:
        raise RuntimeError(f"gh {' '.join(args)} failed: {result.stderr.strip()}")
    return result.stdout


def ensure_labels() -> None:
    for name, color in ((LABEL, "1f6feb"), (BLOCKED_LABEL, "b60205")):
        try:
            gh(["label", "create", name, "--color", color])
        except RuntimeError:
            pass  # 既存


def create_issue(title: str, body: str) -> int:
    out = gh(["issue", "create", "--title", title, "--body", body, "--label", LABEL])
    m = re.search(r"/issues/(\d+)", out)
    if not m:
        raise RuntimeError(f"could not parse issue number from: {out.strip()}")
    return int(m.group(1))


def write_back_issue_column(text: str, writebacks: list[tuple[str, int]]) -> str:
    """plan.md のタスク表の issue 列に番号を書き戻す(該当行の issue セルのみ)。"""
    mapping = dict(writebacks)
    lines = text.splitlines(keepends=True)
    header: list[str] = []
    issue_idx = -1
    id_idx = -1
    in_table = False
    for i, line in enumerate(lines):
        if line.strip().startswith("## タスク一覧"):
            in_table = True
            header = []
            continue
        if in_table:
            if line.strip().startswith("##"):
                in_table = False
                continue
            if not line.strip().startswith("|"):
                continue
            cells = _split_row(line)
            if not header:
                header = cells
                issue_idx = header.index("issue") if "issue" in header else -1
                id_idx = header.index("ID") if "ID" in header else -1
                continue
            if issue_idx < 0 or id_idx < 0:
                continue
            if id_idx >= len(cells):
                continue
            tn = cells[id_idx].strip()
            if tn in mapping and issue_idx < len(cells):
                cells[issue_idx] = f"#{mapping[tn]}"
                lines[i] = "| " + " | ".join(cells) + " |\n"
    return "".join(lines)


# --------------------------------------------------------------------------- #
# main
# --------------------------------------------------------------------------- #
def build_report(plan: Plan) -> dict:
    return {
        "creates": plan.creates,
        "links": plan.links,
        "closes": plan.closes,
        "writebacks": plan.writebacks,
        "flags": plan.flags,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Project plan.md tasks to GitHub issues.")
    parser.add_argument("plan", type=Path)
    parser.add_argument("--apply", action="store_true", help="実際に gh を叩く(既定は dry-run)")
    parser.add_argument("--dry-run", action="store_true", help="副作用なしで変更予定のみ表示(--apply より優先)")
    parser.add_argument("--no-close-done", action="store_true",
                        help="done タスクでも Issue を close しない(PR運用時: PR の Closes #N に任せる)")
    parser.add_argument("--json", action="store_true", help="レポートを JSON で出力")
    args = parser.parse_args()
    apply = args.apply and not args.dry_run

    text = args.plan.read_text(encoding="utf-8")
    feature_slug = feature_slug_from_path(args.plan)

    # 承認ゲート: draft の計画は投影しない(CI 直実行でも安全に)
    status = plan_status(text)
    if status not in ("approved", "in_progress", "done"):
        print(f"[skip] {feature_slug}: 計画が承認されていない(状態: {status or '不明'})。投影しない")
        return 0

    tasks = parse_plan(text)

    # gh issue list は読み取り専用なので dry-run でも実行し、正確な preview を出す
    issues_json = gh([
        "issue", "list", "--label", LABEL, "--state", "all",
        "--json", "number,title,body,state,labels", "--limit", "1000",
    ])
    issues = parse_issues(issues_json, feature_slug)

    plan = reconcile(tasks, issues)

    if not apply:
        report = build_report(plan)
        print(json.dumps(report, ensure_ascii=False, indent=2) if args.json else _text_report(plan, dry=True))
        return 2 if plan.flags else 0

    ensure_labels()
    tn_to_number: dict[str, int] = {t.tn: t.issue_num for t in tasks if t.issue_num}
    for tn, num in plan.links:
        tn_to_number[tn] = num

    task_by_tn = {t.tn: t for t in tasks}
    issue_by_number = {iss.number: iss for iss in issues}

    # 1) 作成(番号を確定させる)
    for tn in plan.creates:
        task = task_by_tn[tn]
        num = create_issue(issue_title(feature_slug, task), issue_body(feature_slug, task, tn_to_number))
        tn_to_number[tn] = num
        plan.writebacks.append((tn, num))

    # 2) 本文・状態・ラベルの同期(全番号が出揃ってから依存を解決する2パス目)
    created_set = set(plan.creates)
    synced_tns = plan.creates + [tn for tn, _ in plan.links]
    for tn in synced_tns:
        task = task_by_tn[tn]
        num = tn_to_number[tn]
        desired_body = issue_body(feature_slug, task, tn_to_number)
        current = issue_by_number.get(num)
        # 新規作成タスクは、作成時に前方依存の番号が未確定だったので必ず本文を再同期する
        if tn in created_set or current is None or bodies_differ(current.body, desired_body):
            gh(["issue", "edit", str(num), "--body", desired_body])
        # 状態(--no-close-done 時は done→close をスキップし PR の Closes #N に任せる)
        want_closed = desired_closed(task) and not args.no_close_done
        cur_closed = current.state == "CLOSED" if current else False
        if want_closed and not cur_closed:
            gh(["issue", "close", str(num)])
        elif not desired_closed(task) and cur_closed:
            gh(["issue", "reopen", str(num)])
        # blocked ラベル
        has_blocked = BLOCKED_LABEL in current.labels if current else False
        want_blocked = desired_blocked(task)
        if want_blocked and not has_blocked:
            gh(["issue", "edit", str(num), "--add-label", BLOCKED_LABEL])
        elif not want_blocked and has_blocked:
            gh(["issue", "edit", str(num), "--remove-label", BLOCKED_LABEL])

    # 3) 破棄
    for num, reason in plan.closes:
        gh(["issue", "close", str(num), "--comment", reason])

    # 4) issue 列の書き戻し
    if plan.writebacks:
        args.plan.write_text(write_back_issue_column(text, plan.writebacks), encoding="utf-8")

    print(json.dumps(build_report(plan), ensure_ascii=False, indent=2) if args.json else _text_report(plan, dry=False))
    return 2 if plan.flags else 0


def _text_report(plan: Plan, dry: bool) -> str:
    head = "[dry-run] 以下を行う予定:" if dry else "投影しました:"
    out = [head]
    out.append(f"  作成: {', '.join(plan.creates) or 'なし'}")
    out.append(f"  リンク: {', '.join(f'{tn}->#{n}' for tn, n in plan.links) or 'なし'}")
    out.append(f"  破棄close: {', '.join(f'#{n}' for n, _ in plan.closes) or 'なし'}")
    if plan.flags:
        out.append("  要確認(触っていない):")
        out += [f"    - {f}" for f in plan.flags]
    return "\n".join(out)


if __name__ == "__main__":
    raise SystemExit(main())
