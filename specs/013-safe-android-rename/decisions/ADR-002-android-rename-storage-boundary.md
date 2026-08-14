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

`DocumentsProvider.renameDocument`の`displayName`について、公式資料は「**providerが内部の制約を満たすためにこの名前を変えてよい**」とし、その例として名前の衝突を避けることを挙げている。そして`DocumentsContract.renameDocument`が`Throws`に挙げるのは`FileNotFoundException`(と認証関連)だけで、**名前衝突を表す失敗が定義されていない**。

よってSAFは判定軸「原子的no-replace」と「名前の同一性」の両方を満たせない。**ADR-001の判断は、資料側の変化なく維持される。**

**この記述は原文の転記ではなく筆者の要約である。** 出典と読み取りの根拠は[`research-matrix.md`](../tasks/T01-decide-storage-boundary/research-matrix.md)にある。精度が要る場面では出典を直接読むこと(同節の「原文を転記しない」を参照)。

MediaStoreは`DISPLAY_NAME`の更新でrenameできるが、扱えるのが実質mediaに限られ、004が持つ`document` / `all`を覆えない。`MediaStore.Files`まで広げると`MANAGE_EXTERNAL_STORAGE`の領域に入る。

### spikeで確定したこと

`MANAGE_EXTERNAL_STORAGE`が与える**直接file path access**の上で、NDKの`renameat2(RENAME_NOREPLACE)`が使える。2026-08-13のS-2で次を実測した。

| 環境 | NOREPLACE / target あり | targetの内容 | flags=0 / target あり | NOREPLACE / target なし |
|---|---|---|---|---|
| `/data/local/tmp` | `-1` / `EEXIST` | 無傷 | `0` — 上書きした | `0` |
| `/sdcard` | `-1` / `EEXIST` | 無傷 | `0` — 上書きした | `0` |

環境: Android emulator、Pixel 8a image、Android 17、x86_64。`/sdcard`がFUSEであることは`stat -f`の`Type: 0x65735546`(`FUSE_SUPER_MAGIC`)と`mount`の`/dev/fuse on /storage/emulated type fuse`で観測した。

**`/sdcard`のFUSE経路は`RENAME_NOREPLACE`を尊重する。** フラグ有りは`EEXIST`で失敗しtargetを壊さず、フラグ無しは成功して上書きした。**差はフラグに由来する**ので、「そのpathがそもそも上書きrenameを拒むだけ」という説明は排除された。

対照(flags=0)は初回のspikeに無く、2026-08-13のreviewで指摘されて追加・再実施した。

**ただし「FUSE daemon自身が判定した」とまでは言えない。** 同じ`mount`出力に`/dev/block/dm-6 on /mnt/pass_through/0/emulated type ext4`があり、下位filesystemはext4である。FUSEが判定したのか下位へ委譲したのかは切り分けていない。**1機種・1 API level・`shell` uid・下位ext4の結果である**点も含め、`T08`が引き継ぐ。

## Decision

**候補E(`MANAGE_EXTERNAL_STORAGE` + `renameat2(RENAME_NOREPLACE)`)以外に、005の契約を満たす道は無い。**

**2026-08-13、開発者が候補Eの採用を決定した。** Androidが主対象である以上、「主要プラットフォームで改名できない」状態は製品として成立しないという判断による。以下の2点は採用にあたって受け入れた条件である。

### 受け入れた条件1: `MANAGE_EXTERNAL_STORAGE`をPlayで宣言する

公式資料の条件(**筆者の要約**。出典と読み取りは[`research-matrix.md`](../tasks/T01-decide-storage-boundary/research-matrix.md))。

- 要求してよいのは、**よりprivacy-friendlyなAPI(SAF、Media Store)では目的を達せられない場合に限る**。
- 権限の使い方は、**permitted usesの範囲に入り**、appの**中核機能へ直接結びついて**いなければならない。
- file manager、document management等**に似たuse caseを含むなら要求できる可能性が高い**、としている。

**この一覧は閉じたallowlistではない。** 条件は「一覧に載っていること」ではなく「載っているものに**似ている**こと」と、上のpermitted usesの方である。

**2026-08-13追記: `support.google.com`がallowlistへ追加され、"permitted uses"の原文を読めた。** `[未到達]`は解消した。要点は次のとおり(**筆者の要約**。詳細と出典は[`research-matrix.md`](../tasks/T01-decide-storage-boundary/research-matrix.md))。

