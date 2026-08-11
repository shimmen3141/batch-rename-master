# Manual verification — empty rule UI

## Evidence identity

- Commit: pending
- Build/artifact: pending
- Environment/device: Android and desktop UI
- Fixture/data: 空ruleと、tokenを一つ追加したrule
- Observer: pending
- Observed at: pending

## Checklist

1. 空ruleではrenameを開始できず、「未設定」と設定への導線が明確に表示される。
2. tokenを追加すると同じ画面で通常状態へ戻り、rename actionが利用可能になる。
3. 空名warningと未設定表示が重複・競合しない。

## Result

- Status: pending
- Notes: Agentが対象branch、exact commit/build、検証workspaceを準備してから依頼する。人間によるbranch移動は原則不要。
