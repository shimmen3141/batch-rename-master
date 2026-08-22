# T03 Androidの読み込み導線を定義する

## 目的

Androidのfile選択をSAFからapp内のfile browserへ変える。その振る舞いを004 specへ反映し、再承認を得る。

## 入力と依存

- [`decisions/ADR-002`](../../decisions/ADR-002-android-rename-storage-boundary.md)の「受け入れた条件2」。
- `T02`で決まる権限の方針(権限が無いときに何を見せるか)。
- 004 spec。特にREQ-011(種類の選択)、決定D-2(実装が返したものをそのまま扱う)、REQ-006。
- `development-findings/2026-08-12-documentsui-type-chip-crosses-folders.md`。**SAFの種類chipがfolderを横断する問題は、app内browserでは起きない。**

## 配布要件でもある

**このtaskの設計はPlayのpolicy適合に直結する。** permitted usesの**File management**は「主目的がapp固有storage外のfileとfolderのaccess・編集・管理であること」だが、invalid usesには「**利用者が個々のfileを手で選ぶ file selection activity**」があり(資料は`Any`と書いて限定していない)、SAFを使うよう案内されている。代替の表には「fileを選んでimport / transfer / **processing**する用途」の行もある(詳細は[`research-matrix.md`](../T01-decide-storage-boundary/research-matrix.md)の「Playのpermitted uses」)。

**両立しうる読みであり、このappがどちらに当たるかは未解決である。** したがって、**単なるfile選択画面ではなく、folderとfileを管理する導線として作る**(File managementの定義へ寄せる)。**ただしそれで外れる保証は無い。** あわせて「このappの主目的をどう説明するか」も決める。policyはcore functionalityがstore説明文で目立つ形に記載・訴求されていることを求めており、**実装後に考えると間に合わない。**

## 決めること

1. **何を見せるか。** folder階層を辿るのか、既知の場所(Downloads、DCIM等)への近道を出すのか、両方か。
2. **`FileKind`(画像/動画/文書/すべて)をどう扱うか。** SAFのMIME filterが無くなるので、拡張子で絞るのか、絞るのをやめるのか。004 REQ-011の意味が変わる。
3. **複数folderをまたぐ選択を許すか。** SAFでは事実上できてしまっていた(上記finding)。app内browserでは**設計で決められる**。005の重複警告の頻度に直結する。
4. **hidden fileとsystem領域の扱い。** 012(隠しfilter)の先取りにならない範囲で、最低限何を見せないかを決める。
5. **desktopとの差。** desktopはOS pickerのまま。**同じappで選択体験が2つになる**ことを仕様として認める。

## 変更範囲

- 004 specの更新と再承認。
- **判定を新設しない。** 004の決定D-2は維持する。app内browserは「filesystemが返したものをそのまま見せる」。

## 受け入れ証拠

- 004 specの更新差分が、上記の決めることすべてに答えている。
- **人間による004 specの再承認。**
- ~~承認されたREQ IDをT07の`task.json`の`covers`へ書く~~ **`covers`はcross-featureの被覆を表現できない**(構造検査が所有planのspec.mdのIDとして引く。`013:T10`で観測)。代わりに**`T07`の`task.md`へ「仕様被覆」節を置き、004のREQ IDを書く**。
- `python <asdd-plugin>/scripts/workspace.py check specs`がPASS。

## 決めたこと(2026-08-22)

「決めること」への回答。**正本は[004 spec](../../../004-file-source/spec.md)のREQ-011・REQ-015〜019と「013:T03 由来の更新」節**。ここは索引である。

