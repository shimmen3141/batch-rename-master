# 013:T01 調査matrix — Androidで安全なrenameが成立する境界

- 作成: 2026-08-13
- 状態: **完了**。採否は[ADR-002](../../decisions/ADR-002-android-rename-storage-boundary.md)(`accepted`)が正本。この文書はその根拠である
- 対象: 005 contract revision 3の`INV-002`(既存fileを置換しない)と`OP-004`(失敗時不変)をAndroidで満たせるstorage・permission境界

## この文書の読み方

主張を3段階で区別する。**この区別を崩さないこと。**

| 記号 | 意味 |
|---|---|
| **[一次]** | 公式資料の原文を読んで確認した。**出典のURLと節名を示し、内容は自分の言葉で書く** |
| **[要spike]** | 資料からは決まらない。実機で観測しないと言えない |
| **[未到達]** | AI containerのegress制限で一次資料へ到達できていない |

### 原文を転記しない

**この文書は外部資料を引用しない。** 出典のURLと節名を示し、読み取った内容は自分の言葉で書く。

2026-08-13のreviewで、引用ブロックの誤りが**3回続けて**検出された。要約toolの言い換えを原文として貼った、人間の生出力を整形して貼った、そして**逐語引用を直す作業の中で原文の`except`を`such as`と書いて意味を反転させた**。3回目は「書けない」を「書ける」に変えており、planを都合よく見せる方向だった。

原因は転記そのものである。**転記しなければ転記ミスは起きない。** 精度が要る場面では、この文書ではなく出典を読む。

判断が引用の一語に依存するとき(`except`か`such as`か、`only`か`likely`か)は、**その語が判断を分けることを本文へ書く。** 語そのものを写すのではなく、どちらであるかを述べる。

## 判定軸

005の契約から降りてくる。**緩めない。**

1. **原子的no-replace** — 目標名の実体が既にあるとき、置換せずに失敗するか。確認してからrenameする形はTOCTOUなので満たさない(ADR-001で判断済み)。
2. **失敗時不変** — 失敗したとき名前・内容・個数・handleが変わらないか。
3. **名前の同一性** — 成功したとき、実体の名前が**要求した目標名と一致する**か(REQ-018 / INV-003)。実装が別名を選ぶ成功を許すと契約が変わる。
4. **handle継続性** — rename後のhandleを呼び出し側が受け取れるか(INV-005)。
5. **対象file種別** — 004が読み込む`document` / `all`を覆えるか。画像・動画だけでは足りない。
6. **追加permission・配布** — 必要な権限とGoogle Play審査への影響。
7. **minSdk** — 現在は`24`(Flutterの既定 `flutter.minSdkVersion`。`packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt:26`で確認)。

## 候補の比較

| # | 候補 | 原子的no-replace | 名前の同一性 | 対象種別 | 追加permission | 判定 |
|---|---|---|---|---|---|---|
| A | SAF `DocumentsContract.renameDocument`(現状) | **不可** [一次] | **保証なし** [一次] | 広い | なし | **不採用**(ADR-001を維持) |
| B | A + rename後にdisplay nameを検証 | 不可(検出のみ) [一次] | 検出可・保証不可 | 広い | なし | 要検討。3を満たせない |
| C | MediaStore `DISPLAY_NAME` update | [要spike] | [要spike] | **media限定** [一次] | 他app所有fileに同意が要る [一次] | 種別で不足 |
| D | `MANAGE_EXTERNAL_STORAGE` + `File.renameTo` | **不可**(POSIX renameは置換する) | 可 | 広い [一次] | **要Play審査** [一次] | 1を満たさない |
| E | `MANAGE_EXTERNAL_STORAGE` + NDK `renameat2(RENAME_NOREPLACE)` | **no-replaceは実測**(原子性はkernel契約に依拠) | 可 | 広い [一次] | **要Play審査** [一次] | **採用**(ADR-002) |
| F | app固有storageに限定 | 可 | 可 | 利用者のfileを扱えない | なし | 用途を満たさない |

## 一次資料

### A / B — SAFは要求名を保証しない

