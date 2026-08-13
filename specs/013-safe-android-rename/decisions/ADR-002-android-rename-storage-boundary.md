# ADR-002: Androidで安全なrenameを成立させるstorage境界

- Status: **proposed**(人間の決定待ち)
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

**FUSEはフラグを透過する。** 「既存fileを置換せず、kernelが不可分に失敗させる」がAndroidでも得られる。

## Decision

**候補E(`MANAGE_EXTERNAL_STORAGE` + `renameat2(RENAME_NOREPLACE)`)以外に、005の契約を満たす道は無い。**

採否そのものは技術判断では決まらない。**次の2点は人間が決める。**

### 決めること1: `MANAGE_EXTERNAL_STORAGE`を宣言する方針を取れるか

Playが宣言を認めるのは次に限られる。

> File managers / Backup and restore apps / Anti-virus apps / Document management apps / On-device file search / Disk and file encryption / Device-to-device data migration

> Request the permission only when your app can't effectively use more privacy-friendly APIs such as the Storage Access Framework or the Media Store API.

一括改名appが「File managers」「Document management apps」に当たるかは配布の判断である。なお後段の条件「よりprivacy-friendlyなAPIでは目的を達せられない」については、**本ADRの一次資料分析がそのまま論拠になる**(SAFは名前の同一性を保証せず、MediaStoreは対象種別を覆えない)。

**通らなければ、実装しても配布できない。** 他の何よりも先に決める。

### 決めること2: Androidのfile選択導線の作り直しを受け入れるか

`renameat2`はfilesystem pathを要る。SAFのURIは不透明なhandleで**pathへ変換できない**(ADR-001で却下済み)。したがって候補Eを採ると、**Androidのfile選択はSAFからapp内のfile browserへ変わる。**

伴うもの:

- **004の読み込み導線をAndroidだけ作り直す。** 004 specの再承認が要る。
- OSの見慣れた選択画面が自作の画面に変わる(利用者から見える変化)。
- 「すべてのファイルへのアクセス」を許可させる導線と説明が要る。

**これは当初の想定に無かった。** 実装量も利用者影響も「renameを1つ足す」より大きい。

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

**決めること1または2でNoとなった場合の結論。** 失敗ではない。desktopでは完全に動作し、Androidでは理由を明示して実体に触れない。005が守る保証を下げないという一貫した状態である。

## Consequences

### 採用する場合

- 005 contractは**変えない**。INV-002へのplatform例外を作らない。
- `minSdk`を24から30以上へ上げるか、API 30未満で未対応へ分岐する(`renameat2`はAPI 30公開)。**24〜29の端末を切るかどうかも人間の判断**である。
- 004のAndroid読み込み導線を作り直し、specを再承認する。
- 採用後に、S-2で残した未検証を確かめる。**API level幅(Android 11〜16)、実機、FAT系(SD/OTG)、`MANAGE_EXTERNAL_STORAGE`を持つapp自身のmount view。** 特に最後の1つは、今回`adb shell`から観測したものであり、app内で再確認する必要がある。
- production実装は別taskまたは別planへ定義する。**本ADRは実装を含まない。**

### 採用しない場合

- 005のAndroid未対応が**確定**になる。「将来対応する」ではなく「対応しない」と決めたことになるので、利用者への説明もそれに合わせる。
- 013は`T01`の完了をもって閉じる。
- 010(写真・動画source)がMediaStoreを導入するとき、**media限定なら候補Cが再検討の対象になりうる**。そのときは本ADRを入力とする。
