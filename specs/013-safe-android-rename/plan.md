# 013 Androidの安全なrename境界

## 目的

Androidで既存fileを置換しない原子的no-replaceと失敗時不変を維持しながら、利用者が選んだfileをrenameできるstorage・permission境界が存在するかを調査し、実装を約束する前に採用・不採用・制約付き採用の設計判断を出す。

## 境界

### 対象

- storage方式の比較と設計判断(`T01`で完了。[ADR-002](decisions/ADR-002-android-rename-storage-boundary.md))。
- `MANAGE_EXTERNAL_STORAGE`の取得導線と、権限が無いときの振る舞い。
- `renameat2(RENAME_NOREPLACE)`によるAndroidの`RenameExecutor`実装。
- **Androidのfile選択をSAFからapp内file browserへ作り直すこと。** 004 specの更新と再承認を伴う。
- 005 contractのAndroid経路の更新(revision 4)と再承認。
- 実装後の端末幅・媒体・app内mount viewの再検証。
- **対象folderの占有名を衝突判定へ入れること**(`T10`)。占有名=実在名−この実行で改名される選択fileの現在名。001と004の仕様改訂を伴う。
- **005 contract revision 4の実行経路(再採番・結果提示・実在確認)の実装**(`T11`)。**desktopを含む。**

### 対象外

- 005 INV-002のplatform例外やprovider依存raceの受容。**契約は緩めない。**
- SAF URIを未検証のraw pathへ変換するworkaround。
- desktopの読み込み導線の変更(OS pickerのまま)。
- Play Consoleへの配布申請そのもの。→ 人間が行う
- 隠し・system fileのfilter。→ 012
- 写真・動画のgallery選択。→ 010

## 方針

- **契約にplatform例外を作らない。** INV-002(既存fileを置換しない)、INV-003 / REQ-018(**確認した名前**と結果名の一致)、OP-004(失敗時不変)。**ただし2026-08-14のcontract revision 4で、INV-002の成立範囲は環境依存になった**(原子的no-replaceがあれば完全、無ければTOCTOUの分だけ成立しない)。**これは全platform共通の契約であって、Androidの例外ではない。**
- **端末・媒体で「改名できない」を作らない**(2026-08-14)。`RENAME_NOREPLACE`が効かない端末は、実在確認による事前検出へ**劣化するだけ**とする。効くかを実行前に測る(preflight)必要は無くなった。
- **Playのpolicy確認をT05〜T07の前段のgateとした。** 2026-08-13に`support.google.com`が到達可能になり、原文を読んだ(`[未到達]`は解消)。permitted usesのFile managementとこのappの主目的は一致すると読めるが、invalid usesのfile selection activityにも該当しうる。**当てはまりは資料からは決まらない**ため、開発者がriskを受容してT05以降へ投資すると決めた(下の決定表)。**gateは通過済みである。**
- **退避経路を残す。** Playの宣言が却下される可能性がある。`lib/data/rename_exec/saf_rename_executor.dart`(安全な未対応)とそのnegative testは実装中も削除しない。
- **仕様を変えるものは、仕様更新taskと実装taskを分ける。** 004はapproved、005はStrict approvedなので、外部から観測できる振る舞いを変えるには人間の再承認が要る。
- **一次資料とspikeを区別する。** `T01`が確立した`[一次]` / `[要spike]` / `[未到達]`の区別を以後も使う。
- **`covers`は仕様task(T02/T03/T04)が埋める。** REQ IDが確定するのはそれぞれの承認時なので、各taskの受け入れ証拠に「対応する実装task(T05〜T08、T10)の`covers`を書く」ことを入れてある。**ただし`T10`と`T11`の`covers`は空のままにする**(2026-08-20) — 構造検査は`covers`を**所有planのspec.mdのID**として引くので、`001:REQ-007`のような他featureのIDを書くと未解決参照の警告になる。両taskが実装するのは001/004/005のREQであり、013自身のREQではない。**cross-featureの被覆は各`task.md`の「仕様被覆」節へ書く。**`T02`の分は2026-08-14に記入済み、004/005側は`T03`/`T04`が埋める。**特にT04は005 Strict contractを触るので、被覆の記録を落とさない。**
- **`covers`へIDを書くだけで終わらせない。** REQ IDを載せたtaskの「変更範囲」と「受け入れ証拠」に、そのREQを検査する記述が実際にあることまでを条件とする。`T02`のreview attempt 2で、preflightのREQ-010〜013が`T05`の`covers`にだけ存在し**どのtaskの受け入れ証拠にも現れない**状態が見つかったため加えた(当時は`T09`を新設して解消した。`T09`は2026-08-14の方針転換で削除したが、この規則は残す)。
- **spikeの未検証を実装後に埋める。** `T01`のS-2は1機種・1 API level・`shell` uidの観測である。`T08`で実装したappから確かめる。**ただしこれは製品の可否を左右しない** — フラグが効かなくても実在確認へ劣化するだけである。確認の目的は、INV-002がどの環境で完全に成立するかを知ることである。

