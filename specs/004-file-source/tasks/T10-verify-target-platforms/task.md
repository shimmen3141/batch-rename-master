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

- 2026-08-12 / **manual verification実施 / 受け入れ条件を満たした**。開発者が`dev@7154ce3`のAndroid(emulator)とWindows desktop buildでchecklistを実施し、結果を会話で報告。
  - 種類の入口(REQ-011): 4種類が出る。「画像」「動画」は選んでも読み込まず未実装を示す。「文書」は文書系だけが出る。**確認できた**。
  - 置き換えと場所表示(REQ-004 / REQ-007 / REQ-009)、選ばずに戻ったときの不変(REQ-008)、作成日時不明のwarningと強調・別sortでの強調解除(002 REQ-011 / REQ-013): **すべて確認事項どおり**。後述の見切れがあっても、警告アイコンは省略対象外(`file_list_view.dart:626`は`Expanded`の外)のため、どの行の作成日時が不明かは観測できた。
  - desktop(Windows)個別: 種類「すべて」からの複数選択で一覧が置き換わり場所が出る(手順1)、選び直しで前回分が残らない(手順3)、cancelで一覧・通知とも不変(手順4)を**個別に確認**。Androidと同じ契約になっている。
  - 権限: 設定→アプリ→権限が`No permissions allowed`。**追加の全file access権限を要求していない**ことを確認。
  - **フォルダ跨ぎ(REQ-012)は成立した**。ただし想定と違う経路で、file選択画面上部の`Documents`チップを選ぶと、folderが`asdd-src-a`のままでも`asdd-src-b`のtxtも一覧に出る(chipがfolderではなく種類で横断集約する)。両方のsame.txtを同時に選択でき、**複数folderが混ざっている旨の警告も出た**。REQ-012の実機受け入れはこれで取れている。
  - 同一fileの重複選択(Android手順3 / desktop手順2)は、どちらのfile選択画面でも同じfileを2回選べないため**実施不能**。REQ-004の重複集約はVER-002の自動testで検査済みで、実機受け入れの必須項目ではない。
  - desktopのfolder跨ぎ(手順5)も選択画面の制約で**実施不能**。Android側で取れているため受け入れに影響しない。
  - 観測した読みにくさ: 行のサブ情報が狭幅で見切れ、`作成日時: 不明`の文字列が読めないことがある。`file_list_view.dart:648`が`maxLines: 1` + ellipsisで1行にまとめているため。ただし警告アイコンは`Expanded`の外(同`:626`)で省略されないため、**002 REQ-013の識別自体は成立しており仕様違反ではない**。読みやすさの問題として**008へ送った**(開発者判断)。このtaskの受け入れは阻却しない。

- Review attempt 5: PR #122 `dev@7154ce3...f98f53f` — PASS — 残るP0/P1: none(manual結果を対象とした初回review。P2 5件はこの後のcommitで解消)

## Current state / handoff

- Last checkpoint: manual verificationがPASSし、それを対象とした独立reviewもPASS。受け入れ条件を満たしたので`done`
- Blocker category: なし
- Waiting for: なし
- Requested action: なし
- Evidence revision: `dev@7154ce3`でmanualを実施。以後この branch で code / dependency / build設定の差分はゼロ(reviewerが実diffで確認)
- Evidence: manual verification=PASS(`dev@7154ce3`、2026-08-12、開発者、Android emulator + Windows desktop)、独立review=PASS(P0/P1なし)、`workspace.py check specs`=PASS(7 plans, 43 tasks)、`flutter test`=PASS(346)、`flutter analyze`=PASS(0)、`dart format`=PASS(0 changed)
- Next Agent action: なし(完了)。PR #122のmergeは人間が行う
