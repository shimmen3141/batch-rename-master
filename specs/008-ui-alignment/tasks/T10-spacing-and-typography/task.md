# T10 余白・階層・typographyを揃える

## 目的

参考designの(d)にあたる最終の追い込み。個々の画面ではなく、**app全体で余白と文字の階層が一貫している**状態にする。

## 入力と依存

- `specs/history/asdd-0.x-discovery.md`の(d)「全体の余白・階層・タイポグラフィ」。
- 参考design `docs/design/Bulk Renamer.html`。
- 現行実装: `lib/ui/theme/app_theme.dart`、`lib/ui/theme/app_colors.dart`(`AppColors` ThemeExtension)。
- **008の他の実装task(T02/T04/T06/T07/T08/T09/T18/T19/T20)すべて。** 構造が動いている間に余白だけ整えても作り直しになる。**T18/T19/T20は2026-09-02に追加した** — 要望10(区切り線)が触る行は`T18`が、要望13(上部見出し)と隣接する下部バーは`T20`が作り直すため。

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

## 受け入れ証拠

- 既存のwidget testがすべて継続PASSする(振る舞いを変えていないことの主な証拠)。
- 余白・文字sizeの直書きがthemeへ寄っていることをdiffで示す。
- 狭幅で情報が読めることを検査するT07/T09のtestが継続PASSする。
- `flutter test` / `flutter analyze` / `dart format --output=none --set-exit-if-changed .` がPASS。
- [`manual-verification.md`](manual-verification.md)でAndroid実機とWindows desktopの主要画面を確認する。
- exact rangeの独立reviewがPASSする。

## 作業記録

- 2026-08-13 / 人間の判断で(a)〜(d)を008の対象へ入れた際に定義。

## Current state / handoff

- Last checkpoint: 定義しただけ。未着手
- Blocker category: なし
- Waiting for: 008の実装taskすべて。最後に一度で行う
- Requested action: なし
- Evidence revision: `dev@ea1dd04`
- Next Agent action: 先行taskの完了後に着手する。先に手を付けない
