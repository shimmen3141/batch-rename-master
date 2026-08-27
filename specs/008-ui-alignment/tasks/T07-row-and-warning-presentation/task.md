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
`maxLines: 1` + ellipsisで省略している(`file_list_view.dart:826`)。場所が先頭にあるため、
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

### mutation の生の出力

```text
command: flutter test test/spec_002_file_list/
ID | STATUS | FILE | NOTE | DETAIL
--- | --- | --- | --- | ---
M163 | KILLED | lib/ui/file_list/file_list_view.dart | 008:T07 作成日時を縮む側(Flexible)へ移す — 狭幅で省略され(h)が再発する | exit 1
M164 | KILLED | lib/ui/file_list/file_list_view.dart | 008:T07 場所を日時と同じ行へ戻す — 場所が幅を使い切り日時が読めなくなる | exit 1
2 mutations: 2 KILLED, 0 SURVIVED, 0 SKIPPED
```

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

## Current state / handoff

- Last checkpoint: 行のlayout・preview基盤・行への組み込み・警告帯の高さまで実装し、範囲を行とpreviewへ確定した。`flutter test` = PASS(704) / `analyze` = PASS / `format` = PASS / mutation 2件 KILLED
- Blocker category: なし
- Waiting for: なし
- Requested action: なし
- Evidence revision: `asdd/008-ui-alignment/T07-row-and-warning-presentation`(PR #159)
- Next Agent action: `implementation` phaseの独立reviewを起動する。PASS後にcodeを凍結し、`manual-verification.md`をcurrent revisionへ合わせてdry-runしてから実機確認を依頼する
