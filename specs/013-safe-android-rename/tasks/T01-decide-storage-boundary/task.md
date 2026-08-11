# T01 storage・permission境界を設計判断する

## 目的

Androidで005のno-replace保証を満たせる候補を比較し、採用・不採用・制約付き採用の判断材料とdecision recordを作る。

## 入力と依存

- `005:T05`で統合されるcontract revision 2とAndroid安全unsupported。
- PR #116で作成された旧`design-safe-android-rename-boundary`定義の移行内容と005のADR。

## 変更範囲

- 公式資料調査、最小spike、permission・配布制約の比較、decision record。
- 人間承認前にproduction renameや広権限を導入しない。

## 受け入れ証拠

- 候補API/version/providerを固定した再現可能なspike結果。
- Android/Google Playの公式資料と必要権限の対応。
- 未検証領域と次に必要な実装planを明示した採否decision。
- 005 contractとnegative testの継続PASS。

## 作業記録

- 2026-08-09 / PR #116の独立reviewで、DocumentsContract.renameDocumentに原子的no-replace契約が無いことをP0として検出。
- 2026-08-09 / 開発者判断により、provider依存raceを許容せずAndroid成功経路を別の設計成果へ分離。
- 2026-08-12 / PR #116を`dev`へmerge（merge commit `425c30a`）。005:T05の安全unsupported、Android manual、Desktop manual、CI、独立reviewがPASSし、依存を解消。

## Current state / handoff

- Last checkpoint: 005:T05/T06をPR #116で`dev`へ統合し、013:T01の開始依存を解消
- Blocker category: none
- Waiting for: none
- Requested action: none
- Evidence revision: `origin/dev@425c30a`（PR #116 merge commit）
- Next Agent action: Issue運用が有効ならT01のIssueを作成・claimし、候補ごとの検証可能な調査matrixを作る。production実装は人間の設計判断後に別taskまたは別planへ定義する
