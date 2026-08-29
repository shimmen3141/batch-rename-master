# T07 行と警告の情報階層を整える

## 目的

狭幅でも、どの行の作成日時が不明かと、警告の内容が読み取れるようにする。あわせて参考designの(b)「ファイル種別アイコンとリッチな行レイアウト」を行の情報階層の一部として入れる。仕様の変更を伴わない提示の調整。

(b)を分けないのは、**どちらも同じ行のlayoutを決める判断**だからである。別taskにすると同じwidgetを二度書き直すことになる。

## 入力と依存

- `specs/product-map.md`「008へ引き継いだ人間の決定(planへ反映済み)」の(h)(i)。
- `specs/history/asdd-0.x-discovery.md`の(b)。
- 現行の種別表現: `lib/ui/file_source/file_kind.dart`(読み込み時の種類chip)。行側に種別の表示は無い。
- 002 spec REQ-013(どのitemの作成日時が不明かを提示する。**提示方法の詳細は視覚デザインとして対象外**)。
- 005 specの「警告・確認・結果表示の視覚デザイン」→ 008送りの記載。
- 現行実装: `lib/ui/file_list/file_list_view.dart`の行サブ情報(`maxLines: 1` + ellipsisで1行にまとめている)、`lib/ui/file_list/rename_warning_view.dart`の警告帯。

## 変更範囲

- 行のサブ情報の折り返し・省略の優先順位・レイアウト。
- ファイル種別アイコンと行のlayout((b))。

  `FileKind`は**読み込み時に選ぶ種類**(004 REQ-011)であって、行ごとの種別ではない。行にアイコンを出すには拡張子かMIMEからの判定を新設することになる。これは提示ではなく**判定の追加**なので、次のいずれかに限る。

  - 拡張子からの分類を`lib/ui/`内の表示専用のものとして持ち、判定できないものは既定アイコンにする(改名の挙動に影響しない)。
  - 判定を持たず、アイコンを入れない。

  どちらを取るかは着手時に決め、`task.md`の作業記録へ根拠を書く。**004の決定D-2(実装が返したものをそのまま扱う)を曲げない**こと。種別を推測して読み込み対象を変えるような使い方はしない。
- ~~警告帯の情報階層~~ → **`T15`/`T16`へ移した**(2026-08-27の開発者決定)。件数が多いときに読めるようにするには**警告の置き場所ごと変える**必要があり、002の行データと005の警告提示・REQ-021のまとめ規則が動くため、仕様更新taskと実装taskへ分けた。**T07に残るのは、内訳の高さを画面に応じるようにした分だけ**である(小さい画面では従来値が下限)。経緯は作業記録の「警告帯: ここで止めて人間へ返す論点」。

**行ごとの「場所(元folder)」の提示はT07が持つ。** 一覧全体としての「何がどこから入っているか」はT08が持つ。同じ情報を二重に出さないよう、後に着手した側が先の結果に合わせる。詳細は[`T08のtask.md`](../T08-load-affordance-and-path/task.md)。

### 行widgetの分担(T04・T09と共有する)

`lib/ui/file_list/file_list_view.dart`の行widgetには、008の3つのtaskが入る。`file_source_bar.dart`(T04とT08)と同じ種類の重複なので、担当を先に固定する。

| task | 行のうち持つもの |
|---|---|
| **T07** | 情報階層と静的なlayout。サブ情報の省略順、種別アイコン、警告アイコンの位置 |
| **T04** | 操作。×の廃止、除去の新しい導線(左swipe等)、checkboxとの関係 |
| **T09** | mode別の描画。**リッチ案はT07の行をそのまま使う**。グリッド・コンパクトの構成 |

**T07が最初に着手できる。** T04は`T03`の仕様承認待ち、T09はT02とT07の完了待ちなので、実行順は自然にT07 → T04 → T09になる。ただし依存として宣言しているのはT09→T07だけである。

