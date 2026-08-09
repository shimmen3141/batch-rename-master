# 開発単位: Androidの安全なrename境界を設計する

## 目的

AndroidでINV-002の原子的no-replaceとOP-004の失敗時不変を満たしながら、利用者が選んだfileをrenameできるstorage・permission境界が存在するかを調査し、実装を約束せず採用・不採用・制約付き採用の設計判断を出す。

## 根拠

- 依頼・issue・PRD: Issue #96から分離する2026-08-09の開発者判断
- 関連コード・既存仕様: `specs/005-rename-exec/contracts/behavior-contract.json` revision 2、`specs/005-rename-exec/decisions/ADR-001-android-saf-rename-safety.md`
- 関連するdevelopment unit: `development-units/complete-rename-execution/`

## 境界

### 対象

- SAF以外のstorage方式が、選択・継続permission・原子的no-replaceを同時に提供できるかの調査。
- providerを限定する案について、識別可能性、端末差、fallback、利用者への制約を調査。
- MediaStore、app-owned storage、native filesystem API、DocumentProvider拡張等の候補について、Android versionとscoped storage下の実現可能性を比較。
- `MANAGE_EXTERNAL_STORAGE`等の権限、Play配布審査、privacy・利用者説明への影響を比較。
- race、permission失効、stale handle、同名target、失敗時不変を観測する最小spikeと設計判断。

### 対象外

- production実装、UI導線、migration、配布申請。採用判断後に別development unitとして定義する。
- INV-002のplatform例外やprovider依存raceの受容。
- SAF URIを未検証のraw pathへ変換するworkaround。

## 重要な決定

| 日付 | 決定 | 対象仕様・revisionまたは意味差分 | 理由・決定者 |
|---|---|---|---|
| 2026-08-09 | 最初の成果を実装ではなく調査と設計判断に限定する | 005 contract revision 2のAndroid安全未対応を維持 | 現SAF境界では原子的no-replaceを証明できず、storage・権限・配布制約の選択が利用者とdata riskを変えるため / 開発者 |

## 受け入れ証拠

| 観測する成果 | 証拠・実行方法 |
|---|---|
| 各候補の原子的no-replace、失敗時不変、handle継続性が一次資料とspikeで区別される | Android公式資料への参照、対象API/version/providerを固定した再現可能なspike結果 |
| permissionと配布制約が明示される | Android/Google Playの公式policy・API資料と、要求権限・対象versionの比較 |
| 採用・不採用・制約付き採用のいずれかを判断できる | 長期的なWhy/Why notを持つdecision recordと、未検証領域・必要な次unitの明示 |
| 現productionの安全未対応を弱めない | 005 contract revision 2と既存negative testが引き続きPASS |

## リスクと進め方

- 曖昧さ: high — storage方式、provider制限、権限、配布可能性で利用者体験が変わる。
- 失敗コスト: high — 誤判断は既存file置換、permission逸脱、配布不能につながる。
- 共有調整: required — 新しい親Issueをlive statusと人間判断の正本にする。
- 振る舞い仕様: 調査中は新規production仕様を作らない。採用判断後、既存005 contractの新revisionまたは新unitのspecを人間承認してから実装する。
- 実行依存マップ: 不要。最初の成果は一つの設計判断で、実装packageへ分解しない。
- 実装前の人間判断: 調査結果に基づくstorage方式、provider制限、追加権限、配布riskの受容が必要。

## 未決定事項

- INV-002を満たすAndroid API・provider境界が存在するか。
- 成立する候補がある場合、必要な権限と配布制約を受容するか。
