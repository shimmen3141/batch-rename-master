# T12 保存場所の列挙を、app から見える手段へ作り直す

## 目的

**装着されている SD カード・USB を保存場所として並べる**(004 REQ-015 / 代表例26e)。
`T07` が採った「`/storage` を列挙する」手段は、**app からは `EACCES` で使えない**ことが
`T08` の実機観測で判明した。

## 何が起きているか(`T08` の観測、2026-08-26)

`sdk_gphone16k_x86_64` / API 37 で、app 自身から見た `/storage` は次のとおりだった。

```
列挙できなかった: PathAccessException: Directory listing failed, path = '/storage/'
  (OS Error: Permission denied, errno = 13)
保存場所として採用: 1 件
  内部ストレージ = /storage/emulated/0
```

**全ファイルアクセス権限があっても列挙できない。** 一方、端末の `mount` には
`(null) on /mnt/media_rw/0000-0000 type vfat` があり、**媒体は実際に装着されている。**

`AndroidStorageBrowser.locations()` は**列挙に失敗しても内部ストレージだけは返す**ので、
利用者にも Agent にも**「媒体が無い」ようにしか見えなかった**。`T08` が
`storageViewOf` を足して初めて切り分いた。

## 何を直すか

- **列挙の手段を差し替える。** 候補は `StorageManager.getStorageVolumes()`(Android 7+)。
  **004 spec は列挙の手段を「自由とする点」に挙げている** — 自由なのは手段であって、
  結果ではない。**REQ-015 と代表例26e は変えない。**
- `getStorageVolumes()` は Java/Kotlin の API なので、**platform channel が要る。**
  `013:T06`(権限導線)が既に channel を持っているなら、そこへ相乗りできるかを先に見る。
- **列挙に失敗したことを、利用者から見て「媒体が無い」と区別できるようにする。**
  現在の「失敗しても内部ストレージだけ返す」は、**004 REQ-014 の
  「空の `NamesListed` と `NameListFailed` を混同しない」と同じ型の取り違え**である。
  提示の仕方は 004 spec の自由の範囲だが、**区別を持たないことは要求違反に近い。**
  `T08` が入れた `storageViewOf` と同じ区別を、製品側にも持たせるかを決める。

## 変更範囲

- `lib/data/file_source/android_storage_browser.dart` の `locations()`。
- Android 側(Kotlin)の platform channel。**`android/` に手を入れる。**
- `lib/data/file_source/storage_browser.dart` の port 定義(必要なら)。
- **`tool/normative_platform.json` の allow list を広げる必要があるか**を確認する
  (ADR-003 の OS 境界。`013:T07` で `lib/main.dart` を1件足した先例がある)。

**判定・権限・改名の経路は変えない。** 005 と 013 の REQ、004 の REQ-016〜019 はそのまま
である。

## `008:T11` / `008:T12` との分担

**008 の T11/T12 は同じ画面(browser)の「入口と近道の提示」を扱う。** こちらが扱うのは
**保存場所が何であるか**(データの供給)で、**提示ではない。**

- `008:T11` は「保存場所が1つしかないとき一覧を挟まない」を論点にしている。
  **このtaskで保存場所が2つになる端末が出てくる**ので、**T11 の判断材料が変わる。**
  先に着手した側が結果を相手へ知らせること。
- 同じ file(`storage_browser_view.dart`)を両方が触る可能性がある。**依存edgeにはしない**
  (どちらが先でも成立する)が、**後に着手した側が先の結果に合わせる。**

## 受け入れ証拠

- 列挙を port にして、**fake で「2つの volume が並ぶ」「列挙に失敗した」を widget/unit test で
  閉じる**。`013:T07` が `StorageBrowserPort` で採った形に合わせる。
- **Kotlin 側は実機でしか確かめられない。** [`manual-verification.md`](manual-verification.md)で、
  **SD カードを挿した端末に保存場所が2つ並ぶ**ことを確認する。
  **`T08` の probe(`storageViewOf`)がそのまま使える** — 出力に `0000-0000` が出るかで判定できる。
