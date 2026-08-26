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
| 観測 harness の**核**(`probeDirectory`、`defect` の判定、観測対象の作り方、報告の形) | **host の実 filesystem で閉じる。** `test/spec_013_android_rename/storage_probe_test.dart` が temp directory を使って実際に排他 rename と通常 rename を呼ぶ。辿れない場所は `chmod 000` で作る | — |
| **runner**(`integration_test/android_storage_probe_test.dart`) | **閉じていない。** device build を要求するので host では走らない。**中身を核へ寄せて薄くしてある**(観測対象の列挙・観測・報告・後片付けはすべて核の側) | **人間**(手順2で実際に走る) |
| harness が**保証の破れを見逃さない**こと | **mutationで固定する**(範囲と件数は下の「検証結果」表が持つ。ここへ書き写さない) | — |
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
実 filesystem で回す**。**mutation は、その test が harness の手抜きを実際に落とすことを
固定する** — **範囲と件数は下の「検証結果」表だけが持つ。** ここへ書き写すと、足すたびに
古くなる(独立review attempt 2 の P2-10、attempt 3 の P3-1 で**同じ型を2回**踏んだ。
根は 2026-08-22 の[finding](../../../../development-findings/2026-08-22-restating-a-requirement-outside-its-row-went-stale-twice.md)
と同じで、**生きた値の正本を1つにする**のが解である)。

**この host test の PASS は「Androidで効く」を一切意味しない。** Linuxのext4はフラグを
解釈するので当然通る。確かめているのは harness であって Android ではない。

## 手順と7項目の対応

| 項目(`research-matrix`「S-2で残った未検証」) | 手順 |
| --- | --- |
| 1 appのmount view | 手順2 |
| 2 失敗時のsource側 | 手順2(`source の中身`) |
| 3 `/data/local/tmp`のfilesystem種別 | 手順3 |
| 4 下位filesystem | 手順2の**非FUSE の対照**(app の内部領域は `/data` 上で FUSE を経由しない。同じ app プロセスで比べられる)+ 手順3(`stat -f` と `mount`)。**媒体が増えれば手順6でさらに進む** |
| 5 API levelの幅 | 手順4(**端末が無ければ埋まらない**) |
| 6 実機 | 手順5(同上) |
| 7 FAT系 | 手順6(同上。挿さっていれば手順2の出力に自動で並ぶ) |

**5〜7は端末の有無で決まる。** 埋まらなければ「埋まらなかった」と記録する
(`task.md`の受け入れ証拠「Agentが推測で埋めない」)。

**項目4は `T01` が「この観測では切り分けられない」と結論した所である。** `stat -f` と
`mount` を採り直すだけでは前進しないので、**同じ app プロセスの中に非FUSE の観測対象を
1つ置いた**(独立review attempt 1 の P2-3)。FAT 系の媒体があれば手順6でさらに進むが、
**媒体が無くても1段は進む**形にしてある。

## 検証結果

| 種別 | commandと結果 |
| --- | --- |
| related test | `flutter test test/spec_013_android_rename/storage_probe_test.dart` = **PASS(52件)** |
| full regression | `flutter test` = **PASS(641件)**。T08着手前は589件 |
| static analysis | `flutter analyze` = **PASS** |
| format | `dart format --output=none --set-exit-if-changed .` = **PASS** |
| ASDD構造 | `workspace.py check specs` = **PASS** |
| mutation | `M122`〜`M143` = **22 KILLED / 0 SURVIVED / 0 SKIPPED**。うち`M126`〜`M130`・`M133`〜`M137`・`M140`〜`M142`は**独立reviewerが足したもの**(`M129`/`M135`は対照)。表全体は `--list` = **143 mutations, 0 with an unexpected match count** |
| **端末での観測** | **1回目を受領(2026-08-26)。** 項目1〜4が埋まり、5〜7は未了。詳細は下の節 |
| **Android build** | **未実施。** SDKが無い(手順7で人間が確かめる) |

## 独立review attempt 1(2026-08-25)= FAIL

