# T02 権限とAPI levelの方針を定義する

## 目的

`MANAGE_EXTERNAL_STORAGE`をどう要求し、許可されないときに何が起きるか、どのAndroid versionを対象にするかを、外部から観測できる形で決める。**以後のtaskはすべてこの決定に乗る。**

## 入力と依存

- [`decisions/ADR-002`](../../decisions/ADR-002-android-rename-storage-boundary.md)(accepted)。
- `developer.android.com/training/data-storage/manage-all-files`(`Environment.isExternalStorageManager()`、`Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION`)。
- 現在の`minSdk`は`24`(Flutterの既定)。
- `renameat2`が**bionicのwrapperとして**公開されたのはAPI 30とされるが、これは検索結果の要約であり原文を読めていない(**[未到達]**)。**しかも生の`syscall(SYS_renameat2, ...)`を使えばwrapperの有無に依存しない。** `T01`のspike binaryは`android24`向けにビルドして動作した。**制約はlibcではなくkernelとfilesystemの側にある。**

## 決めること

**人間の決定が要るものを先に挙げる。** ADR-002が「未解決のまま残る決定」としたものを含む。

1. **`minSdk`をどうするか。** 少なくとも3案ある。**2案の二択として人間へ出さない。**
   - (a) 30へ上げて24〜29の端末を切る。最も単純だが端末を失う。
   - (b) 24のまま**生のsyscall**で呼び、`renameat2`が使えない端末を**実行時に検出して**未対応へ落とす。端末を失わないが、「同じappでも端末によって改名できない」状態を作る。
   - (c) 24のまま**API levelで一律分岐**し、30未満は無条件に未対応。(b)より単純だが、実際には動く端末も切る。
   - (b)(c)は利用者へどう説明するかまで決める。**どれを採っても、対応可否の判定は実測に基づくこと**(API levelは代理指標にすぎない)。
2. **権限が無いときの振る舞い。** file一覧の読み込み自体をさせないか、読めるが実行時に未対応を返すか。
3. **権限を要求する時機。** 起動時か、読み込みを試みたときか、実行を押したときか。
4. **権限を拒否されたあとの導線。** 設定画面へ再度誘導するか、一度断られたら黙るか。

## 変更範囲

- **新規[`specs/013-safe-android-rename/spec.md`](../../spec.md)** を作成した。権限はsource(004)と実行(005)の両方に関わるため、どちらかへ追記すると片方の仕様が他方の都合で膨らむ。独立させた。
- 改名そのものの正しさは**005 contractが正本**であり、013は緩めない(INV-001)。004/005 specは`T03`/`T04`が触る。
- `AndroidManifest.xml`の権限宣言は**このtaskでは行わない**(T06)。

## 受け入れ証拠

- 上記4点すべてに、外部から観測できる形で答えている。
- **人間による承認**(仕様の新規approvedまたは既存specの再承認)。
- 承認されたREQ IDを、T05〜T09の`task.json`の`covers`へ書く。**IDを書くだけにせず、そのtaskの受け入れ証拠にREQを検査する記述があることまで確認する。**
- **Playのpolicy原文との突き合わせが済んでいること(通過済み)。** 2026-08-13に`support.google.com`へ到達して原文を読み、`[未到達]`は解消した。当てはまりは資料からは決まらないため、**開発者が2026-08-13にriskを受容**してT05以降への投資を決めた。却下されればAndroid未対応維持へ戻る(ADR-002の退避経路)。
- `python <asdd-plugin>/scripts/workspace.py check specs`がPASS。

## 作業記録

- 2026-08-13 / ADR-002の採用決定を受けて定義。
- 2026-08-13 / 着手。`T01`のP2×4(結論節の未検証が7項目のうち4つ、plan.mdの未決定が2件、`Evidence revision`の二重括弧とmerge前base、trailing whitespace)を先に解消した。
- 2026-08-13 / **開発者が`minSdk`を「24のまま実行時検出」と決定。** API levelは対応可否の代理指標として弱く、実際に効くかを決めるのはkernelとfilesystemであるため。
- 2026-08-13 / **開発者が`spec.md`を承認(draft → approved)。** 承認されたREQ IDをT05〜T08の`covers`へ書いた。
- Review attempt 1: `4fd6ab1..e02a7a8` — FAIL — P1×4。
  1. **Playのinvalid usesを自分に都合よく要約していた。** 原文は`Any File selection activity where the user manually selects individual files`で、筆者は「手で選ぶ**だけ**の」と限定語を足していた。さらに代替の表にある「fileを選んでimport / transfer / **processing**する用途はSAFを検討せよ」という**最も不利な行を落としていた**。「一覧は網羅的でない」の注記もinvalid usesの側に付いており、範囲を広げる方向にしか働かないのに、反証側に置いていた。**限定語の増減が3箇所とも自分に有利な向きだった。**
  2. 上の結果、「残る不確実性は『審査に通るか』であって『該当しうるか』ではなくなった」が成立していなかった。**該当しうるかは未解決である。**
  3. **preflightの後片付けが要求として閉じていなかった。** 観測の過程で名前が移動するため「作ったものを削除する」では3つ目の宛先が残る。中断時の残骸の扱いも無く、残骸をINV-002の「既存ファイル」と扱うと**そのfolderで永久に改名できなくなる**経路があった。
  4. **複数folderに跨るbatchの意味論と、preflight結果の失効条件が未定義だった。**
  - 対処: 1と2は5fileすべてで直し、要約をやめて**原文を読むよう促す形**にした。3はREQ-010/011とINV-004、4はREQ-012/013で閉じた。`covers`のREQ-008をT05へ移した。
  - 2026-08-13 / **開発者がinvalid usesのriskを受容してT05以降へ投資すると決定。** ADR-002とplan.mdへ記録した。
  - **1は同じ根本原因の4回目である。** 転記をやめても、**要約する時点で自分の結論へ寄る**ことは止まっていなかった。findingへ記録した。