出典: `DocumentsProvider`の`renameDocument(String, String)`(API 21)、および`DocumentsContract`の`renameDocument(ContentResolver, Uri, String)`(API 21)。下記URLの各methodの節。

読み取った内容(**筆者の要約。原文の転記ではない**):

- `DocumentsProvider`側の`displayName`パラメータの説明は、**providerが内部の制約を満たすためにこの名前を変えてよい**としており、その例として**名前の衝突を避けること**を挙げている。
- 戻り値は、renameに伴って別のdocument IDが必要ならそれを返し、元のIDがそのまま有効なら`null`を返す、と定めている。
- `DocumentsContract`側は、providerが新しいdocument IDを作る必要があるならそれを返し元のdocumentは無効になる、そうでなければ元のdocumentを返す、としている。
- **どちらのmethodも、名前衝突を表す失敗を定義していない。** `DocumentsProvider`側の`Throws`は`FileNotFoundException`と`AuthenticationRequiredException`、`DocumentsContract`側は`FileNotFoundException`のみである。なお`DocumentsContract`側は失敗時に`null`を返しうるとも書かれている。

**判断はこの2点に依存する。** (i) 要求名の改変が**許されている**か禁じられているか、(ii) 改変が起きたことを呼び出し側へ伝える失敗経路が**存在しない**か存在するか。資料は(i)許されている・(ii)存在しない、と読める。**この読みが誤っていれば結論が変わる**ので、疑うときは出典を直接読むこと。

**これが決定的である。** providerは衝突を避けるために名前を変えてよいと明記されており、しかも「変えた」ことを呼び出し側へ伝える失敗経路が無い。つまりAは判定軸1と3の両方を満たせない。ADR-001の判断はこの原文どおりで、**revisionを重ねても資料側は変わっていない。**

Bはrename後に`COLUMN_DISPLAY_NAME`を読めば**改変の検出**はできる。しかし検出時点で実体は既に変わっており、巻き戻しも失敗しうる(ADR-001で却下済み)。**検出は保証ではない。**

- 出典: <https://developer.android.com/reference/android/provider/DocumentsProvider>
- 出典: <https://developer.android.com/reference/android/provider/DocumentsContract>

### C — MediaStoreはmedia限定で、他appのfileには同意が要る

出典: 「Access media files from shared storage」の"Update media files"節(下記URL)。

読み取った内容(**筆者の要約**):

- `ContentResolver.update()`で`MediaColumns.RELATIVE_PATH`または`MediaColumns.DISPLAY_NAME`を変えると、**disk上のfileを移動できる**(資料の語は"move files on disk")。`DISPLAY_NAME`を変える場合が改名にあたる、というのは筆者の読みである。
- scoped storageでは、**他のappがmedia storeへ登録したfileを通常は更新できない**。

他appのfileには`RecoverableSecurityException`の捕捉と利用者同意が要る。Android 11以上なら`createWriteRequest()`で**まとめて1回の同意**にできる。一括改名appとしてはこれは扱いやすい。

**それでも足りない。** MediaStoreが素直に扱えるのは画像・動画・音声で、004は`FileKind.document`と`FileKind.all`を持つ。`MediaStore.Files`まで広げると`MANAGE_EXTERNAL_STORAGE`の領域に入り、候補D/Eと同じ配布制約を負う。

衝突時に`update`が失敗するのか別名を採るのかは、**資料に明記が無い** [要spike]。

- 出典: <https://developer.android.com/training/data-storage/shared/media>

### D / E — All files accessの範囲とPlay審査

出典: 「Manage all files on a storage device」の"Operations permitted by MANAGE_EXTERNAL_STORAGE"節と、Google Play policyの節(下記URL)。

権限が与えるもの(**筆者の要約**):

- 共有storage内の全fileへの読み書き。
- `MediaStore.Files` tableの内容への access。
- USB OTG drive と SD card の root directory への access。
- 内部storageのdirectoryへの書き込み。**`/Android/data/`、`/sdcard/Android`、および`/sdcard/Android`の大半のsubdirectoryは除く。** この書き込みには**直接のfile path access**が含まれる。
- この権限があっても、他appのapp固有directory(`Android/data/`の下)へは到達できない。
- なお資料は、`/sdcard/Android/media`は共有storageの一部である、と注記している(=読み書きの対象に入る)。

