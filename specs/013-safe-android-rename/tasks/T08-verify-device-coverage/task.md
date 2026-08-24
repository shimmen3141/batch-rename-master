# T08 端末幅とapp内mount viewを再検証する

## 目的

`T01`のspike S-2で残した未検証を、**実装したappで**確かめる。ここを通らないとAndroidのrenameを「安全」とは言えない。

## 入力と依存

- [`T01`のresearch-matrix](../T01-decide-storage-boundary/research-matrix.md)「S-2で残った未検証」。
- `T05`(native port)と`T07`(file browser)の実装。

## 確かめること

S-2は**1機種・1 API level・`shell` uidからの観測**だった。実装後に次の**7項目**を埋める(([`research-matrix.md`](../T01-decide-storage-boundary/research-matrix.md)の「S-2で残った未検証」と同じ集合)。

1. **appのmount view。** `MANAGE_EXTERNAL_STORAGE`を持つapp自身から呼び、`EEXIST`になりtargetが無傷であることを確認する。**S-2は`shell` uidからの観測なので、これが最も重要である。**
2. **失敗時のsource側。** S-2はtarget側しか観測しておらず、判定軸「失敗時不変」は`EEXIST`からの推論に留まる。spikeへ確認を追加済みなので、実行すれば実測になる。
3. **`/data/local/tmp`のfilesystem種別。** S-2で`stat -f`を採っていない。FUSEを経由しない対照として使う以上、種別を記録する。
4. **下位filesystem。** S-2ではFUSEの下がext4だった。**FUSE自身が判定したのか下位へ委譲したのかを切り分けていない。** 下位がFATやf2fsのとき同じとは限らない。
5. **API levelの幅。** Android 11〜16のいずれかでも確認する。MediaProviderのFUSE実装はversionごとに変わる。
6. **実機。** emulatorだけでなく実機で確認する。vendor kernelやf2fsで挙動が変わりうる。
7. **FAT系。** SD card / USB OTGで確認する。**FATでフラグが効かないなら、その媒体は未対応にする**必要がある。

**この確認は製品の可否を左右しない。** 005 contract revision 4により、`RENAME_NOREPLACE`が効かない環境でも実在確認へ劣化するだけで機能する。**確認する目的は、005 INV-002がどの環境で完全に成立するかを知ることである。**

**NGだった媒体は「対応外」にしない。** 保証の水準が下がることを記録する。

### 測り方の要件

**どの観測でも`flags=0`との対照を取る。** `T01`の初回spikeにこれが無く、「フラグが効いた」の因果を示せなかった(reviewでP1)。**片側だけでは安全の原因が分からない。** app内でも、別API levelでも、FAT系でも必ず両方を測り、あわせて`stat -f`と`mount`でfilesystemを記録する。

## 受け入れ証拠

- 上記1〜7の観測結果を`task.md`へ記録する。**Agentが推測で埋めない。**
- 1または2がNGなら、**005 INV-002が完全には成立しない環境である**ことを記録する(013 ADR-002の見直しではなく、成立範囲の記録である)。
- 7がNGなら、その媒体で保証の水準が下がることを記録する。**対応外にはしない。**
- host側のAndroid buildが成功する(containerでは実行できない)。
- [`manual-verification.md`](manual-verification.md)に手順を書く。**`T01`のmanualと同じ具体度**にする(実行できるコマンド、期待する出力、判定条件)。

## 作業記録

- 2026-08-13 / ADR-002の採用決定を受けて定義。S-2が1機種・`shell` uidの観測に留まることを明示的に引き継ぐ。
- 2026-08-24 / **`T06`から申し送り。** 権限導線の実機確認は `Pixel 8a` / `Android 17.0` /
  `x86_64` / `API 37.1` で PASS した(`T06/task.md`)。**この環境で覆えていないのは**
  (a) 設定画面の**アプリ一覧へ落ちる分岐**(この環境では個別画面が直接開いた)、
  (b) **API 30未満**の端末での見え方(`MANAGE_EXTERNAL_STORAGE` が存在しない)、
  (c) `x86_64` なので**emulatorだった可能性が高く、実機での遷移先**。

## Current state / handoff

- Last checkpoint: 定義しただけ。未着手
- Blocker category: dependency
- Waiting for: `T05`と`T07`の実装
- Requested action: なし
- Evidence revision: `dev@4fd6ab1` + ADR-002 + spike S-2(Android 17 emulator、x86_64、shell uid) + `spec.md`(approved 2026-08-14)+ 005 contract revision 4
- Next Agent action: `T05`/`T07`完了後、実行できるmanual手順を書いてから人間へ依頼する。**依頼前にdry-runする**