- 2026-08-13 / **`support.google.com`がallowlistへ追加され、Playのpermitted usesの原文を読めた。** ADR-002が`[未到達]`としていた箇所が埋まり、`T02`のgate(実装投資前のpolicy確認)を満たせた。
  - permitted usesの**File management**の定義は、このappの主目的と一致すると読める。
  - **同時にinvalid usesのfile selection activityにも該当しうる。** 資料は`Any`と書いて限定せず、代替の表は「fileを選んでimport / transfer / processingする用途」にSAFを案内している。
  - 例外条項は3条件すべてを要し、Consoleでの説明は追加の義務である。
  - **設計への含意を`T03`へ渡した。** folder管理の導線として作ることはFile managementの定義へ寄せる方向に働くが、invalid usesを外れる保証にはならない。
  - **「該当しうるか」は未解決のままである。** 到達できたのは定義であって当てはまりではない。**人間のrisk受容とする。**
- 2026-08-13 / `spec.md`をdraftとして起草した。**preflight(REQ-005〜008)がこのtaskで最も重要な設計判断である。** `renameat2`が`EINVAL`/`ENOSYS`を返す端末は安全(実体不変)だが、**フラグを黙って無視して上書きする端末は実行時に検出できない**(`T01`のspikeの`C)`)。したがって実行前に対象folderで実測する必要がある。対照(flags=0)を含めるのは、`T01`のreviewで「片側だけでは因果を示せない」と指摘されたのと同じ理由による。
- 2026-08-13 / **`minSdk`の判断材料を整理し、人間へ問うた。** `renameat2`のkernel実装はLinux 3.15で入っており、bionicのwrapperが無くても生syscallで到達できる(`T01`のspike binaryは`android24`向けにビルドして動作)。**したがってAPI levelは対応可否の代理指標として弱い。** 実際に効くかを決めるのはkernelとfilesystem(FUSEの下がext4かFATか等)であり、これはAPI levelと独立に端末ごとに変わる。

- 2026-08-14 / **開発者が`spec.md`を再承認(draft → approved)。** REQ-010〜013とINV-004を含む仕様が確定し、`T02`の未決定は無くなった。plan.mdの決定表へ記録した。

- Review attempt 2: `4fd6ab1..ce4ae6e` — FAIL — P1×4、P2×6。**外部資料の中立性は今回は問題を検出されなかった**(reviewerがpolicy原文をHTTP 200で取得し、限定語の増減・不利な行の欠落・注記の付け替えが無いことを7項目突き合わせた。`^>`行も0を確認)。**引用を全廃した対処が持ちこたえた最初のreviewである。**
  1. **PR #137の本文にattempt 1の偏った要約が逐語で残っていた。** specs配下は直したが、**人間が配布riskを判断する画面はPRである。** 「手で選ぶだけの」も「残る不確実性は審査に通るかであって該当しうるかではない」も本文に残存し、rangeも旧headのままだった。**修正がGit管理下のfileで止まり、成果物の外へ伝播していなかった。**
  2. **`covers`にREQ IDを書いただけで、所有taskの範囲・受け入れ証拠が更新されていなかった。** REQ-010〜013は`T05`(native port)のcoversにあるが、`T05/task.md`にpreflightの語が一度も無い。そもそもREQ-012(batchの停止単位)とREQ-007(理由の提示)は実行flowとUIの要求で、native portの範囲ではない。**preflightのorchestrationを所有するtaskが存在しなかった。** → `T09`を新設し、`T05`のcoversを部品の範囲へ戻した。
  3. **REQ-011とINV-002が同じ入力へ逆の動作を要求していた。** 「規則に合致する残骸を削除」は判定を**名前だけ**に置いており、利用者のファイルがたまたま合致すれば黙って消える。risk `strict`のplanで唯一の無条件削除だった。→ preflightを**専用subfolder + marker file**へ閉じ、削除条件を「名前の合致**かつ**markerの存在」にした。markerの無い同名実体は中止する(REQ-007)。
  4. **INV-003にVERが無かった。** 権限失効(REQ-004が想定)と競合したとき書き込みを試みないことは、この仕様で最も検証したい不変条件のひとつなのに、承認済み仕様に検証方法が無かった。→ VER-010を追加し、`T06`の受け入れ証拠へ書いた。
  - P2×6も解消(plan.mdの`[未到達]`とcovers空の記述、同一節での自己矛盾、`T02`受け入れ証拠の現在形、REQの並びと`REQ-005〜008`の範囲記法、ADR-002のhedgeの非対称)。