**"直接のfile path access"が要点である。** 実pathが得られるので、SAFのopaque handleではなくPOSIX APIを直接使える。

**ただし全域ではない。** `/Android/data/`と`/sdcard/Android`の大半へは**書けない**。**app内file browserはそこを改名できない。** この制約は`T03`(読み込み導線の定義)で利用者から見える形にする。

Google Playの制約(**筆者の要約**):

- Android 11(API level 30)以上をtargetし、`MANAGE_EXTERNAL_STORAGE`で全file accessを要求するappを、Playが審査対象にしている(2021年5月から)。
- 要求してよいのは、**よりprivacy-friendlyなAPI(SAF、Media Store)では目的を達せられない場合に限る**。
- appによる権限の使い方は、**permitted usesの範囲に入り**、appの**中核機能に直接結びついて**いなければならない。
- そのうえで、file manager、backup/restore、anti-virus、document management、on-device file search、暗号化、device間のdata移行**に似たuse caseを含むなら、要求できる可能性が高い**としている。

**最後の一覧は閉じたallowlistではない。** 資料の書き方は「これらに**似ている**なら**おそらく**要求できる」であって、「これらに限る」ではない。**この違いが判断を分ける。** 規範的な条件は「permitted usesの範囲に入り、中核機能へ直接結びついていること」の方である。

**"permitted uses"の定義はこのpageには無く、Play Consoleのpolicy pageにある。** 2026-08-13までは`support.google.com`へ到達できず`[未到達]`だったが、同日のallowlist更新で読めるようになった。次節に記す。

`Environment.isExternalStorageManager()`で付与を確認し、`Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION`で設定画面へ誘導する。

- 出典: <https://developer.android.com/training/data-storage/manage-all-files>

### Playのpermitted uses(2026-08-13に到達可能になった)

出典: Play Console Help「Use of All files access (MANAGE_EXTERNAL_STORAGE) permission」(下記URL)。`support.google.com`は2026-08-13のallowlist更新で到達できるようになった。**以前`[未到達]`としていた"permitted uses"の定義はここにある。**

読み取った内容(**筆者の要約。原文の転記ではない**):

- 対象はAndroid 11(API 30)をtargetし、この権限を宣言するapp。宣言するなら**Play ConsoleのPermissions Declaration Formを提出し、承認を受ける**必要がある。提出しない、または要件を満たさないappは**Playから削除されうる**。
- 「core functionality」は**appの主目的**と定義され、それが無ければappは壊れている(unusable)状態になるもの、とされる。さらに**appの説明文で目立つ形に記載・訴求されていること**が求められる。
- permitted usesの表に**File management**があり、その定義は「appの主目的が、**app固有storageの外にあるfileとfolderへのaccess、編集、管理(maintenanceを含む)**であること」。この用途は`MANAGE_EXTERNAL_STORAGE`の対象として挙げられている。
- 他にbackup/restore、anti-virus、document management、on-device search、暗号化、device移行がある。いずれも**Playの審査と承認が前提**と注記されている。

**重要: 「invalid uses」にこのappが該当しうる。** ここは要約しない。**判断が語の強さに依存するため、原文を読むこと。**

- 認められない例の一つは、**利用者が個々のfileを手で選ぶ file selection activity 全般**である(資料は`Any`と書いており、「選ぶだけのapp」に限定していない)。代替としてSAFが案内されている。
- 代替の表には、**利用者がfileを選んで import / transfer / processing する用途**にSAFを検討せよ、という行がある。**一括改名は processing に読める。**
- 「この一覧は網羅的ではない」という注記は、**invalid usesの列挙**に付いている。**invalidの範囲を広げる方向にしか働かない。**

**したがって「該当しうるか」は未解決である。** 到達できたのはpermitted usesの**定義**であって、このappの**当てはまり**ではない。permitted usesのFile managementに当てはまるという読みと、invalid usesのfile selection activityに当てはまるという読みが**両立しうる**。どちらが優先するかは資料に書かれていない。

