# R-001 MediaStore の `DATE_TAKEN` は何から作られるか

- 調べた日: 2026-10-04(`010` の要求整理。開発者の問い「DATE_TAKEN も一般的に撮影日時として扱われるなら」)
- 一次資料: Android の MediaProvider の `ModernMediaScanner.java`
  (<https://android.googlesource.com/platform/packages/providers/MediaProvider/+/f9fbb3964c8256162af48d62e82a6267291b1726/src/com/android/providers/media/scan/ModernMediaScanner.java>)。
  **ある1つの revision の source** であり、端末の版・メーカーごとの差は確かめていない。

## 読み取れたこと

- 画像: `DATE_TAKEN` は `parseOptionalDateTaken(exif, lastModified)` の結果だけで入る。値の元は **EXIF の `DateTimeOriginal`** である。
  - EXIF に `OffsetTimeOriginal`(時差)があれば、そのまま使う。
  - 無ければ、GPS の時刻、次にファイルの更新時刻との差から**時差を15分単位で推定**して足す。差が24時間以上なら推定をあきらめ、**値を入れない**。
  - **ファイルの更新時刻は時差の推定にだけ使い、日時の代わりには入れない。** EXIF に撮影日時が無ければ `DATE_TAKEN` は空である。
- 動画: `DATE_TAKEN` は `MediaMetadataRetriever` の `METADATA_KEY_DATE`(動画の中に記録された日時)から入る。
- したがって、**scanner が入れる `DATE_TAKEN` は、ファイルの中身に書かれた撮影日時に由来する**。名前に入れても「撮影した日時」と言える。

## 確かめていないこと(残る不確かさ)

- **MediaStore へ自分で登録する app**(カメラ・スクリーンショットなど)が `DATE_TAKEN` を直接書く場合、その値の元は app しだいである。
- 上と同じ理由で、端末の版・メーカーの MediaProvider が別の補い方をしていないかは確かめていない。
- `DATE_TAKEN` は UTC のミリ秒である。EXIF の `DateTimeOriginal` は時差を持たない「その土地の時刻」なので、
  **同じ写真でも、自分で EXIF を読んだ値と `DATE_TAKEN` を端末の時刻帯で表した値は、撮影地と端末の時刻帯が違えばずれうる**。
- EXIF に撮影日時があっても、時差を推定できなければ `DATE_TAKEN` は空になる(上記)。**自分で中身を読む経路のほうが取りこぼしが少ない**。

## この調査から決めたこと

- 開発者は、`DATE_TAKEN` も撮影日時として使う(要求整理の案B)と決めた(2026-10-04)。順位と時刻帯の扱いは `010:T01` が仕様にする。
