# Manual verification — desktop modified time

## Evidence identity

- Commit: pending
- Build/artifact: pending
- Environment/device: desktop OS
- Fixture/data: mtimeを比較できる複数fileと、mtime更新を拒否できるfixture
- Observer: pending
- Observed at: pending

## Checklist

1. optionはdesktopだけに表示され、既定OFFではmtimeを変更しない。
2. ONではrename成功fileのmtimeが表示順にずれる。
3. mtime更新に失敗してもrename成功と新しいhandleは維持され、副次失敗が区別して表示される。

## Result

- Status: pending
- Notes: Agentが対象branch、exact commit/build、検証workspaceを準備してから依頼する。人間によるbranch移動は原則不要。