**T04が先に着手した場合**、T07は除去導線を壊さないよう、T04が作った行の構造の上でlayoutを整える。**判断が割れたらT07の情報階層を優先する**(T07が(h)の見切れという観測済みの不具合を解いているため)。
- **仕様は変えない。** 002 REQ-013の識別自体は現行でも警告アイコンで成立している(アイコンは省略対象外)。読みやすさの改善である。

## 着手時の決定(2026-08-27)

### 種別アイコンではなくpreviewを出す(開発者決定)

上の「変更範囲」が挙げていた二択(拡張子から表示専用の分類を持つ / アイコンを入れない)の
**どちらでもない**。開発者が**画像・動画のpreview**(スマホのファイルアプリのようなもの)を
指定した。**種別アイコンは無くならず、previewが取れないものの下地として残る。**

対象は**画像と動画**である。文書・PDFのpreviewは出さない(開発者決定)。

### previewの基盤はT07が作り、`T13`は適用だけを行う(開発者決定)

[`T13`](../T13-browser-file-preview/task.md)が同じpreviewを**app内file browserの行**
(`storage_browser_view.dart`)に対して持っている。**画面は違うが仕組みは同じ**であり、
`T13`の「先に決めること」(数百件でのメモリと速度、遅延読み込み、上限、cache、
「previewが無い」と「読めなかった」の区別)は**そのままT07にも要る**。

`T13`は`T12`←`T11`(仕様承認)待ちで今は着手できない。ここで分担を決めないと同じ基盤を
2回作ることになるため、**T07がportとcacheを新設し、`T13`はそれをbrowserの行へ繋ぐだけの
taskにする。** `T13`の「先に決めること」はT07が埋める。

`T13`は文書には無い**テキストのpreview**も持つ(U4の原文)。それは`T13`の裁量に残す —
T07が作るのは「あるpathからthumbnailを得るport」で、textを足すのはその実装を1つ増やす
ことである。

### `sourceHandle`がpathであることに依存しない

`013`の結果、Androidもdesktopも`FileEntry.sourceHandle`に**実path**が入る
(`android_file_source.dart:106`、`desktop_file_source.dart:108`)。previewはこれを使う。

ただし`SafFileSource`は**document URI**を入れる(`saf_file_source.dart:118`)。これは
`013 ADR-002`が保っているPlay却下時の退避先である。**「handleはpathである」を前提に
書くと退避したときに壊れる。** portは「preview を作れない」を正常な結果として返し、
行は**種別アイコンへ落ちる**。退避しても劣化するだけで壊れない。

**`013 ADR-002`の退避手順表には行を足さない** — 落ちる先が既定動作なので、退避時に
戻す作業は発生しない。この性質自体をtestで固定する。

### 「previewが無い」と「読めなかった」を型で区別する

`004`の`NameListResult`(列挙できない / 空)と`013:T12`の`StorageVolumesResult`が採った形に
合わせる。**失敗を「previewの無いfile」へ潰さない。** 潰すと、読めないfileが「preview の
無い普通のfile」に見える。

### 狭幅の見切れは、優先順位ではなく行数で解く

現行の`_DateSubInfo`は「場所 · 作成日時 / 更新日時」を**1つの`Text`**にまとめ
`maxLines: 1` + ellipsisで省略していた(着手時の`file_list_view.dart`の`_DateSubInfo`)。場所が先頭にあるため、
狭幅では**後ろの`作成日時: 不明`から消える**。これが(h)の見切れである。

省略の優先順位を調整して`不明`を残す形も取れるが、**幅次第で再発する**。リッチな行は
高さに余裕があるので、**場所と日時を別の行に置く**。`不明`が省略で消えることが構造上
起こらなくなる。コンパクトmodeで1行に戻す判断は`T09`が持つ。

### 警告の提示は`T15`/`T16`が引き受ける(2026-08-27)

上の「変更範囲」の3つ目を、開発者の決定で分離した。**`T07`は行のlayoutとpreviewで閉じる。**

`T15`は 002 の行データと 005 の警告提示を定義し直す(人間の再承認が要る)。`T16`が実装する。
`T07`が入れた行の縦積みは`T16`の土台になるので、**`T16`は`T07`の情報階層を壊さない**。

