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

- [x] harness が host で働く。
  - 証拠: `flutter test test/spec_010_photo_video_source`、mutation M686〜M690。
- [x] エミュレータで、btime の有無と改名の前後、`DATE_ADDED` の改名の前後が分かっている。
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
- Review attempt 3(差分): `75732fa..55ee859` — **PASS** — P0/P1 なし。端末観測1・2回目で見つかった harness と手順の欠陥を直した範囲
  (`267e75b..75732fa` は記録だけで SELF-CHECK)。
  - 確認できた点: 生成した照会 command と手順書の byte 一致、PowerShell の単一引用符の解釈と端末の `sh -c` の語分けを再現して `--where` の値が
    1語になること(二重引用符を含まないので PowerShell 5.1 / 7 の引数の渡し方の差が出ない)、`flutter test` の `--uninstall` の既定が真で
    `--no-uninstall` で消さないこと、`flutter test` の install は `adb install -t -r`(データを保つ)であること、shell で置いた file が
    後片付けの接頭辞に当たらないこと、M686〜M693 の再現(8 KILLED)、`flutter test` 1256 PASS・analyze・format・workspace check。
  - F1(記録, P3): 3回目の Evidence revision が「HEAD」で曖昧 → `55ee859` と書いた。
  - F2(安全網の穴, P3): `flutter install --debug` の APK と `flutter test` の APK の署名・版が食い違うと、`adb install -r` が失敗して
    アンインストールからの入れ直しになり、権限が外れうる。同じ machine・同じ debug keystore では起きない。**残余riskとして受容**
    (引き受け先: この task。3回目で権限の失敗が出たらこれを疑う)。
  - F3(P3): 手順3の照会は MediaProvider の登録より先に走りうる → 手順3は「行が無くてもそのまま貼る」としてあり、手順5の照会が主の証拠なので、
    記録だけにする。
- 連鎖: `57c8e0e..a86cc92` PASS → `a86cc92..267e75b` PASS → `267e75b..75732fa` 記録だけ(SELF-CHECK) → `75732fa..55ee859` PASS。


### 端末での観測 1回目(2026-10-04、開発者・Android エミュレータ emulator-5554)

harness は `267e75b` と同一。出力(開発者が貼ったもの、要点):

```text
statx: あり
--- 対照(改名しない): brm-010-control.txt   btime: (無し)  mtime: 1791119240
--- 作った直後: brm-010-a.txt                 時刻 1791119240  btime: (無し)  mtime: 1791119240
--- 1回目の改名の後: brm-010-a-renamed-1.txt  時刻 1791119244  btime: (無し)  mtime: 1791119240  改名の結果: success
--- 2回目の改名の後: brm-010-a-renamed-2.txt  時刻 1791119247  btime: (無し)  mtime: 1791119240  改名の結果: success
改名: 2回とも成功 / btime が改名で変わらない: 読めない / mtime が改名で変わらない: true
```