range は `5307fa7...6d03fff`。**P1が1件、P2が8件。** reviewerは主張の3点を自分でcodeを
読んで確かめている — 「製品の画面からは観測できない」(実在確認と劣化の透過性、
`unsupported`がAndroidでは返らないこと、フラグの状態を出すUIが無いこと)、
「対照が成立している」、「CI・release buildへ影響しない」(`.flutter-plugins-dependencies`で
`integration_test`が`dev_dependency: true`であること)。**7項目との対応にも漏れなし**と
判定された。

| # | 指摘 | 分類 | 始末 |
| --- | --- | --- | --- |
| **P1-1** | **nativeの呼び出しだけが`try`の外**にあり、投げると報告が1行も出ないまま端末に残骸が残る。`@Native`のsymbol解決失敗は`FileSystemException`ではない | 成果物の欠陥 | **直した。** 呼び出しを保護し、**注入できるようにして**host testで固定した(`M132`)。runnerのloop側にも保険を置き、**何が起きても報告へ到達する** |
| P2-1 | `Evidence revision`のbaseが「実測値」と書いてあるのに実測値でない(`ae59859`) | 成果物の欠陥 | 直した(`5307fa7`) |
| P2-2 | manualに`flutter pub get`が無い。**このtaskは`pubspec.yaml`を変えており**、containerとhostで`.pub-cache`が別 | 成果物の欠陥 | 直した(手順2と手順7) |
| P2-3 | 項目4を手順3へ割り当てているが、手順3は`T01`が「切り分けられない」と結論した出力を採り直すだけ | 成果物の欠陥 | **直した(reviewerの推奨案a)。** 同じappプロセスに**非FUSEの観測対象**を1つ足した。媒体が無くても1段進む |
| P2-4 | **`RV-N1`がSURVIVED** — 劣化した行で保証が破れても落ちない。`fallbackRequired`は**Androidで最も起きやすい結果** | 安全網の穴 | **直した。** 劣化した行での破れをtestで固定(`M126`) |
| P2-5 | `permissionDenied`の免除が実体検査の**前**にあり、目標名とsourceを見ずに抜ける | 安全網の穴 | 直した。免除は**対照だけ**にした(`M129`が対照として残る) |
| P2-6 | runnerのguardが`permissionDenied`も「観測できた」と数える。全volumeがそれでも緑になる | 安全網の穴 | 直した。`answersTheQuestion`で数える(`M131`) |
| P2-7 | 残骸確認が観測対象の一部しか見ない。`Android/media/<pkg>`も消えない | 成果物の欠陥(軽微) | 直した。**空なら消す**(元からあった場所は巻き添えにしない)。manualの確認commandも足した |
| P2-8 | manualの終端行がcurrent revisionと一致しない | 成果物の欠陥(軽微) | 直した |

**`RV-N1`〜`RV-N5`を`M126`〜`M130`として取り込んだ**(AGENTS.md「独立reviewが足した
mutationは実装側へ取り込む。対照として置いたものも落とさない」)。

**mutation実行中に事故が1件**あった。詳細と再発防止は
[finding](../../../../development-findings/2026-08-23-edited-a-file-while-a-mutation-runner-was-restoring-it.md)へ追記した。

## 独立review attempt 2(2026-08-26)= FAIL

range は `5307fa7...15ae58d`。**attempt 1 の9件はすべて閉じたと確認された**(reviewerが
差分・test・mutationを自分で回し、`M122`〜`M132` = 11 KILLED を再現した)。
**`Directory.systemTemp` が非FUSEである根拠も、reviewerが一次資料で裏を取った** —
Dart は `TMPDIR` を見て(`runtime/bin/directory_linux.cc`)、Android の app process では
`ActivityThread` が `TMPDIR` を app の cache dir へ設定する(`/data` 上)。

**しかし P1-1 と同じ根本原因が、直さなかった別の場所に残っていた。**

