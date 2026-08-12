# Development finding: 移行でmanual checklistが圧縮され、must要求の確認手順が落ちた

- 観測日: 2026-08-12
- 観測した作業: 凍結historyの棚卸し(「他にも移行しきれていないものがないか」の確認依頼)
- 改善先: project(`004:T10`、`007:T06`、`005:T07`のmanual verification)、およびASDD plugin(移行手順)
- 関連artifact: `specs/004-file-source/history/asdd-1.x-development-unit/manual-verification.md`、`specs/007-rule-persistence/history/asdd-1.x-development-unit/manual-verification.md`、および対応するlive taskの`manual-verification.md`

## 観測した事実

`development-units/`から移行した3件のmanual verificationが、live側では大きく圧縮されている。`migration-coverage.md`は「実装doneと未完manual受け入れを分離」とだけ記しており、手順が縮んだことは記録されていない。

### 004: 9 step → 3 step

凍結側(`history/asdd-1.x-development-unit/manual-verification.md`)のAndroid SAF手順は9項目。live側(`tasks/T10-verify-target-platforms/manual-verification.md`)は3項目。落ちた項目に**must要求と権限方針の確認が含まれる**。

- 「画像」「動画」は読み込みを始めず、写真機能で対応予定であることを示す — **004 REQ-011(must)**の中核。liveのchecklistに無い。
- 「文書」では文書系fileを選ぶpickerが開く — REQ-011の残り半分。無い。
- **追加の全file access権限を要求しない** — `MANAGE_EXTERNAL_STORAGE`を使わないというこのprojectのAndroid権限方針そのもの。liveに無く、**この方針を実機で確認するtaskは他に無い**。
- pickerのcancelで通知も変化しないこと(liveは一覧の不変のみ)。
- 「記録する証拠」の列挙(置換前後、cancel前後、種類別入口、跨ぎwarning、日時warning)。

desktop側も4項目→2項目で、「選び直しとcancelがAndroidと同じ契約になる」が落ちている。

### 007: cold start 2回 → 1回

凍結側はAndroid 5 step / desktop 4 stepで、**hot restart(`R`)とcold startを区別**し、さらに**tokenを変更してからもう一度cold startして新しい値へ更新されること**まで確認する。live側は4項目で、この2回目のcold startが無い。復元はcheckできるが、**上書き保存がcheckされない**。

### 005 T07

liveの`manual-verification.md`は4行のtemplate相当で、`Commit: pending`のまま。凍結dev-unitはT05/T06しか covers しておらず、T07の手順は0.x planにしか無い。

## 期待していた動きと実際の動き

- 期待: manual受け入れをtaskへ分離するとき、確認手順はそのまま(または詳細化して)移る。
- 実際: 手順が要約され、must要求の確認と権限方針の確認が落ちた。落ちたこと自体はどこにも記録されていない。

## 影響とworkaround

- 影響: `004:T10`と`007:T06`は`pending`で、**このまま実施すると要約版で受け入れ判定される**。004 REQ-011と権限方針は、実機で誰も確認しないまま`done`になりうる。
- 影響: 凍結側が詳しいことに気づかないと、要約版が唯一の正本に見える。AGENTS.mdは凍結historyをlive stateの正本にしないと定めているため、規約に従うほど詳しい版に到達しない。
- 影響の限定: `005:T05` / `T06`は既に凍結版の手順で人間が実施し、証拠を取り終えている。過去の判定は劣化していない。
- workaround: 未実施の`004:T10`、`007:T06`、`005:T07`について、凍結側の手順を読み直してlive checklistへ戻す。実施前なら手戻りは無い。

## 仮説と提案

- 圧縮は、移行時にtask.mdの体裁(目的・範囲・受け入れ証拠)へ合わせて要約したためと見られる。manual checklistは**要約してよい文書ではない**。人間が番号順に実行して観測結果を返す実行手順であり、step数が減ることは検査項目が減ることと等しい。
- ASDDの移行手順へ「manual verificationは要約せず全文移送する。減らす場合は減らした項目と理由を`migration-coverage.md`へ書く」を入れる。
- 併せて、各stepが**どの要求を確認するか**の対応が分かれば、圧縮時に落ちたものを機械的に検出できる。今回004で落ちたREQ-011は、対応が記録されていれば移行時に気づけた。ただしこれをそのまま一般化してよいかは自明でない。論点は下節へ分けた。
- 一般化: 移行の被覆判定を「file/taskが移ったか」ではなく「**検査項目が移ったか**」で行う。今回の対応表はfile単位でPASSしていた。

## 改善結果

2026-08-12に3件を復元した(branch `docs/restore-manual-checklists`)。いずれも未実施のtaskなので手戻りは無い。

- **004:T10**: 凍結側と突き合わせ、落ちていたREQ-011(「画像」「動画」は読み込まず未実装を示す / 「文書」はMIME絞り込み)と、追加の全file access権限を要求しないことの確認を戻した。あわせて、fixture作成command(PowerShell + `adb push`)、期待結果、handleの区別(同一handleは1件・別folderの同名は2件)を人間が番号順に実行できる形にした。
- **007:T06**: hot restartとcold startの区別と、ruleを変更してからの2回目のcold start(上書き保存の確認)を戻した。識別可能なruleを2種類(A/B)定義した。
- **005:T07**: 点検の結果、**移行での欠落は無かった**。凍結0.x planのT7受け入れ条件3件のうち、既定OFF/表示順と「ずらし失敗でもrename成功」はtask.mdの受け入れ証拠へ、「Androidでは設定自体を提示しない」は変更範囲へ移っている(受け入れ証拠側には無いが、失われてはいない)。stubだったのは実装前だからである。UI未確定のまま手順を書くと実画面と食い違うため、実装時にchecklistへ落とす観点6件を残し、実行手順は実装時に書くことを明記した。つまり当初の観測のうちT07分は誤りで、劣化は004と007の2件だった。

