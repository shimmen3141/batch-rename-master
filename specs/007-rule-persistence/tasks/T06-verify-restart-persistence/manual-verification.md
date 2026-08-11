# Manual verification — rule persistence across restart

## Evidence identity

- Commit: pending
- Build/artifact: pending
- Environment/device: Android and desktop OS
- Fixture/data: 元名、自由text、連番、日時tokenを区別できるrule
- Observer: pending
- Observed at: pending

## Checklist

1. ruleを設定してpreviewへ反映されたことを確認する。
2. hot reloadではなくアプリprocessを終了し、同じbuildを再起動する。
3. token種別・値・順序が保存前と一致し、previewも同じになることをAndroidとdesktopで確認する。
4. 必要なら空値・壊れた値のfallbackは既存自動testの証拠を参照し、実dataを不用意に破壊しない。

## Result

- Status: pending
- Notes: branch移動は原則不要。Agentが対象branch、exact commit/build、検証workspaceを準備してから依頼する。
