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
| 4. hidden fileとsystem領域 | **隠さない**(決定D-2を維持)。`/Android/data/`配下だけは書けないことが一次資料で確認済みなので**注記する**が、**表示も選択も妨げない** — 判定で機能を止めない。system領域は起点を保存場所の一覧にすることで**そもそも辿れない** | Agent | 004 REQ-017 / REQ-018 |
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
- 2026-08-22 / 着手。`T02`の権限方針(013 spec REQ-001〜004)は承認済みで依存は解けていた。決めること5件のうち**2件を開発者へ確認**(FileKind、folder跨ぎ)、**3件はADR-002と決定D-2の制約からAgentが決めた**。004 specへREQ-011の改訂とREQ-015〜019・VER-005を書いた。**実装は`T07`が行う。このtaskはspecの更新と再承認までである。**

## Current state / handoff

- Last checkpoint: **004 specの更新が2026-08-22に開発者から再承認された。** Playへの提出材料(主目的の説明の草案と提出チェックリスト)も用意した。`workspace.py check specs`はPASS
- Blocker category: なし
- Waiting for: 独立review
- Requested action: なし。**2026-08-22に004 specの再承認を受領した。** 承認時に確認した差分は3点 — Androidから「文書」が消える(REQ-011)、Androidで複数folderから集める選択ができなくなる(REQ-016)、Androidの元場所ハンドルがSAF URIから絶対pathへ変わる(REQ-002の注記)
- **人間の作業(このtaskの完了条件ではない)**: Playへの提出。**2026-08-22に開発者が「草案で仮置きし、一通り完成してから提出する」と決定した。** 上の「Playへの提出材料」は提出前に読み直す材料である。**この判断により、`T03`はPlayの提出を待たずに完了できる**
- Evidence revision: branch `asdd/013-safe-android-rename/T03-define-android-file-browsing`、base は `dev@38bf66d`
- Next Agent action: **exact rangeの独立reviewを通してPRを作る。** このtaskは実装を含まないので`flutter test`等の実行結果は変わらない
