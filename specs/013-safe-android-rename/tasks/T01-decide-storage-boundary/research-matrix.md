# 013:T01 調査matrix — Androidで安全なrenameが成立する境界

- 作成: 2026-08-13
- 状態: **調査中**。決定はまだ出していない。採否は人間の判断を得てからADRへ書く
- 対象: 005 contract revision 3の`INV-002`(既存fileを置換しない)と`OP-004`(失敗時不変)をAndroidで満たせるstorage・permission境界

## この文書の読み方

主張を3段階で区別する。**この区別を崩さないこと。**

| 記号 | 意味 |
|---|---|
| **[一次]** | 公式資料の原文で確認した。引用を併記する |
| **[要spike]** | 資料からは決まらない。実機で観測しないと言えない |
| **[未到達]** | AI containerのegress制限で一次資料へ到達できていない |

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
| E | `MANAGE_EXTERNAL_STORAGE` + NDK `renameat2(RENAME_NOREPLACE)` | [要spike] | 可 | 広い [一次] | **要Play審査** [一次] | **最有力。spike必須** |
| F | app固有storageに限定 | 可 | 可 | 利用者のfileを扱えない | なし | 用途を満たさない |

## 一次資料

### A / B — SAFは要求名を保証しない

`DocumentsProvider.renameDocument`(API 21)の`displayName`パラメータ:

> The provider may alter this name to meet any internal constraints, such as avoiding conflicting names.

戻り値:

> If a different `Document.COLUMN_DOCUMENT_ID` must be used to represent the renamed document, generate and return it. Any outstanding URI permission grants will be updated to point at the new document. If the original `Document.COLUMN_DOCUMENT_ID` is still valid after the rename, return `null`.

client側`DocumentsContract.renameDocument`(API 21):

> Change the display name of an existing document. If the underlying provider needs to create a new `Document.COLUMN_DOCUMENT_ID` to represent the updated display name, that new document is returned and the original document is no longer valid. Otherwise, the original document is returned.

`Throws`は`FileNotFoundException`のみで、**名前衝突を表す失敗が定義されていない。**

**これが決定的である。** providerは衝突を避けるために名前を変えてよいと明記されており、しかも「変えた」ことを呼び出し側へ伝える失敗経路が無い。つまりAは判定軸1と3の両方を満たせない。ADR-001の判断はこの原文どおりで、**revisionを重ねても資料側は変わっていない。**

Bはrename後に`COLUMN_DISPLAY_NAME`を読めば**改変の検出**はできる。しかし検出時点で実体は既に変わっており、巻き戻しも失敗しうる(ADR-001で却下済み)。**検出は保証ではない。**

- 出典: <https://developer.android.com/reference/android/provider/DocumentsProvider>
- 出典: <https://developer.android.com/reference/android/provider/DocumentsContract>

### C — MediaStoreはmedia限定で、他appのfileには同意が要る

renameは`DISPLAY_NAME`の`update`で行う:

> You can move files on disk during a call to `update()` by changing `MediaColumns.RELATIVE_PATH` or `MediaColumns.DISPLAY_NAME`.

しかし所有者の制約がある:

> If your app uses scoped storage, it ordinarily can't update a media file that a different app contributed to the media store.

他appのfileには`RecoverableSecurityException`の捕捉と利用者同意が要る。Android 11以上なら`createWriteRequest()`で**まとめて1回の同意**にできる。一括改名appとしてはこれは扱いやすい。

**それでも足りない。** MediaStoreが素直に扱えるのは画像・動画・音声で、004は`FileKind.document`と`FileKind.all`を持つ。`MediaStore.Files`まで広げると`MANAGE_EXTERNAL_STORAGE`の領域に入り、候補D/Eと同じ配布制約を負う。

衝突時に`update`が失敗するのか別名を採るのかは、**資料に明記が無い** [要spike]。

- 出典: <https://developer.android.com/training/data-storage/shared/media>

### D / E — All files accessの範囲とPlay審査

`MANAGE_EXTERNAL_STORAGE`が与えるもの:

> Read and write access to all files within shared storage / Access to the contents of the `MediaStore.Files` table / Access to the root directory of both the USB OTG drive and the SD card / Write access to all internal storage directories except `/Android/data/`, `/sdcard/Android`, and most subdirectories of `/sdcard/Android` (including direct file path access)