| 論点 | 決着 | 決定者 | 反映先 |
|---|---|---|---|
| 1. 何を見せるか | **保存場所の一覧 + 既知の場所への近道 + folder階層のすべて。** 現在地を示し上位へ戻れる。ADR-002が「単なるfile選択画面ではなく**folderとfileを管理する導線**として作る」ことをPlayのFile managementへ寄せる手段に挙げているため | Agent | 004 REQ-015 |
| 2. `FileKind`の扱い | **Androidでは絞らない。** 種類は「画像」「動画」「すべて」の3つで、**「文書」を出さない**。app内browserにMIME filterの手段が無く、拡張子リストを自前で持つと**リスト漏れでfileが黙って消える**。決定D-2と同じ理由 | **開発者** | 004 REQ-011 / REQ-017 |
| 3. 複数folderを跨ぐ選択 | **同一folder内に限る。** folderを移動すると選択が解除される。004 planの2026-08-05決定に素直で、占有名の列挙が1 folderで済む。**代償: SAFの種類チップで事実上できていた跨ぎ選択ができなくなる** | **開発者** | 004 REQ-016 / REQ-012 |
| 4. hidden fileとsystem領域 | **隠さない**(決定D-2を維持)。`/Android/`配下は書けない領域があるので**注記する**が、一次資料が「**大半の**subdirectory」としか書かず境界が文書化されていないため、**判定ではなく注記**とし可否は実行結果に委ねる(`/Android/media`は書けるので対象外)。**表示も選択も妨げない**。system領域は**REQ-015が定める遡行上限**によって到達経路を作らない(絞り込みで隠すのではない)。**範囲の定義は004 specのREQ-015とREQ-018が正本で、この表へ書き写さない** | Agent | 004 REQ-015 / REQ-017 / REQ-018 |
| 5. desktopとの差 | **仕様として認める。** desktopはOS pickerのまま、Androidはapp内browser。**同じappで選択体験が2つになる。** desktop側を寄せる作業は行わない | Agent | 004「対象外」 |

**Play policyへの寄せ方**は004 specの「013:T03 由来の更新」へ書いた。store説明文と`Permissions Declaration Form`は**人間の作業**でありspecの範囲外である。

## Playへの提出材料(人間の作業。ここは材料だけを用意する)

このtaskの「配布要件でもある」節が「あわせて**このappの主目的をどう説明するか**も決める」「実装後に考えると間に合わない」と書いている。**決めた内容が下である。** 提出操作そのものはAgentが行わない — 外部の公開・配布であり、[ADR-002](../../decisions/ADR-002-android-rename-storage-boundary.md)が「配布riskの受容であり、**原文を読んだうえでの人間の判断**」と明記している。

### 主目的の説明(草案)

policyは`core functionality`を「appの**主目的**であり、それが無ければappは壊れている状態になるもの」と定義し、**appの説明文で目立つ形に記載・訴求されていること**を求める([research-matrix](../T01-decide-storage-boundary/research-matrix.md)のPlayのpermitted uses)。したがって説明文の**冒頭**へ置く。

> 端末内のファイルとフォルダにアクセスし、**まとめて名前を変更して整理する**ためのアプリです。フォルダを辿ってファイルを一覧し、命名ルールを作り、**既存のファイルを上書きせずに**一括で改名します。

**語彙を「選ぶ」から「アクセス・編集・管理」へ寄せてある。** permitted usesの**File management**の定義が「app固有storageの外にあるfileとfolderへのaccess、編集、管理」であり、invalid usesが「利用者が個々のfileを手で選ぶ file selection activity」だからである。**これで外れる保証は無い**(両立しうる読みであり、資料はどちらが優先するかを書いていない)。

### Permissions Declaration Form に書くこと

policyの例外条項は**3条件すべて**を要する。**(ii)だけがこのrepoの分析で埋まる。**

| 条件 | 材料 | 状態 |
|---|---|---|
| (i) その権限が`core functionality`を成立させる | 安全な改名はfilesystemのpathを要り、pathはこの権限でしか得られない(ADR-002)。権限が無いと**改名という主目的そのものが成立しない** | **材料あり** |
| (ii) privacy-friendlyな代替が無いか、critical featureへ実質的な悪影響を与える | **ADR-002の一次資料分析がそのまま論拠になる。** SAFの`DocumentsContract.renameDocument`はproviderが**別名を採ることを許し**、要求した名前と結果名の同一性を保証しない(005 REQ-018 / INV-003を満たせない)。MediaStoreは実質media(画像・動画・音声)に限られ、004の`document`/`all`を覆えない | **材料あり(ADR-002)** |
| (iii) privacyへの影響がbest practiceで緩和されている | **未整理。** 材料になりうるのは「読み取りは利用者が辿ったfolderに限る」「改名以外のfile操作を持たない(004の対象外に明記)」「app外へdataを送らない」の3点だが、**このrepoで裏を取っていない** | **人間が用意する** |