### machine検証する範囲と、引き受け先のtask

| 範囲 | 検証手段 |
|---|---|
| portの契約(preview有り / 対象外 / 失敗の区別)、cacheの上限と鍵、同時実行数 | unit test |
| 行のlayout、狭幅での`作成日時: 不明`、種別アイコンへの落ち方、警告帯 | widget test(幅を指定する) |
| 画像thumbnailの生成 | unit test(fixtureの画像fileを`test/`に置く) |
| **Android の動画thumbnail(Kotlin側)** | **実機のみ。** `MethodChannelStorageVolumes`と同じで、Dart側の写像はchannelを差し替えて検査できるが、`MediaMetadataRetriever`が本当にframeを返すかはCIで実行できない → **このtaskのmanual確認が引き受ける** |
| **件数の多いfolderでの速度とメモリ** | **実機のみ** → このtaskのmanual確認が引き受ける(DCIM等) |

**Windows desktopの動画thumbnailは実装しない。** `IShellItemImageFactory`(COM)が要り、
T07の範囲を大きく超える。**Windowsでは動画は種別アイコンへ落ちる** — 上の「取れなければ
落ちる」が既定動作なので、破綻ではなく劣化である。画像thumbnailはDartのdecodeなので
**両platformで動く**。動画をWindowsでも出すなら別taskとして足す。

この宣言の外側の指摘は安全網の穴として扱う(AGENTS.md)。

### 仕様の扱い

`plan.md`の方針は「T07/T08/T10/T13/T14は仕様を変えないため`covers`は空のままが正しい」と
している。**previewはfileの中身を読む**ので、行が今まで持っていなかった振る舞いが増える。
002 specは「視覚デザインは非規範」としており、previewの見せ方はその中に収まるが、
**「中身を読む」こと自体は視覚デザインではない。**

判断: **002 specへREQは足さず、`decisions/`へ根拠を残す。** 002が定めているのは行が
**何を表示するか**であって、表示のために何を読むかではない。読み取りは004が既に持っている
権限の範囲内で、改名の判定にも読み込み対象にも影響しない。**ただしこれは人間へ報告し、
REQを足すべきという判断ならその時点で仕様更新taskを分ける。**

## 受け入れ証拠

- 狭幅で`作成日時: 不明`が読み取れることをwidget testで検査する(幅を指定して省略位置を検査する)。
- 警告帯の内訳の高さが画面から決まり、小さい画面でも従来値を下回らないことをtestで検査する
  (**内容が読み取れるかは`T16`が引き受ける**)。
- **preview portが「preview有り」「対象外」「失敗」を区別して返すことをunit testで検査する。**
  失敗を対象外へ潰していないことを含む。
- **`sourceHandle`がpathでないとき(SAF document URI)にpreviewを試みず、行が種別アイコンへ
  落ちることをtestで検査する**(`013 ADR-002`の退避経路を壊していない証拠)。
- **cacheの上限と同時実行数が効いていることをunit testで検査する**(数百件でも
  無制限に読まない)。
- 002/005の既存testが継続PASSする(判定も文言の意味も変えていない)。
- `flutter test` / `flutter analyze` / `dart format --output=none --set-exit-if-changed .` がPASS。
- [`manual-verification.md`](manual-verification.md)でAndroid実機の狭幅表示を確認する。**004:T10で見切れを観測したのと同じ条件で確認する。**
- exact rangeの独立reviewがPASSする。

## 作業記録