| # | 指摘 | 分類 | 始末 |
| --- | --- | --- | --- |
| **P1-2** | **`androidProbeTargets` が投げると報告が丸ごと消える。** `Directory.exists()` は辿れない親の下で **`false` を返さず投げる**(reviewerがcontainerで実測)。`/storage` に取り外し済み・stale mount の entry が1つでもあると、**実機・SDカードという一番高くつく場面**で報告ゼロ+残骸になる | 成果物の欠陥 | **解き方を変えた**(下記) |
| P2-9 | **`RVB-2` がSURVIVED** — 劣化した行の「対照」検査が固定されていない。1件ずつ足す形は隣が空いたまま残る | 安全網の穴 | **testを升目で回す形へ変えた**(結果3種 × 破れ方7種)。`RVB-2`は`M134`として取り込み、KILLEDになった |
| P2-10 | 宣言表が`M122`〜`M125`のままで、検証結果表と食い違う | 成果物の欠陥 | 直した。あわせて**runnerはhostで閉じていない**ことを宣言表へ書き分けた |
| P2-11 | 残骸確認の glob が `Android/data` などにも当たり、人間がYES/NOで判定できない | 成果物の欠陥(軽微) | 直した。「`brm-t08-`で始まる名前が出なければよい」へ |
| P2-12 | 手順2の「対照」期待が`permissionDenied`の行にも読める | 成果物の欠陥(軽微) | 直した |
| P2-13 | 対照の block だけ `on FileSystemException` で、後片付けが`finally`でない | 安全網の穴 | **P1-2の構造変更で同時に消えた**(`M139`) |

### P1-2 の解き方を変えた(AGENTS.md「同じ根本原因が修正後も2回続いた」)

**窓をもう1つ塞ぐのをやめた。** attempt 1 で「native の呼び出しだけ囲む」で直したら、
attempt 2 で列挙側に同じ穴が見つかった。`await` を1つ足すたびに同じことが起きる。

**このprojectは既に同じ結論に達している** — `lib/data/rename_exec/desktop_rename_executor.dart`
の「個別のawaitをcatchで囲むのではなく、まとめて囲む。事例ごとに囲む形は、awaitを1つ
足すたびに漏れる」。同じ形にした。

1. `probeDirectory` の後片付けを **`finally`** へ。
2. runner の本体を `try` に入れ、**報告と後片付けを `finally`** へ。
3. `androidProbeTargets` は**1 volume の失敗で全体を落とさない**。

**testが穴を実際に落とすかも確かめ直した。** 最初に書いたtestは `M138` を落とせなかった
(守りが無くても外側のcatchが拾い、assertionが通ってしまう)。**辿れない側を`primaryRoot`に
して「後続のvolumeが残ること」まで見る**形に変えて、KILLEDになった。

## 独立review attempt 3(2026-08-26)= PASS

range は `5307fa7...b150fa9`。**未解決のP0/P1は無い。** reviewerは attempt 2 の6件がすべて
閉じたことを確認し、**`M138` が KILLED になったこと**(testが穴を実際に落とすこと)、
**`M125`/`M132` の言い直しが元の意図を保っていること**、**P2-9 の升目に抜けが無いこと**を
自分で確かめている。

**reviewerが自分のmutationの誤りを1件開示した** — attempt 3 の `RVC-1` は `try {` を
`if (true) {` へ置換したため構文エラーになり、`KILLED` は「testが落とした」ではなく
「compileできなかった」だった。作り直した `RVC-1b` では **SURVIVED** で、それがP3-3である。

| # | 指摘 | 分類 | 始末 |
| --- | --- | --- | --- |
| P3-1 | 同じfileの3箇所目のmutation範囲だけが古い。**同じ型が3回目** | 成果物の欠陥 | **生きた値の正本を検証結果表の1箇所へ寄せた。** 他は「表を見る」とだけ書く(2026-08-22 のfindingと同じ解) |
| P3-2 | 実体を読めなかったことを「無傷」と読み替えても落ちない(`RVC-2` SURVIVED) | 安全網の穴 | 直した。目標名を消す実装を注入してtestで固定(`M140`) |
| P3-3 | **列挙そのものが落ちたときの外側の守りが固定されていない**(`RVC-1b` SURVIVED)。`primaryRoot`の**親**が辿れない場合 | 安全網の穴 | **reviewer推奨の(b)を採った** — `androidProbeTargets`の本体をまとめて囲み、構造で閉じた(`M141`) |
| P3-4 | `mediaProbeDirectoryOf`の場所が固定されていない(`RVC-5` SURVIVED) | 安全網の穴 | 直した(`M142`) |
| P3-5 | runnerの`finally`で後片付けが報告より**前**にある。**その1行が新しい窓になる** | 安全網の穴 | **依頼前に直した**(端末で走るcodeなので、manual後に直すと実機の観測をやり直すことになる) |

