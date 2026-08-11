# Manual verification — target platform file selection

## Evidence identity

- Commit: pending
- Build/artifact: pending
- Environment/device: Android SAF and desktop OS
- Fixture/data: 種類・日時・親directoryの異なる複数file
- Observer: pending
- Observed at: pending

## Checklist

### Android SAF

1. 種類を選び、複数fileを確定すると既存一覧が選択集合で置き換わる。cancel時は一覧が不変。
2. 同じfileを重複選択しても同一handleは一件だけになり、別directoryの同名fileは別件として残る。
3. 種類跨ぎ・作成日時不明のwarningが仕様どおり表示され、取得不能値を更新日時で代用しない。

### Desktop

1. 複数fileの選択、一覧の置換、cancel時の不変を確認する。
2. 各entryが元のabsolute pathを保持し、同一pathを重複させない。

## Result

- Status: pending
- Notes: branch移動は原則不要。Agentが対象branch、exact commit/build、検証workspaceを準備してから依頼する。
