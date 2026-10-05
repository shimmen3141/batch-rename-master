# T03 Android で MediaStore の撮影日時と追加日時を補う

## 目的

Android で、中身から日時を取れなかったファイルについて、MediaStore の `DATE_TAKEN`(004 REQ-010 の②)、それも無ければ `DATE_ADDED`(③)を引いて
作成日時に入れる。どちらも UTC なので端末の時刻帯へ直す。
あわせて、T02 と合わせた全体を Android エミュレータで確かめる。

## 入力と依存

- T01 の差分(順位・時刻帯)、T02 の実装。
- [R-001](../../decisions/R-001-mediastore-date-taken-source.md)。
- [`T04`](../T04-verify-creation-time-stability/task.md) の結論(`DATE_ADDED` は改名で変わらない。この app が path で作った file は MediaStore に載らない)。
- 既存の platform channel(`MainActivity.kt`)と、channel 名を突き合わせる test(`test/tooling/platform_channel_names_test.dart`)。

## 変更範囲

- Kotlin 側で path から `DATE_TAKEN` と `DATE_ADDED` を引く処理と、Dart 側の呼び出し。
- 触れない: desktop の経路、改名の実行。

## 受け入れ条件

- [ ] 中身に撮影日時が無く `DATE_TAKEN` を持つファイルで、その値が入る。中身から取れたファイルは中身の値のまま(代表例 47・48)。
  - 証拠: Dart 側の test(channel を差し替える)、channel 名の突き合わせ test、Android エミュレータの manual。
- [ ] ①②が無く `DATE_ADDED` を持つファイル(ダウンロード・スクリーンショットなど)で、その値が入る(代表例 11・49・51)。この app で改名した後に読み込み直しても変わらない(代表例 50)。
  - 証拠: Dart 側の test(channel を差し替える)、Android エミュレータの manual。
- [ ] MediaStore に無いファイル・引けないときは「不明」のままで、読み込みは失敗しない。
  - 証拠: test、manual。
- [ ] エミュレータで、カメラで撮った写真・動画が撮影日時の順に並び、日時トークンで撮影日が名前に入る。ダウンロードしたファイル・スクリーンショットにも作成日時が入る。
  - 証拠: [manual-verification.md](manual-verification.md)。

## machine検証範囲と引き受け先

- machine(CI): channel の写像(`DATE_TAKEN` ミリ秒・`DATE_ADDED` 秒を端末の時刻帯へ、0 と想定外の値と失敗は「無い」)、Android の読み込みでの
  順位(①が②③より先、②が③より先、どれも無ければ不明)、①がある file を照会も上書きもしないこと、補っても他の項目を変えないこと、照会の失敗で
  読み込みを止めないこと、開き直し(REQ-021)でも補うこと、`fileSourceFor` が照会を渡すこと、channel 名が Kotlin 側にあること。
- 端末(この task の manual): **Kotlin の照会そのもの**(container では build できない)、実際の写真・動画・ダウンロード相当の file で値が入ること、
  改名して読み込み直しても変わらないこと(代表例 50)、`createPlatformFileSource` が Android で照会を渡す結線(composition root。test が通らない)。

## 作業記録

- Kotlin: `MainActivity.kt` に channel `com.example.batch_rename_master/media_dates`(`datesOf`)。`MediaStore.Files`(`VOLUME_EXTERNAL`)を
  `_data IN (…)` で 500 件ずつ照会し、`DATE_TAKEN`(ミリ秒)・`DATE_ADDED`(秒)を返す。main thread から外す(既存の pool)。API 29 未満は空。
  **container に Android SDK が無いので Kotlin は build していない** — manual の `flutter run` が最初の build になる。
- Dart: `lib/data/file_source/media_dates.dart`(port と channel 実装)、`AndroidFileSource._withMediaDates`(①の無い file だけをまとめて照会)、
  `fileSourceFor` / `createPlatformFileSource` の結線。
