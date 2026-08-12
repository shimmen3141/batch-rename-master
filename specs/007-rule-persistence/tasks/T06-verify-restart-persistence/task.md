# T06 process再起動をまたぐルール復元を受け入れ確認する

## 目的

Androidとdesktopで、保存したruleがアプリprocess終了後も実storageから復元される証拠を得る。

## 入力と依存

- `T05`のshared_preferences adapterとapplication配線。
- `spec.md`のREQ-005〜008。
- 共通環境手順[`docs/development/emulator-verification.md`](../../../../docs/development/emulator-verification.md)。

## 変更範囲

- 同一commit/buildでの保存・process終了・再起動・復元の観測。
- serializationや保存仕様の変更は、観測された不具合を別checkpointとして定義してから行う。

## 受け入れ証拠

- [`manual-verification.md`](manual-verification.md)のAndroidとdesktop checklist。
- exact revisionと証拠に対する独立reviewのPASS。

## 作業記録

- 旧007 T05はmockを含む自動検査を完了したが、実storageのprocess再起動確認を残したままdoneだったため、移行時に独立taskとして抽出した。

- 2026-08-12 / manual checklistを復元した。ASDD移行で、凍結側にあった**hot restartとcold startの区別**と、**ruleを変更してからの2回目のcold start(上書き保存の確認)**が落ちていた(`development-findings/2026-08-12-manual-checklists-lost-steps-in-migration.md`)。復元前は復元しか検査せず、「一度保存したきり更新されない」不具合を見逃す手順だった。識別可能なruleを2種類(A/B)定義し、A保存 → hot restart → cold start → Bへ変更 → 2回目のcold startの順に確認する形へ戻した。未実施のため手戻りは無い。

- Review attempt 1: PR #121 `dev@abc8007...7cb943b` — FAIL — 残るP0/P1: none(P2-2「人間向けmanualへ内部用語」がこのtaskのmanualにも該当。`fb6f7d7`で解消)
- Review attempt 2: PR #121 `dev@abc8007...aaacf5d` — FAIL — P1: このtaskのattempt 1記録がFAILをPASSと書いていた(P1-B。`6432da8`で解消)。復元内容自体は網羅性を確認済み
- Review attempt 3: PR #121 `dev@abc8007...6432da8` — FAIL — 残るP0/P1: none(このtaskへの指摘はattempt 2行の形式=P2-2のみ)

- Review attempt 4: PR #121 `dev@abc8007...3255f87` — PASS — 残るP0/P1: none(P2-4/P2-5: 例示がサンプル実file名でない、連番labelが実UIと不一致。この後のcommitで解消)

- 2026-08-12 / PR #121が`dev`へmerge済み(`7154ce3`)。復元したchecklistで実機確認を依頼する段階になったため、statusを`blocked`(manual待ち)へ変更した。

- 2026-08-12 / **manual verification実施 / 全項目を確認**。開発者が`dev@7154ce3`のAndroid buildとWindows desktop buildでchecklistを実施し、全項目が確認事項どおりだったと会話で報告。
  - 復元: ルールA(元の名前 / 文字列`_v` / 連番 開始番号7・桁数3 / 日時 作成日時`YYYYMMDD`)を組み、Android節の再読み込み(`R`)でも、AndroidとWindows双方のprocess完全終了後の起動でも、token種別・**順序**・設定値が一致した。
  - **上書き**: ルールBへ作り替えてからもう一度完全終了して起動すると、**ルールBが出てルールAは復活しなかった**(Android・Windowsとも)。
  - 実施環境: Android(emulatorか実機かは報告に無く未確定)、Windows desktop build。checklistはどちらも許容しており、受け入れ判定は変わらない。
  - 証拠のidentity: `dev@7154ce3`で実施。以後`dev@b7f1e1b`までの差分は記録のみで、`lib/` `test/` `pubspec.*` `android/` `windows/`の差分はゼロ(`git diff 7154ce3..HEAD`で確認)。
- 2026-08-12 / 考察(観測ではない): 上書きのstepは今回不具合を検出しなかったが、**検出できる状態になった**ことに意味がある。移行後の要約版はREQ-005/007とREQ-008の保存側を実storageで一度も観測しておらず、「初回だけ書いて以後更新しない」実装がmanualを通過できた。PR #121での復元がこのPASSに必要だったことを、独立reviewも確認している。
- Review attempt 5: PR #123 `dev@b7f1e1b...838b694` — PASS — 残るP0/P1: none(manual結果を対象とした初回review。P2 4件はこの後のcommitで解消)

## Current state / handoff

- Last checkpoint: manual verificationがPASSし、それを対象とした独立reviewもPASS。受け入れ条件を満たしたので`done`
- Blocker category: なし
- Waiting for: なし
- Requested action: なし
- Evidence revision: `dev@7154ce3`で実施。`dev@b7f1e1b`まででcode / dependency / build設定の差分はゼロ(reviewerが実diffで確認)
- Evidence: manual verification=PASS(`dev@7154ce3`、2026-08-12、開発者、Android + Windows desktop)、独立review=PASS(P0/P1なし)、`workspace.py check specs`=PASS(7 plans, 43 tasks)、`flutter test`=PASS(346、うち`test/spec_007_rule_persistence`は33件)
- Next Agent action: なし(完了)。PR #123のmergeは人間が行う