- 2026-08-12 / plan作成時に定義。(h)は`004:T10`のAndroid実機確認で観測、(i)は同確認でfile選択画面の種類チップがfolderを横断すると判明したことによる。
- 2026-08-27 / claim。開発者から3つの決定を受けた(リッチの行はT07が作る / 種別アイコンではなく画像・動画のpreview / preview基盤はT07が作り`T13`は適用だけ)。上の「着手時の決定」へ記録した。
- 2026-08-27 / (h)の見切れを`360dp`のwidget testで再現(`didExceedMaxLines` = true)。行を縦積みにし、場所を別の行へ、作成日時を`Row`の縮まない側へ置いて解消。`flutter test` = PASS(665)。
- 2026-08-27 / mutation 2件を`tool/mutations.json`へ追加(M163: 作成日時を`Flexible`へ移す / M164: 場所を日時と同じ行へ戻す)。`mutation_check.py` = **2 KILLED, 0 SURVIVED**。生の出力は下記。
- 2026-08-27 / preview port・cache・種別振り分け・Kotlin側を実装。`flutter test` = PASS(694)。
- 2026-08-27 / 行への組み込みと警告帯の高さ。`flutter test` = PASS(704)、`flutter analyze` = PASS、`dart format` = PASS、`workspace.py check specs` = PASS。
- 2026-08-28 / 独立review attempt 2 = **PASS**。P2×2(bufferの持ち主のコメントが事実と違う / task.md内の行番号引用の陳腐化)を修正し、reviewerが足した安全網の穴5件を受容せず殺すtestを書いた。`flutter test` = PASS(720)、`analyze` = PASS、`format` = PASS、mutation **10 KILLED, 0 SURVIVED**。
- 2026-08-28 / `manual-verification.md`をcurrent revision(`bf48aa9`)へ合わせて書き直し、引用する画面文言・ショートカット名・commandを`git grep`で突き合わせた(dry-run)。残余riskのN-5・N-6・N-7を項目に入れ、N-8は範囲外として明記した。
- 2026-08-29 / Android emulatorで手順1〜5を実施。**手順1〜4はPASS、手順5は3つ目のcheckが不成立**(帯が一覧の半分以上を覆った)。N-5・N-6・N-7が解消した。N-8は再現し、sort barのはみ出し(N-8a→`T02`)とheaderのoverflow(N-8b→`T10`)へ分けた。不成立だった手順5の3つ目はN-9として`T16`へ渡した。開発者の改善案を`T03`(checkbox廃止案・件数表示の位置)、`T12`(空folderの文言)、`T15`(作成日時代替bannerは行へ移さない)、`T11`+product-map(browserの範囲選択)へ記録した。**appのcodeは変えていない** — 変えたのはtest1件の名前とコメント(主張の是正)だけである。

### mutation の生の出力

`python3 <asdd-plugin>/scripts/mutation_check.py <部分表> --root .` を、このtaskが足した
10件へ絞って走らせたもの(`command` は表と同じ `flutter test`)。

```text
command: flutter test
ID | STATUS | FILE | NOTE | DETAIL
--- | --- | --- | --- | ---
M163 | KILLED | lib/ui/file_list/file_list_view.dart | 008:T07 作成日時から下限(Flexible+ellipsis)を外す — 狭幅で省略ではなくoverflowになる | exit 1
M164 | KILLED | lib/ui/file_list/file_list_view.dart | 008:T07 場所を日時と同じ行へ戻す — 場所が幅を使い切り日時が読めなくなる | exit 1
M165 | KILLED | lib/ui/file_list/row_preview_view.dart | 008:T07 古い応答の破棄をやめる — scrollで行が別fileを指した後に前のfileの絵が出る(独立reviewが追加) | exit 1
M166 | KILLED | lib/ui/rule_builder/rule_builder_workspace.dart | 008:T07 合成でpreview portを配り忘れる — productionの行からpreviewが消える(独立reviewが追加) | exit 1
M167 | KILLED | lib/ui/rule_builder/rule_builder_workspace.dart | 008:T07 wide(2ペイン)経路でpreview portを配り忘れる — narrowだけ通してもWindows/大画面で行からpreviewが消える(独立review attempt 2が追加) | exit 1
M168 | KILLED | lib/main.dart | 008:T07 composition rootがport自体を渡さない — T07の機能が丸ごと切れても行は種別アイコンで「それらしく」見える(独立review attempt 2が追加) | exit 1
M169 | KILLED | lib/ui/file_list/row_preview_view.dart | 008:T07 外れた行へのsetStateを防ぐmounted判定を外す — scrollで行が捨てられた後に応答が届くとframeが組めなくなる(独立review attempt 2が追加) | exit 1
M170 | KILLED | lib/data/preview/cached_file_preview.dart | 008:T07 semaphoreの席を返さない — 一巡した後の要求が永久に待ち、previewが二度と出なくなる(独立review attempt 2が追加) | exit 1
M171 | KILLED | lib/ui/file_list/file_list_view.dart | 008:T07 FileListViewが行へportを渡さない — 対照として置く(独立review attempt 2が追加) | exit 1
M172 | KILLED | lib/data/preview/image_file_preview.dart | 008:T07 engine側のbufferを解放しない — 読めない画像1件ごとにnative memoryが残る(独立review attempt 2が追加) | exit 1
10 mutations: 10 KILLED, 0 SURVIVED, 0 SKIPPED
```

