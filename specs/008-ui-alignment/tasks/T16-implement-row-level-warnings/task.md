# T16 警告を行に出す提示を実装する

## 目的

`T15`で承認された仕様どおり、警告を各行へ出し、集約帯を置き換える。

## 入力と依存

- **`T15`で承認された 002 / 005 spec。** 承認前に着手しない(`plan.md`の方針)。
- `docs/design/Bulk Renamer.html` の行の`warnText` / `rowBg` / `cardBorder` と、
  ヘッダの`warnLabel`。**適用する画面範囲は一覧の行、ヘッダの警告表示、そして下部バーの
  警告の提示ぶんである。** 下部バーは`005:T09`の成果なので、**実行buttonの振る舞い・ルール
  設定sheetの開き方・バーの構成そのものは動かさない**(下記「下部バーの所有」)。
- 現行実装: `lib/ui/file_list/rename_warning_view.dart`(集約帯と文言生成)、
  `lib/ui/file_list/row_view.dart`(行データ)、`lib/ui/file_list/file_list_controller.dart`。
- `T07`が入れた行のlayout。**行は既に現在名・変更後名・サブ情報を縦に積んでいる**ので、
  警告はその構造の上に載る。`T07`の情報階層を壊さないこと。

## 変更範囲

- 行データが警告を持つ(`RowView`)。
- 行の警告表示(短い一文、行の色・枠)。
- 集約帯の置き換え(ヘッダの件数と、詳細のトグルまたはmodal)。

  **`T07`から引き受けた残余risk N-9**: 現行の帯は高さの上限を**画面**の割合で決めているが、
  帯は一覧の上に載るので、header・barを引いた**一覧の取り分**に対しては割合が跳ね上がる。
  2026-08-29のAndroid emulator確認で、開いた帯が**一覧の見える範囲の半分以上**を覆った。
  **`T15`が帯の廃止を決めたので、この論点そのものは消える。** ただし置換先(ヘッダーの件数と
  modal)が**一覧を覆わない**ことは、このtaskが確かめること — 常時の占有が0になるのが
  廃止の狙いである。
- `describeWarning`が作る文面の整理。**実行前確認dialog(`T14`が持つ)が使っている文面**を
  壊さないこと。分担は`T14`と突き合わせる。
- 置き換えた検証(下記)。

### `T14`との分担

`T14`は**実行前確認dialog**(`file_list_view.dart`の`Key('rename-confirmation-dialog')`)を持つ。このtaskが
作るのは**警告の詳細を見る**ための提示である。**同じmodalに二つのtaskが手を入れない**よう、
着手時にどちらが入れ物を持つかを決めて両方の`task.md`へ書く。

### `T09`との関係

`T09`はmodeごとの描画を持つ。**リッチ案は`T07`の行をそのまま使う**と決めてあるので、
このtaskが行へ足す警告表示も`T09`が引き継ぐ。グリッド・コンパクトで警告をどう出すかは
`T09`が決める。

### 提示の場所はこのtaskが決める(`T15` revision 8.0)

**005 も 002 も配置を「自由とする点」へ置いている。** `T15`が課すのは場所ではなく
**利用者から何が読めるか**である。どの部品のどこに置くかは**このtaskの裁量**で、
参考designと`T15`の設計指針を土台にする。

**必ず確かめること — 幅で分岐する。** `RuleBuilderWorkspace`は幅 840dp で分かれ、
**wide では`onEditRule`を渡さない**(`rule_builder_workspace.dart`の`_buildWide`)。
`FileListView`の`_RuleButton`は生成されず、**下部バーにルール設定の導線が無い。**
wide のルール編集は右ペインの`RuleBuilderView`である。**narrow だけを見て実装すると、
wide で原因の提示が行き場を失う**(`T15`の独立review attempt 3 が見つけた)。
**このplanは同じ型の誤りを一度直している** — 「Androidでは必ずsheet越し」は platform では
なく幅で決まる。**両方のlayoutをwidget testで通すこと。**

