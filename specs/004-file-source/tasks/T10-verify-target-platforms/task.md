# T10 target platformでファイル選択を受け入れ確認する

## 目的

Android SAFとdesktop pickerで、既存004仕様の選択・cancel・置換・警告が実際のplatform上でも成立する証拠を得る。

## 入力と依存

- `T09`の選択導線実装。
- `spec.md`のREQ-002〜005、REQ-009〜012。
- 共通環境手順[`docs/development/emulator-verification.md`](../../../../docs/development/emulator-verification.md)。

## 変更範囲

- 同一commit/buildの手動観測と、必要なら観測で判明した不具合の別task化。
- このtaskだけで選択仕様やUIを黙って変更しない。

## 受け入れ証拠

- [`manual-verification.md`](manual-verification.md)のAndroidとdesktop checklistが同一code revisionに対して記録される。
- exact revisionと証拠を対象に独立reviewがPASSする。

## 作業記録

- 旧004 T04/T09では自動検査まで完了した一方、target platformの最終受け入れが旧plan全体に残っていたため、移行時に独立taskとして抽出した。

- 2026-08-12 / manual checklistを復元した。ASDD移行で凍結側の9 stepが3 stepへ要約され、**REQ-011(「画像」「動画」は読み込まず未実装を示す / 「文書」はMIME絞り込み)**と、**追加の全file access権限を要求しないこと**の確認が落ちていた(`development-findings/2026-08-12-manual-checklists-lost-steps-in-migration.md`)。凍結側`history/asdd-1.x-development-unit/manual-verification.md`と突き合わせ、落ちた項目を戻したうえで、fixture作成commandと期待結果を人間が番号順に実行できる形にした。skillの規定に従い返信templateとstatus欄は置かない。未実施のため手戻りは無い。

- Review attempt 1: PR #121 `dev@abc8007...7cb943b` — FAIL — P1: folder跨ぎstepが実行不能(`fb6f7d7`で解消)
- Review attempt 2: PR #121 `dev@abc8007...aaacf5d` — FAIL — P1: attempt 1の修正commitがAndroidのcancel確認stepを削除していた(復元前live版にも凍結側にもあった項目。この修正で復帰)

- Review attempt 3: PR #121 `dev@abc8007...6432da8` — FAIL — P1: 設定画面のアプリ表示名が実在しない値(`一括リネーム（デモ）`は`MaterialApp.title`=Recents用。設定→アプリに出るのは`AndroidManifest.xml:3`の`android:label="batch_rename_master"`)
- 2026-08-12 / **3回連続FAILのため自動修正を停止した**(AGENTS.md「同じtaskで独立verifierが3回FAILしたら自動修正を止め、diff、各回の実出力、未解決指摘、否定された仮定を報告する」)。statusを`blocked`にし、人間の判断を待つ。P1-1自体は1語の置換で仕様・scope・riskの判断を含まないが、規約は回数で止めることを求めているため、Agent判断で続行しない。

## Current state / handoff

- Last checkpoint: manual checklistの復元をPR #121で実施。独立reviewが3回連続FAILし、自動修正を停止
- Blocker category: review(3回FAIL規律)
- Waiting for: 人間の判断。(a) P1-1の1語をAgentが直して続行、(b) 人間が直す、(c) 別の扱い
- Requested action: 上記(a)〜(c)を選ぶ。選択後、必要ならattempt 4を取る
- Evidence revision: PR #121 head `6432da8`(base `dev@abc8007`)
- Evidence: `workspace.py check specs`=PASS(7 plans, 43 tasks)、`flutter test`=PASS(346)、`flutter analyze`=PASS(0)、`dart format`=PASS(0 changed)。いずれもattempt 3のreviewerが独立に再実行して一致
- Next Agent action: 人間の判断を待つ。manual自体の実施依頼はP1-1解消後
