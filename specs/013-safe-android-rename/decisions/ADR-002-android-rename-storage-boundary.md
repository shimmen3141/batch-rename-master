# ADR-002: Androidで安全なrenameを成立させるstorage境界

- Status: **accepted**(2026-08-13 開発者承認)
- Date: 2026-08-13
- Related: [ADR-001](../../005-rename-exec/decisions/ADR-001-android-saf-rename-safety.md)、005 `contracts/behavior-contract.json` revision 3、004 spec 決定D-2
- Related requirements: INV-002(既存fileを置換しない)、INV-003 / REQ-018(要求名と結果名の一致)、OP-004(失敗時不変)
- Related tasks: `013:T01`
- 根拠: [`tasks/T01-decide-storage-boundary/research-matrix.md`](../tasks/T01-decide-storage-boundary/research-matrix.md)

## Context

ADR-001は「Android SAFのrenameは005の契約を満たせない」と判断し、Androidを安全なunsupportedにした。013:T01は、**契約を緩めずにAndroidでrenameできる境界が存在するか**を調べる責務を負った。

候補A〜F(`research-matrix.md`)を、一次資料と実機spikeで検証した。

### 一次資料で確定したこと

`DocumentsProvider.renameDocument`の`displayName`について、公式資料は次を明記する。

> The provider may alter this name to meet any internal constraints, such as avoiding conflicting names.

client側`DocumentsContract.renameDocument`の`Throws`は`FileNotFoundException`のみで、**名前衝突を表す失敗が定義されていない**。よってSAFは判定軸「原子的no-replace」と「名前の同一性」の両方を満たせない。**ADR-001の判断は、資料側の変化なく維持される。**

MediaStoreは`DISPLAY_NAME`の更新でrenameできるが、扱えるのが実質mediaに限られ、004が持つ`document` / `all`を覆えない。`MediaStore.Files`まで広げると`MANAGE_EXTERNAL_STORAGE`の領域に入る。

### spikeで確定したこと

`MANAGE_EXTERNAL_STORAGE`が与える**直接file path access**の上で、NDKの`renameat2(RENAME_NOREPLACE)`が使える。2026-08-13のS-2で次を実測した。

| 環境 | target あり | targetの内容 | target なし |
|---|---|---|---|
| `/data/local/tmp`(ext4) | `-1` / `EEXIST` | 無傷 | `0` |
| `/sdcard`(FUSE) | `-1` / `EEXIST` | 無傷 | `0` |

環境: Android emulator、Pixel 8a image、Android 17、x86_64。

観測できたのは「`RENAME_NOREPLACE`を付けた`renameat2`は、targetがあるとき`EEXIST`で失敗し、targetを壊さない」までである。

**「フラグが効いたから安全だった」という因果はまだ示せていない。** flags=0の対照を取っていないため、「そのpathがそもそも上書きrenameを拒む」可能性を排除できない。安全側の挙動である点は変わらないが、**他のAPI level・kernel・filesystemへ一般化する根拠にはならない。** 対照はspikeへcase Bとして追加済みで、再実施待ちである(`T08`が引き継ぐ)。

## Decision

**候補E(`MANAGE_EXTERNAL_STORAGE` + `renameat2(RENAME_NOREPLACE)`)以外に、005の契約を満たす道は無い。**

**2026-08-13、開発者が候補Eの採用を決定した。** Androidが主対象である以上、「主要プラットフォームで改名できない」状態は製品として成立しないという判断による。以下の2点は採用にあたって受け入れた条件である。

### 受け入れた条件1: `MANAGE_EXTERNAL_STORAGE`をPlayで宣言する

公式資料の条件は次のとおりである。

> Request the `MANAGE_EXTERNAL_STORAGE` permission only when your app can't effectively make use of the more privacy-friendly APIs, such as the Storage Access Framework or the Media Store API. Your app's usage of the permission **must fall within permitted uses** and must be directly tied to the core functionality of the app.

> If your app includes a use case **similar to any of the following, it's likely that** it can request the `MANAGE_EXTERNAL_STORAGE` permission:
>
> File managers / Backup and restore apps / Anti-virus apps / Document management apps / On-device file search / Disk and file encryption / Device-to-device data migration

**この一覧は閉じたallowlistではない。** 条件は「一覧に載っていること」ではなく「載っているものに**似ている**こと」と「permitted usesの範囲に入り、中核機能へ直接結びついていること」である。

**"permitted uses"の定義はこのpageに無く、Play Consoleのpolicy pageにある。そのdomainはcontainerから到達できていない [未到達]。** よって「一括改名appが該当する」ことを資料で確定できていない。**却下されるriskを抱えたまま実装planへ進む**という判断である。