下部バーへ載せる場合、実行buttonの振る舞い・ルール設定sheetの開き方・バーの構成そのものは
動かさない(`005:T09`の成果)。余白・typographyは`T10`、modalの文言は`T14`。

## 受け入れ証拠

- 行に警告が出て、どのファイルが何の理由かを行から読み取れることをwidget testで検査する。
- **すべての種別が併発しても行の警告が2行に収まる**ことを、幅を指定したwidget testで
  検査する(`T15`が要求に入れた場合)。
- 詳細(トグルまたはmodal)で全件と説明が読めることをwidget testで検査する。
- **置き換えたtestが、元の要求を同じ強さで押さえている**ことを示す。
  `warning_display_test.dart` / `empty_rule_test.dart` の該当箇所は**緩めるのではなく
  付け替える** — 005 REQ-009 の「対象fileとトークンが特定できる」を、新しい提示に対して
  検査する。
- 001の判定を変えていないこと(既存testの継続PASS)。**提示だけを変える。**
- **空ルールのとき、行にも警告が出ない**ことを検査する(005 REQ-020)。**廃止するwidgetのkeyに
  依存しない形で書くこと** — 現行の`empty_rule_test.dart`は`renameWarningsKey`の不在で
  REQ-020を押さえており、帯を消すと**widgetが無いから通る**状態になる(`T15`の独立reviewが
  安全網の穴 N-15-1 として挙げ、このtaskを引き受け先に指定した)。002 REQ-015は「空ルールなら
  供給しない」とは書いていないので、行へ出す実装が空ルールでも出す穴が開きうる。
- **`[元名][日時 作成]`で作成日時が不明なとき**(名前は空にならない)、005の例20g/20hのとおり
  **30件それぞれで種別が読め、トークンの説明は1つ**であることを検査する。
- **狭幅(< 840dp)と広幅(≥ 840dp)の両方**で、005 REQ-009 の3つを満たすことをwidget testで
  検査する。**片方だけ通しても、もう片方の抜けは検出できない**(`008:T07`のM166/M167と同じ型)。
- **`sortMode`を名前順にしても**、`[元名][日時 作成]`の行から基準日時不明の種別が読めることを
  検査する(002 REQ-013)。**REQ-013 が `sortMode` でゲートしているのは日時表示そのものの強調**で
  あり、ルール文脈の警告はゲートの対象外である。真似てゲートすると REQ-009 (1) が破れるが、
  既存testでは検出されない(`T15`の独立reviewが安全網の穴 N-15-2 として挙げ、このtaskを
  引き受け先に指定した)。
- `tool/mutations.json`へ、**005 REQ-009 (1) の状態から警告の種別が読めなくなる**mutationを足して`KILLED`を確認する。**配置に依存しない言い方で書くこと** — 8.0 では場所は自由である。
- `flutter test` / `flutter analyze` / `dart format --output=none --set-exit-if-changed .` がPASS。
- [`manual-verification.md`](manual-verification.md)でAndroid実機の狭幅表示を確認する。
  **件数の多い状態**(重複が数十件)を含める。
- exact rangeの独立reviewがPASSする。

## 作業記録

- 2026-08-27 / `T07`から分離して定義。`T07`は行のlayoutとpreviewで閉じる。
- 2026-08-29 / claim。集約帯(`RenameWarningPanel`)を廃止し、005 revision 8.0 の3つを満たす提示へ置き換えた。`flutter test` = PASS(731)、`analyze` = PASS、`format` = PASS。
- 2026-08-29 / mutation 7件を`tool/mutations.json`へ追加(M173〜M179)。`mutation_check.py` = **7 KILLED, 0 SURVIVED**。生の出力は下記。
- 2026-08-29 / 独立review attempt 1 = **FAIL**(P1-1: ヘッダの文言が切り詰められる退行)。P2×8とあわせて修正し、reviewが足したmutation 6件を取り込んだ。`mutation_check.py` = **14 KILLED, 0 SURVIVED**。

### 独立review