- 004 の既存 test が継続 PASS する(REQ-015 の遡行上限、REQ-016/017/018 を弱めていない)。
- `flutter test` / `flutter analyze` / `dart format --output=none --set-exit-if-changed .` が PASS。
- `python3 tool/check_platform_boundary.py` が PASS。
- exact range の独立review が PASS する。

## machine検証する範囲と引き受け先(2026-08-26 着手時に確定)

| 対象 | この環境での検証 | 引き受け先 |
| --- | --- | --- |
| Dart 側の列挙(port の結果を保存場所へ写す、欠落の区別、拠り所へ落ちる条件) | **testで閉じる**(`android_storage_browser_test.dart`) | — |
| channel から返った値の**読み方**(型・欠損・失敗) | **testで閉じる**(`storage_volumes_channel_test.dart`。`TestDefaultBinaryMessenger` で相手を差し替える) | — |
| **欠落を画面に出すこと** | **widget testで閉じる**(`storage_browser_view_test.dart`) | — |
| `locations()` が**投げないこと** | **testで閉じる**(約束を破って投げる port を注入する) | — |
| 上記を**手抜きできないこと** | **mutationで固定する**(範囲と件数は下の「検証結果」表が持つ) | — |
| **Kotlin 側の channel と `getStorageVolumes()` の実挙動** | **できない**(SDKが無い。`MainActivity.kt` は CI で1行も実行されない) | **人間**([`manual-verification.md`](manual-verification.md) 手順3) |
| **SD カード・USB が実際に並ぶこと** | **できない** | **人間**(手順2・手順3) |
| **`volume.getDescription()` が返す名前** | **できない**(端末が決める) | **人間**(手順2) |
| Android build(`armeabi-v7a` を含む) | **できない** | **人間**(手順4。`013:T08` から引き継いだ `__arm__` の照合もここで閉じる) |

## 実装(2026-08-26)

### 列挙の手段

`StorageManager.getStorageVolumes()` を platform channel
(`com.example.batch_rename_master/storage_volumes`)越しに読む。**`013:T06` の
権限 channel と同じ形**で、`MainActivity` に handler を1つ足した。

- **開ける volume だけ返す。** 取り外し済み・未 mount は落とすが、**読み取り専用で
  mount されているものは並べる** — 装着されている以上 REQ-015 の保存場所で、開いて
  辿れる(独立review attempt 1 の P1-1)。書けないことは REQ-018 の注記と 005 REQ-013 の
  実行結果が示す。**列挙から落とすのは「判定で機能を止める」側**である。
- **API 30 未満は `error` を返す。** `StorageVolume.getDirectory()` が API 30 からで、
  `MANAGE_EXTERNAL_STORAGE` も API 30 からなので、**この経路は API 30 未満では到達しない**
  (013 REQ-001 で browser が開かない)。
- **失敗を空の一覧にしない。** `result.error` で理由を渡す。

### 欠落を隠さない

**これが今回の欠陥が長く隠れた原因である。** `013:T07` の実装は列挙に失敗しても内部
ストレージだけを返し、**利用者からも Agent からも「媒体が無い端末」と区別できなかった。**

- `StorageVolumesResult` を `VolumesListed` / `VolumesUnavailable` の sealed 型にした
  (**004 REQ-014 が `listNames` に課しているのと同じ規律**)。
- `StorageBrowserPort.locations()` の戻り値を `StorageLocations`(見つかった一覧 +
  欠落の理由)へ変えた。**保存場所は内部共有ストレージだけでも成立する**ので、
  取得の失敗は全滅ではなく**欠落**である。
- **画面に注記を出す**(`browser-locations-failure`)。004 spec は提示の仕方を自由と
  しているので要求は増えていないが、**区別を持たないことが実際に問題を隠した**以上、
  持たせる方を採った。
- **`locations()` は投げない。** 投げると browser が読み込み中のまま止まる
  (`013:T08` で「例外が保護の外にある」型を2回踏んだ)。

