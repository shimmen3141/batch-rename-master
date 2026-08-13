# T08 端末幅とapp内mount viewを再検証する

## 目的

`T01`のspike S-2で残した未検証を、**実装したappで**確かめる。ここを通らないとAndroidのrenameを「安全」とは言えない。

## 入力と依存

- [`T01`のresearch-matrix](../T01-decide-storage-boundary/research-matrix.md)「S-2で残った未検証」。
- `T05`(native port)と`T07`(file browser)の実装。

## 確かめること

S-2は**1機種・1 API level・`adb shell`からの観測**だった。実装後に次を埋める。

1. **`flags=0`との対照を毎回取る。** `T01`の初回spikeにこれが無く、「フラグが効いた」の因果を示せなかった(reviewでP1)。**片側だけでは安全の原因が分からない。** app内でも、別API levelでも、FAT系でも、必ず両方を測る。あわせて`stat -f`と`mount`でfilesystemを記録する。
2. **appのmount view。** `MANAGE_EXTERNAL_STORAGE`を持つapp自身から`renameat2(RENAME_NOREPLACE)`を呼び、`EEXIST`になりtargetが無傷であることを確認する。**S-2は`shell` uidからの観測なので、これが最も重要である。**
3. **API levelの幅。** Android 11〜16のいずれかでも確認する。MediaProviderのFUSE実装はversionごとに変わる。
4. **実機。** emulatorだけでなく実機で確認する。vendor kernelやf2fsで挙動が変わりうる。
5. **FAT系。** SD card / USB OTGで確認する。**FATでフラグが効かないなら、その媒体は未対応にする**必要がある。

**5がNGだった場合、契約を緩めるのではなく対象媒体を絞る。** INV-002へplatform例外を作らない(ADR-002)。

## 受け入れ証拠

- 上記1〜5の観測結果を`task.md`へ記録する。**Agentが推測で埋めない。**
- 1または2がNGなら**ADR-002を見直す**。実装を残したまま「動くはず」で進めない。
- 5がNGなら、対象外にする媒体を仕様へ書き、利用者へ提示する。
- host側のAndroid buildが成功する(containerでは実行できない)。
- [`manual-verification.md`](manual-verification.md)に手順を書く。**`T01`のmanualと同じ具体度**にする(実行できるコマンド、期待する出力、判定条件)。

## 作業記録

- 2026-08-13 / ADR-002の採用決定を受けて定義。S-2が1機種・`shell` uidの観測に留まることを明示的に引き継ぐ。

## Current state / handoff

- Last checkpoint: 定義しただけ。未着手
- Blocker category: dependency
- Waiting for: `T05`と`T07`の実装
- Requested action: なし
- Evidence revision: `dev@f97a2cc` + ADR-002 + spike S-2(Android 17 emulator、x86_64、shell uid)
- Next Agent action: `T05`/`T07`完了後、実行できるmanual手順を書いてから人間へ依頼する。**依頼前にdry-runする**
