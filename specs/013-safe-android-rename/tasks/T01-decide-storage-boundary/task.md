# T01 storage・permission境界を設計判断する

## 目的

Androidで005のno-replace保証を満たせる候補を比較し、採用・不採用・制約付き採用の判断材料とdecision recordを作る。

## 入力と依存

- `005:T05`で統合されるcontract revision 2とAndroid安全unsupported。
- PR #116で作成された旧`design-safe-android-rename-boundary`定義の移行内容と005のADR。

## 変更範囲

- 公式資料調査、最小spike、permission・配布制約の比較、decision record。
- 人間承認前にproduction renameや広権限を導入しない。

調査の正本は[`research-matrix.md`](research-matrix.md)。**[一次]**(公式資料の原文で確認)、**[要spike]**(実機で観測しないと言えない)、**[未到達]**(egress制限で一次資料へ到達できていない)を区別して書く。この区別を崩さない。

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

- 2026-08-13 / 開発者が**(a)**を選択。PR #127で`developer.android.com`・`source.android.com`・`api.flutter.dev`・`cs.android.com`をallowlistへ追加し、rebuild後に到達を確認(いずれも200)。`android.googlesource.com`と`support.google.com`は引き続きtimeout。
- 2026-08-13 / 公式資料調査を実施し、[`research-matrix.md`](research-matrix.md)へ候補A〜Fの比較、一次資料の引用、必要なspike(S-1〜S-4)を書いた。
  - **一次資料で確定**: `DocumentsProvider.renameDocument`は「providerが衝突回避のために要求名を変えてよい」と明記し、名前衝突を表す失敗を定義していない。SAF単独では原子的no-replaceも名前の同一性も満たせず、**ADR-001の判断は資料側の変化なく維持される**。
  - **一次資料で確定**: `MANAGE_EXTERNAL_STORAGE`は直接file path accessを与えるが、Google Playが宣言を認めるappの種類が限定されている。一括改名appが該当するかは配布判断であり、Agentは決めない。
  - **見立て**: 候補E(`MANAGE_EXTERNAL_STORAGE` + NDK `renameat2(RENAME_NOREPLACE)`)が唯一契約を緩めずに成立しうる。成否は**S-2(FUSEがRENAME_NOREPLACEを透過するか)**に完全に依存する。
  - spikeはAndroid SDK・実機が要るためhost側で人間が実施する。

- 2026-08-13 / **spike S-2を実施(人間)。結果はA) `RENAME_NOREPLACE`は有効。**
  - 環境: Android emulator、Pixel 8a image、Android 17("CinnamonBun")、x86_64。
  - `/data/local/tmp`(ext4)と`/sdcard`(FUSE)の**両方**で、targetが既にある場合は`-1` / `errno 17 EEXIST`、targetの内容は無傷、targetが無い場合は`0`。
  - **FUSEがフラグを透過している。** 候補Eの技術的前提が成立した。
  - 未検証: API levelの幅(Android 11〜16)、実機、FAT系(SD/OTG)、`MANAGE_EXTERNAL_STORAGE`を持つapp自身のmount view。**採用を決めてから確かめる。**
- 2026-08-13 / 調査の結果、**候補Eの採用がAndroidのfile選択導線の作り直し(004への波及)を伴う**ことが判明した。`renameat2`はpathを要り、SAF URIはpathへ変換できないため、選択がSAFからapp内file browserへ変わる。当初の想定に無かった影響なので、採否の判断材料へ加えた。

## Current state / handoff

- Last checkpoint: 公式資料調査とspike S-2が完了。**候補Eは技術的に成立する**ことを実測で確認し、[`decisions/ADR-002`](../../decisions/ADR-002-android-rename-storage-boundary.md)を`proposed`として起草した
- Blocker category: decision(人間の配布・scope判断)
- Waiting for: **候補Eを採るかどうかの人間の決定。** 技術ではなく、(1) `MANAGE_EXTERNAL_STORAGE`をPlayで宣言する方針を取れるか、(2) Androidのfile選択をSAFからapp内file browserへ作り直す範囲を受け入れるか
- Requested action: ADR-002の「決めること」に答える。採用する場合は004の再承認も要る
- Evidence revision: `dev@f97a2cc` + spike S-2(2026-08-13、Android 17 emulator、x86_64、ext4とFUSEの両方でEEXIST)
- Next Agent action: 採用ならADR-002を`accepted`にし、実装planのtask案(004のAndroid選択導線の作り直しを含む)を作る。不採用ならADR-002を`rejected`にし、005のAndroid未対応を確定として013を閉じる。どちらも承認前に実装しない