**M165〜M172 は独立reviewが SURVIVED として足したものである。** 穴を記録して受容するのでは
なく、殺すtestを書いた。M166 / M167 / M168 は `013:T05` で3回FAILしたのと同じ型
(productionが通る合成をtestが一度も通らない)なので、特に残す価値が高い。M171 は対照として
置いたもので、落とさない。

### 警告帯: ここで止めて人間へ返す論点

`変更範囲`の3つ目「警告帯の情報階層。件数が多いときに読めるか」を**途中で止めた。**

**観測**: 360dp で重複警告30件を開くと、1件が4行へ折り返して68px になり、固定132px の
内訳には**2件しか入らない**。folder跨ぎの重複は通常経路で出る((i))ので、件数が多いのは
例外ではない。

**やったこと**: 内訳の高さを画面から決めるようにした(小さい画面では従来値を下限に保つ)。

**やらなかったこと**: 実際に効くのは**種別でまとめ、繰り返される説明文を見出しへ出し、
各行を「file名(場所) → 変更後名」の1〜2行に縮める**ことである。これをやると1行68px が
17〜34px になり、同じ高さで4〜8倍読める。

**止めた理由**: 005の既存testが、REQ-009 / REQ-021 の証拠として**各行が説明文を丸ごと
持つこと**を固定している。

- `empty_rule_test.dart:169` — 行の`Text.data`が`名前が空になります`と`基準日時が取れない`の両方を含む
- `warning_display_test.dart:172` — 帯の`Text`の数が`警告件数 + 1`(見出し1行 + 1件1行)
- 同`:180` — `作成日時が不明`が**2件ぶん**見つかる(説明が行ごとに繰り返されている)

005 spec は提示手段を自由としており(「自由とする点」)、REQ-009 が求めるのは
**対象fileが識別できること**なので、まとめた形でも要求は満たせる。しかし上の3つは
**現在の提示を要求の証拠として書いている**ので、進めるにはこれらを書き換えることになる。
`plan.md`の方針は「T07は仕様を変えない」であり、Agentが自分でtestを緩める側にも回れない。

**人間へ返す選択肢は報告に出した。**

### 独立review

- Review attempt 1: `dev...29dade5` — **FAIL** — P1-1(狭幅で作成日時が既知の行がoverflow)、P2×7。すべて修正済み。
- Review attempt 2: `dev...98db21b` — **PASS**。成果物の欠陥はP2が2件、安全網の穴が5件(うち1件は対照)。**穴は受容せず、5件すべて殺すtestを書いた。**
- Review(`final-evidence`): `dev...ccc1e0a` — **PASS**。成果物の欠陥はP2が7件で、すべて**記録の誤り**(app codeの欠陥は無し)。すべて修正済み。auto-mergeの7条件も条件ごとに判定を受けた。

**P1-1 は私が入れた回帰である。** dev 側は `Expanded(Text.rich(..., ellipsis))` で構造上
あふれ得なかったが、「作成日時を縮まない側へ置く」に**下限を与えなかった**。testが
`createdAt: null`(=最短文字列「不明」)しか通しておらず、**この経路を一度も踏んでいなかった。**
`Wrap` へ変えて更新日時が次の行へ落ちるようにし、作成日時自身にも省略を持たせた。