**`M143`(P3-5 の対照)は置かなかった。** runner は host の test で走らないので恒久的に
SURVIVED になり、表の意味(「落ちること」を約束する)が壊れる。**runnerがhostで閉じて
いないことは宣言表に書いてある。**

## 端末での観測 1回目(2026-08-26)

| 項目 | 値 |
| --- | --- |
| 環境 | Android emulator `sdk_gphone16k_x86_64`、**API 37**、`CP31.260623.005 dev-keys` |
| 対象commit | `7dd4018`(PR #154) |
| 実行者 | 開発者(人間) |

**4箇所すべてで `RENAME_NOREPLACE` が効いた。**

| 場所 | 排他 rename | 目標名 | source | 対照(通常 rename) |
| --- | --- | --- | --- | --- |
| `/storage/emulated/0`(内部ストレージ root) | **`nameConflict`** | 無傷 | 無傷 | `success` かつ置換 |
| `/storage/emulated/0/Download` | **`nameConflict`** | 無傷 | 無傷 | `success` かつ置換 |
| app ごとの保存領域 | **`nameConflict`** | 無傷 | 無傷 | `success` かつ置換 |
| `/data/user/0/com.example.batch_rename_master/code_cache`(**非FUSE の対照**) | **`nameConflict`** | 無傷 | 無傷 | `success` かつ置換 |

**対照が全箇所で置換している**ので、「フラグが効いた」は因果として読める。

### 7項目の埋まり方

| 項目 | 状態 |
| --- | --- |
| 1 appのmount view | **埋まった。** `MANAGE_EXTERNAL_STORAGE` を持つ app 自身の mount view で `EEXIST` になり、target は無傷だった。**S-2 が `shell` uid でしか見ていなかった穴が閉じた** |
| 2 失敗時のsource側 | **埋まった。** `EEXIST` からの推論ではなく、**source の中身を実測**して無傷を確認した |
| 3 `/data/local/tmp` の種別 | **埋まった。** `ext3/4` |
| 4 下位filesystem | **一段進んだ。** `/sdcard` は FUSE(`Type: 0x65735546`)で、`mount` によれば下は `/dev/block/dm-6` の **ext4**。**非FUSE の `/data`(ext4)でも同じく効いた**ので、**FUSE は少なくともフラグを阻んでいない**。**FUSE 自身が判定したのか下位へ委譲したのかは、まだ切り分いていない** — 下位が FAT の媒体で観測できて初めて分かる(項目7) |
| 5 API levelの幅 | **埋まらなかった。** API 37 のみで、`T01` の S-2 と同じ level である。**Android 11〜16 は未観測のまま** |
| 6 実機 | **埋まらなかった。** emulator のみ |
| 7 FAT系 | **埋まらなかった。理由は判明した** — app が `/storage` を列挙できないので、装着されていても保存場所にならない(下記)。**媒体側の可否は依然として未観測** |

### 端末に vfat の volume があるのに、app が観測していない

`mount` の出力に **`(null) on /mnt/media_rw/0000-0000 type vfat`** と
**`/dev/fuse on /storage/0000-0000 type fuse`** があり、**この emulator には仮想 SD
カードが装着されている**。ところが probe の観測対象は4件で、`/storage/0000-0000` が
入っていない。

**これが「app の mount view にそもそも無い」のか「列挙に失敗した」のかを、現在の
出力からは区別できない。** `AndroidStorageBrowser.locations()` は
**列挙に失敗しても内部ストレージだけは返す**設計だからである(`android_storage_browser.dart`
の「空にして『保存場所が無い』と見せない」)。

**区別が付かないままだと、004 REQ-015(装着されている SD カード・USB を保存場所として
出す)を満たしているかを判定できない。** そこで **app から見た `/storage` の生の列挙結果**を
報告へ足した(`storageViewOf`。`M143` で「読めなかった」を「空」と混同しないことを固定)。
**2回目の観測を依頼する。**

- `0000-0000` が**出るのに保存場所へ採用されていない** → **`013:T07` の欠陥**(実装が
  取りこぼしている)。修正は別taskで引き受ける。
- `0000-0000` が**出ない** → app の mount view にそもそも無い。**004 REQ-015 の
  「装着されている」の意味を、権限モデルに照らして詰め直す**必要がある(仕様側の論点)。

## 端末での観測 2回目(2026-08-26)= 切り分けが付いた

対象commit は `16d6b24`(`storageViewOf` を足したもの)。環境は1回目と同じ
`sdk_gphone16k_x86_64` / API 37。

```
--- app から見た /storage ---
列挙できなかった: PathAccessException: Directory listing failed, path = '/storage/'
  (OS Error: Permission denied, errno = 13)
保存場所として採用: 1 件
  内部ストレージ = /storage/emulated/0
```

### 分かったこと(1): **app は `/storage` を列挙できない**

**全ファイルアクセス権限があっても `EACCES` である。** したがって現在の実装
(`AndroidStorageBrowser.locations()` が `/storage` の中身から保存場所を作る)は、
**この端末で取り外し可能な volume を1つも列挙できない。** `mount` には
`(null) on /mnt/media_rw/0000-0000 type vfat` があり、**媒体は実際に装着されている。**

**これは 004 REQ-015 と代表例26e に対する成果物の欠陥である**(`013:T07` の実装)。

- REQ-015 は保存場所を「内部共有ストレージ**と、装着されている SD カード・USB
  ストレージのそれぞれ**」と定めている。
- 代表例26e は「SD カードが装着されている端末で browser を開く → 内部共有ストレージと
  SD カードが**それぞれ保存場所として並ぶ**」を期待としている。
- **列挙の手段は 004 spec が「自由とする点」に挙げている**(`StorageManager.getStorageVolumes`、
  `getExternalFilesDirs` からの導出、その他)。**自由なのは手段であって、結果ではない。**
  選んだ手段(`/storage` の列挙)が要求を満たさないことが実機で判明した。

**この欠陥は `T08` では直さない**(T08 の範囲は観測である)。**引き受け先を人間へ諮る。**

### 分かったこと(2): 内部共有ストレージの **root 直下に file を作れない**ことがある

2回目は `/storage/emulated/0` が `観測できず: fixture を置けない: Operation not permitted`
になった。**1回目は同じ場所で成功していた**(`nameConflict`)。差分は権限付与
(`appops set`)の直後かどうかだけである。原因は未特定である。

- **004 spec と矛盾しない。** REQ-018 は「**注記が出ない場所でも改名に失敗しうる**」と
  明記しており、可否は実行結果が示す(005 REQ-013)。
- **`Download` と app ごとの保存領域では両回とも成功している**ので、利用者が実際に使う
  場所での改名には影響しない。
- **harness は落ちずに理由つきで skip した。** 独立review attempt 1〜3 で固めた
  「報告へ必ず到達する」構造が、実際にこの経路で働いた。

### 2回目でも変わらなかったこと

`Download`・app ごとの保存領域・非FUSE の対照の3箇所は、**両回とも `nameConflict` /
目標名無傷 / source 無傷 / 対照は置換**だった。**項目1・2・4 の結論は変わらない。**

## Current state / handoff

- Last checkpoint: **端末での観測2回目で切り分けが付いた**(2026-08-26)。**app は `/storage` を列挙できない(`EACCES`)** ため、現在の実装は取り外し可能な volume を1つも保存場所にできない — **004 REQ-015 / 代表例26e に対する `013:T07` の欠陥**である。項目1〜4は埋まり、5〜7は埋まらなかった
- Blocker category: なし(依存は解けた。`T05`/`T07`とも done)
- Waiting for: **人間の判断**(保存場所の列挙をどう直すか)と、**手順7**(`flutter build apk --debug`)
- Requested action: なし
- Evidence revision: PR #154(Draft)、branch `asdd/013-safe-android-rename/T08-verify-device-coverage`、base は `dev@5307fa7`(`git merge-base dev HEAD` の実測値。当初 `ae59859` と書いたのは誤りで、それは祖先ではあるが merge-base ではない — その値で range を取ると `008` の無関係な doc commit が3件混入する)
- Next Agent action: **人間の観測結果を待つ。** 受けたら7項目を環境つきで記録し、**埋まらなかった項目はそう書く**(Agentが推測で埋めない)。そのあと`final-evidence`のreviewを通してmergeする。**このbranchは動かさない**
