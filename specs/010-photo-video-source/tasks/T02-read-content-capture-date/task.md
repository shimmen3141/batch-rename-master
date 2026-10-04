# T02 ファイルの中身から撮影日時を読む

## 目的

写真の EXIF と動画に記録された撮影日時を読み、読み込んだ `FileEntry` の作成日時に入れる(Android の app 内 browser と desktop の両方)。
読めないファイルは「不明」のまま。

## 入力と依存

- T01 で承認された 004(と 001・002)の差分。形式・時刻帯・順位はそこが正本。
- 既存の読み込み: `lib/data/file_source/android_file_source.dart`・`desktop_file_source.dart`(今は作成日時を常に `null` で返す)。

## 変更範囲

- 中身を読む部品(新設。package を足すか自前で読むかは実装で決め、task.md へ理由を書く)。
- 上の2つの読み込みの経路。
- 触れない: 001 の判定、改名の実行。

## 受け入れ条件

- [ ] T01 の代表例のうち中身の経路のものが、fixture のファイルを使う test で成り立つ。
  - 証拠: `flutter test` の該当 test、mutation(`tool/mutations.json`)。
- [ ] 読めない・壊れたファイルで読み込み全体が失敗しない(そのファイルが「不明」になるだけ)。
  - 証拠: 壊れた fixture の test。

## machine検証範囲と引き受け先

- machine(CI): test の中で組み立てた JPEG(II・MM、APP0 の前後)・HEIF(iloc v0/v1、infe v2/v3)・MP4/MOV(mvhd v0/v1、moov が mdat の前後)
  から読めること、壊れた・別形式・無い path が `null` になること、Android と desktop の読み込みが作成日時を入れること。
- 端末(`010:T03` の manual): エミュレータのカメラで撮った写真・動画で読めること。**組み立てた fixture は読む側と同じ思い込みで作りうる**ので、
  下の「実在のサンプルでの確認」と合わせて補う。

## 作業記録

- 実装: `lib/data/file_source/content_created_at.dart`(`readContentCreatedAt`)。package を足さず自前で読む — EXIF の
  `DateTimeOriginal` と `mvhd` の `creation_time` だけが要り、読む範囲が小さい。file 全体は読まず、box・segment の header を辿って
  必要な部分だけを読む(1つの読みの上限 1 MiB)。同期の I/O(`RandomAccessFile`)で、desktop の `entriesOfDirectory`(同期)からも呼べる。
- 結線: `AndroidFileSource._entryOf` と `DesktopFileSource._entryOf` の `createdAt`。
- 実装で決めた点:
  - **EXIF は `DateTimeOriginal`(0x9003)だけを読む**。IFD0 の `DateTime`(0x0132)は更新日時なので使わない(004 REQ-010 の①が
    「撮影/作成日時」であり、更新日時での代替は REQ-003 が禁じる)。`OffsetTimeOriginal` は読まない — 書かれた時刻がそのまま撮影地の時刻で、
    値は変わらない(代表例 45)。
  - `0000:00:00 00:00:00`・範囲外・実在しない日付は「無い」(`null`)。
  - `mvhd` の `creation_time` が 0 は「記録していない」(`null`)。UTC として端末の時刻帯へ直す。
  - HEIF の Exif item は、file の中にある1つの extent(construction_method 0)だけを扱う。それ以外は `null`(②③へ)。
- 実在のサンプルでの確認(scratchpad に置き、repository には入れていない。第三者の file のため):

| サンプル | 中身(独立に確かめた値) | `readContentCreatedAt` |
|---|---|---|
| `ianare/exif-samples` の `jpg/Canon_40D.jpg` | `DateTimeOriginal` 2008:05:30 15:56:01(`DateTime` は 2008:07:31 10:38:11) | 2008-05-30 15:56:01 |
| 同 `heic/IMG_5195.HEIC`(iPhone) | 2021:04:11 15:47:53 | 2021-04-11 15:47:53 |
| 同 `heic/mobile/HMD_Nokia_8.3_5G_hdr.heif`(Android) | Exif IFD に `DateTimeOriginal` が**無い**(IFD0 の `DateTime` 2022:01:12 07:30:14 だけ) | `null`(仕様どおり。端末では②③へ) |
| 同 `heic/samplefilehub.heif` | Exif なし | `null` |
| `web-platform-tests/wpt` の `media/movie_5.mp4` | `mvhd` v0 2010-06-01 16:08:42 UTC(Python で独立に読んだ値) | 同じ(UTC で比較) |
| `mediaelement/mediaelement-files` の `big_buck_bunny.mp4` | `mvhd` v0 2010-02-09 01:55:39 UTC | 同じ |