- 2026-08-14 / **3の修正は利用者から観測できる振る舞いを変える**(subfolderが一時的に現れる、markerの無い同名実体があると中止する)。`spec.md`へ**修正A-1として確認待ち**と明記した。

- Review attempt 3: `4fd6ab1..85fba32` — FAIL — P1×2、P2×8。**外部資料の中立性は2回連続で指摘ゼロ**(reviewerがpolicy原文を実取得し7項目突き合わせ)。attempt 2のP1-2(covers)とP1-4(VER-010)は伝播含め解消と確認された。
  1. **修正A-1そのものに欠陥がある。attempt 1のP1-3が形を変えて残っていた。** markerは所有判定を決定的にするはずだったが、**markerが必ず存在するとは限らない**。(a) subfolderを作ってからmarkerを書くまでの間に中断すると、**markerを持たない自分のsubfolder**が残る。それは「利用者のもの」と分類されて削除されず、REQ-007(3)で中止し、**そのfolderで永久に改名できなくなる**。しかも提示は「利用者の実体と衝突した」と事実に反する。(b) REQ-006の観測でmarkerを踏まないことが仕様で閉じていない(REQ-010が「名前が移動する」と明記しているのに、移動先がmarker名に当たる実装を禁じていない)。**`spec.md`の「中断で残った実体は必ずmarkerを伴う」は根拠なく断言していた。**
  2. **PR本文の`review base/head/range`が旧headのままだった。** これはattempt 2のP1-1で名指しされた項目であり、**その根本原因を記録したfinding自身のforward-testを、findingを追加したcommitが壊した**。同じ根本原因の3回目。
  - P2×8: ADR-002に`minSdk`の未解決記述が残存(訂正が一部fileで止まる型の再発)、REQ-007(3)の「削除できない」が削除試行を許す読みを残す、INV-002の「内側だけ」がsubfolder自体の作成・削除と矛盾しVER-005がすり抜ける、REQ-005の「代理として成立する」が同一mountを十分条件のように断定している(未検証項目に依存)、並行preflightが未定義、subfolderの外部可視性(MediaStore・gallery・同期app)が未定義、`T09`の`dependsOn`にT06/T07が無い、PR本文が「引用しない方針」と書いた段落で逐語引用している、`Evidence revision`が修正A-1の確認待ちを含んでいない。
  - **reviewerの判断: この状態でmergeしてはならない。** `Status: approved`の直下に「本文の一部は未承認」と書くとstatusが二値になり、downstreamの`T09`は承認済みの入力として受け取る。AGENTS.mdのauto-merge条件6を満たさない。
- 2026-08-14 / **3回連続FAILのため、AGENTS.mdに従い自動修正を停止し人間へ報告した。**
  - **否定された仮定**: 「markerを第二条件にすれば所有判定は決定的になる」。**決定的なのはmarkerが存在するときだけで、markerを書く前の窓と、観測がmarkerを壊す経路が残る。** attempt 1のP1-3(削除判定を名前だけに置いた)と根本は同じで、**複数stepの操作へ単一stepの不変条件を仮定した**点が共通している。穴を閉じたつもりで小さく移動させただけだった。
  - **P1-2の否定された仮定**: 「訂正の伝播先を`grep`で全文横断すれば足りる」。findingでPR本文を伝播先に含めたが、**その直後のcommitで自分のrangeを進めながらPR本文を更新しなかった。** 伝播先の列挙を一度書くだけでは足りず、**成果物を変えるたびに再評価する必要がある。**

## Current state / handoff

- Last checkpoint: **review attempt 3もFAIL。3回連続のため自動修正を停止した**
- Blocker category: decision
- Waiting for: **REQ-011の所有判定をどう閉じるかの人間の判断。** markerだけでは足りないことが判明した
- Requested action: 空のmarkerless subfolderを回収可能にするか、一時名→正規名の2段階作成で所有の確立を不可分にするか、両方採るかを決める
- Evidence revision: `dev@4fd6ab1` + ADR-002 + `spec.md` re-approval 2026-08-14(**修正A-1は未承認かつ欠陥あり**)
- Next Agent action: **勝手に直さない。** 判断を受けてからREQ-011を書き直し、P2を解消し、attempt 4を起動する