**P2-1 も記録の欠陥だった。** M163 は構文エラーになる mutation で、`mutation_check.py` は
コンパイル失敗も KILLED と数えるため、**その行は何も検査していなかった**。「2 KILLED」が
test強度の証拠になっていなかったことになる。意味の通る版へ差し替えた。

その他: P2-2 [`decisions/ADR-001`](../../decisions/ADR-001-row-preview-reads-file-content.md)を作成 /
P2-3 `T13`をT07の分担へ追随させ`dependsOn`へ`T07`を追加(`T16`も) /
P2-4 種別アイコンの拡張子集合を preview 可否から分離(`heic`等が汎用アイコンに落ちていた) /
P2-5 testのコメントと名前を実際の検査へ合わせた /
P2-7 Kotlin: `compress`が投げてもbitmapを解放、破棄後のchannel応答を捨てる。

#### attempt 2 の指摘と対処

**P2-1(成果物の欠陥): bufferの持ち主についてコメントが事実と違った。** 「codecを作れたら
bufferはcodecのもの」と書いていたが、SDKの`instantiateImageCodecWithSize`は
`ImageDescriptor.encoded`が成功した後は**成否に関わらず**bufferを捨てる
(`painting.dart`の`finally { buffer.dispose(); }`)。正しい条件は「encodedが投げたときだけ
自分のもの」であり、**呼び出し側からは判別できない。** 現行codeが動いていたのは、
目標サイズの計算が投げる経路へ到達していなかっただけである(`maxEdge: 0`で
`ArgumentError`になり、finallyから二重解放のassertが飛んでportの「例外を投げない」約束が
破れる)。`ImageDescriptor.encoded`を直接呼び、その`finally`一箇所でbufferを捨てる形へ変えた。
目標サイズの計算も投げないようにした。

**P2-2(成果物の欠陥): task.md内の行番号引用が、このrange自身の変更で陳腐化していた。**
`T16`の「`file_list_view.dart:157`の`AlertDialog`」は、このrangeが同じfileへ21行足したため
別の場所を指すようになっていた。**動かない識別子へ変えた**(`Key('rename-confirmation-dialog')`)。
同じ型の引用を008配下で洗い、`T14`の2件(`file_list_view.dart:157` /
`rule_builder_workspace.dart:76`)と`T07`自身の1件(`file_list_view.dart:826`)も直した。
`file_source_bar.dart:192`と`token_editors.dart:13`はこのrangeが触っていないので残した。

**安全網の穴5件は受容せず閉じた。** reviewerはAGENTS.mdの条件2(データ損失・無断置換・
偽の成功・権限逸脱・互換性破壊)を満たさないとしてPASSにしたが、**閉じる費用が小さく、
うち2件は`013:T05`で3回FAILしたのと同じ型**だったため殺す側へ回した。M167〜M172として
`tool/mutations.json`へ取り込み(対照のM171を含む)、10件すべてKILLEDを確認した。

`ImageDescriptor`を作る手続きを差し替えられるようにしたのは、**開いたbufferが呼び出し側から
見えず、解放漏れを観測できなかった**ためである(reviewerは「CIで閉じるのは難しい」と
判断していた)。継ぎ目はtest専用で、productionは既定のまま通る。

### 実機(Android emulator)確認の結果

| | |
|---|---|
| 日付 | 2026-08-29 |
| 対象 | `0e66b24`(appの動きを決める最終commit)の build |
| 環境 | Android emulator。**実端末は使っていない** — 見たいのがAndroid frameworkの返す値だったため |
| 手順 | [`manual-verification.md`](manual-verification.md) の手順1〜5 |

**手順1〜4はcheckをすべて満たした。手順5は3つ目のcheckが不成立**(帯が一覧の半分以上を覆った。N-9として`T16`が引き取る)。引き受けていた残余riskの決着は次のとおり。