- 検証: `flutter test` 1286 PASS、`flutter analyze` No issues、`dart format` 0 changed。
- mutation(範囲付き `flutter test test/spec_004_file_source`): M104(find を追随)・M707〜M716。初回 M709(①があっても上書き)が SURVIVED
  → ①だけの file では照会が起きなかったため、①の無い file を混ぜた test にし、fake が尋ねられていない path も返すようにした。

```text
M104 | KILLED / M707 | KILLED / M708 | KILLED / M709 | KILLED(直した後)/ M710 | KILLED / M711 | KILLED
M712 | KILLED / M713 | KILLED / M714 | KILLED / M715 | KILLED / M716 | KILLED
```

- 残余risk(安全網の穴。受容): `createPlatformFileSource` が `MethodChannelMediaDates` を渡す行は test が通らない(Linux では Android の
  分岐に入らない)。外れると②③が黙って無くなる(不明が増えるだけで、データ損失・無断置換・偽の成功・権限・互換性のどれでもない)。
  引き受け先: この task の manual(手順1の `download.txt`)。

### 実機確認

- Manual attempt 1(2026-10-05、Android エミュレータ、build は `lib/`・`android/` = `0c7b80a`)— **FAIL(③が入らない)**
  - `flutter run` の build は通った(Kotlin の最初の build)。端末の `date`: `Mon Oct  5 01:38:11 GMT 2026`(時刻帯 GMT)。
  - 手順1: `canon_2008.jpg` = `2008/5/30 15:56`(OK)、`movie_2010.mp4` = `2010/6/1 16:08`(GMT の端末なので期待どおり。OK)、
    **`download.txt` = `不明`(NG。期待は置いた時刻)**。
  - 手順2: 写真 → 動画 → `download.txt` の順(`download.txt` が不明のため末尾)。
  - 手順3: 3つとも改名前と同じ値(OK。`download.txt` は不明のまま)。
  - 手順4: 未確認(開発者が後で行う)。手順5: 未報告。
  - ①(T02)は端末で値が入った。②③の経路(channel → Kotlin の照会 → Dart)のどこで値が落ちたかは未特定。

### 独立review

reviewer は Sonnet 5(Agent tool、`model: sonnet`。開発者の指定)。実装は Claude Opus 5.5。

- Review attempt 1: `95c2cb0..0c7b80a`(全範囲) — **PASS** — 指摘なし
  - 確認できた点: Kotlin の import・API level の守り(API 29 未満は早期 return)・`while` の中の `continue`・SQLite の変数上限に対する 500 件ずつの照会・
    main thread への応答と `destroyed` の守り・例外が `result.error` → Dart で空の結果になること、Dart の順位と単位の変換と失敗の扱い、
    `_withCreatedAt` が `FileEntry` の全項目を写すこと、path の形(`/storage/emulated/0` 起点)が MediaStore の `_data` と合うこと、
    manual の URL が届くこと・adb の構文・UI の文言(`ファイルを選ぶ`・`別フォルダへ`・`すべて`)の実在・表示形式と期待値の一致、
    M104・M707〜M716 の再現(11 KILLED)、`flutter test` 1286 PASS・analyze・format・workspace check。
  - 安全網の穴(`createPlatformFileSource` の結線)は task が記録したとおり3条件に当たらず、受容が妥当。

## Current state / handoff

- Last checkpoint: Manual attempt 1 FAIL(`download.txt` の作成日時が不明)。原因を切り分け中
- Blocker category: manual-evidence
- Waiting for: 開発者(Android エミュレータでの実機確認。Kotlin の最初の build を兼ねる)
- Requested action: [manual-verification.md](manual-verification.md) の手順1〜5を行い、結果を会話で伝える
- Evidence revision: `lib/`・`android/` が `0c7b80a` と同一の build
- Next Agent action: 結果を作業記録へ書き、問題が無ければ `done` にして PR を作り、merge する