### `013:T08` の probe も新しい手段へ合わせた

`storageViewOf` が **platform が返した生の volume と、保存場所として採用した結果の
両方**を出す。**次の実機確認で、`0000-0000` が出るかどうかが直接分かる。**

## 検証結果

| 種別 | commandと結果 |
| --- | --- |
| related test | `flutter test test/spec_004_file_source/` = **PASS(147件)**、`test/spec_013_android_rename/storage_probe_test.dart` = **PASS(52件)**、`test/tooling/platform_channel_names_test.dart` = **PASS(3件)** |
| full regression | `flutter test` = **PASS(660件)**。T12着手前は641件 |
| static analysis | `flutter analyze` = **PASS** |
| format | `dart format --output=none --set-exit-if-changed .` = **PASS** |
| ASDD構造 | `workspace.py check specs` = **PASS(8 plans, 67 tasks)** |
| OS境界 | `python3 tool/check_platform_boundary.py` = **PASS**(47 file、4 rule) |
| 規範の書き写し | `python3 tool/check_normative_terms.py` = **PASS** |
| mutation | `M114`・`M143`・`M144`〜`M162` = **21 KILLED / 0 SURVIVED / 0 SKIPPED**。うち`M152`〜`M158`と`M160`〜`M162`は**独立reviewerが足したもの**(`M154`〜`M157`は対照)。表全体は `--list` = **162 mutations, 0 with an unexpected match count** |
| **Kotlin 側** | **実機で確認済み(2026-08-26)。** CI では1行も実行されないが、手順2・3で `getStorageVolumes()` が2件返すことを観測した |
| **実機確認** | **実施済み(2026-08-26)。** 手順1〜4がすべて期待どおり。詳細は下の節 |

**`M114` と `M143` は消さずに言い直した。** 列挙の手段が変わって元の find が消えたので、
**同じ意図を新しい構造の上で押さえ直した**(`M114` = 保存場所の root を volume の上位に
する、`M143` = 取得できなかったことを「0 件」と報告する)。

## 仕様被覆

**004 spec の REQ-015 と代表例26e を満たすための実装であり、要求は変えない。**
`task.json.covers` は空のままにする(`013:T07` と同じ理由 — このworkspaceの構造検査は
`covers` を所有 plan の spec.md の ID として引くため)。

## 作業記録

- 2026-08-26 / `T08` の実機観測(2回目)で `/storage` が `EACCES` であることが判明し、
  開発者が「013 に新task を立てて直す」と決定して定義。**ID は `T12`** —
  `T09` は2026-08-14に削除済みで**再利用しない**、`T10`/`T11` は使用中である。

## 独立review attempt 1(2026-08-26)= FAIL

range は `cc5f031...6fb1c6d`。**方針は正しいと確認された** — 004 `spec.md` に差分が無く、
`StorageManager.getStorageVolumes` は「自由とする点」に**名指しで**載っている。reviewer は
AOSP の一次資料(`StorageVolume.java` / `StorageManager.java`)に当たり、`getDirectory()` の
nullable、`getStorageVolumes()` に権限要件が無いこと、`getDescription()` の扱いも確かめている。

**しかし、このtaskが消しに来た型が Kotlin に1行残っていた。**