あわせてConsoleの申告で「SAF/MediaStoreが不十分な理由」を説明する義務が別に加わる(説明だけでは足りず、3条件と併せて要る)。

### 提出前に人間が行うこと

1. **Playのpolicy原文と突き合わせる。** このrepoの記述はすべて**筆者の要約**であり、原文の転記ではない(research-matrixが明記)。要約と原文がずれていないかを確かめる。
2. **(iii)の材料を用意する。** 上表の3点でよいかを判断し、足りなければ足す。
3. **store説明文を確定する。** 上の草案は主目的の言い回しだけを決めたもので、文章全体ではない。
4. **提出し、承認を受ける。** 提出しない、または要件を満たさないappは**Playから削除されうる**。

### いつやるか

**2026-08-22 開発者決定: 提出物は草案で仮置きし、一通り完成してから提出する。** したがってこの節の内容は**提出前に読み直す材料**であって、いま提出操作を行うわけではない。**`T03`の完了条件にも含めない。**

**提出はAndroidが動くようになってから**(`T05` renameat2 port / `T06` 権限導線 / `T07` app内browserが揃った後)。ただし**説明文の主目的だけは先に決める**必要があった — policyが「説明文で目立つ形に訴求されていること」を求めており、後から言い換えると設計と食い違うためである。それがこの節である。

**却下された場合はAndroid未対応へ戻す**(ADR-002の退避経路。`saf_rename_executor.dart`とそのnegative testを維持している理由)。

## 他taskへの影響

- **`T07`(app内file browserの実装)** — 004 REQ-011(Android側)・REQ-015〜019・REQ-014のAndroid実装を持つ。`task.md`へ「仕様被覆」節を追加済み。**`013:T10`はdesktopでしか占有名を供給できておらず、`plan.md`のAndroid受け入れの証拠元は`T07`である。**
- **`008:T08`(読み込み導線と場所の提示を整える)** — 「**選択中のfolderが無い状態が通常**」を前提に設計せよと書いてあるが、**Androidではその前提が変わる**(REQ-016で選択は常に1 folder)。008が着手するときはこの節を読むこと。desktopでは前提のままである。
- **`012`(隠し・system file filter)** — REQ-017で「絞らない」を維持したので、先取りしていない。Androidで「文書」を絞る話も012の判別手段が確実になってから再検討する。

## 作業記録

- 2026-08-13 / ADR-002の採用決定を受けて定義。
- 2026-08-22 / **開発者が解き方Bと(a)を選択したので再開した。**
  - **B: 枠組みを変えた。** cross-taskの「仕様被覆」表から括弧書きの説明を全廃してREQ IDだけにし、**規範の範囲を規範の行の外へ書き写していないかを機械的に検査する道具**を入れた(`tool/check_normative_terms.py` / `tool/normative_terms.json`)。**検査は5件の書き写しを見つけた** — 独立reviewが挙げた2件(`T07`の仕様被覆表、`plan.md`の決定行)に加え、**指摘されていなかった2件**(004 spec自身の更新要約とAgent決定表)も含まれていた。**proseの規律では見落としていたことが、検査を作った時点で分かった。**
  - 検査が本物かを確かめた: `T07`の表へ`REQ-018(`/Android/data/`は改名できない旨)`を注入すると**FAILし、戻すとPASSする**。3回目の指摘そのものを再現できる。
  - あわせてP2-2(「自由とする点」に残っていたREQ-015の遡行上限の再記述)も消した。
  - **(a): 再承認後に加えたspec変更は「要求不変の明確化」として記録追記で足りるとする**(開発者判断)。004 spec の Status と `plan.md` の決定表へ、何を加えたかを書いた。
