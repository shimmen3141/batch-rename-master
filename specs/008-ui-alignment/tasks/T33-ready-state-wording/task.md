# T33 警告0件の見出しを「正常にリネームできます」へ整える

## 目的

一覧ヘッダの警告件数が **0件のときの見出し**を、いま何が言えているのかが読める文言と配色にする。

## 受領した要望(2026-09-19、原文)

`008:T29` の実機確認で受領した5件のうちの1件で、**開発者が「`T29` とは無関係」と
明示したもの**である。

> - T29とは無関係な改善案: ケバブメニューがある帯の、「✓問題なし」というような記述は緑(リネーム後の色と同じ)にし、「✓正常にリネームできます」のように文言を変えたほうがよさそう。

## 変更範囲

- [`lib/ui/file_list/rename_warning_view.dart`](../../../../lib/ui/file_list/rename_warning_view.dart)
  の `warningCountLabel`(0件のとき `'問題なし'`)と `WarningCountView`
  (0件のとき icon・文字とも `colors.textSecondary`)。
- 「リネーム後の色」は **`colors.success`**(`#4ADE80`)である
  — `file_list_view.dart:1541` の変更後名が警告の有無で `danger` / `success` を選んでおり、
  緑はそこ**1か所だけ**で使われている。**token を足す必要は無い。**

## 先に決めること

- **「正常にリネームできます」と言い切ってよい条件。** 現状の 0件は
  「**警告が0件**」であって「**リネームすると何かが変わる**」ではない。次の2つが別物である。
  - ルールが空 → **件数labelそのものを出さない**(`008:T16` の P2-10。005 REQ-020 の案内が
    代わりに出る)。ここは変わらない。
  - ルールはあるが**変更が生じるファイルが0件** → いま件数labelは「問題なし」と出て、
    実行buttonは「変更されるファイルがありません」と出る。ここで
    「**正常にリネームできます**」と出すと、**押しても何も起きないのに「できます」と読める**。

  案は2つ: (a) 文言を「正常にリネームできます」にし、**変更0件のときは出さない/別の文言にする** /
  (b) 「問題なし」より積極的で、かつ変更の有無を主張しない文言(例「問題は見つかりません」)。
  **推奨は (a)** — 要望は「できる」と言い切る方向で、変更0件はそもそも実行buttonが
  言っている。ただし**どちらを採るかは開発者に一問で確認する**(利用者から見える文言である)。
- **配色**: icon と文字をどちらも `success` にするか、icon だけにするか。
  **どちらも緑**が要望に素直である。

## 気をつけること

- **005 の代表例 20f が「『問題なし』の表示は出してよい」と文字列を名指ししている。**
  要求は **may** なので REQ の改訂は要らないが、**記録が実装と食い違ったままにしない** —
  `T29` が 002/004 で行ったのと同じ形(取り消し線 + 移設先 + 経緯)で 005 spec を直し、
  Status 行に「要求(may)は変えていないので再承認は求めていない」と書く。
  `008:T15` の task.md にも `'問題なし'` を名指しした記述がある(こちらは過去の設計記録なので
  書き換えない)。
- **`008:T16` が閉じた保証を戻さない。**
  - ルールが空のときは件数labelを**出さない**(`warningCountKey` が `findsNothing`。M198)。
  - 件数を**切り詰めない**(`⚠ 1000 件の問題` を `⚠ 1…` と読ませない。2行まで折り返す)。
    **文言が長くなるので、狭幅 × 文字倍率での折り返しを見直す。** 「正常にリネームできます」は
    「問題なし」より倍以上長い。
- 0件のときは `onTap` が `null` である(開くものが無い)。**緑にして押せそうに見えても
  押せない**という状態が強まらないか実機で見る。
- 文字列を見ている既存testを洗い出す(`grep -rn '問題なし' test/`)。

## 入力と依存

- `specs/005-rename-exec/spec.md` REQ-009 / REQ-010、代表例 20f。
- [`T16`](../T16-implement-row-level-warnings/task.md)(件数labelの現在の保証)。
- **`T30` / `T31` / `T32` とは独立**(あちらは `file_list_view.dart` と `file_source_bar.dart`、
  ここは `rename_warning_view.dart`)。**別worktreeで並行できる。**
  `T29` に依存するのは、`T29` が同じ file の件数labelを2行折り返しへ直したためである。

## 受け入れ証拠

- 警告0件で**緑の見出し**が出る(widget test)。
- ルールが空のときは**やはり出ない**(既存testが緑のまま)。
- 狭幅(320dp)× 文字倍率(最大)で**切り詰められない**。
- `flutter test` / `flutter analyze` / `dart format` / `mutation_check.py` が PASS。
- Android実機での manual 確認(`manual-verification.md` を作る)。**`T30` / `T32` と
  同じ回にまとめられる**(同じ画面である)。

## 調査checkpoint(2026-09-20)

文言判断に必要な状態は、すでに製品のcomposition rootまで届いている。

| 状態 | 現在の判定 | 現在の表示 | 案(a)を選んだ場合 |
|---|---|---|---|
| ルールが空 | `controller.isRuleEmpty == true` | 件数labelを出さず、未設定の案内を出す | 変更しない |
| 警告0件・変更あり | `warnings.isEmpty && changedFileCount > 0` | `問題なし` | 緑で `正常にリネームできます` |
| 警告0件・変更0件 | `warnings.isEmpty && changedFileCount == 0` | `問題なし`、実行buttonは `変更されるファイルがありません` | **件数見出しを出さない** |
| 警告あり | `warnings.isNotEmpty` | 赤で `n 件の問題` | 変更しない |

- `FileListController.changedFileCount` は、実行可否と同じ `rowHasNoChange` を使う。
  新しい判定やルール形状による近似は不要である。
- `_HeaderBar` は `FileListController` を持つため、`WarningCountView` へ変更有無を渡せる。
- 既存testは `warning_display_test.dart` が警告0件の変更あり・変更0件を別fixtureで持ち、
  `empty_rule_test.dart` が空ルールでlabelを隠す保証を持つ。`row_presentation_test.dart` は
  狭幅320dp・文字倍率2.0まで切り詰めないことを検査している。これらを文言別のassertionへ
  付け替えれば、三状態を製品経路で検査できる。
- 案(a)は `file_list_view.dart` の `WarningCountView` 呼び出しにも数行触るため、同じfileで
  gestureを実装する`T31`と統合時に小さな競合がありうる。責務は別で、並行調査・実装は可能。
  `tool/mutations.json`はどちらのtaskも触るため、mutation追加位置も競合しうる。
- 案(b)は `rename_warning_view.dart` 内で閉じられるが、変更0件と変更ありを同じ表示に保つ。

## Current state / handoff

- Last checkpoint: 開発者が案(a)を決定した。警告0件・変更ありは緑で
  `正常にリネームできます`、変更0件と空ルールでは件数見出しを出さない(2026-09-20)
- Blocker category: none
- Waiting for: none
- Requested action: none
- Touches: `lib/ui/file_list/rename_warning_view.dart`、案(a)では
  `lib/ui/file_list/file_list_view.dart`の呼び出し1か所、`specs/005-rename-exec/spec.md`
  (代表例20f の記録更新。**要求(may)は変えないので再承認は求めない**)
- 並行: `T31`と並行できるが、案(a)では`file_list_view.dart`の別責務と
  `tool/mutations.json`が重なるため、統合時に小さな競合がありうる
- Evidence revision: `3a64e48` + 調査commit(2026-09-20、hashはcommit後に確定)
- Next Agent action: 005代表例20fの記録を更新し、widget testを先に追加してから最小の表示変更を実装する
