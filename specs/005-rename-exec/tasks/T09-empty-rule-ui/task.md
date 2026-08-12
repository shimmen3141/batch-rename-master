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
- **designを適用する画面範囲**(AGENTS.mdの正本規定に従う): `docs/design/Bulk Renamer.html`のうち、mobile画面の**下部固定バー**(ルール設定ボタンと実行ボタンの縦積み)と、**結果toast内の「元に戻す」**だけを適用する。同designのリスト表示3案、ファイル種別アイコン、読み込み導線、余白・タイポは`008`の範囲であり、このtaskでは触らない。
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

- 2026-08-12 / manual verificationを開発者が`d707e6d`のWindows desktop buildで実施し、全項目PASS(会話で報告)。最重要だった「結果toast上のundoが実機で押せる」も確認できた。手順のPowerShellが`$emptyRuleFixture`のwindowまたぎで落ちる不備を見つけ、注意書きを追加した(UI確認結果には影響なし)。
- 2026-08-12 / `origin/dev`をmerge。人間が`docs/design/Bulk Renamer.html`を005 UIの配置・導線・情報階層の正本としてAGENTS.mdへ明記した(`e7ccfaa`)ため、このtaskが適用するdesign画面範囲を変更範囲へ明記した。merge後も`flutter test`=PASS(346)、`workspace.py check specs`=PASS。

- Review attempt 1: `origin/dev@28eb772...aabe8f5` — PASS — 残るP0/P1: none(P2 8件は下記で処理)
- Review attempt 1 (PR #121, 別range): `dev@abc8007...aaacf5d` — FAIL — 残るP0/P1: none(このtaskへの指摘は無く、`done`化の妥当性はattempt 1・2とも確認済み。FAILは同PRの004分による)
- 2026-08-12 / **Review attempt 1 / PASS**(task level)。range `origin/dev(28eb772)...aabe8f5`を実装文脈から分離したAgentがreviewし、`flutter test`=346 PASS、`analyze`=0、`format`=0 changed、`workspace.py check specs`=PASSを独立に再実行して報告値と一致を確認。P0/P1なし、P2が8件。反証された論点は、既存test 4件の書き換えが緩和でないこと(assertion本体は無傷で`widget_test`はむしろ強化)、undoのtoast移設がREQ-006/007の窓を変えないこと(`persist: false`は必要指定)、`presentWarnings`のインスタンス同一性依存が現行の全呼び出し経路で破れないこと、manual証拠`d707e6d`以後にcode/dependency/build差分が無いこと。
  - このtaskで対処したP2: 手順のcommitプレースホルダ未記入(P2-3)、`warning_display_test`の古いコメント(P2-7)、manualへ返信templateとstatus欄を作っていた点(P2-4。skillの`manual-verification.md`が「返信template、結果欄、別のstatus欄を作らない」と定めているため削除し、状態の正本を`task.json`へ一本化)。
  - 他taskへ接続したP2: `spec.md`の検証表が契約とdriftしている(P2-2。VER-004/005の被覆にREQ-019〜022が写されていない。T08由来の既存driftで、T09のdiffに`spec.md`は含まれない)。005 plan完了ゲートまでに解消する。`plan.md`の未解決事項へ記録した。
  - 受容したP2: toastのdurationが表示開始起点、undo deadlineがexecute完了起点のため入場animation分(〜250ms)だけ死んだundoが見えうる(P2-5。`undo()`の`canUndo`ガードで実体は変化しないためcosmetic)。`action`の有無がshowSnackBar時点の`canUndo`で固定される(P2-6。先行toastが出る経路は現状無い)。`product-map.md`と`migration-coverage.md`の編集が変更範囲外(P2-8。凍結historyからの人間決定の救出で、対応するfindingが動機付けている)。

- 2026-08-12 / PR #120をready for reviewで作成し、Issue #102へ状況を記録した。required CI(`check`)=SUCCESS、mergeable=MERGEABLE、未解決threadなし。

## Current state / handoff

- 2026-08-12 / PR #120が人間により`dev`へmerge済み(`abc8007`)。merge後の`dev`で`flutter test`=PASS(346)、`workspace.py check specs`=PASSを再確認し、statusを`done`にした。
- Last checkpoint: PR #120がmergeされ、merge後の`dev`で回帰と構造checkがPASS
- Blocker category: なし
- Waiting for: なし
- Requested action: なし
- Evidence revision: `dev@abc8007`
- Evidence: `flutter test`=PASS(346)、`flutter analyze`=PASS(0)、`dart format --set-exit-if-changed`=PASS(75 files / 0 changed)、`workspace.py check specs`=PASS(7 plans, 43 tasks)、manual verification=PASS(`d707e6d`)、独立review=PASS(attempt 1)、CI `check`=SUCCESS、merge後の`dev`で回帰PASS
- Next Agent action: なし(完了)