## 全体の受け入れ証拠

- [x] 候補ごとの原子的no-replace、失敗時不変、handle継続性が一次資料とspikeで区別される(`T01`)
- [x] permissionと配布制約が公式資料に接続される(`T01`)
- [x] 長期的なWhy/Why notを持つdecision recordで採否を判断できる([ADR-002](decisions/ADR-002-android-rename-storage-boundary.md))
- [ ] Androidで、目標名のfileが既にあるとき**置換せずに失敗**し、実体が無傷である
  - 証拠: 005 contract revision 4、仕様由来test、`T08`の実機確認
- [ ] `MANAGE_EXTERNAL_STORAGE`の要否と、許可されないときの振る舞いが利用者から観測できる
  - 証拠: `T02`で承認された仕様、widget test、実機確認
- [ ] Androidでfileを選び、改名し、undoできる(desktopと同じ受け入れシナリオ)
  - 証拠: 004 spec再承認、実機確認
- [ ] 実装したappのmount viewで`RENAME_NOREPLACE`の挙動を確認し、INV-002の成立範囲を記録した
  - 証拠: `T08`。**`shell` uidの観測では代用しない**
- [x] **desktopで**、読み込んでいないfileとの衝突が実行前に警告として出て、**入れ替え・循環では警告が出ない**
  - 証拠: `T10`(2026-08-21)、001 contract revision 2 / 004 spec の改訂と再承認、005 spec例25/25b/25c。`test/spec_005_rename_exec/occupied_names_test.dart`と`test/spec_001_rename_core/validation_test.dart`、mutation M30〜M34
- [ ] **Androidで**、同じことが成立する
  - 証拠: `T07`(app内file browser)が列挙権限を持ってから。**現在はSAFが親folderを列挙できないため`listNames`が失敗し、REQ-027で実行が止まる** — 契約どおりの振る舞いだが、警告を出す段階まで到達しない。`T10`はこの受け入れをdesktopでしか満たしていない
- [ ] 実行時の`nameConflict`が再採番され、結果に「確認した名前と異なる」が出る
  - 証拠: `T11`、005 spec例24/26/28〜30、VER-008
- [x] 占有名がfolder単位で効き、実在名を取得できないfolderを含む実行は行わない
  - 証拠: `T10`(2026-08-21)/`T11`、005 spec例25d/25e、REQ-026/REQ-027、OQ-001〜OQ-008の決着(revision 5として承認済み)。mutation M23/M24/M34/M38/M41/M43
- [ ] 005の安全なunsupportedとnegative testを弱めない(退避経路の維持)

## 人間の決定