**この判断はAgentが行わない。** 配布riskの受容であり、原文を読んだうえでの人間の判断とする。

`T03`でapp内file browserをfolder管理の導線として作ることは、**File managementの定義へ寄せる方向に働く**。ただしそれでinvalid usesを外れると保証されるわけではない。

例外条項もある。permitted usesに当てはまらなくても、**(i)** その権限がcore functionalityを成立させ、**(ii)** 代替が無いか、privacy-friendlyな代替がcritical featureへ実質的な悪影響を与え、**(iii)** privacyへの影響がbest practiceで緩和されている場合に、一時的な例外がありうる。**3条件すべてが要る。** さらにConsoleの申告でSAF/MediaStoreが不十分な理由を説明する義務が加わる(説明だけで足りるのではない)。

ADR-002の一次資料分析(SAFは要求名の同一性を保証せず、MediaStoreは対象種別を覆えない)は**(ii)の論拠になる**。(i)と(iii)は別に示す必要がある。

- 出典: <https://support.google.com/googleplay/android-developer/answer/10467955>


### E — `renameat2(RENAME_NOREPLACE)`

POSIXの`rename(2)`は**既存targetを黙って置換する**ので、`java.io.File.renameTo`は判定軸1を満たさない(候補D)。`java.nio.file.Files.move`も、`REPLACE_EXISTING`なしなら`FileAlreadyExistsException`になるが、実装が「存在確認 → rename」であればTOCTOUが残る [要spike]。

Linuxの`renameat2`に`RENAME_NOREPLACE`を渡せば、targetが存在するとき**kernelが不可分に失敗させる**。bionicでは**API level 30**で公開されたとされる(検索結果の要約であり、AOSPのheaderを直接読めていない [未到達])。

**ただしこれはbionicのwrapper関数が公開されたlevelであって、syscallが使えるlevelではない。** 生の`syscall(SYS_renameat2, ...)`を呼べば、wrapperの有無に関わらず到達できる。実際、S-2で使ったbinaryは**`android24`向けにコンパイルし、生のsyscallで呼んで動作した**。

したがって`minSdk = 24`のまま採れる可能性がある。制約はlibcではなく**kernelとfilesystem**の側にあり、そこは[要spike]である。選択肢は少なくとも3つある。

- minSdkを30へ上げる(24〜29端末を切る。最も安全だが端末を失う)。
- minSdk 24のまま生のsyscallで呼び、**動かない端末を実行時に検出して**未対応へ落とす。
- 実行時にAPI levelで分岐し、30未満は一律未対応にする。

**さらに重大な未確認点がある。** Android 11以降の共有storageはMediaProviderのFUSEを経由する。**FUSE層が`RENAME_NOREPLACE`フラグを解釈して透過するか**は資料から確定できない [要spike]。透過しなければ、`renameat2`を呼んでも実効的に置換renameになるか`EINVAL`になる。**ここが候補Eの成否を決める。**

- 出典(**[未到達]**。検索結果の要約であり、bionicのheader原文を読めていない): <https://android.googlesource.com/platform/bionic/+/main/libc/include/android/api-level.h>

## 実機spike

AI containerにはAndroid SDKもemulatorも無い(`AGENTS.md`の前提)ため、host側で人間が実施する。

**最優先のS-2は、実行できる手順書として[`manual-verification.md`](manual-verification.md)に分けてある。人間へ依頼するときはそちらを渡す。** 以下は各spikeの**設計**(何を観測したら何が言えるか)であり、Agentが判定に使う。

### S-1 SAFのdisplay name改変を実測する(候補A/Bの確認)

1. 端末の共有storageに`spike-a.txt`と`spike-b.txt`を置く。
2. SAFで`spike-a.txt`を選び、`DocumentsContract.renameDocument`で`spike-b.txt`へ改名する。
3. **観測**: 例外が出るか、成功して戻りUriが返るか。成功した場合、戻りUriの`COLUMN_DISPLAY_NAME`を読む。`spike-b.txt`の元の内容が残っているかも確認する。