| # | 結果 |
|---|---|
| **N-5**(Kotlinの動画thumbnail) | **解消。** 動画の行にその動画の一場面が出た。`MediaMetadataRetriever`が実際にframeを返すことを確認した |
| **N-5**(速度・メモリ) | **emulatorの範囲で問題なし。** previewは「ガタつきを観測できないほど短時間」で出た。scrollの引っかかりは**このtask以前から感じていたもの**と開発者が判断した。**実端末での追試は行っていない** |
| **N-6**(動画の縦横比) | **解消。** 格子と正円のfixtureで確認し、崩れていなかった。`getScaledFrameAtTime`は比を保つ |
| **N-7**(文字サイズ最大) | **解消。** 警告の印でどの行か分かり、overflowもはみ出しも無かった |
| **N-8**(headerのoverflow) | **再現した。しかも見た目だけではない** — ソートchipが画面外へ出て**一部を選択できなかった**。下記のとおり引き受け先を分けた |

**副次的に分かったこと**

- `broken-fixture.jpg`が壊れた画像の印、`.txt`/`.pdf`が文書の印になった。**型で分けた区別が
  画面まで残っている**ことを実機でも確認できた。
- 文字サイズを上げると、更新日時は**省略ではなく次の行へ落ちた**。`Wrap`が先に折り返し、
  折り返しても足りないときだけ省略する形である。開発者は「更新日時はソートにも使うので、
  削るより改行がよい」と評価した。**現行の実装がその形になっている。**
- 動画は全件previewが出たため、**動画がアイコンへ落ちる経路は実機で観測していない**
  (unit testが押さえている)。


#### `final-evidence` reviewの指摘と対処

**7件すべてが記録の欠陥であり、うち2件は私が事実を歪めていた。**

- **P2-2 開発者の発言を強めていた。** 「修正する必要はない**かも**」を「と判断した」、
  「表示しても良い**かも**」を「述べた(=決定)」と書いていた。**原文の強さのまま引用する形へ
  直した**(この`task.md`と`T15`)。あわせて「5項目すべてPASS」という要約が、**手順5の3つ目
  (帯が画面の半分を超えない)の不成立を吸収していた**。「手順1〜4はPASS、手順5の3つ目は
  不成立」へ直した。
- **P2-4 N-8aの原因が code と食い違っていた。** sort barは
  `SingleChildScrollView(Axis.horizontal)`なので**水平scrollすれば届く**。「到達できない操作」
  は誤りで、欠陥は**はみ出していることに気づけない**ほうである。`T02`の受け入れ条件も
  直した。
- **P2-3 N-8bの「外側`Column`もoverflowする」を再現できなかった。** reviewerのprobeでは
  `_HeaderBar`の`Row`が**水平に約69px**あふれるだけで、垂直のoverflowは出ない。開発者も
  「文字が枠の外へはみ出していない」と報告している。**観測できた事実だけ**へ直した。
- **P2-1 `0e66b24`以後の差分の数え方が誤り。** 核心(app code不変)は真だが、「test1件」は
  最後のcommitだけの話だった。`git diff`の結果で書き直した。
- **P2-5 引き受け先として名指ししたtaskに記載が無かった。** N-9は`T15`にしか書いておらず
  `T16`に無く、件数表示の位置も`T04`に無かった。**両方へ足した。**
- **P2-6 PR #159の本文が陳腐化していた。** 「作成日時を`Row`の縮まない側へ置いた」は
  attempt 1 で潰した形、「警告帯…人間の判断待ち」は2026-08-27に決着済み。**本文だけが
  判断待ちに見え、auto-merge条件6の読み取りに直接効く**ため書き直した。
- **P2-7 manual手順が実装の見え方に追随していなかった。** 「削られるのは更新日時の側」を
  「まず次の行へ落ち、それでも足りなければ省略される」へ直した。

### 残余riskとして受容するもの

安全網の穴のうち、AGENTS.mdの3条件を満たさないため受容する。受容はtask所有Agentが記録する。

**IDは通し番号で、N-1 / N-2 は存在しない**(採番のずれであり、内容の欠落ではない)。

