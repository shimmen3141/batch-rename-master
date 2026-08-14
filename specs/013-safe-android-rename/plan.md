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

### 対象外

- 005 INV-002のplatform例外やprovider依存raceの受容。**契約は緩めない。**
- SAF URIを未検証のraw pathへ変換するworkaround。
- desktopの読み込み導線の変更(OS pickerのまま)。
- Play Consoleへの配布申請そのもの。→ 人間が行う
- 隠し・system fileのfilter。→ 012
- 写真・動画のgallery選択。→ 010

## 方針

- **契約を緩めない。** INV-002(既存fileを置換しない)、INV-003 / REQ-018(要求名と結果名の一致)、OP-004(失敗時不変)にplatform例外を作らない。Androidで満たせない状況が出たら、契約ではなく**対象媒体やAPI levelを絞る。**
- **Playのpolicy確認をT05〜T07の前段のgateにする。** 「一括改名appがpermitted usesに入るか」は`[未到達]`のままである。実装へ投資する前に人間が原文と突き合わせる(`T02`の受け入れ証拠)。
- **退避経路を残す。** Playの宣言が却下される可能性がある。`lib/data/rename_exec/saf_rename_executor.dart`(安全な未対応)とそのnegative testは実装中も削除しない。
- **仕様を変えるものは、仕様更新taskと実装taskを分ける。** 004はapproved、005はStrict approvedなので、外部から観測できる振る舞いを変えるには人間の再承認が要る。
- **一次資料とspikeを区別する。** `T01`が確立した`[一次]` / `[要spike]` / `[未到達]`の区別を以後も使う。
- **`covers`は仕様task(T02/T03/T04)が埋める。** 現在は全taskで空である。REQ IDが確定するのはそれぞれの承認時なので、各taskの受け入れ証拠に「対応する実装task(T05〜T08)の`covers`を書く」ことを入れてある。**特にT04は005 Strict contractを触るので、被覆の記録を落とさない。**
- **spikeの未検証を実装後に埋める。** `T01`のS-2は1機種・1 API level・`shell` uidの観測である。`T08`で実装したappから確かめるまで「安全」と言わない。

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
- [ ] 実装したappのmount viewで`RENAME_NOREPLACE`が有効であることを確認した
  - 証拠: `T08`。**`shell` uidの観測では代用しない**
- [ ] 005の安全なunsupportedとnegative testを弱めない(退避経路の維持)

## 人間の決定

| 日付 | 論点 | 決定 | 決定者 |
|---|---|---|---|
| 2026-08-09 | 現SAF APIがStrict no-replaceを保証できない | Android成功経路を005から分離し、最初の成果を調査と設計判断に限定する | 開発者 |
| 2026-08-13 | storage境界の採否 | **候補E(`MANAGE_EXTERNAL_STORAGE` + `renameat2(RENAME_NOREPLACE)`)を採用する。** Androidが主対象である以上、主要プラットフォームで改名できない状態は製品として成立しない。Play審査riskと、Androidのfile選択をapp内browserへ作り直す範囲を受け入れる | 開発者承認 |
| 2026-08-13 | `minSdk` | **24のまま、対応可否を実行時に判定する。** API levelは対応可否の代理指標として弱く、実際に効くかを決めるのはkernelとfilesystemであるため | 開発者承認 |
| 2026-08-13 | Play policyのinvalid uses | **該当しうることを認めたうえでriskを受容し、T05以降へ投資する。** `T03`のfolder管理導線、store説明文での主目的の訴求、Declaration Formでの説明で寄せる。却下されたらAndroid未対応へ戻す | 開発者承認 |
| 2026-08-14 | `spec.md`の再承認 | **approved。** preflightの後片付け(REQ-010/011)、複数folder batchの停止単位(REQ-012)、結果の失効条件(REQ-013)、痕跡を残さないこと(INV-004)を追加した仕様を承認 | 開発者承認 |

未決定として残っているものは**4件**あり、正本は[`T02`](tasks/T02-define-permission-and-api-level/task.md)の「決めること」である。ここへ複製せず、件数と論点だけ示す。

1〜4はいずれも`T02`の`spec.md`で決着し、**2026-08-14に再承認された。`T02`の未決定は残っていない。**

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