- Review attempt 1: `dev...e9241da` — **FAIL** — P1-1(狭幅でヘッダの文言が切り詰められる退行)、P2×8。すべて対処済み。

**P1-1 は私が入れた退行である。** `_HeaderBar` へ `Flexible + Spacer + Flexible` を並べた
ため Row の余白が3等分され、**どちらの文言も intrinsic 幅を取れずに切り詰められた**。
360dpで200件だと `200 / 2…`、411dpで `200 / 20…` と出て、**総数を20と誤読できる**。
`dev` では flex child が無く intrinsic 幅で全文が出ていたので、このdiffが入れた退行である。
文字サイズ最大の N-8b(`T10`引き受け)とは別物で、**通常のfont sizeで起きる。**

**私が書いた「はみ出さない」testでは検出できなかった。** `Flexible` + ellipsis は
**内容を切ることで overflow を出さない**ので、`RenderFlex overflow` を見る検査では
原理的に落ちない。`didExceedMaxLines` で切り詰めそのものを見る形へ差し替えた。
**M186 がこの退行を殺す。**

その他: P2-3/P2-4(併発時の2行・行の種別の重複排除がtestで固定されていない)→ testを足して
M180/M181で殺した / P2-5(空ルールtestの説明側assertionが空振り)→ 導線がある状態で
pumpするよう直した / P2-8 `describeWarningSummary`が帯の廃止でdead codeになっていたので
削除 / P2-9 `preview`のdocが「build 1 回につき1回」と書いていたが広幅では2回走るので
実態へ直した / P2-10 ルールが空のときヘッダが「問題なし」と出ていたので**出さない**
ようにした(001は空名と重複を返しているので誤りになる) / P2-6・P2-7 記録の追随。

**独立reviewが足したmutationは6件すべて取り込んだ**(M180〜M185)。equivalent mutantと
判定された1件(ルールが空のとき原因の説明を出す)は取り込んでいない — ルールが空なら
トークンが無く、桁不足も基準日時不明も生じないため、説明は常に空である。

### 選んだ置き場所(要求ではない)

**005 revision 8.0 は場所を課さない。** 下は`T15`の設計指針と参考designに沿って
このtaskが決めたものである。

| 005 REQ-009 | 何を | どこへ |
|---|---|---|
| (1) 種別が一覧を見た状態で分かる | 短い一文(`RowWarningView`) | **行**の変更後名のすぐ下 |
| (2) 変わらない説明を件数ぶん繰り返さない | 原因の説明(`RuleWarningNotice`) | **ルールを変更する操作のそば**。狭幅=下部バーの直前、広幅=右ペインの上 |
| (3) 全件と説明を読める | 種別ごとにまとめたdialog | **ヘッダの件数**と**行の警告**の両方から開く |

**広幅と狭幅で導線が違う。** `RuleBuilderWorkspace`は幅 840dp で分かれ、広幅では
`onEditRule`を渡さないので**下部バーにルール設定の導線が無い**。広幅のルール編集は
右ペインの`RuleBuilderView`なので、そちらへ同じ`RuleWarningNotice`を描いた。
**片方だけ描くと、もう片方のlayoutで説明が行き場を失う**(M177がこれを殺す)。

### 判定を変えていない

001 の`validate`にも`autoResolve`にも触れていない。`presentWarnings`と
`describeWarning`はそのままで、**実行前確認dialog(`T14`が持つ)は同じ提示単位を
使い続ける**。行に出さない重複(REQ-021 規則2)も判定からは消さず、詳細には出す。

### 行データが警告を持つ(002 REQ-015)

`RowView.warnings`を足し、`warningTargetOf`が`null`を返す警告(連番の桁不足)は
載せない。`rows`と`warnings`は同じ検証から作れるので`preview`へまとめた
(別々に呼ぶと 001 の検証が2回走る)。

### mutation の生の出力