**判定**: `spike-b (1).txt`のような別名になれば、資料どおり「providerが名前を変える」ことの実測になり、候補Aは確定的に不採用。もし`spike-b.txt`の内容が失われていれば**置換が起きた**ことになり、より強い不採用理由になる。

### S-2 `renameat2(RENAME_NOREPLACE)`がFUSEを透過するか(候補Eの成否)

**これが最優先。** これが通らなければ候補Eは消える。

**実行手順は[`manual-verification.md`](manual-verification.md)。** 観測用のCプログラムは[`spike/renameat2_spike.c`](spike/renameat2_spike.c)にあり、fixtureの作成・2ケースの実行・片付けまで行う。

観測するのは次である。

1. targetが既にある状態で`renameat2(..., RENAME_NOREPLACE)`を呼んだときの戻り値と`errno`。
2. そのときtargetの内容が保たれているか。
3. targetが無い場合に通常どおり成功するか(対照)。
4. `/data/local/tmp`(FUSEを経由しないapp外のpath)と`/sdcard`(FUSE)の両方で1〜3を行う。**前者で効かなければkernel側の問題**で、FUSEを疑う前に切り分けられる。`stat -f`で両方のfilesystem種別を記録する。

`MANAGE_EXTERNAL_STORAGE`を持つappは**使わない**。知りたいのはフラグがFUSEを透過するかであり、それは`adb shell`から観測できる。app内での再確認は、候補Eを採用すると決めたあとに行えばよい。**人間の手間を先に増やさない。**

**判定**:
- `-1` / `EEXIST`かつ`spike-d.txt`の内容が不変 → **RENAME_NOREPLACEが有効**。候補Eは判定軸1を満たす。**判定軸2(失敗時不変)はsource側を観測するまで満たしたと言えない**(spikeへ追加済み)。
- `-1` / `EINVAL`または`ENOSYS` → FUSEまたはkernelがフラグを解さない。**候補Eは不成立。**
- `0`(成功)かつ`spike-d.txt`が上書きされている → **最悪。フラグが黙って無視されている。**候補Eは不成立で、かつ危険。

Android 11以上の端末と、可能なら別世代の端末の2台で行う。**SD card / USB OTGでも実施する**(filesystemがFATだと挙動が変わりうる)。

### S-2の結果(2026-08-13 実施。対照を追加して再実施)

**A) `RENAME_NOREPLACE`が効いている。** 両方のpathで同じ結果だった。

| 環境 | A: NOREPLACE / target あり | targetの内容 | B: flags=0 / target あり | C: NOREPLACE / target なし |
|---|---|---|---|---|
| `/data/local/tmp`(fs種別未観測) | `-1` / `errno 17 EEXIST` | 無傷 | `0` — **上書きした** | `0` |
| `/sdcard` | `-1` / `errno 17 EEXIST` | 無傷 | `0` — **上書きした** | `0` |

**case Bが決め手である。** 同じ操作をフラグ無しで行うと成功して上書きする。**差はフラグに由来する**ので、「そのpathがそもそも上書きrenameを拒む」possibilityは排除された。

**観測したのはtarget側だけである。** case Aは失敗後の`spike-d.txt`が`TARGET`のままであることを見ているが、**source(`spike-c.txt`)が元の名前・内容で残っているかは測っていない**。`EEXIST`はrenameが行われなかったことを意味するので推論としては妥当だが、判定軸2(失敗時不変)を実測したとは言えない。spikeへsource側の確認を追加したので、`T08`の実行では実測になる。

`/sdcard`がFUSEであることも観測した(推測ではない)。