| # | 指摘 | 分類 | 始末 |
| --- | --- | --- | --- |
| **P1-1** | **`MEDIA_MOUNTED_READ_ONLY` の媒体が、注記も無しに消える。** 書き込み保護のSDカードなどが該当し、**落とされた volume は `failure` も付かない**ので画面は「理由なしで内部ストレージだけ」になる — **`013:T08` で見たのと同じ絵**である。004 REQ-018 の「隠さず注記する。判定で機能を止めない」とも逆向き | 成果物の欠陥 | **並べる側へ直した。** 装着されている以上 REQ-015 の保存場所であり、開いて辿れる。書けないことは注記(REQ-018)と実行結果(005 REQ-013)が示す。**要求を弱める側ではない**ので、reviewer の推奨どおりこの選択を採った |
| P2-1 | `013:T08` の手順書の期待出力が現revisionと一致しなくなった(`--- app から見た /storage ---`) | 成果物の欠陥 | 直した。あわせて**SDカードの確認は`T12`の手順書の方が新しい**ことも書いた |
| P2-2 | testのヘッダが存在しない注入口(`volumesDirectory`)を説明していた | 成果物の欠陥 | 直した |
| P2-3 | **`_primaryOnly()` の守りが test を1度も通らない**(`RV01` SURVIVED)。宣言表は「`locations()` が投げないこと = testで閉じる」と宣言している | 安全網の穴 | **塞いだ。** `chmod 000` の親 directory で test を置いた(`M152`) |
| P2-4 | 空の volume 名を弾く分岐が未検査(`RV02` SURVIVED) | 安全網の穴 | 塞いだ(`M153`) |
| P2-5 | **channel 名の Kotlin↔Dart 一致を CI が1度も見ていない**(`RV07` SURVIVED)。ずれると機能が丸ごと死ぬが、Dart の test は mock 相手なので**自分自身と常に一致する** | 安全網の穴 | **受容せず塞いだ。** `test/tooling/platform_channel_names_test.dart` が **Kotlin の source を読んで**突き合わせる。**権限 channel(`013:T06`)も一緒に守られる**(`M158`) |
| P3-1 | 画面側 `_loadLocations` が port の例外を受けない | 安全網の穴 | **受容せず塞いだ**(3行。`M159`) |

**`RV01`〜`RV07` を `M152`〜`M158` として取り込んだ**(`M154`〜`M157` は対照)。
**P2-5 と P3-1 は reviewer が「受容してよい」としたが、どちらも数行で閉じられるので塞いだ。**

## 独立review attempt 2(2026-08-26)= PASS

range は `cc5f031...1482655`。**未解決のP0/P1は無く、成果物の欠陥も無い。**

**reviewerが自分で経路を追って副作用を否定した。** 読み取り専用の媒体で改名まで進むと、
C 側が **`EROFS` を `permissionDenied` へ写す**(`src/native_exclusive_rename.c`)ので
**`fallbackRequired`(危険な通常renameへの劣化)には落ちない** — データ損失・偽の成功の
経路は無く、005 REQ-013 が理由を出して終わる。実機 probe も RO volume で落ちない
(`defect` が `permissionDenied` の行で対照を免除する)。

**他の mount state に同じ型が残っていないことも確認された** — 残りはすべて mount されて
おらず、`getDirectory()` が `null` を返すので次の行でも落ちる。**述語は「開ける volume」と
一致した。**

**channel名testの逆向きも検証された。** 私が入れた `M158` は Dart 側の literal を動かす
向きだけで、**Kotlin 側が動いた場合は未検証**だった。reviewer が `MainActivity.kt` を直接
壊す mutation を2件足し、どちらも KILLED になった(`M160`/`M161` として取り込み)。
`013:T06` の権限 channel も本当に一緒に守られている。

**この検査で何を検出できないかも確かめられた** — literal が Kotlin のコメントとしてだけ
残る場合、method 名(`"list"`)の一致、handler の登録そのもの。**test 自身の header に
書いてあるので過大な安心は与えていない**と判定された。

`RW01`〜`RW03` を `M160`〜`M162` として取り込んだ。**`RW04`(P1-1 の直しを取り消す)は
取り込んでいない** — **期待値が SURVIVED の観測用**(CIがKotlinを1行も実行しないことの
確認)で、表の「0 with an unexpected match count」と混ざるためである。

## 実機確認(2026-08-26)= 期待どおり

| 項目 | 値 |
| --- | --- |
| 環境 | Android emulator `sdk_gphone16k_x86_64`、API 37、`CP31.260623.005 dev-keys` |
| 対象commit | `225f5db`(`1482655` 以降 `lib/` `src/` `android/` `hook/` `test/` `integration_test/` `pubspec.yaml` に差分なし) |
| 実行者 | 開発者(人間) |