| 日付 | 論点 | 決定 | 決定者 |
|---|---|---|---|
| 2026-08-09 | 現SAF APIがStrict no-replaceを保証できない | Android成功経路を005から分離し、最初の成果を調査と設計判断に限定する | 開発者 |
| 2026-08-13 | storage境界の採否 | **候補E(`MANAGE_EXTERNAL_STORAGE` + `renameat2(RENAME_NOREPLACE)`)を採用する。** Androidが主対象である以上、主要プラットフォームで改名できない状態は製品として成立しない。Play審査riskと、Androidのfile選択をapp内browserへ作り直す範囲を受け入れる | 開発者承認 |
| 2026-08-13 | `minSdk` | **24のまま、対応可否を実行時に判定する。** API levelは対応可否の代理指標として弱く、実際に効くかを決めるのはkernelとfilesystemであるため | 開発者承認 |
| 2026-08-13 | Play policyのinvalid uses | **該当しうることを認めたうえでriskを受容し、T05以降へ投資する。** `T03`のfolder管理導線、store説明文での主目的の訴求、Declaration Formでの説明で寄せる。却下されたらAndroid未対応へ戻す | 開発者承認 |
| 2026-08-14 | `spec.md`の再承認(失効) | ~~preflightの後片付け・batch単位・失効条件を追加した仕様を承認~~ **同日の方針転換でpreflightごと削除。** | 開発者承認(失効) |
| 2026-08-14 | preflightの所有判定(第1案) | ~~2段階作成 + 空の回収~~ **同日に破棄。** review attempt 4で、解除側の窓とmarker書きかけの窓が残ることが判明した | 開発者方針決定(破棄) |
| 2026-08-14 | 005 contract revision 4 | **approved。** 占有名(folderごと)を衝突判定と自動解決へ常に含める(REQ-026)、実在名を取得できないfolderを含む実行は行わない(REQ-027)、`nameConflict`は再採番(REQ-023)、改名ポートは常に実在確認(REQ-025) | 開発者承認 |
| 2026-08-15 | 結果toastのdesign逸脱 | **受容してmergeする。** 再採番された項目の「旧 → 新」を全件出すため、結果toastの情報階層をdesignの1行から2段へ変えた。REQ-024の「黙って別の名前にしない」がdesignの1行と両立しないため。**提示手段の見直し(modal化)は008へ送った** | 開発者 |
| 2026-08-14 | 013 `spec.md`の再承認 | **approved。** preflight削除に加え、**新規must要求REQ-005・REQ-006とVER-005を含む**。REQ-005は「`renameat2`が使えない端末を対応外にしない」で、旧承認版のREQ-009と方向が逆である | 開発者承認 |
| 2026-08-14 | **衝突の扱い(方針転換)** | **衝突は失敗ではなく採番で回避する。** 他の警告と同じモーダルで確認し、実行するなら`(n)`を付ける。`RENAME_NOREPLACE`は破壊を防ぐ砦から**再採番の入口**へ役割が変わり、**preflightは不要になった**。005 contract revision 4と[005 ADR-002](../005-rename-exec/decisions/ADR-002-collision-resolution-by-numbering.md)。代償はTOCTOU(フラグが効かない環境のみ) | 開発者決定 |
| 2026-08-20 | **OQ-006(001の重複判定の範囲)** | **001の重複判定をfolder単位へ揃える。** 001の用語「最終名集合」をfolderごとの多重集合に改め、REQ-007/010/012・INV-003をfolder単位へ、REQ-015(占有名を最終名集合へ含める)を追加する。004 T7 OQ-3の「001の判定範囲は変更しない」を**明示的に取り消す**。理由は、占有名がfolderごとと決まった以上、最終名集合を横断のまま残すと規則が2つ並び、**実際には衝突しないのに ` (n)` を付ける自動解決**が残るため。単一folderからの選択では挙動は変わらない | 開発者決定 |
| 2026-08-21 | **001 / 004 / 005の再承認** | **approved。** 005 contract **revision 5**(OQ-001〜OQ-008の決着、REQ-028「占有名は実行を要求した時点で取り直す」、OP-005 `collectOccupiedNames`)、001 contract **revision 2**(最終名集合のfolder単位化、REQ-015、OP-003/OP-004への`occupiedNames`追加)、004 spec(REQ-013 所属folderハンドル、REQ-014 `listNames`)。**REQ-028とOP-005は新規のmust要求・新規操作**であり、**001のfolder単位化によりrevision 4までは警告が出ていた例25f(別folderの読み込み済み・未選択fileと同名)が警告なしになる**ことを承認時の差分として確認した | 開発者承認 |
| 2026-08-21 | **`T10`のAndroid実機確認** | **不要とする。** `T10`でAndroidの観測可能な振る舞いは変わる(実行すると`prepare()`で止まり「フォルダ内のファイル名を確認できないため実行しませんでした」になる。従来は`SafRenameExecutor`のunsupportedで「0 件を改名しました。失敗: …」)が、**Androidの実renameはrevision 2以来「安全な未対応」であり、`T10`は失敗の見え方を変えただけで実体は変化しない**。Androidの受け入れは`T07`/`T08`が別途持つので、実機確認は`T07`のapp内browserが入ってからまとめて行う | 開発者承認 |
| 2026-08-21 | **005 contract revision 5.1** | **approved。** OP-005の`interface`行が実装のsignatureとずれていた(`(entries, source)`と書いていたが実装は`(entries, rule, now, listNames)`)ので、実装へ揃えた。**規範部分は変えていない** — `preconditions`が`rule`/`now`の必要性を含意し、`postconditions`は実装と一致していた。**署名を書いた1行の記述訂正である** | 開発者承認 |
| 2026-08-22 | **004 spec(Androidの読み込み導線)** | **approved(同日に独立reviewの指摘で2点を直し、再承認した)。** Androidのfile選択をSAFからapp内file browserへ(REQ-015)。**選択は同一folder内に限り**(REQ-016)、**Androidでは種類で絞らず「文書」を出さない**(REQ-011 / REQ-017)。`/Android/data/`配下は隠さず改名できない旨を示す(REQ-018)、権限が無い間はbrowserを開かない(REQ-019)。**承認時に確認した差分**: Androidから「文書」が消える、複数folderから集める選択ができなくなる、元場所ハンドルがSAF URIから絶対pathへ変わる。**独立review attempt 1のP1を受けて同日に2点を直し、再承認した** — (1) REQ-018の対象を`/Android/data/`から`/Android/`配下(`/Android/media`を除く)へ広げ、一次資料が「大半のsubdirectory」としか書かないため**判定ではなく注記**にした(可否は実行結果に委ねる)、(2) REQ-015へ遡行上限を足した。**辿れる上限は保存場所(共有ストレージのボリューム)のrootであり、それは全ファイルアクセス権限が与える範囲そのものである** | 開発者承認 |
| 2026-08-22 | **Playへの提出時期** | **提出物(store説明文と`Permissions Declaration Form`)は草案で仮置きし、一通り完成してから提出する。** `T03`が主目的の説明の草案と提出チェックリストを用意済み。**この判断により、`T03`と以後の実装taskはPlayの提出を待たずに進められる。** 却下されたらAndroid未対応へ戻す退避経路(ADR-002)は維持する | 開発者決定 |
| 2026-08-14 | preflightの残骸方針(破棄) | ~~毎回一意な名前 + 決して中止しない~~ **同日の方針転換でpreflightごと削除。** 「認識できない実体があったら中止する」をやめる。review attempt 1・3・4で同じ不具合が3回、場所を変えて現れ、窓を1つ塞ぐたびに別の場所へ移ったため、**窓ではなく中止する設計の方を外した**。代償として残骸が増えうることを受容する(INV-004) | 開発者方針決定 |