```text
$ adb shell stat -f /sdcard
  File: "/sdcard"
    ID: 0000000000000000 Namelen: 255    Type: 0x65735546
Block Size: 4096    Fundamental block size: 4096
Blocks: Total: 2541783  Free: 1168353   Available: 1131489
Inodes: Total: 655360   Free: 645365

$ adb shell mount | Select-String sdcard,fuse,emulated
none on /sys/fs/fuse/connections type fusectl (rw,relatime)
/dev/fuse on /mnt/user/0/emulated type fuse (rw,lazytime,nosuid,nodev,noexec,noatime,user_id=0,group_id=0,allow_other)
/dev/fuse on /storage/emulated type fuse (rw,lazytime,nosuid,nodev,noexec,noatime,user_id=0,group_id=0,allow_other)
/dev/fuse on /mnt/androidwritable/0/emulated type fuse (rw,lazytime,nosuid,nodev,noexec,noatime,user_id=0,group_id=0,allow_other)
/dev/fuse on /mnt/installer/0/emulated type fuse (rw,lazytime,nosuid,nodev,noexec,noatime,user_id=0,group_id=0,allow_other)
/dev/block/dm-6 on /mnt/pass_through/0/emulated type ext4 (rw,seclabel,nosuid,nodev,noatime,resgid=1065,errors=panic)
/dev/fuse on /mnt/user/0/0000-0000 type fuse (...)
/dev/fuse on /storage/0000-0000 type fuse (...)
/dev/fuse on /mnt/androidwritable/0/0000-0000 type fuse (...)
/dev/fuse on /mnt/installer/0/0000-0000 type fuse (...)
```

(`0000-0000` volumeの4行だけoptionを省略した。他は生出力のままである。)

`0x65735546`は`FUSE_SUPER_MAGIC`である。**`/sdcard`はFUSE経由であり、その経路が`RENAME_NOREPLACE`を尊重した。**

**ただし「FUSE daemon自身がフラグを判定した」とまでは言えない。** 同じ出力に`/dev/block/dm-6 on /mnt/pass_through/0/emulated type ext4`があり、**下位のfilesystemはext4である**。FUSEが自分で判定したのか、下位のext4へ委譲した結果なのかは、この観測では切り分けられない。下位がFATやf2fsのときに同じ結果になる保証は無い(`T08`)。

実施環境: Android emulator、Pixel 8a image、**Android 17("CinnamonBun")**、x86_64。

初回のspikeにはcase Bが無く、「フラグが効いた」の因果を示せていなかった(2026-08-13のreview attempt 1でP1として指摘)。対照を追加して再実施し、**因果が確定した。**

**1機種・1 API level・`shell` uidの結果であることは変わらない。** 残る未検証は次節に書く。

### S-2で残った未検証

- **API levelの幅**: Android 17でしか見ていない。実装が対象にするAndroid 11〜16のFUSEで同じとは限らない。**MediaProviderのFUSE実装はversionごとに変わる。**
- **実機**: emulatorのみ。実機のvendor kernelやfilesystem(f2fs等)で挙動が変わりうる。
- **下位filesystem**: 今回の`/sdcard`はFUSEの下がext4だった。**FUSEが自分で判定したのか下位へ委譲したのかを切り分けていない。** 下位がFATやf2fsのとき同じとは限らない。
- **`/data/local/tmp`のfilesystem種別**: `stat -f`を採っていない。
- **失敗時のsource側**: 上記のとおり未観測(推論に留まる)。
- **FAT系**: SD card / USB OTGは未実施。FATは`renameat2`のフラグをfilesystem側で扱えない可能性がある。
- **appのmount view**: `adb shell`(shell uid)からの観測である。`MANAGE_EXTERNAL_STORAGE`を持つappは**別のmount viewで`/storage`を見る**ため、同じ結果になるとは限らない。**候補Eを採用すると決めた場合、app内での再確認が要る。**

これらは**採用を決めてから**確かめる。決める前に人間の時間を使わない。

### S-3 `Files.move`の非置換動作(候補D/Eの代替)

`java.nio.file.Files.move`をtargetが存在する状態で呼び、`FileAlreadyExistsException`になるか、置換されるかを観測する。**原子性は観測できない**ので、これは「使えるか」ではなく「明らかに使えないか」を早く知るためのspikeである。

### S-4 MediaStore `DISPLAY_NAME`更新の衝突挙動(候補C)

同じfolderに既にある名前へ`update`し、失敗するか別名になるかを観測する。候補Cは種別の点で既に不足なので、**S-2が成立した場合はこのspikeを省いてよい。**