- 検証: `flutter test` 1275 PASS、`flutter analyze` No issues、`dart format` 0 changed、`TZ=Asia/Tokyo` と `TZ=Pacific/Honolulu` で関連 test PASS
  (container の既定は UTC なので、時刻帯へ直すことを別の時刻帯でも確かめた)。
- mutation(範囲付き `flutter test test/spec_004_file_source`、13件):

```text
M694〜M706 | 13 mutations: 13 KILLED, 0 SURVIVED, 0 SKIPPED
(APP1 を探さない / IFD0 の DateTime を読む / 2月30日を通す / mvhd 0 を通す / v1 を 32bit で読む / UTC のまま返す /
 Exif の前置きを飛ばさない / infe v3 を v2 で読む / iloc v1 の construction_method を飛ばさない / JPEG の segment の位置 /
 MM を II で読む / Android・desktop の結線を外す)
```

- 残余risk(安全網の穴ではなく範囲の外。受容): PNG(`eXIf`)・WebP・HEIC の idat 内の Exif・複数 extent の Exif は読まない(Android では②③へ)。
  一部のカメラは `mvhd` に UTC ではなくその土地の時刻を書く — 仕様は UTC として扱うと決めており、ずれる。引き受け先: なし(頻度を見て 004 の
  自由とする点の中で足せる)。

### 独立review

reviewer は Sonnet 5(Agent tool、`model: sonnet`。開発者の指定)。実装は Claude Opus 5.5。

- Review attempt 1: `048c79f..d0f4401`(全範囲) — **PASS** — P0/P1 なし
  - 確認できた点: JPEG の marker の辿り方、TIFF(II/MM、IFD、ASCII の inline と offset)、HEIF(meta の FullBox、iinf v0/v1、infe v2/v3、
    iloc v0/v1/v2 の各大きさと construction_method、box の順に依らないこと)、ISO BMFF(size 0・1、moov の前後、mvhd v0/v1、1904 起点)が
    ISO/IEC 14496-12・23008-12・EXIF の記述と一致、例外が外へ出ないこと、時刻(EXIF は書かれたまま、mvhd は端末の時刻帯。`DateTime` の
    `==` が `isUtc` も比べるので UTC のまま返す実装を検出できる)、`TZ=Asia/Tokyo`・`Pacific/Honolulu` での再実行、M694〜M706 の再現(13 KILLED)、
    reviewer の対照(iloc v2、size==1、size==0 は読める)、**実在のサンプル6件を取り直して記録の表と全件一致**(null の2件は Python で
    構造を読み直して「①が無い」ためと確認)、`flutter test` 1275 PASS・analyze・format・workspace check。
  - P2(気づき): Android の `_entryOf` は async だが中身の読みは同期 I/O。複雑な HEIF でも1件 1.6ms 程度(host)で、数百件で累積数百 ms〜1秒
    UI を止めうる。**直さない**: REQ-010 は性能を要求せず、読み込みは今も1件ずつ順に `stat` している。目立てば isolate へ移す。
    引き受け先: なし(実機で遅さが観測されたら新しい task)。
  - P3: JPEG の marker の前の詰め物の 0xFF を読み飛ばさない(挟まると `null`)。**直さない**: 実在のカメラのサンプルでは起きず、起きても
    ①が無いだけで②③へ流れる(REQ-010 の「読めなければ不明」の範囲)。
  - P3: top-level に `moov` があれば `meta` を見ない。**直さない**: 両方を持つ file は実務上ほぼ無い。
  - 対照は一時 test で走らせたもので、表(`tool/mutations.json`)へ入れる mutation は無い(どれも find/replace の形ではなく fixture の追加)。

## Current state / handoff

- Last checkpoint: 独立review attempt 1 PASS(`048c79f..d0f4401`)。P2/P3 は直さない理由を記録した
- Status: done(端末での確認は `T03` の manual が引き受ける)
- Next Agent action: なし(PR を作って merge し、`T03` に着手する)