`T02`が問うた論点は**4件**で、正本は[`T02`](tasks/T02-define-permission-and-api-level/task.md)の「決めること」である。ここへ複製せず、そこを見る。**4件はいずれも`spec.md`で決着した。**

**`spec.md`は2026-08-14に`approved`。** preflightを削除し、権限のREQ-001〜004だけを残した。**この表は「承認した論点」の記録であり、状態の正本は[`spec.md`](spec.md)の`Status`と各`task.json`である。**

**`T04`の未決定は無い**(revision 4は2026-08-14に承認済み)。契約の`open_questions` **OQ-001〜OQ-008は8件とも`T10`がrevision 5として契約へ戻し、2026-08-21に開発者が承認した**。**OQ-001・OQ-005・OQ-007・OQ-008は`T11`が決着させたもの**で、実装が契約より広い状態が解消される。**OQ-002・OQ-003・OQ-004・OQ-006は`T10`が決めた**(OQ-006は開発者決定)。~~残る未決定は`T03`(004の読み込み導線)だけである~~ **`T03`は2026-08-22に004 specへ定義し、開発者が再承認した。契約・仕様の未決定は無い。**

**`T10`と`T03`の順序は`T10`が先である**(2026-08-20)。両者とも004 specへ触れるが、`T10`はポートへ`listNames`と所属folderハンドルを足すだけで、種類の選択・選択UI・導線には触れない。`T03`が導線を作り直すときも同じ契約を満たせばよい。逆順にすると、`T11`の実装が`dev`に入っているのにREQ-026/REQ-027が効いていない状態が長く残る。

## タスク

タスクのID・依存・状態は`plan.json`と各`tasks/*/task.json`が正本。番号は安定した識別子であり、実行順ではない。

| ID | 詳細 |
|---|---|
| T01 | [task.md](tasks/T01-decide-storage-boundary/task.md) |
| T02 | [task.md](tasks/T02-define-permission-and-api-level/task.md) |
| T03 | [task.md](tasks/T03-define-android-file-browsing/task.md) |
| T04 | [task.md](tasks/T04-update-rename-contract-for-android/task.md) |
| T05 | [task.md](tasks/T05-native-renameat2-port/task.md) |
| T06 | [task.md](tasks/T06-implement-permission-flow/task.md) |
| T07 | [task.md](tasks/T07-implement-android-file-browser/task.md) |
| T08 | [task.md](tasks/T08-verify-device-coverage/task.md) |
| T10 | [task.md](tasks/T10-add-existing-names-to-collision-check/task.md) |
| T11 | [task.md](tasks/T11-implement-renumbering-execution/task.md) |

`T09`(preflightの実行制御)は**2026-08-14に削除した**。preflightそのものが不要になったため。IDは再利用しない。