- **btime は使えない。** `statx` は見つかったが、共有ストレージ(MediaProvider の FUSE)は `STATX_BTIME` を返さなかった。
- 更新時刻は、この app の改名(`renameat2`)で変わらなかった。
- `DATE_ADDED` の照会は `/system/bin/sh: no closing quote` で失敗した。**harness の欠陥**: 照会 command に二重引用符を入れ子にしており、
  PowerShell は `\"` を escape として扱わない。独立review は生成した文字列が手順書と一致することを確かめたが、PowerShell がそれをどう渡すかは
  確かめていなかった。→ 端末の shell へ渡す文字列から二重引用符を無くした(PowerShell の単一引用符 + 端末の `\` の escape)。
  host で端末の shell の語の分け方を `sh -c` で再現し、`_data LIKE '…/%'` が1語になることを確かめた。置いた file は残っているので、
  照会だけをやり直してもらう。

### 端末での観測 2回目(2026-10-04、開発者・emulator-5554)

直した照会(場所で探す)を実行 → `No result found.`。原因を見分けるため、harness の再実行・`ls`・場所と名前の2通りの照会を依頼した。

```text
flutter test …creation_time_probe_test.dart → PathAccessException: Cannot open file '…/brm-010-control.txt' (Permission denied, errno = 13)
  → runner が null の報告で2つ目の例外(Null check operator)
ls -l …/brm-010-probe → brm-010-a-renamed-2.txt と brm-010-control.txt(13:07、u0_a209 media_rw)
場所で照会 → No result found.
名前で照会 → Row: 0 _display_name=brm-010-probe, _data=/storage/emulated/0/Download/brm-010-probe, date_added=NULL
```

- **app が path で書いた file は MediaStore に載らなかった。** directory の行(`date_added=NULL`)だけがあり、1回目に置いた2つの file の行は無い。
  したがって、この app が作った file の `DATE_ADDED` は観測できない。**製品にとっての意味**: 製品が path で改名した file を MediaStore が
  どう扱うかは別に見る必要がある(下の3回目)。
- 2回目の harness の失敗は**手順の欠陥**: `flutter test` は既定で終わるとアプリを消す(`flutter_tools` の `--[no-]uninstall`。既定は消す)。
  再インストールで「すべてのファイルへのアクセス」が外れ、前回の(別の uid の)file を開けなかった。1回目が通ったのは、前から入っていたアプリに
  権限があったためと考えられる。→ 手順で先に `flutter install --debug` と `appops set` を行い、`--no-uninstall` で走らせる。
- runner が失敗を報告せず null で落ちた → 失敗を報告として出すようにした。
- 照会は名前(`brm%`)で探し `_data` も出す形にした(場所で探すと、載っていないのか条件の誤りかを見分けられなかった)。

### 3回目の設計

`adb shell` で `brm010-shell.txt` を置く(shell は MediaProvider を通るので載る見込み。手順3で載ったことを確かめる)。harness はそれがあれば
製品と同じ改名を3秒おきに2回行う(接頭辞が違うので後片付けで消えない)。改名の前と後の `DATE_ADDED`・`_data` を比べる。
- `DATE_ADDED` が置いた時刻のままで `_data` が新しい名前 → MediaStore は改名を追い、`DATE_ADDED` は使える。
- `DATE_ADDED` が改名した時刻に変わる、または行が消える/古い名前のまま → 使えない(古い名前のままなら、ギャラリーとずれることも分かる)。

### 端末での観測 3回目(2026-10-04、開発者・emulator-5554。harness は `55ee859`)

```text
手順3(shell で置いた直後):
Row: 1 _display_name=brm010-shell.txt, _data=…/brm010-shell.txt, date_added=1791123760
手順4(要点): statx あり / btime はどの file でも (無し) / mtime は改名で不変
  shell で置いた file: 改名する前 1791123963、1回目の改名の後 1791123966(success)、2回目の改名の後 1791123969(success)
  app で作った file: 改名は2回とも success
手順5(改名の後):
Row: 1 _display_name=brm010-shell-renamed-2.txt, _data=…/brm010-shell-renamed-2.txt, date_added=1791123760
(app で作った brm-010-*.txt の行は無い)
```

## 結論

- **`DATE_ADDED` は使える。** MediaStore に載っている file をこの app が改名(`renameat2`)すると、**MediaStore の行が名前と `_data` を
  追って更新され、`DATE_ADDED` は置いた時刻(1791123760)のまま**だった(改名は 1791123966・1791123969)。改名が MediaProvider の FUSE を
  通っているためと考えられる。
- **btime は使えない。** 共有ストレージは `statx` に作成時刻を返さない(3回とも)。
- この app が path で作った file は MediaStore に載らない(2回目・3回目)。ダウンロード・スクリーンショット・カメラの file は他の app が作るので
  載っている見込みで、③の対象になる。**載っていない file は③が無く、①②も無ければ「不明」**のまま。
- 副産物: 改名で MediaStore の名前が追従するので、**ギャラリーと名前がずれる心配は、この観測の範囲では無い**(plan の対象外に書いた
  「改名した後に MediaStore へ知らせること」は、少なくとも MediaStore に載っている file では不要だった)。
- 観測したのは emulator(sdk gphone16k x86 64)の1台だけである。端末・版による差は確かめていない。

→ `T01` は③を **Android の `DATE_ADDED`** として仕様にする。

## Current state / handoff

- Last checkpoint: 端末での観測 3回目(2026-10-04)。`DATE_ADDED` は改名で変わらず、btime は返らない。結論を `T01` へ渡した
- Status: done
- Next Agent action: なし