- permitted usesの**File management**は「主目的がapp固有storage外のfileとfolderのaccess・編集・管理であること」と定義され、このappの主目的と**一致すると読める**(当てはめは筆者の解釈であり、資料が判定しているわけではない)。
- **同時に、invalid usesの file selection activity にも該当しうる。** 資料は`Any`と書いて限定しておらず、代替の表は「利用者がfileを選んでimport / transfer / **processing**する用途」にSAFを案内している。**一括改名はprocessingに読める。** さらに「一覧は網羅的でない」の注記は**invalid usesの側**に付いており、範囲を広げる方向にしか働かない。
- 例外条項は**3条件すべて**(core functionalityの成立 / 代替が無いか実質的な悪影響 / privacyの緩和)を要し、Consoleでの説明は**追加の義務**である。本ADRの分析は2つ目の論拠になるが、それだけでは足りない。
- `Permissions Declaration Form`の提出と承認が要る。提出しない、または要件を満たさないappは**Playから削除されうる**。
- core functionalityは**appの説明文で目立つ形に記載・訴求されている**必要がある。

**「該当しうるか」は未解決のままである。** 到達できたのはpermitted usesの**定義**であって、このappの**当てはまり**ではない。File managementに当てはまる読みとfile selection activityに当てはまる読みが**両立しうる**。**却下riskを抱えたまま進む判断は変わらないが、riskは当初の見立てより大きい。**

**2026-08-13、開発者がこのriskを受容して進めることを決定した。** invalid usesに該当しうることを認めたうえで、次で寄せる。

- `T03`でapp内file browserを**folderとfileを管理する導線**として作る(File managementの定義へ寄せる)。
- store説明文で**主目的を目立つ形に訴求する**(policyの要求)。
- `Permissions Declaration Form`で、SAF/MediaStoreが不十分な理由を本ADRの分析で説明する。

**却下された場合はAndroid未対応へ戻す。** 退避経路(未対応adapterとnegative testの維持)はこのriskのために保つ。

**設計への含意**: `T03`のapp内file browserを、単なるfile選択画面ではなく**folderとfileを管理する導線**として作ることは、File managementの定義へ寄せる方向に働く。**ただしそれでinvalid usesを外れる保証は無い。**

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
- `minSdk`の扱いを決める。`renameat2`が**bionicのwrapperとして**公開されたのはAPI 30とされるが、これは検索結果の要約で原文を読めていない [未到達]。しかも**生のsyscallを使えばwrapperの有無に依存しない**(S-2のbinaryは`android24`向けにビルドして動作した)。制約はlibcではなくkernelとfilesystemの側にある。選択肢は「30へ上げる」「24のまま生syscallで呼び動かない端末を実行時に検出する」「API levelで一律分岐する」の少なくとも3つ。`013:T02`で人間へ問う。
- 004のAndroid読み込み導線を作り直し、specを再承認する。**この権限があっても`/Android/data/`、`/sdcard/Android`とその大半のsubdirectory、他appのapp固有directoryへは書けない** [一次]。app内file browserがそこを改名できないことを、`T03`で利用者から見える形にする。
- 採用後に、S-2で残した未検証を`013:T08`で確かめる。**7項目ある**([`research-matrix.md`](../tasks/T01-decide-storage-boundary/research-matrix.md)の「S-2で残った未検証」と同じ集合)。
  1. **appのmount view**(`MANAGE_EXTERNAL_STORAGE`を持つapp自身。今回は`shell` uidからの観測)
  2. **失敗時のsource側**(今回はtarget側しか観測しておらず、`EEXIST`からの推論に留まる)
  3. **`/data/local/tmp`のfilesystem種別**(`stat -f`未採取)
  4. **下位filesystem**(今回はFUSEの下がext4。FUSE自身の判定か下位への委譲かを切り分けていない)
  5. **API levelの幅**(Android 17のみ。11〜16は未確認)
  6. **実機**(emulatorのみ)
  7. **FAT系**(SD card / USB OTG未実施)

  **1と2が最も重要である。** 1は`shell` uidの観測をappへ一般化できない点、2は判定軸「失敗時不変」を実測していない点で、どちらもNGなら本ADRを見直す。
- production実装は`013:T02`以降として定義する。**本ADRは実装を含まない。**

### 未解決のまま残る決定

- **`minSdk`をどうするか。** 上記3案。`013:T02`で人間へ問う。
- **Playの宣言が却下された場合の退避。** そのときはAndroid未対応へ戻す(005 contractを緩めない)。この退避経路を保つため、005のAndroid未対応adapterとnegative testは実装中も削除しない。
- **Permissions Declaration Formの提出内容と、store説明文への記載。** リリース時の人間の作業である。policyは「core functionalityがappの説明文で目立つ形に記載・訴求されていること」を求める。**実装が終わってから考えると間に合わない**ので、`T03`の設計時に「何を主目的として説明するか」を決めておく。

### 参考: 採用しなかった場合に起きたこと

005のAndroid未対応が確定し、013は`T01`で閉じていた。なお010(写真・動画source)がMediaStoreを導入するとき、**media限定なら候補Cが再検討の対象になりうる**。その場合も本ADRを入力とする。
