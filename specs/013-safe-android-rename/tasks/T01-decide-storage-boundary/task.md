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
  - `/data/local/tmp`と`/sdcard`の**両方**で、targetが既にある場合は`-1` / `errno 17 EEXIST`、targetの内容は無傷、targetが無い場合は`0`。
  - 候補Eの技術的前提が成立した(この時点では対照が無く、因果は未確定)。
  - 未検証: API levelの幅(Android 11〜16)、実機、FAT系(SD/OTG)、`MANAGE_EXTERNAL_STORAGE`を持つapp自身のmount view。**採用を決めてから確かめる。**
- 2026-08-13 / 調査の結果、**候補Eの採用がAndroidのfile選択導線の作り直し(004への波及)を伴う**ことが判明した。`renameat2`はpathを要り、SAF URIはpathへ変換できないため、選択がSAFからapp内file browserへ変わる。当初の想定に無かった影響なので、採否の判断材料へ加えた。
- 2026-08-13 / **開発者が候補Eの採用を決定。** ADR-002を`accepted`にし、T02〜T08を定義した。`flutter test` — PASS (359)。005のnegative testは無傷。
- Review attempt 1: `ec2e74f..ccd234f` — FAIL — P1×4。
  1. **Playの許可対象の一次資料の意味を変えていた。** 原文は「similar to any of the following, it's likely that」という**開いた例示**なのに、「宣言が許されるのは次のみ」と閉じたallowlistとして書き、`[一次]`を付けていた。WebFetchの要約をそのまま原文として扱ったことが原因。原文を再取得して修正した。**"permitted uses"の定義は`support.google.com`にあり到達できない**ことも明記した。
  2. **spikeに`flags=0`の対照が無く、「フラグが効いた」の因果を示せていなかった。** 「そのpathがそもそも上書きrenameを拒む」可能性を排除できない。spikeへcase Bを追加し、主張を観測の範囲へ戻した。**再実施待ち。**
  3. **`renameat2`のAPI 30という`[未到達]`主張が、ADRとT02では無印の事実に昇格していた。** しかもspike binaryは`android24`向けにビルドして動作しており、生syscallならwrapperのlevelに依存しない。T02の選択肢を2案から3案へ直した。
  4. **T02の`dependsOn`が空**でT01への実質依存が未宣言だった。`["T01"]`にした。
  - P2も併せて解消(状態表記、引用の逐語性、`/Android/data`等の書込不可をT03へ、spikeの早期returnでの後始末、`exists()`のTOCTOU、case Cの診断文言、mount種別の採取、allowlist依頼の宙吊り、covers)。
- 2026-08-13 / spikeへcase B(`flags=0`の対照)とmount種別の採取を追加。container(x86_64/ext4)で再ビルド・実行し、case A=`EEXIST`/target無傷、case B=`0`/上書き、case C=`0`、判定`A)`、消し残し無しを確認した(dry-run)。
- Review attempt 2: `ec2e74f..2baaa48` — FAIL — P1×5。**うち2件はattempt 1の修正が一部のfileにしか届いていなかった**(`research-matrix.md`の結論節に閉じたallowlist表現が残存、`T05`/`T04`にAPI 30が無印で残存)。他は`mount`出力を逐語でなく整形して生出力として提示(attempt 1のP1-1と同じ根本原因の再発)、`Evidence revision`が実在しないbase`f97a2cc`のまま、判定軸2(失敗時不変)をsource側で観測していないのに満たしたと書いていた。
  - 対処: 訂正対象を`grep`で全文横断してから直した。spikeへsource側とcase Cの中身の確認を追加(次回の実行から実測になる)。`Evidence revision`を8fileとも`dev@ec2e74f`へ。Playのpolicy確認を`T02`の受け入れ証拠としてgate化した。
  - **1件は指摘を採らなかった。** 「Android 17のcodename "CinnamonBun"に出典が無い」との指摘だが、これは人間が2026-08-13の報告で「device managerではPixel 8a, Android 17.0 ("CinnamonBun")と書いてありました」と伝えた内容である。reviewerへ渡した抜粋に含まれていなかったための誤検出。出典を明記して残す。
