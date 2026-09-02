# T18 行の結果表示を参考designへ揃える

## 目的

`T17`で承認された仕様どおり、**行だけを見て結果と原因が分かる**ようにする。変更後名を
正常・異常で色分けし、桁不足を該当行へ出し、変更が生じないときは`(変更なし)`を出す。
あわせて行のサブ情報の位置を参考designへ戻す。

## 入力と依存

- **`T17`で承認された 002 / 005 spec。承認前に着手しない**(`plan.md`の方針)。
- `docs/design/Bulk Renamer.html`。**適用する画面範囲は一覧の行に限る。**
  該当する土台は行の `newColor`(`bad ? '#f87171' : '#4ade80'`)、`oldColor` / `oldDeco`、
  `rowBg` / `cardBorder`、右寄せの `warnText`、`（変更なし）`。
- 現行実装: `lib/ui/file_list/row_preview_view.dart`、`lib/ui/file_list/row_view.dart`、
  `lib/ui/file_list/rename_warning_view.dart`、`lib/ui/file_list/file_list_controller.dart`。
- `T07`が決めた行の情報階層と、`T16`が行へ入れた警告表示。

## 変更範囲

観測の出所は[`T16`のtask.md](../T16-implement-row-level-warnings/task.md)の
「受領したUIの改善要望(2026-09-02、原文)」。番号は同節のもの。

- **要望7(色)**: 変更後名を、正常なら緑・警告対象なら赤にする。
- **要望7(桁不足)**: 桁があふれる行に、その行の警告として桁不足を出す。
  **判定は001のまま**で、行への割り当ては`T17`が定義した派生規則に従う。
- **要望1(`(変更なし)`)**: ルールが空のとき、および変更後名が現在名と同じとき、
  `.jpg`のような生成後名を出さずに`(変更なし)`を出す。**青などで強調しない。**
- **要望8(行の警告の位置)**: 開発者の原文は「各行のファイルは、リネーム後の名前の下の行では
  なく、リネーム前の名前と同じ行の右のスペースか、さらにその上に1行設けてそこに右寄せで
  表示する(参考design準拠)」。

  **原文の主語が一意に決まらなかったため、2026-09-02に開発者へ確認した。対象は「行の警告」
  である。** 確認は選択肢の提示で行っており、**開発者の自由記述は無い**。提示した3案は
  **(a) 行の警告 / (b) ファイルの場所 / (c) サブ情報全般(日時・サイズ)** で、開発者は
  **(a) を選んだ**。原文の「各行のファイルは」という語をどう読むかについての開発者の説明は
  受け取っていないので、**実装中にこの読みと合わない挙動が出たら、断定せずもう一度尋ねること。** 参考designも `warnText` を `margin-left:auto` の右寄せで上段(現在名と同じ行)へ
  置いており、`meta`(サイズ・日時)は下段のままなので、この読みが design と整合する。
  **サブ情報(サイズ・日時)は動かさない。ファイルの場所は`T08`が扱う(要望11)。**

  ```text
  現状                              このtaskが作る形
  [✓] [■] photo.jpg                 [✓] [■] photo.jpg      ⚠ 名前が重複
           → 100.png                         → 100.png
           ⚠ 名前が重複                      2026/08/12 · 1.2MB
           2026/08/12 · 1.2MB
  ```

### 他taskとの分担

**同じ行widgetを複数のtaskが触らない。** このtaskが行を持つ。

- `T19`は**詳細modalの中身**だけを持つ。行のどこを押すと開くかはこのtaskが決め、
  開いた先の中身は`T19`が決める。
- `T20`は**下部バー**(ルール設定buttonと実行button)だけを持つ。
- `T09`はmodeごとの描画を引き継ぐ。グリッド・コンパクトでの色と警告の出し方は`T09`が決める。
- 余白・字体・区切り線の濃さは`T10`。
- 行から**ファイルの場所**を外すこと(要望11)は`T08`が持つ。**要望8の対象は警告だと確定した
  ので、このtaskは場所を動かさない。** ただし警告を上段右へ移すと下段の並びが変わるため、
  **着手時に`T08`の状態を確認し、どちらが先かを`task.md`へ書くこと。**

## 引き受けた残余risk(`008:T16`から)

- **tap範囲の実機確認**: `T16`のmanual確認はAndroid **emulator**で行い、手順4の確認E
  (行の警告が「押しやすい」)だけは実機より弱い。開発者が2026-09-02にこの扱いを決めた。
  **行の警告のtap targetはこのtaskと`T19`で作り直すので、このtaskのmanual確認へ
  「行の警告が実機で押しやすい」を入れること。**

