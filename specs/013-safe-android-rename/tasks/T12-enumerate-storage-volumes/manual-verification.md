# 手動確認: SD カード・USB が保存場所に並ぶこと

**アプリの画面と、`T08` の probe の両方を見る。** 画面は利用者から見た結果、probe は
**プラットフォームが何を返したか**である。片方だけだと、`013:T08` の 2026-08-26 と同じ
袋小路(「無い」のか「見えていない」のか分からない)に入る。

## 使う端末

**Android 11 以上。** `T08` の観測に使った `sdk_gphone16k_x86_64` の emulator には
**仮想 SD カード(vfat)が装着されている**ことが分かっている(`mount` に
`(null) on /mnt/media_rw/0000-0000 type vfat` がある)。**この emulator で確認できる
見込みである。**

起動手順は
[`docs/development/emulator-verification.md`](../../../../docs/development/emulator-verification.md)。

## 手順1 — 権限とビルド

**`T08` の手順1をそのまま使う** —
[`T08` の manual-verification.md](../T08-verify-device-coverage/manual-verification.md)
の「手順1 — 権限を与える」。**ここへ書き写さない。**

そのうえで、リポジトリのルートで:

```powershell
flutter pub get
flutter devices
flutter run -d <device_id>
```

**期待**: アプリが起動する。**Kotlin 側を変更しているので、ホットリロードではなく
入れ直しが要る**(`flutter run` を1回止めてから実行する)。

## 手順2 — 画面で見る(この確認の中心)

1. 「ファイルを選ぶ」→「すべて」を選ぶ。
2. 出てきた保存場所の一覧を見る。

**こうなってほしい**

- **保存場所が2つ以上並ぶ。** 内部ストレージと、SD カード(名前は端末が付ける。
  `SD カード` `SDCARD` などのことがある)。
- **「保存場所を取得できませんでした」という注記が出ていない。** 出ていたら、その文言を
  そのまま書いてほしい。
- SD カード側を選んで**中を辿れる**。**その root で、上へ戻る矢印が出ない**
  (root より上へは辿れない。`T07` の手順1と同じ)。

**SD カードが並ばなかった場合も、そのまま書いてほしい。** 手順3でどちらなのかが分かる。

## 手順3 — プラットフォームが何を返したかを見る

**`T08` の probe をそのまま使う。** リポジトリのルートで:

```powershell
flutter test integration_test\android_storage_probe_test.dart -d <device_id>
```

**期待**: 出力の先頭が `--- app が列挙した保存場所 ---` で始まり、次のように並ぶ。

```
platform が返した volume: 2 件
  内部ストレージ = /storage/emulated/0
  SD カード = /storage/0000-0000
保存場所として採用: 2 件
  ...
```

**ここが要点である。**

- `platform が返した volume: 2 件` 以上なら、**列挙は直っている**。
- `platform から取得できなかった: ...` なら、**Kotlin 側が失敗している**。その理由を
  そのまま書いてほしい。
- `platform が返した volume: 1 件` なら、**プラットフォームが SD カードを返していない**
  (端末の構成の問題であって、実装の問題ではない可能性がある)。

**そのあとの `=== 013:T08 排他 rename の観測 ===` も、まるごと貼ってほしい。**
SD カードが保存場所に入れば、**`013:T08` が埋められなかった項目7(FAT 系の媒体で
`RENAME_NOREPLACE` が効くか)がここで埋まる。**

## 手順4 — armeabi-v7a のビルド(`T08` から引き継いだ確認)

`013:T05` が「NDK build 時に `_Static_assert` が armeabi-v7a で自動照合する」として
残した確認である。**通れば、32bit ARM の syscall 番号(382)が実 kernel header と
一致していることになる。**

```powershell
flutter build apk --debug --target-platform android-arm
```

**期待**: `✓ Built build\app\outputs\flutter-apk\app-debug.apk` で終わる。
**失敗したら、エラーの最後の20行くらいを貼ってほしい**(特に `static_assert` を含む行)。

## 報告

結果は会話で自由に書いてよい。**決まった書式や合否の記入は不要**である。

- 手順3の出力は**そのまま**貼ってほしい。要約しないでほしい。
- 手順2で保存場所の名前が何だったか(端末が付ける名前は端末によって違う)。
- 気づいたこと(SD カードの中が空だった、名前が読みにくい、など)があればそのまま。