| # | 内容 | 引き受け先 |
|---|---|---|
| N-3 | `CachedFilePreview`は inner の例外を`_store`せず呼び出し元へ伝播する。`RowPreviewView`は受けないので、将来portが投げると unhandled async error になる。現行の実装はいずれも投げない(結果値で返す)ので届かない | `008:T13`(portへ実装を1つ増やす側) |
| N-4 | cacheの鍵が`sourceHandle == null`の行同士で衝突する。現状はどちらも`Unsupported`へ落ちるので無害 | `008:T13` |
| ~~N-5~~ | Kotlin側と速度・メモリ。**2026-08-29のemulator確認で解消**(速度は実端末未追試) | 解消 |
| ~~N-6~~ | `getScaledFrameAtTime`の縦横比。**2026-08-29のemulator確認で解消**(格子と正円のfixtureで確認) | 解消 |
| ~~N-7~~ | 文字サイズ最大での省略。**2026-08-29のemulator確認で解消** — 印は消えず、行も崩れなかった | 解消 |
| N-8a | 文字サイズ最大でsort chipが画面外へはみ出し、**一部を選べなかった**と開発者が報告した。bar自体は`SingleChildScrollView(Axis.horizontal)`なので**水平scrollすれば届く**(`file_list_view.dart`の`_SortBar`)。**欠陥は到達不能ではなく、はみ出していることに気づけない**ことである。このcontrolは`T01`の決定で**ドロップダウンへ置き換わる**(plan.md 2026-08-05)ので、今の形を直しても消える | `008:T02`(並び順controlの実装) |
| N-8b | `textScaler` 3.0で`_HeaderBar`の`Row`が**水平に約69px** overflowする(independent reviewのprobeで再現。`file_list_view.dart`の`_HeaderBar`)。**T07が触っていない既存code**で、行(`_FileRow`)は無傷。**垂直のoverflowは再現していない** — 開発者も「文字が枠の外へはみ出していない」と報告している | `008:T10`(余白・typography) |
| N-9 | 警告帯を開くと、**一覧の見える範囲の半分以上を覆う**ことがある。高さの上限を**画面**の割合で決めているが、帯は一覧の上に載るので、header・barを引いた**一覧の取り分**に対しては割合が跳ね上がる。従来の固定132pxではこうならなかった。**内訳が読めるようにするための意図した代償**である。開発者の評価は「(後に各fileの行に出すなら)ここで修正する必要はない**かも**」(2026-08-29、原文のまま)で、**T07で直さない確定判断ではない**。帯を残す形を選ぶなら`T16`が上限の基準を決め直す | `008:T16`(帯を置き換える側) |

## Current state / handoff

- Last checkpoint: **`final-evidence` phaseの独立review = PASS。** 指摘7件(すべて記録の誤り)を修正し、PR本文を書き直した。`flutter test` = PASS(720) / `analyze` = PASS / `format` = PASS / mutation 10件すべて KILLED / `workspace.py check specs` = PASS
- Blocker category: なし
- Waiting for: CIとmerge
- Requested action: なし
- Evidence revision: manual証拠は`0e66b24`のapp buildに対応する。**以後`lib/`・`android/`・`pubspec`に差分は無い**
- Next Agent action: **このtaskは`done`。** PR #159 をreadyにしてmergeする。merge後は`dev`上の結果とCIを確認し、worktreeを整理する。引き継いだ残余riskは`T02`(N-8a) / `T10`(N-8b) / `T13`(N-3・N-4) / `T16`(N-9)が持つ

## 次のtaskへの申し送り

- **`T09`**: 行のlayoutはこのtaskが確定させた。リッチ案はこの行をそのまま使う。
- **`T13`**: preview portとcacheはこのtaskが作った。browserの行へ繋ぐだけでよい。N-3(例外の伝播)とN-4(鍵の衝突)を引き受ける。
- **`T16`**: このtaskが入れた行の縦積みを壊さないこと。N-9(帯の高さの基準)を引き受ける。
- **人間へ未回答のまま残っている論点**: 「行がfileの中身を読む」ことに002へREQを足すか。現在は[`decisions/ADR-001`](../../decisions/ADR-001-row-preview-reads-file-content.md)に根拠を残す形で閉じている。**mergeはこの判断を妨げない** — 足すと決まれば仕様更新taskを分ける。
