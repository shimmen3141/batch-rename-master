# T38 app内browserの選択・戻る導線を定義する

## 目的

2026-09-22のT37実機報告で、範囲選択は概ね動く一方、全選択後の一括解除、画面を閉じる×の意味、選択行の表示、保存場所とfolderの戻り方が直感的でないと指摘された。004の承認済みの振る舞いを守りつつ、Android app内browserの操作導線を一つの設計へ整理し、必要な仕様変更を開発者の承認へかける。実装はT39が持つ。

## 入力と既存taskとの境界

- 観測: 2026-09-22のT37実機報告（会話）。「概ね機能」「TalkBack手順の意味が不明」「全選択はあるが全解除は無い」「headerの×が選択解除の×に見える」「checkboxをリネーム画面へ統一したい」。
- 開発者の案: footer左下に暗い背景・シアンの枠と文字の「リネーム画面に戻る」button、上部を保存場所名と左矢印にし、選択中は×と「〇件選択中」へ変える、現在地の帯へfolder一括選択checkboxを置く。
- 004 REQ-015/016/020: 保存場所の一覧から始めること、rootより上へ辿れないこと、folder移動で選択が消えること、全選択は現在folder直下のfileだけを対象にすることを保持する。変更したい場合は仕様案を作り、承認前に実装しない。
- T11/T12: 保存場所1件時の入口、近道の見分け、戻る矢印の向き、空folder表示を持つ。T38はT11の承認済みの意味を前提に定義し、それらを複製しない。T39はT12の実装結果とも整合させる。
- T37: 長押しdragとedge自動scrollの意味を変えない。T38は選択controlと画面を閉じる操作の提示を持つ。
- desktopのOS pickerは対象外。

## 決めること

1. 一括解除をどこに置き、全選択と一対の操作として見せるか。候補は現在地帯の一括checkbox、headerの×、ケバブ。複数の同義操作を無造作に並べない。
2. headerの×を撤去してfooterへ「リネーム画面に戻る」を常時表示するか。閉じたときは現在と同じく未確定の選択を捨て、rename画面の既存状態を保持する。
3. 保存場所名を上部へ、現在folderの場所をその下へ置くか。左矢印はfolder内なら親folderへ、保存場所rootなら保存場所一覧へ戻るのかを区別し、rootより上のfilesystemへは移動しない。
4. 選択時に上部を「× + N件選択中」に変える場合、×は「現在folderの選択を全部解除」か「選択表示を閉じる」かを明確にし、画面を閉じる操作と誤認させない。
5. 「folder全体checkbox」は直下fileだけを選ぶのか、子folder以下も含むのか。REQ-020は前者を要求し、後者はfolder移動と同一folder選択の保証を変えるため、明示承認なしに採らない。
6. file行のcheckboxをメイン一覧T29の右端・円形・アクセント色に揃え、選択済み行の面色も揃えるか。browser固有のfolder/shortcut行はnavigationとして識別できる形を保つ。
7. TalkBackを知らない開発者でも、manualのUI説明だけで全選択と一括解除の操作を再現できるか。

## 受け入れ証拠

- 操作状態表: 保存場所一覧、root、下位folder、選択0/一部/全件で、header・現在地帯・footer・戻る・一括選択/解除の意味が一意に読める。
- 004 REQ-015/016/020の維持・変更点をdiffで示し、変更が必要なら仕様と代表例の案を作って開発者の再承認を得る。
- 承認後、実装が守る仕様IDをT39の`task.json.covers`へ反映する。
- T11/T12との重複と実装順を整理し、T39へ観測可能なwidget testと、fixture・対象build・操作・期待結果まで書いた実機手順を着手前に引き渡す。
- ASDD workspace check PASS。仕様やproduct挙動の決定後に独立reviewを行う。review modelは開発者指定のluna。

## Current state / handoff

- Last checkpoint: 2026-09-22のT37実機報告から論点を登録した。候補UIは未承認。登録の独立reviewは `gpt-5.6-luna`、exact range `bef8337...edf4b08` でP2×3のFAIL、依存・証拠版・実機手順の引継ぎを修正後の `bef8337...5f31387` でPASS（P0〜P2なし）。T38の仕様・UI実装自体は未review。
- Blocker category: dependency / T11.
- Evidence revision: 2026-09-22会話報告をT37の `f4b7868` に記録。対象code/testは `d88ab4f`、報告時HEADは `90efb6c`。このtaskのbranch baseはdev@`bef8337`。
- Waiting for: T11の仕様決定。
- Requested action: なし。
- Next Agent action: T11の仕様決定後、T12およびT37の最新状態を照合し、状態表と仕様変更案を作る。物質的な選択だけ一問ずつ開発者へ尋ねる。
