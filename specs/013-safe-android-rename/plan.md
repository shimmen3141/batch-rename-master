# 013 Androidの安全なrename境界

## 目的

Androidで既存fileを置換しない原子的no-replaceと失敗時不変を維持しながら、利用者が選んだfileをrenameできるstorage・permission境界が存在するかを調査し、実装を約束する前に採用・不採用・制約付き採用の設計判断を出す。

## 境界

### 対象

- SAF以外のstorage方式、provider限定、MediaStore、app-owned storage、native filesystem API等の比較。
- permission、Android version、scoped storage、Play配布、privacy・利用者説明への影響。
- race、permission失効、stale handle、同名target、失敗時不変を観測する最小spike。

### 対象外

- production実装、UI導線、migration、配布申請。
- 005 INV-002のplatform例外やprovider依存raceの受容。
- SAF URIを未検証のraw pathへ変換するworkaround。

## 方針

005 contract revision 2のAndroid安全未対応を維持して調査する。一次資料と再現可能なspikeを区別し、storage方式・provider制限・追加権限・配布riskは人間の決定を得る。採用後のproduction実装は別taskまたは別planへ定義する。

## 全体の受け入れ証拠

- 候補ごとの原子的no-replace、失敗時不変、handle継続性が一次資料とspikeで区別される。
- permissionと配布制約が公式資料に接続される。
- 長期的なWhy/Why notを持つdecision recordで採否を判断できる。
- 005の安全なunsupportedとnegative testを弱めない。

## 人間の決定

| 日付 | 論点 | 決定 | 決定者 |
|---|---|---|---|
| 2026-08-09 | 現SAF APIがStrict no-replaceを保証できない | Android成功経路を005から分離し、最初の成果を調査と設計判断に限定する | 開発者 |

## タスク

| ID | 詳細 |
|---|---|
| T01 | [task.md](tasks/T01-decide-storage-boundary/task.md) |