復元中に別の規約違反も見つかった。移行時のtemplate(および筆者がT09で書いたもの)が`## Result` / `- Status:`欄と返信templateを持っていたが、skillの`manual-verification.md`は「manualに返信template、結果欄、別のstatus欄を作らない」と定めている(状態の正本は`task.json`)。復元した3件からは外した。`005:T05` / `T06`の分は実施済みの証拠記録なので変更していない。

ASDD pluginの移行手順への一般化(「manual verificationは要約せず全文移送する。減らす場合は減らした項目と理由を記録する」「stepと要求の対応表を`task.md`側へ持つ」)は未対応。

2026-08-12の独立review(PR #121)で、復元そのものは網羅的だが、004のfolder跨ぎ選択stepが**実行不能**だと指摘されFAILになった。projectが`004:T07`で自ら記録していた「DocumentsUIはフォルダ移動で選択が解除されるため実質フォルダ跨ぎは起きない」という事実に反して、必須stepとして書いていた。fallbackも技法も無かったため、人間はそこで詰まる。

これは復元作業そのものの教訓である。**凍結側の手順を戻すだけでは足りず、戻した各stepが現在のplatformで実行可能かを、projectが後から記録した事実に照らして確認する必要がある**。凍結側の手順は、その事実が判明する前に書かれていることがある。修正では、跨ぎ選択に「最近タブ/検索から試す」技法と「できなければ確認不能でよい(自動testで検査済み)」というfallbackを付けた。あわせて、reviewが指摘した内部用語(REQ-ID、handle)、UI文言のずれ、desktopの種類指定漏れ、変数依存のcleanupと不可視なfixture pathも直した。

## 論点: manual stepと要求の対応表をどう扱うか(2026-08-12、人間との整理)

「各stepへ対応REQを書く」という当初の提案には、そのまま採用できない事情が複数ある。

### 1. 動機の強さ

今回の圧縮は**大規模な移行を一度行ったために起きた**もので、日常的に繰り返される事象ではない。移行の再発防止だけを理由に、全taskへ恒久的な対応表を課すのは割に合わない。

採用の可否を分けるのは、**移行以外の経路でも同じ漏れが起きるか**である。起きうる例:

- taskの受け入れ条件を後から追加したが、manualへ反映し忘れる。
- 仕様(spec / contract)のrevisionが上がり、REQが増えたが、既存manualが古い集合のまま残る。実際に005で、契約のVER被覆にREQ-019〜022が追加されたのに`spec.md`の写しが追随していないdriftを観測している。
- manualを読みやすさのために整理した結果、stepが統合されて検査項目が減る。

これらが実在するなら、対応表は移行とは独立に価値がある。実在しないなら不要。**次に同種の漏れを観測したときに再判断する**のが妥当で、今の1件だけで一般化しない。

### 2. 誰のための表か

置き場所は、読者が誰かで決まる。

| 読者 | 目的 | 置き場所の案 |
|---|---|---|
| project内の整合性(機械) | 被覆漏れを`workspace.py`が検出する | `task.json`に構造化して持つ。taskの`covers`と同じ扱い |
| AI(次のAgent) | 何を確認する手順なのかを復元する | `task.md`の受け入れ証拠。既に対応する場所がある |
| 人間(manualの実行者) | 自分が今何を確かめているかを理解する | `manual-verification.md`本文 |

現状の`manual-verification.md`は**人間のための文書**である。そこへ機械可読の対応表を置くのは読者違いで、逆に`task.json`へ置けば`workspace.py`が既にtask被覆を機械検査しているのと同じ枠組みに乗る。

### 3. 粒度の問題

`task.json`側へ持つ場合、**手順のstepには安定IDが無い**。stepは編集で増減し、番号は動く。したがって現実的な粒度は次のどちらかになる。

- **manual単位**: 「この`manual-verification.md`が確認する要求の集合」を持つ。既存の`covers`と同型で実装は軽いが、step単位の漏れは検出できない(今回のREQ-011の欠落は、manual単位でも「REQ-011を確認する」と宣言していれば、本文にその語が無いことから検出できた可能性はある)。
- **step単位**: stepへ安定IDを振る。検出力は上がるが、manualを書き換えるたびにID管理が要る。人間向け文書に運用負荷を持ち込むことになる。

manual単位から始めて、足りなければstep単位を検討する順序が無理がない。

### 4. 内部用語禁止との関係

skillの`manual-verification.md`はREQ等の内部用語をmanualへ出すことを禁じているが、これは**手順の中に一般的でない語を混ぜて実行者を混乱させない**という趣旨である。手順自体が内部用語なしで明示されているなら、末尾の付録として対応表を置くことまでは禁じていない読み方もできる。ただし現在の条文は用語の出現自体を禁じており、読み手によって解釈が割れる。**採用するなら条文側を「手順本文では使わない」と明確化する必要がある。**

### 判断

いずれもASDD plugin側の設計判断であり、このprojectだけで決められない。このprojectでは当面、対応表を作らず、reviewとmanual作成時のdry-run(`manual-verification.md`の「依頼前のdry-run」節)で漏れを見る。