```text
command: flutter test
ID | STATUS | FILE | NOTE | DETAIL
--- | --- | --- | --- | ---
M173 | KILLED | lib/ui/file_list/rename_warning_view.dart | 行から警告の種別が読めなくなる | exit 1
M174 | KILLED | lib/ui/file_list/rename_warning_view.dart | ルールが空でも行へ警告を出す(REQ-020) | exit 1
M175 | KILLED | lib/ui/file_list/rename_warning_view.dart | 原因の説明を件数ぶん繰り返す(REQ-009 (2)) | exit 1
M176 | KILLED | lib/ui/file_list/rename_warning_view.dart | 空名の行にも重複を出す(REQ-021 規則2) | exit 1
M177 | KILLED | lib/ui/rule_builder/rule_builder_workspace.dart | 広幅で原因の説明を配り忘れる | exit 1
M178 | KILLED | lib/ui/file_list/file_list_view.dart | 行の警告を sortMode でゲートする(N-15-2) | exit 1
M179 | KILLED | lib/ui/file_list/file_list_view.dart | 行の警告から詳細を開けなくする(対照) | exit 1
M180 | KILLED | lib/ui/file_list/rename_warning_view.dart | 行の警告を1行へ切り詰める(独立reviewが追加) | exit 1
M181 | KILLED | lib/ui/file_list/rename_warning_view.dart | 行で同じ種別を件数ぶん繰り返す(独立reviewが追加) | exit 1
M182 | KILLED | lib/ui/file_list/rename_warning_view.dart | 件数を提示単位でなく生の件数で数える(独立reviewが追加) | exit 1
M183 | KILLED | lib/ui/file_list/file_list_view.dart | 狭幅で原因の説明を配り忘れる(独立reviewが追加) | exit 1
M184 | KILLED | lib/ui/file_list/file_list_controller.dart | 桁不足を全行へ載せる(独立reviewが追加) | exit 1
M185 | KILLED | lib/ui/file_list/file_list_controller.dart | 行の警告を別インスタンスで引き当てる(独立reviewが追加) | exit 1
M186 | KILLED | lib/ui/file_list/file_list_view.dart | ヘッダの余白を等分して文言を切り詰める(独立reviewが見つけたP1) | exit 1
14 mutations: 14 KILLED, 0 SURVIVED, 0 SKIPPED
```

**引き受けた安全網の穴は両方とも殺した。** N-15-1 は M174、N-15-2 は M178 である。
受容ではなく検査で閉じた。

### 置き換えたtest

| 元 | どう付け替えたか |
|---|---|
| `warning_display_test.dart` 帯の`Text`の数が`警告件数 + 1` | **提示単位の数を数えるのをやめた**(帯が無い)。REQ-009 の3つへ組み替え、種別が行から読めること・説明が1つであること・詳細に全件あることを検査する |
| 同 `作成日時が不明`が2件ぶん | 行では**種別**が2行に出て、**説明はまとまりに1つ**であることへ付け替えた(繰り返しが消えたことが要求になった) |
| `empty_rule_test.dart` 1行の`Text.data`が結果と原因の両方を含む | **行は結果だけ**・**詳細に結果と原因がまとまって1件**、へ分けた |
| 同 REQ-020 を`renameWarningsKey`の不在で押さえる | **廃止するkeyに依存しない形**へ(行の警告の不在・説明の不在・「問題なし」)。M174が殺す |
| `row_presentation_test.dart` 帯の高さ(T07の(i)) | 帯が無くなったので、**件数が増えても一覧の取り分が変わらない**ことへ置き換えた(N-9 がここで閉じる) |

## Current state / handoff

- Last checkpoint: 独立review attempt 1 の**P1-1とP2×8を修正**。`flutter test` = PASS(734) / `analyze` = PASS / `format` = PASS / **mutation 14件すべて KILLED**
- Blocker category: なし
- Waiting for: 独立review attempt 2
- Requested action: なし
- Evidence revision: `asdd/008-ui-alignment/T16-implement-row-level-warnings`(PR #161、Draft)
- Next Agent action: 独立reviewを再度起動する。PASS後に`manual-verification.md`をcurrent revisionへ合わせてdry-runし、Android実機の狭幅表示(**件数の多い状態**を含む)を依頼する