- Review attempt 3: `ec2e74f..1f870af` — FAIL — P1×2、P2×6。attempt 2のP1×5は伝播含め解消、spikeの改訂も妥当と確認された。**残るP1は2件、いずれも`research-matrix.md`の2行である。**
  1. `:87-94` — `MANAGE_EXTERNAL_STORAGE`の付与内容の引用で、原文の`except /Android/data/, /sdcard/Android, ...`を**`such as /sdcard/Android`と書いており意味が反転している**。原文をcurlで再取得して確認済み。**逐語引用を直す作業の中で、より悪い誤りを入れた。** 地の文(`:98`)は正しく「書けない」としているので結論は無事だが、原文として提示したblock自体が原文と矛盾する。
  2. `:168` — S-2の**判定基準**節に「`EEXIST`かつtargetの内容が不変 → 判定軸1と2を満たす」が残存。同じfileの`:185`が「判定軸2を実測したとは言えない」と正反対を述べており矛盾。attempt 2のP1-1(結論節に旧主張が残存)と同型の伝播漏れ。
  - **3回連続FAILのため、AGENTS.mdに従い自動修正を停止し人間へ報告した。**
- Review attempt 4: `ec2e74f..9d3d97e` — **PASS** — P0/P1なし。reviewerが4つの公式資料を実取得して全要約を原文照合し、引用をやめたことによる精度低下が無いことを確認した。残P2×6は後続commitで解消。
- 2026-08-13 / **人間が(c)「引用を持たない形にする」を選択。** `research-matrix.md`と`ADR-002`から引用ブロックを全廃し(`^>`行は0)、出典のURLと節名+筆者の要約+「原文の転記ではない」の明示へ置き換えた。判断が原文の一語に依存する箇所(`except`か`such as`か、`only`か`likely`か)は、**その語が判断を分けること自体を本文へ書いた**。`:168`の判定基準の伝播漏れも解消。
  - **転記をやめたのは、注意力ではなく手段を変える対処である。** attempt 2の時点で`AGENTS.md`の「2回続いたら洗い直す」が発火していたが、筆者は記録しただけで手段を変えず、3回目を招いた。この構造上の穴はfindingへ記録した。
- 2026-08-13 / **spike S-2を対照付きで再実施(人間)。因果が確定した。**
  - `/data/local/tmp`と`/sdcard`の両方で、case A=`-1`/`EEXIST`/target無傷、**case B(flags=0)=`0`/上書き**、case C=`0`。
  - **差はフラグに由来する。** 「そのpathがそもそも上書きrenameを拒むだけ」という説明は排除された。
  - `/sdcard`がFUSE経由であることを観測した。`stat -f` → `Type: 0x65735546`(`FUSE_SUPER_MAGIC`)、`mount` → `/dev/fuse on /storage/emulated type fuse`。**推測ではなくなった。**
  - ただし同じ`mount`出力に`/dev/block/dm-6 on /mnt/pass_through/0/emulated type ext4`があり、**下位filesystemはext4**である。FUSEが自分で判定したのか下位へ委譲したのかは切り分けていない。
  - 環境: Android emulator、Pixel 8a image、Android 17.0("CinnamonBun"。人間がdevice managerの表示として報告)、x86_64。**1機種・1 API level・`shell` uid・下位ext4である点は変わらない**(`T08`が引き継ぐ)。

## Current state / handoff

- Last checkpoint: **完了。** review attempt 4がPASSし、PR #133を`dev`へmergeした
- Blocker category: なし
- Waiting for: なし
- Requested action: なし
- Evidence revision: PR #133 merge commit `70e4287` + spike S-2 第2回(対照付き、2026-08-13、Android 17 emulator / x86_64、`/data/local/tmp`と`/sdcard`の両方で`EEXIST`、`/sdcard`はFUSEと観測)
- Next Agent action: `T02`(権限とAPI levelの方針)へ進む。`minSdk`を含む4点を人間へ一度に問う。**引用を再導入しないこと** — 精度が要るときは出典を直接読む
