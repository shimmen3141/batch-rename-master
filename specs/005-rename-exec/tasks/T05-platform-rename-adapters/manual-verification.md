# Manual verification — platform rename adapters

## Evidence identity

- Commit: b866e35b50307e26d0eb90f77d1721782243b32a
- Build/artifact: pending — 上記commitから作成したartifact識別情報を記録する
- Environment/device: Android minSdk 24対象device/emulator、desktop OS
- Fixture/data: source、既存target、permission拒否directory、内容比較可能なfile
- Observer: pending
- Observed at: pending

## Checklist

### Android

1. minSdk 24対象buildが成功する。
2. renameを実行しても成功件数は0で、Strict no-replaceを保証できないため未対応である理由が表示される。
3. provider renameは実行されず、元fileと既存targetの名前・個数・内容が不変。同じ操作を再度行っても不変。

### Desktop

1. 実fileをrenameでき、続くrenameが更新後pathを使う。
2. 既存targetとの競合では両fileの名前・個数・内容が不変で、競合理由が表示される。
3. permission拒否directoryではsourceが残り、targetは作られず、権限拒否理由が表示される。

## Result

- Status: pending
- Notes: Agentが対象branch、exact commit/build、検証workspaceを準備して維持する。人間によるbranch移動は原則不要。
