# T10 余白・階層・typographyを揃える

## 目的

参考designの(d)にあたる最終の追い込み。個々の画面ではなく、**app全体で余白と文字の階層が一貫している**状態にする。

## 入力と依存

- `specs/history/asdd-0.x-discovery.md`の(d)「全体の余白・階層・タイポグラフィ」。
- 参考design `docs/design/Bulk Renamer.html`。
- 現行実装: `lib/ui/theme/app_theme.dart`、`lib/ui/theme/app_colors.dart`(`AppColors` ThemeExtension)。
- **008の他の実装task(T02/T04/T06/T07/T08/T18/T19/T20)すべて。**(`T09`(表示モード)は2026-09-30に削除した — 一覧はリッチの行だけにした) 構造が動いている間に余白だけ整えても作り直しになる。**T18/T19/T20は2026-09-02に追加した** — 要望10(区切り線)が触る行は`T18`が、要望13(上部見出し)と隣接する下部バーは`T20`が作り直すため。

## 変更範囲

- 余白・文字sizeの値をthemeへ寄せ、画面側の直書きを減らす。
- 見出し・本文・補助情報のtypography階層。
- 上記に伴う各画面の調整。

**振る舞いは変えない。** 文言、判定、状態遷移、操作の意味はこのtaskで触らない。触りたくなったら別taskへ送る。

### 2026-09-02に受領した改善要望(10・13)

観測の出所は[`T16`のtask.md](../T16-implement-row-level-warnings/task.md)の
「受領したUIの改善要望(2026-09-02、原文)」。**このtaskが引き受ける。**

- **要望10**: 「行の区切り線がやや薄いので、もう少しだけ濃くしても良いかも。」
  参考designの行は `border-bottom:1px solid rgba(255,255,255,.05)`(コンパクト案は `.04`)。
- **要望13**: 「上部の『一括リネーム』という見出しが幅を取っているので、小さくしてフォントを
  変えるか、削除するなどしてスペースを確保してもよさそう。」参考designは
  `font:700 28px/1.25` の `h1` と補足の `p` を持つ。**見出しを消すか縮めるかはこのtaskの裁量**で、
  一覧の取り分がどれだけ増えるかを根拠にする。

**どちらも余白・字体の取り分の問題なので、他の実装taskが構造を確定させてから着手する**
(上の「入力と依存」の原則)。

### 引き受けた残余risk(`008:T23`から。2026-09-18)

