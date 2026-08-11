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
- 対象外: 実行ラベルの動的化(`N 件をリネーム`等)、undoのtoast化、警告帯・確認ダイアログ・結果表示の再実装、配色やタイポの視覚調整。

## 受け入れ証拠

- 空ruleでadapter call 0、未設定案内、token追加後の通常実行をwidget/仕様由来testで検査する。
- 空名警告と基準日時不明警告が同一fileで重なるとき、提示が2行ではなく1行になることをtestで検査する。
- アクションバーがfile listより後(下)に描画され、ルール設定への導線が同じバーにあることをwidget testで検査する。
- `flutter analyze` 0件、`dart format --set-exit-if-changed` 0 changed。
- full regressionは`flutter test`で確認する。container側は`development-findings/2026-08-11-native-asset-hook-blocks-container-tests.md`のtoolchain追加後に実行し、実行できない間はCI run IDを証拠とする。
- [`manual-verification.md`](manual-verification.md)で利用者から見える導線を確認する。

## 作業記録

- T08の仕様更新は承認済み。T04はPR #110でdevへ統合済み。Issue #102は未claimで着手可能。
- 2026-08-11 / `dev@63de09c`で現在地を確認。analyze 0、format 0 changed。`flutter test`はT05のcode assetをbuildできず(C compiler不在)1件も開始できないため、containerでのfull regressionは不可。
- 2026-08-11 / `T04`(commit `9a0e0e1`)がrename actionをsort barの直下=リスト上部へ置いており、`docs/design`の下部固定バーから逸脱していることを確認。契約は配置に言及していないため仕様違反ではなくdesign正本からの逸脱として、同じバーを扱うT09へ範囲を広げた(人間判断 2026-08-11)。

## Current state / handoff

- Last checkpoint: branch `asdd/005-rename-exec/T09-empty-rule-ui`をclaimし、範囲を更新した
- Blocker category: environment
- Waiting for: `.devcontainer/Dockerfile`へC toolchain(`clang` + `build-essential`)を追加したimage rebuild。完了までcontainerで`flutter test`を実行できない
- Requested action: 人間がDockerfileを更新してrebuildする
- Evidence revision: dev@63de09c
- Next Agent action: rebuild後に`clang --version`と`flutter test`のbaselineを取り、REQ-019〜021の実装とアクションバー移設へ進む