## 受け入れ証拠

- 正常な行の変更後名と、警告のある行の変更後名が**別の色**で描かれることをwidget testで検査する。
  **両方向**(警告あり↔なし)を固定する。
- 桁があふれる行**だけ**に桁不足が出て、あふれない行には出ないことを検査する。**両方向。**
- 空ルールと、変更後名が現在名と同じルールで`(変更なし)`が出ることを検査する。
  **強調色を使っていない**ことを含める。
- **狭幅(< 840dp)と広幅(≥ 840dp)の両方**で検査する。片方だけ通しても、もう片方の抜けは
  検出できない(`T07`のM166/M167、`T16`のM177と同じ型)。
- `tool/mutations.json`へ、**上の各要求が壊れたときに落ちる**mutationを足して`KILLED`を確認する。
  生の出力を報告へ貼る。
- 001の判定を変えていないこと(既存testの継続PASS)。**提示だけを変える。**
- `flutter test` / `flutter analyze` / `dart format --output=none --set-exit-if-changed .` がPASS。
- `manual-verification.md`でAndroid **実機**の狭幅表示を確認する。**tap範囲を含める**(上の残余risk)。
- exact rangeの独立reviewがPASSする。

## 作業記録

- 2026-09-02 / claim。`T17`が承認された 002 REQ-015 / 005 REQ-009 / REQ-029 を実装した。
  `flutter test` = **PASS(764)** / `flutter analyze` = PASS / `dart format` = PASS。
- 2026-09-02 / mutation 12件を`tool/mutations.json`へ追加(M204〜M215)。1回目は
  **M212・M213 が SURVIVED**。受容せず、testの空振りを直して**12件すべて KILLED** にした。

### 何を作ったか

| 要望 | 実装 |
|---|---|
| 7(桁不足を個々の行へ) | `file_list_controller.dart` が、**001 が桁不足を返しているときだけ**、選択順位から対象行を導出して`RowView.warnings`へ載せる。導出条件は `sequenceOverflowsAt`(`row_view.dart`) |
| 7(色) | 変更後名を、警告のある行は `danger`、無い行は `success`(参考designの `newColor: bad ? '#f87171' : '#4ade80'`) |
| 1(`（変更なし）`) | `rowHasNoChange` が真の行で、生成後名の代わりに `（変更なし）` を弱い色で出す。**空のルールの拡張子だけの名前(`.jpg`)を変更後名として出さない**(005 REQ-029) |
| 8(位置) | 行の警告を**現在名の上の行へ右寄せ**で移した |
| 5(文言の一部) | 基準日時不明の行ラベルを `作成日時不明` / `更新日時不明` と基準から導く。桁不足は `連番の桁不足` |

### 参考designから離れた点(`AGENTS.md`: 離れた理由を書く)

**警告を「現在名と同じ行の右」ではなく「現在名の上の行」へ置いた。**

開発者の原文は「リネーム前の名前と同じ行の右のスペース**か**、さらにその上に1行設けて
そこに右寄せで表示する」で、**どちらも指定されている**。参考designも両方の変種を持つ —
リッチ案は `warnText` を現在名と同じ行に `margin-left:auto` で、コンパクト案は上の行に
`text-align:right` で置いている。

**上の行を選んだのは、`T17`の改訂で行に出る種別が最大3つになったためである。**
重複・作成日時不明・連番の桁不足が併発すると `名前が重複・作成日時不明・連番の桁不足` に
なり、同じ行へ載せると狭幅では現在名か種別のどちらかが必ず切り詰められる。上の行なら
行幅を丸ごと使える。**行数は増えない** — 警告は元から変更後名の下で1行を占めていた。

一度「同じ行 + 幅の上限」で実装したが、上限の値を散文で正当化することになり、
`008:T16` が4回落ちた型に戻るため取りやめた。

### 判定を変えていない

001 の `validate` にも `autoResolve` にも触れていない。桁不足を行へ出すのは**提示側の導出**で、
**001 が返していないときはどの行にも出さない**(002 REQ-015 (a))。`preview_rows_test.dart` の
例19b と M206 がこれを固定する。

### 置き換えたtest

旧仕様(改訂前)を固定していた3件を、**緩めるのではなく新しい要求へ付け替えた**。

- `preview_rows_test.dart` 例19「桁不足はどの行データにも入らない」→ 例19 / 19a / 19b
  (超える行に入る / 収まる行に入らない / 001 が返さないなら入らない)と、
  未選択行が連番の位置を消費しないことの検査。
