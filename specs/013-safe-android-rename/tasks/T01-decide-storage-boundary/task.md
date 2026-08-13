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

- 2026-08-12 / **container側の到達可能性を確認した。このtaskはAI containerだけでは完了できない。**
  - egress firewallが公式資料を遮断している。`developer.android.com`・`source.android.com`・`api.flutter.dev`はいずれもtimeout、`pub.dev`のみ200。受け入れ証拠の「Android/Google Playの公式資料と必要権限の対応」を、Agentが一次資料に当たって書けない。
  - 「候補API/version/providerを固定した再現可能なspike結果」も、containerにAndroid SDKもemulatorも無いため実行できない(AGENTS.mdの前提どおり)。
  - したがって、このtaskを進めるには次のどちらかが要る。(a) 人間がfirewallのallowlistへ`developer.android.com`等を追加し、spikeはhost側で実施する。(b) 人間が一次資料の該当箇所とspike結果をAgentへ渡し、Agentは比較・decision recordの作成に限定する。
  - どちらもAgentの判断では選べないため、statusは`pending`のまま人間へ返す。

## Current state / handoff

- Last checkpoint: 依存(005:T05)は解消済み。着手を試みたが、AI containerからは受け入れ証拠を満たせないことが判明した
- Blocker category: environment
- Waiting for: 調査の進め方の決定。(a) firewall allowlistへ公式資料domainを追加し、spikeはhost側で実施する / (b) 人間が一次資料とspike結果をAgentへ渡し、Agentは比較とdecision recordに限定する
- Requested action: (a)か(b)を選ぶ。(a)ならallowlistの更新は`.devcontainer/`側の変更なので人間が行う
- Evidence revision: `dev@ea1dd04`で到達可能性を確認(`developer.android.com`・`source.android.com`・`api.flutter.dev`=timeout、`pub.dev`=200)
- Next Agent action: 人間が方針を選んだら、候補ごとの調査matrixを作る。production実装は設計判断のあと別taskまたは別planへ定義する
