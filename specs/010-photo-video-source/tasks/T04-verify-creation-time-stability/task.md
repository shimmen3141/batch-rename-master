# T04 改名しても作成時刻が変わらないかを端末で確かめる

## 目的

作成日時の3番目の経路(**ファイルがこの端末に作られた時刻**。ダウンロード・スクリーンショットなどに日時を付ける)に使える値があるかを、
Android エミュレータで確かめる。候補は2つで、**このアプリで改名しても値が変わらないもの**だけが使える
(変わると、2回目の改名から作成日時が改名した日になり、名前が崩れる)。

- `statx` の作成時刻(btime): 改名でファイルの実体は変わらないので変わらない見込み。共有ストレージ(MediaProvider の FUSE)が値を返すかは分からない。
- MediaStore の `DATE_ADDED`: path での改名の後に MediaStore へ登録し直されると、改名した時刻に変わりうる(未確認の推測)。

結果は `T01` が仕様の3番目の経路に使う。

## 出所

開発者の問い(原文): 「ダウンロードされた日付、スクショされた日付、写真が撮られた日付のすべてを作成日時とすることは可能ですか。撮影日時という名前自体が写真にしか使えない汎用的でない言葉だと思います。作成日時であれば、文書やカメラで撮った写真、ダウンロード、スクショのどれにもある程度意味が通じます。」

開発者の指示(原文): 「推奨通り、まず改名しても値が変わらないかを調べる task を足してください。私のエミュレータ確認なしでも進められるところまで進めてください。どうしてもエミュレータ確認が必要なら確認します。」

## なぜエミュレータが要るか

値を返すか・改名で変わるかは、Android の共有ストレージ(MediaProvider の FUSE)と MediaStore の振る舞いで、host の Linux では観測できない
(host の ext4 は btime を返し改名で変えないが、それは Android について何も言わない)。**製品と同じ package・権限・mount view**で走る
integration test で、製品と同じ改名(`renameFileWithoutOverwrite`)を使って観測する(`013:T08` と同じ形)。

## machine検証範囲と引き受け先

- machine(CI): harness が働くこと — `statx` の構造体の読み方(合成した構造体と host の実ファイル)、2回の改名、報告の形、前回の残骸の削除。
  `test/spec_010_photo_video_source/creation_time_probe_test.dart`。
- 端末(この task の manual): btime を返すか、改名で btime・`DATE_ADDED` が変わるか。
- **製品の code は増やさない。** `DATE_ADDED` は app から読むのに platform channel が要るので、仕様の承認前には足さず、人間が
  `adb shell content query` で読む。

## 受け入れ条件

- [ ] harness が host で働く。
  - 証拠: `flutter test test/spec_010_photo_video_source`、mutation M686〜M690。
- [ ] エミュレータで、btime の有無と改名の前後、`DATE_ADDED` の改名の前後が分かっている。
  - 証拠: [manual-verification.md](manual-verification.md) の出力を貼った記録。

## 作業記録

- harness: `integration_test/creation_time_probe.dart`(核)、`integration_test/creation_time_probe_test.dart`(端末の runner)。
  `Download/brm-010-probe/` に対照の file と改名する file を置き、3秒あけて2回改名し、各段階の btime・mtime と時刻を報告する。
  置いた file は `DATE_ADDED` の照会のために残す(次の実行の最初に消す)。
- host の test: 11 → 12件 PASS(M689 が SURVIVED だったので「btime が変わったら不安定と報告する」test を足した)。
- mutation(範囲付き `flutter test test/spec_010_photo_video_source`、5件):

```text
M686 | KILLED | integration_test/creation_time_probe.dart | 010:T04 btime の位置を ctime と読み違える | exit 1
M687 | KILLED | integration_test/creation_time_probe.dart | 010:T04 mtime の位置を読み違える | exit 1
M688 | KILLED | integration_test/creation_time_probe.dart | 010:T04 btime を返さない filesystem でも値を読む(mask を見ない) | exit 1
M689 | KILLED | integration_test/creation_time_probe.dart | 010:T04 btime が変わっても安定と報告する | exit 1
M690 | KILLED | integration_test/creation_time_probe.dart | 010:T04 btime が読めない段階があっても安定と言う | exit 1
5 mutations: 5 KILLED, 0 SURVIVED, 0 SKIPPED
```

- 独立review attempt 1 の指摘を直した後の範囲付き実行(7件):

```text
M686〜M690 | KILLED(上と同じ)
M691 | KILLED | integration_test/creation_time_probe.dart | 010:T04 statx へ STATX_BTIME を要求しない(独立review attempt 1 の対照 CM-R1) | exit 1
M692 | KILLED | integration_test/creation_time_probe.dart | 010:T04 DATE_ADDED の照会 command の引用を落とす(独立review attempt 1 の対照 CM-R2) | exit 1
7 mutations: 7 KILLED, 0 SURVIVED, 0 SKIPPED
```

### 独立review

reviewer は Sonnet 5(Agent tool、`model: sonnet`。開発者の指定)。実装は Claude Opus 5.5。

- Review attempt 1: `57c8e0e..a86cc92` — **PASS** — P0/P1 なし
  - 確認できた点: `struct statx` の位置と定数(Linux の `uapi/linux/stat.h`・`fcntl.h` と照合)、FFI の型、bionic の `libc.map.txt` に `statx` が
    公開されていること、照会 command が手順書と1文字も違わないこと、観測の設計(対照の file・各段階の epoch 秒・3秒の間隔)、
    R-001 の一次資料との一致、製品と同じ改名を呼んでいること、M686〜M690 の再現、analyze・format・`flutter test` 1253 PASS・workspace check。
  - F1(安全網の穴, P2): statx へ渡す要求から `STATX_BTIME` が落ちても検出できない(filesystem が要求しなくても返すため。対照 CM-R1 が SURVIVED)
    → 要求を `requestedStatxMask` として出し、値を test で確かめた。CM-R1 を **M691** として取り込んだ。
  - F2(安全網の穴, P2): 照会 command の引用が崩れても検出できない(対照 CM-R2 が SURVIVED)→ 完全一致の test を足した。**M692**。
  - F3(記録, P3): T01 の handoff が `in_progress` なのに「未着手」 → 言い直した。
  - F4(提案, P3): `DynamicLibrary.process()` で `statx` が見つからないときの保険 → `libc.so` を直接開く探し方を足した。
  - 直した commit: `test(asdd-010/T04): 独立reviewの指摘…`。
- Review attempt 2(差分): `a86cc92..267e75b` — **PASS** — 指摘なし。F1〜F4 が閉じたこと、`DynamicLibrary.open` と `lookupFunction` の失敗が
  どちらも `ArgumentError` で3通りの探し方が落ちないこと、M692 がコンパイルは通って assertion で落ちること、M686〜M692 の再現(7 KILLED)、
  照会 command と手順書の一致、`flutter test` 1255 PASS・analyze・format・workspace check を確認。
- 連鎖: `57c8e0e..a86cc92` PASS → `a86cc92..267e75b` PASS。以後の記録だけの差分は SELF-CHECK。


## Current state / handoff

- Last checkpoint: harness を作り、host で働くことを確かめた(2026-10-04)
- Blocker category: manual-evidence
- Waiting for: 開発者(Android エミュレータで harness を走らせ、`DATE_ADDED` を照会する)
- Requested action: [manual-verification.md](manual-verification.md) の手順1〜4
- Evidence revision: harness(`integration_test/creation_time_probe*.dart`)が `267e75b` と同一
- Next Agent action: 出力を読み、btime・`DATE_ADDED` のどちらが使えるかを記録して `T01` へ渡す