- `warning_display_test.dart`「桁不足はどの行にも出ない」→ 3件(超える行に出る /
  収まる行に出ない / 同じルールでも超える行だけに出る)。
- 同「同じ種別は行で 1 つにまとめる」→ 文言変更(`作成日時が空になります` →
  `作成日時不明`)へ追随。要求の強さは変えていない。

### mutation の生の出力

```console
$ python3 <asdd-plugin>/scripts/mutation_check.py tool/mutations.json --root .  # M204〜M215 を抽出した表
M204 | KILLED | lib/ui/file_list/row_view.dart | 桁不足の導出境界を1つずらす | exit 1
M205 | KILLED | lib/ui/file_list/file_list_controller.dart | 導出をやめて全選択行へ載せる | exit 1
M206 | KILLED | lib/ui/file_list/file_list_controller.dart | 桁不足を行データへ載せない | exit 1
M207 | KILLED | lib/ui/file_list/file_list_view.dart | 警告のある行も正常色にする | exit 1
M208 | KILLED | lib/ui/file_list/file_list_view.dart | 警告の無い行も危険色にする | exit 1
M209 | KILLED | lib/ui/file_list/file_list_view.dart | 空のルールで拡張子だけの名前を出す | exit 1
M210 | KILLED | lib/ui/file_list/file_list_view.dart | 生成後名が現在名と同じ行で変更なしを出さない | exit 1
M211 | KILLED | lib/ui/file_list/file_list_view.dart | 空名で改名されない行を変更ありとして扱う | exit 1
M212 | KILLED | lib/ui/file_list/file_list_view.dart | 未選択行まで変更なしにする | exit 1
M213 | KILLED | lib/ui/file_list/rename_warning_view.dart | 行の警告の右寄せをやめる | exit 1
M214 | KILLED | lib/ui/file_list/rename_warning_view.dart | どの基準が取れないかを行から落とす | exit 1
M215 | KILLED | lib/ui/file_list/rename_warning_view.dart | 桁不足の種別名を落とす | exit 1
12 mutations: 12 KILLED, 0 SURVIVED, 0 SKIPPED
```

**1回目は M212 と M213 が SURVIVED した。受容せず、testの空振りを直して閉じた。**

- **M212**: 未選択行の分岐は、widget が `newName == null` を先に見て `—` を出すので
  **widget test では踏めない**。判定 `rowHasNoChange` を直接呼ぶ unit test を足した。
- **M213**: 右寄せを、**当たり判定の箱**(`rowWarningKey` の `InkWell`)で測っていた。
  箱は行幅いっぱいに広がるので、左寄せへ変えても箱の右端は動かない。**文字そのものの
  位置**を測る形へ直し、左端が行の左端より右にあることも足した。

### `T08` との順序(着手時に確認した)

`T08` は `pending` で未着手である(2026-09-02 時点)。要望8の対象は**行の警告**だと開発者が
確定しているので、**このtaskは行の場所(元フォルダ)を動かしていない**。場所を消すか
folder名だけにするかは `T08` が決める。**`T08` が後に着手するので、`T08` がこの行の形に
合わせる。**

### このtaskが満たしていないもの(引き受け先つき)

- **005 REQ-009 (4)**(ファイルごとの入口からはそのファイルの警告)。**行の警告を押すと
  いまも全件の詳細が開く。** 入れ物を作り直すのは `T19` の範囲なので、このtaskは
  「どこを押すと開くか」までを持つ。**引き受け先: `008:T19`。** このtaskは (4) を
  悪化させていない — `T16` から振る舞いは変わっていない。

## Current state / handoff

- Last checkpoint: 実装と検査が済んだ。`dart format` = PASS / `flutter analyze` = PASS / `flutter test` = **PASS(764)** / `mutation_check.py` M204〜M215 = **12件すべて KILLED, 0 SURVIVED, 0 SKIPPED** / `workspace.py check specs` = PASS
- Blocker category: **人間のmanual確認待ち**
- Waiting for: Android **実機**での手動確認(下の Requested action)
- Requested action: 開発者へ[`manual-verification.md`](manual-verification.md)の4項目を依頼する。10〜15分。**手順3(行の警告が押しやすい)は実機でしか見られない** — `008:T16`がemulatorでしか確かめられなかったtap範囲を、このtaskが引き受けている
- Evidence revision: branch `asdd/008-ui-alignment/T18-row-result-presentation`
- Next Agent action: manual結果を受け取り、`task.md`へ対象commitつきで記録してから最終証拠reviewを起動する
