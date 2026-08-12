# T09 空ルール時の実行防止UIを実装する

## 目的

ruleが空ならrenameを開始せず設定案内を表示し、token追加で通常状態へ戻る。あわせて、案内と実行を載せる下部アクションバーを`docs/design`どおりの位置へ揃える。

## 入力と依存

- `T08`で承認済みのREQ-019〜022。
- `T04`で統合済みのrename action境界。
- `docs/design/Bulk Renamer.html`のmobile画面(リスト下の固定バーに、ルール設定ボタンと実行ボタンを縦積みする)。
- Issue #102。

## 変更範囲

- rename buttonのdisabled状態、未設定表示、rule設定への導線、token追加後の復帰。
- 空名警告と基準日時不明警告が同一fileで重なるときの1件へのまとめ(REQ-021)。
- **アクションバーの位置**: `T04`がリスト上部へ置いたrename actionを、designどおりリスト下の固定バーへ移し、`RuleBuilderWorkspace`が別に持っていたルール編集ボタンと同じバーへ集約する。narrowはルール設定＋実行の2段、wideはルールペインが常時見えているため実行のみ。
- **undoの位置**: バーを下部へ移した結果、結果toastがバーを覆いundo buttonを押せなくなったため、undoを結果toast内のactionへ移す。designも同じ形(toast内の「元に戻す」)である。REQ-006 / REQ-007の窓と挙動は変えない。
- 対象外: 実行ラベルの動的化(`N 件をリネーム`等)、警告帯・確認ダイアログ・結果本文の再実装、配色やタイポの視覚調整。

## 受け入れ証拠

- 空ruleでadapter call 0、未設定案内、token追加後の通常実行をwidget/仕様由来testで検査する。
- 空名警告と基準日時不明警告が同一fileで重なるとき、提示が2行ではなく1行になることをtestで検査する。
- アクションバーがfile listより後(下)に描画され、ルール設定への導線が同じバーにあることをwidget testで検査する。
- 実行後にundoを提示している間、undoが実際に押せる(結果toastに覆われない)ことをwidget testで検査する。
- `flutter analyze` 0件、`dart format --set-exit-if-changed` 0 changed。
- full regressionは`flutter test`で確認する。
- [`manual-verification.md`](manual-verification.md)で利用者から見える導線を確認する。

## 作業記録

- T08の仕様更新は承認済み。T04はPR #110でdevへ統合済み。Issue #102は未claimで着手可能。
- 2026-08-11 / `dev@63de09c`で現在地を確認。analyze 0、format 0 changed。`flutter test`はT05のcode assetをbuildできず(C compiler不在)1件も開始できないため、containerでのfull regressionは不可。
- 2026-08-11 / `T04`(commit `9a0e0e1`)がrename actionをsort barの直下=リスト上部へ置いており、`docs/design`の下部固定バーから逸脱していることを確認。契約は配置に言及していないため仕様違反ではなくdesign正本からの逸脱として、同じバーを扱うT09へ範囲を広げた(人間判断 2026-08-11)。

- 2026-08-12 / 人間が`.devcontainer/Dockerfile`へ`clang` + `build-essential`を追加してrebuild済み。`clang 14.0.6`、`/usr/bin/ld`、`/usr/bin/gcc`を確認。`sudo -l`は`init-firewall.sh`のみで境界は変わっていない。containerで`flutter test`が実行可能になった。
- 2026-08-12 / 移設後の初回`flutter test`で5件fail。うち1件は実挙動の後退で、残り4件は仕様変更に追随していない既存testだった。
  - 実挙動: 結果toastが下部バーを覆い、undo buttonがhit testに当たらない(`Offset(726.8, 564.0) would not hit test`)。toastの既定表示は4秒、undo窓は5秒なので、実機でも取り消せる間ずっと押せない。designどおりundoをtoast内のactionへ移して解消した。`SnackBar.persist`が`action != null`で既定trueになりtoastが消えなくなるため、`persist: false`を明示してREQ-007の5秒窓と一致させた。
  - test追随: `warning_display_test`の2件は空ruleを空名警告のfixtureに使っていたが、空ruleは警告帯ではなく未設定案内になった(REQ-020)ため、`LiteralToken('')`へ差し替えた。`widget_test` / `rule_builder_workspace_test`は初期ruleが空のとき導線の表示が「変更する名前を設定する」へ変わるため、`configure-rule` keyでの検査へ変えた。いずれもassertionの意図は保持している。

## Current state / handoff

- Last checkpoint: REQ-019〜021の実装、アクションバー下部移設、undoのtoast移設まで完了し、full regressionがPASS
- Blocker category: なし
- Evidence revision: branch `asdd/005-rename-exec/T09-empty-rule-ui`(base `dev@63de09c`)
- Evidence: `flutter test`=PASS(346)、`flutter analyze`=PASS(0)、`dart format --set-exit-if-changed`=PASS(75 files / 0 changed)
- Next Agent action: `manual-verification.md`を用意し、独立reviewを通したうえでpush / PRを人間へ確認する