**"including direct file path access"が要点である。** 実pathが得られるので、SAFのopaque handleではなくPOSIX APIを直接使える。

Google Playの制約:

> As of May 2021, the Google Play store has updated its policy to evaluate apps that target Android 11 (API level 30) or higher and request all-files access through `MANAGE_EXTERNAL_STORAGE`.

宣言が許されるのは次のみ:

> File managers / Backup and restore apps / Anti-virus apps / Document management apps / On-device file search / Disk and file encryption / Device-to-device data migration

> Request the permission only when your app can't effectively use more privacy-friendly APIs such as the Storage Access Framework or the Media Store API. Your app's usage must be directly tied to core functionality.

一括改名appが「File managers」または「Document management apps」に当たるかは**Agentが決められる論点ではない。** 配布可否と審査risk、利用者への説明責任が変わるので人間の判断とする。ただし「SAF・MediaStoreでは目的を達せられない」という条件は、上のA〜Cの分析でそのまま論拠になる。

`Environment.isExternalStorageManager()`で付与を確認し、`Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION`で設定画面へ誘導する。

- 出典: <https://developer.android.com/training/data-storage/manage-all-files>

### E — `renameat2(RENAME_NOREPLACE)`

POSIXの`rename(2)`は**既存targetを黙って置換する**ので、`java.io.File.renameTo`は判定軸1を満たさない(候補D)。`java.nio.file.Files.move`も、`REPLACE_EXISTING`なしなら`FileAlreadyExistsException`になるが、実装が「存在確認 → rename」であればTOCTOUが残る [要spike]。

Linuxの`renameat2`に`RENAME_NOREPLACE`を渡せば、targetが存在するとき**kernelが不可分に失敗させる**。bionicでは**API level 30**で公開されたとされる(検索結果の要約であり、AOSPのheaderを直接読めていない [未到達])。

`minSdk = 24`なので、採るなら次のどちらかになる。

- minSdkを30へ上げる(24〜29端末を切る)。
- 実行時に分岐し、API 30未満はAndroidを未対応のままにする。

**さらに重大な未確認点がある。** Android 11以降の共有storageはMediaProviderのFUSEを経由する。**FUSE層が`RENAME_NOREPLACE`フラグを解釈して透過するか**は資料から確定できない [要spike]。透過しなければ、`renameat2`を呼んでも実効的に置換renameになるか`EINVAL`になる。**ここが候補Eの成否を決める。**

- 出典(二次): <https://android.googlesource.com/platform/bionic/+/main/libc/include/android/api-level.h>(検索結果経由。原文未読)

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
4. `/data/local/tmp`(ext4)と`/sdcard`(FUSE)の両方で1〜3を行う。**ext4で効かなければkernel側の問題**で、FUSEを疑う前に切り分けられる。

`MANAGE_EXTERNAL_STORAGE`を持つappは**使わない**。知りたいのはフラグがFUSEを透過するかであり、それは`adb shell`から観測できる。app内での再確認は、候補Eを採用すると決めたあとに行えばよい。**人間の手間を先に増やさない。**

**判定**:
- `-1` / `EEXIST`かつ`spike-d.txt`の内容が不変 → **RENAME_NOREPLACEが有効**。候補Eは判定軸1と2を満たす。
- `-1` / `EINVAL`または`ENOSYS` → FUSEまたはkernelがフラグを解さない。**候補Eは不成立。**
- `0`(成功)かつ`spike-d.txt`が上書きされている → **最悪。フラグが黙って無視されている。**候補Eは不成立で、かつ危険。

Android 11以上の端末と、可能なら別世代の端末の2台で行う。**SD card / USB OTGでも実施する**(filesystemがFATだと挙動が変わりうる)。

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

**依頼**: `android.googlesource.com`をallowlistへ追加していただけると、S-2の結果を実装の根拠と突き合わせられる。**追加が難しければspikeの実測だけで判断する**ことも可能なので、必須ではない。

## 現時点の見立て

**候補Eが唯一、005の契約を緩めずにAndroidのrenameを成立させうる。** ただし成立はS-2の結果に完全に依存し、さらに`MANAGE_EXTERNAL_STORAGE`のPlay審査という**技術ではない関門**を通る必要がある。

S-2が不成立なら、**Androidの安全なunsupportedを維持する**のが正しい結論になる。それは失敗ではなく、005が守っている保証を下げないという判断である。
