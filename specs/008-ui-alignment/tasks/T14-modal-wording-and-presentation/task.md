# T14 modalの文言と見せ方を整える

## 目的

`013:T07`の実機確認で開発者が挙げた**U5**を解消する。原文は「**モーダルの文言や
見せ方は改善の余地あり**」である。

## 対象modalが特定できていない — 着手時に人間へ確認する

**U5はどのmodalを指すか書かれていない。** 推測で直すと、指摘されていないものを変えて
manual確認をやり直させることになる。**着手した最初の質問として、下の一覧を示して
確認する**(AGENTS.md「一度に一つ、現実的で相互排他的な選択肢」)。

現在appにあるmodal / dialog。

| # | 実装 | 何を出すか | 所有 |
|---|---|---|---|
| 1 | `lib/ui/file_list/file_list_view.dart` の `Key('rename-confirmation-dialog')` の `AlertDialog` | 警告があるまま実行するかの確認 | **このtask** |
| 2 | `lib/ui/file_source/file_source_bar.dart:192` の `showModalBottomSheet` | 読み込む種類の選択(画像 / 動画 / すべて) | **`T08`**(読み込み導線の一部として確定させる)。**このtaskは文言だけを後から合わせる** — 分担は`T08`の`task.md`にも書いた |
| 3 | `lib/ui/rule_builder/token_editors.dart:13` の `showModalBottomSheet` | tokenの編集 | **`T05`/`T06`**(token追加の確定手順)。**このtaskでは触らない** |
| 4 | `lib/ui/rule_builder/rule_builder_workspace.dart` の `_openRuleSheet` の `showModalBottomSheet` | **ルール構築画面まるごと**(mobileの下部バー「ルール設定」から開く。中身は`RuleBuilderView`) | **このtask。** **狭幅(`breakpoint` = 840dp 未満。実機確認に使った phone を含む)ではルールの編集が必ずこのsheet越しなので、U5がこれを指す可能性が高い**(実機確認の手順3で開発者が実際に操作している)。**sheetの中にあるtoken追加・編集のmodalだけが`T05`/`T06`** |

**3(token編集)が対象だった場合は、このtaskで直さず`T05`/`T06`へ送る**(同じ画面を
2つのtaskが別々に変えない)。**4は入れ物であって token の modal ではない**ので、
このtaskが持つ — ただし`T06`が中身を作り直すので、**入れ物の高さ・scroll・閉じ方を
変えるときは`T06`の結果と突き合わせる**。

### `T19`との分担(2026-08-27に`T16`と結び、2026-09-02に`T19`へ移した)

`T19`が**警告の詳細modal**を持つ(`T16`が作った入れ物を作り直す)。**このtaskが持つのは表の1**
(実行前の確認dialog)である。**同じmodalへ二つのtaskが手を入れない**よう、先に着手した側が
入れ物を確定させ、後の側が合わせる。分担は`T19`の`task.md`にも書いた。

**`describeWarning`系の文面は両方が使う。** `T19`の`task.md`は「着手時にどちらが文面の正本を
持つかを決めて両方の`task.md`へ書く」としている。**どちらが先でも、決めた側が両方のfileへ書く。**

**`T19`が先に着手した場合**、このtaskは`T19`が作った詳細の見せ方に合わせて確認dialogの
文言を整える(同じ警告を二つの語彙で説明しない)。

## あわせて拾う: 結果の提示手段(2026-08-15の決定)

`plan.md`の人間の決定表にある「**再採番結果の提示方法**」が、**どのtaskにも割り当てられて
いなかった**。内容は「`013:T11`が結果toastへ入れた『旧 → 新』の全件表示を008で見直す。
件数が多いとtoastが縦に伸びる(現在は高さ96pxで打ち切ってscroll)。**modalの方が向いて
いる**という指摘があった」である。

**提示手段は005 specが「自由とする点」に入れており、振る舞いは変わらない**ので008の
範囲である。**このtaskが引き受ける。**

## 変更範囲

- 上の表の 1・4 と、結果の提示手段。**2 は`T08`が確定させた後に文言だけを合わせる。**
- 文言(何を聞かれているか、実行すると何が起きるか)と、見せ方(高さ、scroll、
  botton の並び、破壊的操作の見分け)。

**判定は動かさない。** 005の実行可否、衝突・重複の警告条件、001の検証はそのままである。
**警告の内容そのもの**(何を警告するか)は`T07`(行と警告の情報階層)が持つ。

### `T15`との分担(2026-08-29)

`T15`は**警告の詳細を見るmodal**(ヘッダーの「⚠ N 件の問題」と行の警告文から開く)を定義し、
`T16`が実装する。このtaskが持つのは**実行前確認dialog**(`Key('rename-confirmation-dialog')`)
だけである。**同じmodalに二つのtaskが手を入れない。**

文言の体裁(見出し・本文・buttonの並び)はこのtaskが揃えるので、`T16`が作ったmodalへは
**後から文言だけを合わせる**。`T08`との関係と同じ形である。

## 受け入れ証拠

- 変更したmodalの文言と構造を widget test で検査する。**既存の実行経路のtestが継続
  PASSする**(確認を挟むこと自体は005の要求である)。
- 件数が多いときの結果提示が**画面内で読める**ことを widget test で検査する。
- `flutter test` / `flutter analyze` / `dart format --output=none --set-exit-if-changed .` がPASS。
- [`manual-verification.md`](manual-verification.md)で実機の見え方を確認する。
- exact rangeの独立reviewがPASSする。

## 作業記録

- 2026-08-25 / `013:T07`の実機確認(U5)を受けて定義。開発者が「U1〜U5をすべてtask化する」
  と決定した。あわせて、割り当て先の無かった2026-08-15の決定(結果の提示手段)をここへ
  接続した。

## Current state / handoff

- Last checkpoint: 定義しただけ。未着手
- Blocker category: なし
- Waiting for: なし
- Requested action: **着手時に、U5がどのmodalを指すかを人間へ一度だけ確認する**(上の表)
- Evidence revision: `dev@ae59859`
- Next Agent action: 他taskと独立に着手できる。**先に対象を確定させること** — 対象が
  `T05`/`T06`のmodalだけなら、このtaskは結果の提示手段だけを持つ