- 2026-08-22 / **独立review attempt 3 = FAIL(P1が1件、P2が4件)。同じ型の3回目である。** `T07`の「仕様被覆」表に`REQ-018(`/Android/data/`は改名できない旨)`と書いており、**範囲(`/Android/data/`限定)と強さ(断定)の両方が承認済みREQ-018と食い違っていた**。この表は`T03`の受け入れ証拠そのものであり、しかも**このrangeで新規に追加したもの**で、`T07`の実装者が最初に読む表である。attempt 2で問題視した「`/Android/data/`だけに断定文言で出すnarrow実装」を、**この表がそのまま指示していた**。
  - **`AGENTS.md`の「同じtaskで独立reviewが合計3回FAILした」に到達したので、`blocked`にして人間へ返す。** 修正には着手しない — 「同じ種類の修正を繰り返さず解き方を変える」局面である。
  - 他のP2: `plan.md`の決定表1文目にも同じ字面が残る / 004 specの「自由とする点」にREQ-015の遡行上限の再記述が**残っている**(今回REQ-018の同型記述を消した**2行上**である。適用が半分で止まった) / **再承認後に加えたspec変更**(代表例26bの追加、REQ-015の根拠を「一次資料」→「推論」へ)が承認記録に無い / handoffがattempt 2のままで作業記録と自己矛盾。
- 2026-08-22 / **独立review attempt 2 = FAIL(P1が1件)。** 「自由とする点」にREQ-018の範囲と強さを**書き写しており、そこが古いままだった**(範囲は`/Android/data/`限定、強さは「改名できない」と断定)。しかも「自由とする点」は**要求の上限を宣言する文**として読めるので、`/Android/data/`限定の断定実装がspec全体を満たしてしまう状態だった。代表例も旧範囲しか無く落とせなかった。**attempt 1と同じ根本原因(規範の範囲をREQ行の外へ複製する)なので、文言を直すのではなく複製を消した**(`AGENTS.md`の「同じ根本原因が2回続いたら解き方を変える」)。代表例へ`/Android/obb/`を足し、narrow実装が落ちるようにした。経緯は[finding](../../../../development-findings/2026-08-22-restating-a-requirement-outside-its-row-went-stale-twice.md)。あわせてP2を4件直した — 「保存場所の内側」の残骸、`/proc`等を「一次資料」と書いていた点(**推論である**)、代表例26とREQ-014の関係、SAF由来の理由文2箇所の`T07`への申し送り。
- 2026-08-22 / **独立review attempt 1 = FAIL(P1が2件)。** どちらも「決めたこと表には書いたが、004 specの観測可能な要求として落ちていない」型だった。(1) REQ-018が`/Android/data/`しか対象にしておらず、ADR-002が`[一次]`として挙げる`/sdcard/Android`の大半を外していた(`/Android/media`が書ける例外であることも落ちていた)。(2) REQ-015が遡行の上限を定めておらず、「system領域はそもそも辿れない」という決着が**仕様上は成立していなかった**(`/storage`や`/`まで遡れる実装が許される)。両方を直し、**REQ-018は判定ではなく注記**として書き直した — 一次資料が「大半の」としか書いておらず、厳密なpath判定にすると両方向に誤るため。**REQ-015の「保存場所の内側」は判定不能語だったので、開発者の指摘を受けて「保存場所(共有ストレージのボリューム)のroot」と具体化し、それが全ファイルアクセス権限が与える範囲そのものであることを根拠として書いた。** 修正版を2026-08-22に開発者が再承認した。あわせてreviewが挙げたP2を6件直した。
- 2026-08-22 / 着手。`T02`の権限方針(013 spec REQ-001〜004)は承認済みで依存は解けていた。決めること5件のうち**2件を開発者へ確認**(FileKind、folder跨ぎ)、**3件はADR-002と決定D-2の制約からAgentが決めた**。004 specへREQ-011の改訂とREQ-015〜019・VER-005を書いた。**実装は`T07`が行う。このtaskはspecの更新と再承認までである。**

## Current state / handoff

- Last checkpoint: **解き方B(機械検出)を適用し、規範の書き写しを5件すべて消した。** `tool/check_normative_terms.py`はPASS、`workspace.py check specs`もPASS
- Blocker category: なし(2026-08-22に開発者が解き方Bと(a)を選択し、解除された)
- Waiting for: 独立review attempt 4
- Requested action: なし(2026-08-22に解き方Bと(a)の選択を受領した)
- Evidence revision: branch `asdd/013-safe-android-rename/T03-define-android-file-browsing`、base は `dev@38bf66d`
- Next Agent action: **独立review attempt 4を通してPR #144をready化する。** このtaskは実装を含まないので`flutter test`等の実行結果は変わらない。**検証には`python3 tool/check_normative_terms.py`を加える**(解き方Bで入れた道具)。
