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

- [ ] 種類(すべて・写真・動画)とアルバムで絞った一覧を、MediaStore の日時(`DATE_TAKEN`、無ければ `DATE_ADDED`)の新しい順に、少しずつ取れる。ゴミ箱・保存途中は含まない。
  - 証拠: Dart 側の test(channel を差し替える)、channel 名の突き合わせ test、`T07` の端末確認。
- [ ] アルバムの一覧(名前・件数・場所・代表の item)を取れる。
- [ ] 照会に失敗しても例外で止まらず、失敗として返す(画面が理由を示せる)。
- [ ] 独立review が PASS。

## machine検証範囲と引き受け先

- machine: Dart 側の写像・失敗の扱い・channel 名。
- 端末(引き受け先 `T07` の manual): Kotlin の照会そのもの、SD カード、件数が多いときの速さ。

## 作業記録

- 2026-10-05 `T05` が spec(004 REQ-011・012・016・021〜024)の承認を受けて足した。

## Current state / handoff

- Last checkpoint: 未着手
- Blocker category: なし
- Evidence revision: なし
- Next Agent action: 着手時に `in_progress` へ変え、branch を作る