### 手順2(画面)

- **`SDCARD` が内部ストレージと並んで表示された。** 004 REQ-015 / 代表例26e が
  **実機で成立した** — `013:T07` の実装では1件も出せなかったものである。
- **「保存場所を取得できませんでした」の注記は出ていない**(欠落が無い)。
- **SD カードの中を辿れ、その root では上矢印が出なかった**(REQ-015 の遡行上限が
  SD カード側でも成立している。代表例26e の後半)。

### 手順3(probe)

```
--- app が列挙した保存場所 ---
platform が返した volume: 2 件
  内部共有ストレージ = /storage/emulated/0
  SDCARD = /storage/0000-0000
保存場所として採用: 2 件
```

**観測対象が4件から6件に増え、6件すべてで `nameConflict`**(目標名・source とも無傷、
対照は全箇所で置換)。増えた2件は `/storage/0000-0000` とその `Download` である。

**`volume.getDescription()` が返した名前は `内部共有ストレージ` と `SDCARD` だった。**
`013:T07` が固定文字列で出していた「内部ストレージ」とは違う — **端末が決める名前を
そのまま使う**という設計どおりである。

### 手順4(armeabi-v7a のビルド)

```
flutter build apk --debug --target-platform android-arm
✓ Built build\app\outputs\flutter-apk\app-debug.apk
```

**`013:T05` から `T08` を経由して引き継いだ `__arm__` の syscall 番号(382)の照合が
閉じた。** `src/native_exclusive_rename.c` の `_Static_assert(BRM_SYS_RENAMEAT2 == __NR_renameat2)`
は 32bit ARM 向けの compile で評価されるので、**build が通った = 実 kernel header と
一致した**ということである。

## この確認が `013:T08` の残余riskを2件閉じた

**`T08` は3件を引き受け先つきで受容していた。** そのうち2件がここで閉じた。

| `T08` が受容した残余risk | 結果 |
| --- | --- |
| **項目7: FAT 系の媒体で `RENAME_NOREPLACE` が効くか** | **効いた。** `/storage/0000-0000` は `mount` によれば下位が `vfat`(`(null) on /mnt/media_rw/0000-0000 type vfat`)で、そこでも `nameConflict` になり目標名は無傷だった。**媒体を「対応外」にする必要は無い** |
| **`__arm__` の syscall 番号(382)の照合** | **閉じた**(手順4) |
| 項目5(API level の幅)・項目6(実機) | **変わらず未観測。** 端末が増えるまで `T08` の手順4・5 が引き受ける |

### 項目4(FUSE 自身か下位への委譲か)も一段進んだ

**下位が ext4 の FUSE でも、下位が vfat の FUSE でも、非FUSE の ext4 でも効いた。**
したがって **`RENAME_NOREPLACE` の可否は下位 filesystem の種別に依存していない。**
「FUSE 自身が判定しているのか」を直接観測したわけではないが、**下位を変えても結果が
変わらない**という対照は取れた。

## Current state / handoff

- Last checkpoint: **実機確認が期待どおり**(2026-08-26、`sdk_gphone16k_x86_64` / API 37、対象commit `225f5db`)。**SDカードが保存場所として並び、そこで `RENAME_NOREPLACE` も効いた。** `013:T08` の残余risk 2件がここで閉じた
- Blocker category: なし
- Waiting for: `final-evidence` の独立review
- Requested action: なし
- Evidence revision: PR #156(Draft)、branch `asdd/013-safe-android-rename/T12-enumerate-storage-volumes`、base は `dev@cc5f031`(`git merge-base dev HEAD` の実測値)。`T08` の実機観測(2026-08-26、`sdk_gphone16k_x86_64` / API 37)が発端
- Next Agent action: **`final-evidence` の独立reviewを通して merge する。** merge後は `008:T11` へ「保存場所が2つ並ぶ端末が実在する」ことを申し送る(あちらの「保存場所が1つなら一覧を挟まない」の判断材料が変わった)