## 到達できていない一次資料

`android.googlesource.com`と`support.google.com`はcontainerから到達できない(いずれもtimeout)。`developer.android.com`・`source.android.com`・`api.flutter.dev`・`cs.android.com`は2026-08-13のfirewall更新で到達できるようになった。

そのため次を直接読めていない。

- AOSP `ExternalStorageProvider` / `FileSystemProvider`の`renameDocument`実装(衝突時に`buildUniqueFile`で別名を作るかどうか)。
- bionicの`renameat2`宣言とAPI levelの原文。
- MediaProviderのFUSE実装が`RENAME_NOREPLACE`を扱うか。

`android.googlesource.com`をallowlistへ追加すればAOSP実装と突き合わせられるが、**採否の判断には必要なかった**ため依頼していない。必要になるとすれば`T08`で実機の挙動が資料と食い違ったときである。そのとき改めて判断する。

## 現時点の結論

**候補Eは動く。** S-2で、FUSEと確認した`/sdcard`上で`renameat2(RENAME_NOREPLACE)`が`EEXIST`で失敗しtargetを壊さないこと、**同じ操作がフラグ無しなら成功して上書きすること**を対照付きで実測した。候補A〜D・Fはいずれも判定軸のどれかを満たせないので、**候補Eが唯一の道である。**

**ただし1機種・1 API level・`shell` uidの結果である。** 残る未検証は上の「S-2で残った未検証」の**7項目**であり、`T08`が同じ集合を引き継ぐ。ここで数を書き直さない(箇所ごとに集合がばらけるのを避けるため)。

残る関門は2つで、**どちらも技術ではない。**

### 関門1: `MANAGE_EXTERNAL_STORAGE`のPlay審査

**2026-08-13にPlay Consoleのpolicy原文を読めるようになった。** 分かったのは条件の中身であって、このappが通るかではない。

- permitted usesの**File management**の定義は、このappの主目的と一致すると読める。
- **同時に、invalid usesのfile selection activityにも該当しうる**(上の「Playのpermitted uses」節)。資料は`Any`と書き、代替の表は「利用者がfileを選んでimport / transfer / **processing**する用途」にSAFを案内している。**一括改名はprocessingに読める。**
- 「一覧は網羅的でない」という注記は**invalid usesの側**に付いており、invalidの範囲を広げる方向にしか働かない。
- 例外条項は3条件すべてを要し、Consoleでの説明は追加の義務である。
- **Permissions Declaration Formの提出と承認が要り、承認されるかはPlayの審査次第**である。

**「該当しうるか」は未解決のままである。** 到達できたのはpermitted usesの定義であって、このappの当てはまりではない。`T03`でfolder管理の導線として作ることはFile managementの定義へ寄せる方向に働くが、**それでinvalid usesを外れる保証は無い。** これはAgentが決める論点ではなく、原文を読んだうえでの人間のrisk受容である。

### 関門2: Androidのfile選択導線が変わる

これは調査中に判明した、**当初の想定に無かった影響である。**

`renameat2`はfilesystemのpathを要る。SAFのURIは不透明なhandleで、**pathへ変換できない**(ADR-001で却下済み)。したがって候補Eを採るなら、Androidのfile選択は**SAFではなくapp内のfile browserへ変わる**。`MANAGE_EXTERNAL_STORAGE`があれば直接pathでfilesystemを辿れるので技術的には可能だが、次を伴う。

- **004の読み込み導線をAndroidだけ作り直す。** 004 specの再承認が要る。
- 利用者から見て、OSの見慣れた選択画面が自作の画面に変わる。
- 「すべてのファイルへのアクセス」を許可させる導線と説明が要る。

**これは013単独の話ではなく004へ波及する。** 実装量も利用者影響も、当初の「renameを1つ足す」より大きい。

### 採らない場合

**Androidの安全なunsupportedを維持する**のが正しい結論になる。それは失敗ではなく、005が守っている保証を下げないという判断である。desktopでは完全に動作し、Androidでは理由を明示して何もしない — この状態はそれ自体が一貫している。
