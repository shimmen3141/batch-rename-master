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

- Review attempt 4: PR #121 `dev@abc8007...3255f87` — PASS — 残るP0/P1: none(P2 8件。実害のある007 manualの例示・label表記と、記録の不整合をこの後の commit で処理)

- 2026-08-12 / PR #121が`dev`へmerge済み(`7154ce3`)。復元したchecklistで実機確認を依頼する段階になったため、statusを`blocked`(manual待ち)へ変更した。

## Current state / handoff

- Last checkpoint: manual checklistの復元がPR #121で`dev`へ統合済み。実機確認の依頼を出した
- Blocker category: manual
- Waiting for: 人間による[`manual-verification.md`](manual-verification.md)の実施。Android(emulatorまたは実機)とWindows desktop buildの両方が要る
- Requested action: 人間が`dev@7154ce3`のbuildでchecklistを実施し、結果を会話で返す
- Evidence revision: `dev@7154ce3`。Agentはこのcommitでcheckoutを維持し、実施中はcode/dependency/build設定を変更しない
- Evidence: 復元内容の独立review attempt 4=PASS、dry-run=PASS、`workspace.py check specs`=PASS(7 plans, 43 tasks)、`flutter test`=PASS(346)。**manual自体は未実施**
- Next Agent action: 結果を受け取って作業記録へ要約し、受け入れ条件を満たしたか判定する。満たせば独立reviewへ回す