- **幅 90dp では読み込み帯の button 群だけで overflow する。** 場所の有無に関わらず一様に出るので
  `T23` の省略とは無関係で、`T08`/`T23` が宣言した検証範囲(320/360/411dp)の外である。
  90dp の端末は実在せず、安全網の穴の条件(1)「製品経路に載っている」に当たらないため**受容した**。
  余白と最小幅を見直すときに、下限をどこに置くかを決める材料として残す(独立review attempt 1 の #2)。

### 引き受けた残余risk(`008:T08`から。2026-09-18)

- **読み込み帯と一覧を同じ画面へ組んだwidget testが無い。** 帯(`locationLabelOf`)と行
  (`showRowLocation`)は「場所が何種類か」を**別々の式**で数えており、どちらも
  `FileListController` の同じ `_items` を1:1で見るので**現状は構造的に分岐しえない**
  (独立review attempt 2 がコードで確認した)。ただし両者を同時に組んだ検査は無く、
  `ui_entry_test.dart` の合成経路は場所を持たないデータしか通していない。
  3条件のうち(2)(データ損失・無断置換・偽の成功・権限逸脱・互換性破壊)に当たらないため
  **受容**した。**このtaskがbarと一覧を並べたwidget testを足すときに拾う**(余白の検査で
  同じ合成が要るため、ここが最も安い)。
- **「すべて外す」の置き場所**は `008:T04` が持つ(2026-09-18 の開発者判断で読み込み帯のままとし、
  見直しを `T04` へ送った)。**このtaskは余白と階層だけを見る。**

### 引き受けた残余risk(`008:T07`から)

- **N-8b**: ~~`textScaler` 3.0で一覧の`_HeaderBar`の`Row`が**水平に約69px** overflowする~~
  → **2026-08-31、`008:T16`が閉じた。**`_HeaderBar`を`Row`から`Wrap`へ変えたので、入らない
  ときは切らずに次の行へ落ちる。probe(320/360/411dp × `textScaler` 1.0/1.3/2.0/3.0 ×
  1/30/200/1000件)で**overflowは0件**。`T16`のtestが 1.0/1.3/2.0 で切り詰めの不在
  (`didExceedMaxLines`)を押さえ、mutation M186(`Wrap`→`Row`)がこれを殺す。
  sort barの側(N-8a)は`T02`が引き受けたままである。

- **N-8b′(残余)**: `textScaler` **3.0**では、320dpの200件以上と360dpの1000件で、
  2行に落としてもなお末尾が切れる(`200 / 200 件を選` / `200 件の`)。**数字は常に残る**
  ので総数を誤読することは無く、消えるのは`選択`・`問題`のような語尾である。
  probeで確認した実際の見え方は`008:T16`の`task.md`にある。ここは余白・typographyの
  取り分の問題なので、このtaskが引き受ける。CIで押さえるtestは無い。

- **N-8b″(残余)**: `textScaler` **3.0** では、`008:T16`が参考designの形へ作り直した
  ルール設定button(2行 + 種別)が **320×640dpで261px**(画面の41%)を占め、一覧の
  取り分が **25px** まで縮む(360×640dpでは70px)。**overflowは出ず、数字も種別も
  読める**ので誤読は生じないが、実用にならない。`dev`の同条件は button 60px /
  一覧 124px だった。`T16`は検証範囲を`textScaler` 1.0/1.3/2.0 と宣言しており、
  2.0までは一覧が200px以上残る(独立review attempt 4 のprobeで確認)。3.0の
  取り分はこのtaskが引き受ける。CIで押さえるtestは無い。

  **この「overflowは出ず」は画面高が十分あるときの話である。**`008:T16`の独立review
  attempt 6 が、`textScaler` 3.0 かつ**画面高 ≤ 400dp**(600×360、600×400など)では
  `dev`に無かったoverflowが出ることを観測した。Androidのfont scale上限は2.0なので
  実機では到達しないが、記述としてはここまでが範囲である。
  **切り詰めも選択件数だけではない** — 3.0では件数label(`N 件の問題`)の語尾と、
  320dpでは行の`名前が空・改名されません`の後半(005 例20の(ii))も切れる。

## 他taskから引き受けた残余risk

**受容したのは各taskの所有Agentで、このtaskは引き受け先として記録するだけである。**
着手時にこの表を読み、扱いを決めること。**このtaskが余白・字体・階層・色を決め直すので、
下はいずれもその判断の中で自然に閉じられる。**

| 出所 | risk | 対照 |
|---|---|---|
| `008:T18`(独立review attempt 1) | **行の高さを縛る assertion が無い。** 行の警告の余白を大きく増やしても、現在名の行数上限を外しても全testがPASSのまま通る | **M220 / M221**(SURVIVEDのまま`tool/mutations.json`に残っている) |
| `008:T18`(同) | **穴A: 行の警告の濃さに下限が無い。** `rowWarningLabelOpacity` を `0.78 → 0.06` にしても通る。testが置いているのは相対条件(変更後名より薄い / 色相が `danger`)だけ | **M225**(同) |
| `008:T18`(同) | **穴B: 「押せると分かる形」の検査が構造だけ。** 枠を完全に透明にしても、塗りが `0.001` でも通る。testは `border != null` / `borderRadius != null` / `0 < fill.a < 1` しか見ない | **M226**(同) |
| `008:T18`(独立review attempt 4) | **行の警告に文字倍率の被覆が無い。** `textScaler` を上げると (i) アイコンと文字の字面の中心の差が開き(実測 gap = 1.18 / 2.37 / 4.30 / 6.91px @ 1.0 / 1.3 / 2.0 / 3.0)、(ii) 幅320dpで種別3つ併発のとき**倍率 1.3 から警告文が切り詰められる**。`rowWarningIconInkNudge` の比例先 `rowWarningFontSize` が定数で、`Icon` も `applyTextScaling` が既定 false であることが原因。**`T18`手順2′の確認C(フォントサイズ最大)は開発者の回答が無いまま`T18`から移管された。閉じるのはこのtaskである** | 対照は無い。`row_presentation_test.dart` の `TextScaler.linear` が前例 |
| `008:T47`(独立review attempt 5) | **フッターのチップのフェードの下限(`ruleChipFadeMinWidth` = 24)に満たないとき1つ手前をフェードにする分岐と、下限そのものを直接検査する test が無い。** 分岐は M199・M241・M588・M589・M593〜M595 と「フェードがちょうど1つ」「フェードが列の右端まで届く」の test が間接に守る | 対照は無い。下限の値を見直すときに test を足す |

**3条件の判定と受容の根拠は出所側のtask.mdにある** — [`T18`のtask.md](../T18-row-result-presentation/task.md)の
「引き受けた残余risk」の各節。**ここへ複製しない。**

## 受け入れ証拠

- 既存のwidget testがすべて継続PASSする(振る舞いを変えていないことの主な証拠)。
- 余白・文字sizeの直書きがthemeへ寄っていることをdiffで示す。
- 狭幅で情報が読めることを検査するT07のtestが継続PASSする。
- `flutter test` / `flutter analyze` / `dart format --output=none --set-exit-if-changed .` がPASS。
- [`manual-verification.md`](manual-verification.md)でAndroid実機とWindows desktopの主要画面を確認する。
- exact rangeの独立reviewがPASSする。

## 作業記録

- 2026-08-13 / 人間の判断で(a)〜(d)を008の対象へ入れた際に定義。
- 2026-10-01 / 着手(開発者の指示「008:T10に進んでください」)。依存 T02/T04/T06/T07/T08/T18/T19/T20 はすべて done。branch `asdd/008-ui-alignment/T10-spacing-and-typography`、worktree `/workspace/.worktrees/008-T10-spacing-and-typography`、起点 `dev`@`72ca7ef`。`008:T47` が引き受け先にした残余risk(フェードの下限)を上の表へ足した。

### 着手時の棚卸し(2026-10-01、`72ca7ef`)

- 文字の大きさの直書きは `lib/ui` に `fontSize:` 60箇所、値は 9 / 10 / 10.5 / 11 / 11.5 / 12 / 12.5 / 13 / 14 / 15 の10種類。参考designも 10 / 10.5 / 11 / 11.5 / 12 / 12.5 … を使い分けているので、**値は変えずに役割の名前を付けて theme へ寄せる**(見た目は変えない)。値をまとめる(例: 10.5 → 11)のは見た目の変更なので、このtaskではしない。
- 上部の見出し(要望13)は `lib/main.dart` の既定の `AppBar`(高さ 56)。Android では歯車(`008:T43`)が出ないので、見出しだけが 56 を占めている。
- 行の区切り線(要望10)は他の枠と同じ `colors.border`(白 8%)を共有している。

### 開発者の決定(2026-10-01): 文字の大きさの揃え方

- Agent が3案を出した: (A) 値を変えず名前だけ付けて theme へ寄せる(推奨)/ (B) 近い値を寄せて5〜6段にまとめる / (C) 今回は寄せない。
- **開発者は (A) を選んだ。** 見た目は変わらないので、checkpoint 2 の主な証拠は既存の widget test の継続PASSである。plan の「人間の決定」にも記録した。

### 進め方(checkpoint)

1. **見た目の変更(要望13・要望10)** — 見出しを縮める、行の区切り線だけを少し濃くする。test と実機確認1回目。
2. **typography と余白を theme へ寄せる** — 値を変えずに名前を付け、画面側の直書きを置き換える(見た目は変わらない。既存の widget test の継続PASSが主な証拠)。
3. **引き受けた残余risk** — 行の高さ・警告の濃さ・押せる形の下限、行の警告の文字倍率、帯と一覧を組んだ test、フェードの下限。closeする / 受容し直すを1件ずつ記録する。文字 3.0 の項目(N-8b′・N-8b″)は Android の上限が 2.0 なので、製品経路の外として扱いを記録する。
4. 独立review → 実機確認(Android)。Windows desktop の確認は host 側の人間に依頼する。

### checkpoint 1: 見出しと行の区切り線(`c4748a7`)

- 要望13: 見出しの帯を既定の高さ 56 → `appBarHeight`(44)、文字 22 → `appBarTitleFontSize`(16)。theme の `appBarTheme` に置いた。見出しは消さない(デスクトップでは歯車 `008:T43` が載る)。
- 要望10: 行の区切り線だけを専用の色 `rowDivider`(白 12%)にした。他の境界線(`border`、白 8%)は変えない。
- test: `test/widget_test.dart`「上部の見出しは低く小さい」「一覧の行の区切り線は他の境界線より少し濃い」。mutation M598〜M601 を追加、範囲付き(`flutter test test/widget_test.dart test/spec_002_file_list`)で `4 mutations: 4 KILLED, 0 SURVIVED, 0 SKIPPED`。

### checkpoint 2: 文字の大きさを theme へ(`3a8cf7d`)

- `lib/ui/theme/app_typography.dart` の `AppFontSize`(micro 9 / tiny 10 / caption 10.5 / small 11 / label 11.5 / bodySmall 12 / body 12.5 / bodyLarge 13 / title 14 / titleLarge 15 / heading 16)。`lib/ui` の `fontSize:` の直書き 59 箇所を置き換えた。値は変えていない(diff の非 `fontSize` 行は formatter の折り返しだけであることを確かめた)。
- test: `test/theme/typography_literals_test.dart`(直書きが戻らない・段の値を保つ)。
- **余白(`EdgeInsets` 68 箇所)は寄せなかった。** 値の多くは部品ごとに固有で、共有されている値(行・帯の左右 12 など)は既に名前付きの定数になっている。名前だけ付け替えても揃いは変わらないので、文字の大きさの決定(値を変えない)の範囲で効果が無いと判断した。

### checkpoint 3: 引き受けた残余risk(`07b7410`)

| 出所 | risk | 扱い |
|---|---|---|
| `008:T18` | 行の高さを縛る assertion が無い(M220 / M221) | **閉じた。** 「警告の箱は文字 + 上下 4 + 枠の高さ」「長い現在名で行が伸びない」の test。M220・M221 KILLED |
| `008:T18` | 穴A: 警告の濃さの下限(M225) | **閉じた。** 文字 ≥ 0.6(参考design .7、manual で見た 0.78)。M225 KILLED |
| `008:T18` | 穴B: 押せる形の検査が構造だけ(M226) | **閉じた。** 枠 ≥ 0.3・塗り ≥ 0.06。M226 KILLED |
| `008:T18` | 行の警告に文字倍率の被覆が無い(アイコンのずれ・切り詰め)。確認C 未回答 | **直して閉じた。** アイコンと補正量を `textScaler` で拡大(M604)。2 行では倍率 2.0 の 320・360dp で切り詰められた(2026-10-01 の測定。T18 当時の「1.3 から」は以後の変更で 2.0 へ移っていた)ので 3 行まで許した(M605、M180 の find 追随)。test は 320/360/411 × 1.0/1.3/2.0。実機の字体での揃いは manual 3 |
| `008:T08` | 帯と一覧を組んだ widget test が無い | **閉じた。** `load_affordance_test`「帯と一覧を同じ画面に組んでも、場所の出し分けが食い違わない」(場所 0 / 1 / 2 種類) |
| `008:T47` | フェードの下限の分岐を直接検査する test が無い | **閉じた。** 幅×数の loop で「フェードは下限より狭くならない」。M602・M603 KILLED |
| `008:T23` | 幅 90dp で読み込み帯が overflow | **受容のまま。** 検証範囲の下限を 320dp とする(Android の一般的な最小幅)。90dp の端末は実在しない |
| `008:T07`/`T16` | N-8b′・N-8b″(文字 3.0 での語尾の切り詰め・一覧の取り分) | **受容のまま。製品経路の外。** Android の上限は 2.0、Windows の文字サイズの上限は 225%(2.25)で、3.0 には届かない |
| (新規・2026-10-01 の測定) | 文字 2.0 の低い画面で一覧が狭い: 360×640 で一覧 113px(フッター 242px)、320×640 で 62px。高さ 800 前後なら約 270px。overflow・切り詰めは無い | **開発者の決定で受容した**(2026-10-01。3案 受容 / 文字が大きいときフッターを詰める / フッターの文字拡大に上限 のうち受容)。manual 4 で見え方を見る |
| `008:T20`・`T06`・`T28` | 余白・字体・アイコンの妥当性、長押しの範囲など見た目の判断 | manual 1〜4 で見る範囲に含めた。個別に足す変更は無い |

- 範囲付き mutation(`flutter test test/spec_005_rename_exec test/spec_002_file_list test/spec_004_file_source test/widget_test.dart test/theme`、対象 `07b7410`、9件):

```text
M180 M220 M221 M225 M226 M602 M603 M604 M605 すべて KILLED
9 mutations: 9 KILLED, 0 SURVIVED, 0 SKIPPED
```
- 検証(`07b7410`): `flutter test` +1133 PASS、`flutter analyze` No issues、`dart format` 0 changed、`check_mutation_finds.py` 554 PASS。

### manual

- `manual-verification.md` を1回目の手順にした(Android: 見出し・区切り線・文字最大での行の警告・文字最大での全体。Windows desktop: 広い窓・狭い窓・テキストのサイズ 225% で同じ点と歯車)。画面の文言(「一括リネーム」「命名ルールを設定する」「＋ 自由テキスト」)は current revision と `git grep` で照合した。

### 独立review

reviewerは`gpt-6-luna`(開発者指定。AGENTS.md の既定「実装より一段軽い」に代えて従った)。

- **attempt 1**: `72ca7ef..78438ba`(全範囲) — **FAIL**(P1 1件)。確認された点: 見出し・区切り線・文字の大きさの置き換え(値を保つ)、行の警告の拡大と `maxLines: 3` が 005 REQ-009 / REQ-021・002 の行の趣旨を損なわない、行の高さの test が警告の箱と行の箱を実際に測っている、M220/M221/M602/M603 KILLED、受容の根拠が出所を参照している、manual の文言が current revision と一致。`flutter test` 1133 PASS・analyze・format PASS。
  - **P1(成果物の欠陥)**: 受け入れ証拠は Windows desktop の確認も求めているのに、Agent が開発者の判断なしに Android で代えると記録していた → **Agent が受け入れ条件を自分で緩めたもので誤り。** manual に Windows desktop の節(5)を足し、代替の記述を消した。差分review attempt 2 で確かめる。
- **attempt 2**: `78438ba..a79b38d`(差分review。`specs/` だけ) — **PASS**(指摘なし)。reviewerは`gpt-6-luna`。attempt 1 の P1 が閉じた(manual に Windows desktop の手順・期待結果があり、受け入れ証拠と一致。代替の記述は消えた)。
- 連鎖: `72ca7ef..78438ba` FAIL(P1)→ `78438ba..a79b38d` PASS(P1 が閉じた)→ 以後の記録だけの差分は SELF-CHECK。

## Current state / handoff

- Last checkpoint: checkpoint 1〜3 を実装(`07b7410`)。独立review attempt 1 FAIL(P1: Windows desktop 確認を判断なしに省いた)→ 手順を足して attempt 2 PASS(2026-10-01)。review 側の確認は揃った
- Blocker category: human verification
- Waiting for: 開発者による実機確認1回目(`/workspace/.worktrees/008-T10-spacing-and-typography/specs/008-ui-alignment/tasks/T10-spacing-and-typography/manual-verification.md` の 0〜5。Android エミュレータと Windows desktop)
- Requested action: worktree の HEAD から build し(`lib/` は `07b7410` と同一)、0〜5 を確かめて結果を会話で伝える
- Evidence revision: `07b7410`(`lib/`)
- Next Agent action: 結果を「実機確認 1回目」節として記録する → 指摘があれば直して差分review(range は前回の head から)→ 実機確認をやり直す。OK なら done にし、PR #205 を ready → CI → merge commit で merge、`dev` で `workspace.py check specs`、worktree と branch を片付ける
