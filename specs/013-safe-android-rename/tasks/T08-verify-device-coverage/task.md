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

## machine検証する範囲と引き受け先(AGENTS.md の宣言。2026-08-25 着手時)

**このtaskは本質的にCIで実行できない。** 端末が要る。**宣言の外側の指摘は安全網の穴と
して扱う。**

| 対象 | この環境での検証 | 引き受け先 |
| --- | --- | --- |
| 観測 harness の中身(`probeDirectory`、`defect` の判定、観測対象の作り方、報告の形) | **host の実 filesystem で閉じる。** `test/spec_013_android_rename/storage_probe_test.dart` が temp directory を使って実際に排他 rename と通常 rename を呼ぶ | — |
| harness が**保証の破れを見逃さない**こと | **mutationで固定する**(`M122`〜`M125`) | — |
| **Androidの実 mount view での排他 renameの可否**(項目1) | **できない** | **人間**([`manual-verification.md`](manual-verification.md) 手順2) |
| **失敗時のsource側**(項目2) | harness が観測して欠陥判定に含める。**実機での値**は取れない | 同上 |
| **filesystemの種別**(項目3・4) | **できない**(`stat -f` / `mount`) | 同上 手順3 |
| **API levelの幅・実機・FAT系**(項目5〜7) | **できない** | 同上 手順4〜6 |
| **Android build** | **できない**(SDKが無い) | 同上 手順7 |

## 観測の設計(2026-08-25)

### なぜ製品の画面から観測できないか

**画面をどう操作しても、フラグが効いているかどうかで見え方は変わらない。**
`DesktopRenameExecutor.rename` は目標名が実在すれば改名の前に気づいて
`_renameViaTemporary` へ行き、劣化経路でも実在確認を挟む。**劣化は設計どおり透過**
なので、外から差が出ない。

実在確認と syscall の間(TOCTOU の窓)を人間の操作で突くことも考えたが、**窓はミリ秒**で
あり、確認dialogを開いている間に file を作っても実在確認の側で捕まる。**手で再現できない。**

### 採った手段: 端末で走る integration test

`integration_test/android_storage_probe_test.dart` を足した。**製品と同じ package・
同じ権限・同じ mount view**で走り、port(`renameFileWithoutOverwrite`)を直接呼ぶ。
`test/spec_005_rename_exec/android_rename_port_test.dart` が Linux で同じことをしている
(`_BlindProbe` と同じ理由)。

- **製品codeへdebug用の口を作らない。** `integration_test/` は release buildに入らない。
- **観測対象は `AndroidStorageBrowser.locations()` から作る** — 製品と同じ列挙なので、
  SDカード・USBを挿していれば**項目7が自動で埋まる**。
- **volume ごとに `flags=0` の対照を取る**(`plainRenameFile` が実際に置換することを
  確かめてから、排他 renameの結果を読む)。`013:T01`の初回spikeが対照を欠いてreviewで
  P1になった型を繰り返さない。
- **「効いた」も「劣化した」も正常**として扱い、**保証が破れたときだけ**失敗にする
  (目標名が変わった / 改名されていないのにsourceが変わった / 対照が成立しない)。

### harness自体をCIで確かめる

**人間へ依頼してから harness の誤りに気づくと、実機の時間を捨てる**
([finding](../../../../development-findings/2026-08-25-manual-preconditions-were-not-executable-on-the-verification-device.md))。
そこで観測の核を `integration_test/storage_probe.dart` へ出し、**host の test が同じ核を
実 filesystem で回す**。`M122`〜`M125` は、その test が**harnessの手抜きを実際に落とす**
ことを固定する(見逃し2件と対照2件)。

**この host test の PASS は「Androidで効く」を一切意味しない。** Linuxのext4はフラグを
解釈するので当然通る。確かめているのは harness であって Android ではない。

## 手順と7項目の対応

| 項目(`research-matrix`「S-2で残った未検証」) | 手順 |
| --- | --- |
| 1 appのmount view | 手順2 |
| 2 失敗時のsource側 | 手順2(`source の中身`) |
| 3 `/data/local/tmp`のfilesystem種別 | 手順3 |
| 4 下位filesystem | 手順3(`stat -f` と `mount`) |
| 5 API levelの幅 | 手順4(**端末が無ければ埋まらない**) |
| 6 実機 | 手順5(同上) |
| 7 FAT系 | 手順6(同上。挿さっていれば手順2の出力に自動で並ぶ) |

**5〜7は端末の有無で決まる。** 埋まらなければ「埋まらなかった」と記録する
(`task.md`の受け入れ証拠「Agentが推測で埋めない」)。

## 検証結果

| 種別 | commandと結果 |
| --- | --- |
| related test | `flutter test test/spec_013_android_rename/storage_probe_test.dart` = **PASS(18件)** |
| full regression | `flutter test` = **PASS** |
| static analysis | `flutter analyze` = **PASS** |
| format | `dart format --output=none --set-exit-if-changed .` = **PASS** |
| ASDD構造 | `workspace.py check specs` = **PASS** |
| mutation | `M122`〜`M125` = **4 KILLED / 0 SURVIVED / 0 SKIPPED** |
| **端末での観測** | **未実施。** 人間へ依頼する |
| **Android build** | **未実施。** SDKが無い(手順7で人間が確かめる) |

## Current state / handoff

- Last checkpoint: **観測 harness を実装し、host で dry-run した**(`flutter test test/spec_013_android_rename/storage_probe_test.dart` = PASS(18)、`M122`〜`M125` = 4 KILLED)。manual手順を current revision に合わせて書いた
- Blocker category: なし(依存は解けた。`T05`/`T07`とも done)
- Waiting for: 独立review → そのあと人間の端末確認
- Requested action: なし
- Evidence revision: PR #154(Draft)、branch `asdd/013-safe-android-rename/T08-verify-device-coverage`、base は `dev@ae59859`(`git merge-base dev HEAD` の実測値)
- Next Agent action: **独立reviewを通してから**[`manual-verification.md`](manual-verification.md)を人間へ依頼する(reviewの指摘でcodeが変わると証拠が失効する)。結果を受けたら7項目を環境つきで記録し、**埋まらなかった項目はそう書く**
