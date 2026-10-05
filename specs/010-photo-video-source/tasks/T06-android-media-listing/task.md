# T06 Android で MediaStore から写真・動画とアルバムの一覧を取る

## 目的

MediaStore から、このアプリに見える写真・動画の一覧(path・MediaStore の日時・種類・再生時間・アルバム)とアルバムの一覧を、少しずつ取れるようにする。
画面は作らない(`T07`)。Kotlin の channel と Dart の port を足す(`010:T03` の `media_dates` と同じ形)。

## 入力と依存

- [/workspace/specs/004-file-source/spec.md](/workspace/specs/004-file-source/spec.md) REQ-022(何が並ぶか・並び順と日付・絞り込み)。
- `010:T03`: Kotlin の channel と `MediaDatesPort` の形、**adb で置いたファイルはアプリから見えない**。
- `010:T04`: 改名しても MediaStore の行は新しい名前を追う。

## 変更範囲

- `android/app/src/main/kotlin/.../MainActivity.kt`(一覧・アルバム・サムネイルの照会)、`lib/data/file_source/`(port と channel の実装)、`test/`。

## 受け入れ条件

- [x] 種類(すべて・写真・動画)とアルバムで絞った一覧を、MediaStore の日時(`DATE_TAKEN`、無ければ `DATE_ADDED`)の新しい順に、少しずつ取れる。ゴミ箱・保存途中は含まない。
  - 証拠: Dart 側の test(channel を差し替える)、channel 名の突き合わせ test、`T07` の端末確認。
- [x] アルバムの一覧(名前・件数・場所・代表の item)を取れる。
- [x] 照会に失敗しても例外で止まらず、失敗として返す(画面が理由を示せる)。
- [ ] 独立review が PASS。

## machine検証範囲と引き受け先

- machine: Dart 側の写像・失敗の扱い・channel 名。
- 端末(引き受け先 `T07` の manual): Kotlin の照会そのもの、SD カード、件数が多いときの速さ。

## 作業記録

- 2026-10-05 `T05` が spec(004 REQ-011・012・016・021〜024)の承認を受けて足した。
- 2026-10-05 着手(branch `asdd/010-photo-video-source/T06-android-media-listing`、base `27d7a03`)。実装 `d467d28`。

### 作ったもの

- Dart: [/workspace/lib/data/file_source/media_library.dart](/workspace/lib/data/file_source/media_library.dart) — `MediaLibraryPort`(`page` / `albums` / `thumbnail`)と `MethodChannelMediaLibrary`(channel `com.example.batch_rename_master/media_library`)。
  - 一覧・アルバムの失敗は `MediaPageFailed` / `MediaAlbumsFailed` で返し、空の一覧と区別する(画面が「無い」と「取れない」を分けて示せる)。
  - 日時は UTC(`DATE_TAKEN` ミリ秒・`DATE_ADDED` 秒)で受け、端末の時刻帯へ直す。並びと見出しの日付は `MediaItem.date`(`DATE_TAKEN`、無ければ `DATE_ADDED`)。
  - 形の崩れた行は落とす。続きの有無(`hasMore`)は届いた行数で決める(落とした行で続きを取りに行かなくならないように)。
  - サムネイルは作れなければ `null`(選ぶことはできる)。
- Kotlin: [/workspace/android/app/src/main/kotlin/com/example/batch_rename_master/MainActivity.kt](/workspace/android/app/src/main/kotlin/com/example/batch_rename_master/MainActivity.kt)
  - `page`: `MediaStore.Files`(`VOLUME_EXTERNAL` = すべての保存場所)を `MEDIA_TYPE` とバケットで絞り、`COALESCE(datetaken, date_added * 1000) DESC, _id DESC` で、query args の `LIMIT` / `OFFSET` で少しずつ返す。ゴミ箱・保存途中は `MATCH_EXCLUDE` で明示して除く。
  - `albums`: 新しい順に全件を歩いてバケットごとに集める(名前・件数・folder・代表 = いちばん新しい item)。`GROUP BY` には頼らない。
  - `thumbnail`: `ContentResolver.loadThumbnail`(写真・動画とも)を JPEG で返す。
  - API 30 未満は channel の入口で `unsupported` を返す(全ファイルアクセス権限が API 30 から。通常は到達しない)。照会の関数は `@TargetApi(R)`。
- 実装の自由(004「自由とする点」の一覧の読み方)として決めたこと: 少しずつ読むのは offset 方式、サムネイルは MediaStore のもの、アルバムの並びは代表の新しい順。

### 検証(実装 `d467d28`)

- `flutter test test/spec_004_file_source/media_library_channel_test.dart test/tooling/platform_channel_names_test.dart`: PASS(+17)。channel 名と、種類の文字列(`all`/`photos`/`videos`、`photo`/`video`)が Kotlin と一致することも見る。
- `flutter test`: PASS(+1299)。`flutter analyze`: No issues。`dart format --set-exit-if-changed .`: PASS。`tool/check_normative_terms.py`: PASS。`workspace.py check specs`: PASS。
- mutation(M717〜M727 を `tool/mutations.json` へ足した。範囲を `flutter test test/spec_004_file_source/media_library_channel_test.dart` に絞り、11件を回した):

```text
command: flutter test test/spec_004_file_source/media_library_channel_test.dart
M717 | KILLED | 010:T06 続きの有無を落とした後の行数で決める
M718 | KILLED | 010:T06 一覧の失敗を空の一覧にする
M719 | KILLED | 010:T06 応答なしを空の一覧にする
M720 | KILLED | 010:T06 種類の絞り込みを渡さない
M721 | KILLED | 010:T06 アルバムの絞り込みを渡さない
M722 | KILLED | 010:T06 DATE_ADDED の秒をミリ秒として読む
M723 | KILLED | 010:T06 写真にも再生時間を付ける
M724 | KILLED | 010:T06 並びの日付で DATE_ADDED を優先する
M725 | KILLED | 010:T06 アルバムの失敗を空の一覧にする
M726 | KILLED | 010:T06 名前が無いアルバムに folder の path 全体を見せる
M727 | KILLED | 010:T06 サムネイルの失敗を投げる
11 mutations: 11 KILLED, 0 SURVIVED, 0 SKIPPED
```

- **未実施**: Kotlin の build(AI container に Android SDK が無い)。

### 端末でまだ確かめていないこと(引き受け先 `T07` の manual)

- Kotlin が build できること。
- MediaProvider が並び順の式 `COALESCE(...)` と query args の `LIMIT` / `OFFSET` を受け付けること(受け付けなければ `page` が失敗として返り、画面に理由が出る)。
- 写真・動画が `DATE_TAKEN`(無ければ `DATE_ADDED`)の新しい順に並び、種類とアルバムで絞れること。SD カードのものも並ぶこと。
- `loadThumbnail` のサムネイル、件数が多いときのアルバムの集計の速さ。

## Current state / handoff

- Last checkpoint: implementation(`d467d28`)。related・full regression・analyze・format・mutation が PASS
- Blocker category: なし
- Evidence revision: `d467d28`
- Next Agent action: 独立review(base `27d7a03`..head)を起動し、PASS なら PR を作る
