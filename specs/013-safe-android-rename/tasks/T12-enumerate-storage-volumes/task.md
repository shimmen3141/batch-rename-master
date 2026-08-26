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

## machine検証する範囲と引き受け先(着手時に更新する)

| 対象 | この環境での検証 | 引き受け先 |
| --- | --- | --- |
| Dart 側の列挙(port の結果を保存場所へ写す、失敗の区別) | **testで閉じる** | — |
| **Kotlin 側の channel と `getStorageVolumes()` の実挙動** | **できない**(SDKが無い) | 人間(manual) |
| **SD カード・USB が実際に並ぶこと** | **できない** | 人間(manual) |
| Android build | **できない** | 人間(manual) |

## 仕様被覆

**004 spec の REQ-015 と代表例26e を満たすための実装であり、要求は変えない。**
`task.json.covers` は空のままにする(`013:T07` と同じ理由 — このworkspaceの構造検査は
`covers` を所有 plan の spec.md の ID として引くため)。

## 作業記録

- 2026-08-26 / `T08` の実機観測(2回目)で `/storage` が `EACCES` であることが判明し、
  開発者が「013 に新task を立てて直す」と決定して定義。**ID は `T12`** —
  `T09` は2026-08-14に削除済みで**再利用しない**、`T10`/`T11` は使用中である。

## Current state / handoff

- Last checkpoint: 定義しただけ。未着手
- Blocker category: なし
- Waiting for: なし
- Requested action: なし
- Evidence revision: `dev@5307fa7` + `T08` の実機観測(2026-08-26、`sdk_gphone16k_x86_64` / API 37)
- Next Agent action: **着手前に、`013:T06` が持つ platform channel を再利用できるかを見ること。**
  そのうえで列挙を port にし、fake で閉じてから実機を依頼する
