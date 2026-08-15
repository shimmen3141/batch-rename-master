#!/usr/bin/env python3
"""各mutationを当てて flutter test を走らせ、生の結果を表で出す。

手で当てて手で数えると、片方向だけ見て「確認した」と書く事故が起きる
(013:T11で5回)。当てた内容と結果を機械が並べる。
"""
import subprocess, shutil, sys, pathlib

MUTATIONS = [
    ("await除去", "lib/data/rename_exec/desktop_rename_executor.dart",
     "return await _renameViaTemporary(handle, destination, newName);",
     "return _renameViaTemporary(handle, destination, newName);"),
    ("1段目後の再観測除去", "lib/data/rename_exec/desktop_rename_executor.dart",
     "if (await _probe.exists(destination)) {\n      return _rollbackAfter(",
     "if (false) {\n      return _rollbackAfter("),
    ("退避先の実在確認除去", "lib/data/rename_exec/desktop_rename_executor.dart",
     "if (await _probe.exists(candidate)) continue;", ""),
    ("巻き戻し先の実在確認除去", "lib/data/rename_exec/desktop_rename_executor.dart",
     "if (await _probe.exists(handle)) {\n      rollback = NativeRenameResult.nameConflict;\n    } else {",
     "if (false) {\n      rollback = NativeRenameResult.nameConflict;\n    } else {"),
    ("一時名の長さ制限除去", "lib/data/rename_exec/desktop_rename_executor.dart",
     "final base = _temporaryBase(p.basename(handle));",
     "final base = p.basename(handle);"),
    ("確保ループを1回に", "lib/data/rename_exec/desktop_rename_executor.dart",
     "for (var n = 0; n < 32; n++) {", "for (var n = 0; n < 1; n++) {"),
    ("非nameConflictの早期return除去", "lib/data/rename_exec/desktop_rename_executor.dart",
     "if (result != NativeRenameResult.nameConflict) {", "if (false) {"),
    ("前進失敗時の巻き戻し除去", "lib/data/rename_exec/desktop_rename_executor.dart",
     "return _rollbackAfter(\n      temporary,\n      handle,\n      _nativeError(forward, handle, destination),\n    );",
     "return RenameFailed(_nativeError(forward, handle, destination));"),
    ("例外時の巻き戻し除去", "lib/data/rename_exec/desktop_rename_executor.dart",
     "return _rollbackAfter(temporary, handle, errorOf(error));",
     "return RenameFailed(errorOf(error));"),
    ("巻き戻し失敗の理由文除去", "lib/data/rename_exec/desktop_rename_executor.dart",
     "if (rollback == NativeRenameResult.success) return RenameFailed(reason);",
     "return RenameFailed(reason);"),
    ("生存名(1)占有名除去", "lib/data/rename_exec/rename_execution.dart",
     "final names = <String>{...?occupied[folder]};", "final names = <String>{};"),
    ("生存名(2)未実行の目標名除去", "lib/data/rename_exec/rename_execution.dart",
     "names.add(other.targetName); // (2)", "// (2) removed"),
    ("生存名(3)未実行の現在名除去", "lib/data/rename_exec/rename_execution.dart",
     "names.add(other.originalName); // (3)", "// (3) removed"),
    ("生存名(4)一時名除去", "lib/data/rename_exec/rename_execution.dart",
     "names.add(step.newName); // (4) 使用予定を含む", "// (4) removed"),
    ("生存名(5)確定名除去", "lib/data/rename_exec/rename_execution.dart",
     "live.recordSettled(step.request, attemptName);", ""),
    ("folder絞り(requests)除去", "lib/data/rename_exec/rename_execution.dart",
     "if (folderOf(other) != folder) continue;", ""),
    ("folder絞り(一時名)除去", "lib/data/rename_exec/rename_execution.dart",
     "if (folderOf(step.request) != folder) continue;", ""),
    ("再採番の除外(一時名)除去", "lib/data/rename_exec/rename_execution.dart",
     "final renumberable = step.kind == RenameStepKind.target;",
     "final renumberable = true;"),
    ("試行上限除去", "lib/data/rename_exec/rename_execution.dart",
     "attempts < renumberLimit", "true"),
    ("観測済み衝突名の記録除去", "lib/data/rename_exec/rename_execution.dart",
     "observedConflicts.add(attemptName);", ""),
    ("REQ-024の確認名記録除去", "lib/data/rename_exec/rename_execution.dart",
     "confirmedTargetName: step.request.targetName,", ""),
    ("REQ-024のUI提示除去", "lib/ui/file_list/file_list_view.dart",
     "if (renumbered.isEmpty) return Text(summary);",
     "if (true) return Text(summary);"),
]

def run():
    r = subprocess.run(["flutter", "test"], capture_output=True, text=True)
    return r.returncode == 0

rows = []
for name, path, old, new in MUTATIONS:
    f = pathlib.Path(path)
    original = f.read_text(encoding="utf-8")
    if old not in original:
        rows.append((name, "SKIP(対象が見つからない)"))
        continue
    try:
        f.write_text(original.replace(old, new, 1), encoding="utf-8")
        rows.append((name, "SURVIVED(testが落ちない)" if run() else "KILLED"))
    finally:
        f.write_text(original, encoding="utf-8")

width = max(len(n) for n, _ in rows)
for name, result in rows:
    print(f"{name.ljust(width)}  {result}")
survived = [n for n, r in rows if not r.startswith("KILLED")]
print()
print(f"KILLED {len(rows)-len(survived)}/{len(rows)}")
if survived:
    print("要対応: " + ", ".join(survived))
sys.exit(1 if survived else 0)