「よりprivacy-friendlyなAPIでは目的を達せられない」という条件については、**本ADRの一次資料分析がそのまま論拠になる**(SAFは名前の同一性を保証せず、MediaStoreは対象種別を覆えない)。宣言理由にはこれを使う。**ただし提出前に、人間がPlayのpolicy原文と突き合わせること。**

### 受け入れた条件2: Androidのfile選択導線を作り直す

`renameat2`はfilesystem pathを要る。SAFのURIは不透明なhandleで**pathへ変換できない**(ADR-001で却下済み)。したがって候補Eを採ると、**Androidのfile選択はSAFからapp内のfile browserへ変わる。**

伴うもの:

- **004の読み込み導線をAndroidだけ作り直す。** 004 specの再承認が要る。
- OSの見慣れた選択画面が自作の画面に変わる(利用者から見える変化)。
- 「すべてのファイルへのアクセス」を許可させる導線と説明が要る。

**これは当初の想定に無かった。** 実装量も利用者影響も「renameを1つ足す」より大きい。採用の決定はこの範囲を含む。

## Considered alternatives

ADR-001が却下した案は、その判断を維持する(SAF前の存在確認、provider実名の採用、rename後の巻き戻し、copy+delete、SAF URIからのpath推測)。013:T01が新たに検討して却下したものを記す。

### 候補B: SAF renameの後にdisplay nameを検証する

採用しない。改変の**検出**はできるが、検出時点で実体は既に変わっている。巻き戻しも失敗しうるためOP-004の失敗時不変を保証できない。**検出は保証ではない。**

### 候補C: MediaStoreの`DISPLAY_NAME`更新

採用しない。扱えるのが実質mediaに限られ、004の`document` / `all`を覆えない。他appが登録したfileの更新に利用者同意が要る点は、Android 11以上の`createWriteRequest()`でまとめられるため障害ではないが、**対象種別の不足が決定的**である。

### 候補D: `MANAGE_EXTERNAL_STORAGE` + `File.renameTo`

採用しない。POSIXの`rename(2)`は既存targetを**黙って置換する**。INV-002を満たさない。`java.nio.file.Files.move`も、非置換の実現が「存在確認 → rename」であればTOCTOUが残る。

### 候補F: app固有storageに限定する

採用しない。利用者のfileを扱えず、appの目的を満たさない。

### Androidを未対応のまま維持する

**採用しない場合の結論だった。2026-08-13に採用が決まったため、この案は採らない。** 失敗ではない選択肢ではあった。desktopでは完全に動作し、Androidでは理由を明示して実体に触れない。005が守る保証を下げないという一貫した状態である。

## Consequences

### 採用したことによる帰結

- 005 contractは**変えない**。INV-002へのplatform例外を作らない。
- `minSdk`の扱いを決める。`renameat2`が**bionicのwrapperとして**公開されたのはAPI 30とされるが、これは検索結果の要約で原文を読めていない [未到達]。しかも**生のsyscallを使えばwrapperの有無に依存しない**(S-2のbinaryは`android24`向けにビルドして動作した)。制約はlibcではなくkernelとfilesystムの側にある。選択肢は「30へ上げる」「24のまま生syscallで呼び動かない端末を実行時に検出する」「API levelで一律分岐する」の少なくとも3つ。`013:T02`で人間へ問う。
- 004のAndroid読み込み導線を作り直し、specを再承認する。**この権限があっても`/Android/data/`、`/sdcard/Android`とその大半のsubdirectory、他appのapp固有directoryへは書けない** [一次]。app内file browserがそこを改名できないことを、`T03`で利用者から見える形にする。
- 採用後に、S-2で残した未検証を確かめる。**API level幅(Android 11〜16)、実機、FAT系(SD/OTG)、`MANAGE_EXTERNAL_STORAGE`を持つapp自身のmount view。** 特に最後の1つは、今回`adb shell`から観測したものであり、app内で再確認する必要がある。
- production実装は`013:T02`以降として定義する。**本ADRは実装を含まない。**

### 未解決のまま残る決定

- **`minSdk`をどうするか。** 上記3案。`013:T02`で人間へ問う。
- **Playの宣言が却下された場合の退避。** そのときはAndroid未対応へ戻す(005 contractを緩めない)。この退避経路を保つため、005のAndroid未対応adapterとnegative testは実装中も削除しない。

### 参考: 採用しなかった場合に起きたこと

005のAndroid未対応が確定し、013は`T01`で閉じていた。なお010(写真・動画source)がMediaStoreを導入するとき、**media限定なら候補Cが再検討の対象になりうる**。その場合も本ADRを入力とする。
