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

## 他taskへの影響

- **`T07`(app内file browserの実装)** — 004 REQ-011(Android側)・REQ-015〜019・REQ-014のAndroid実装を持つ。`task.md`へ「仕様被覆」節を追加済み。**`013:T10`はdesktopでしか占有名を供給できておらず、`plan.md`のAndroid受け入れの証拠元は`T07`である。**
- **`008:T08`(読み込み導線と場所の提示を整える)** — 「**選択中のfolderが無い状態が通常**」を前提に設計せよと書いてあるが、**Androidではその前提が変わる**(REQ-016で選択は常に1 folder)。008が着手するときはこの節を読むこと。desktopでは前提のままである。
- **`012`(隠し・system file filter)** — REQ-017で「絞らない」を維持したので、先取りしていない。Androidで「文書」を絞る話も012の判別手段が確実になってから再検討する。

## 作業記録

- 2026-08-13 / ADR-002の採用決定を受けて定義。
- 2026-08-22 / 着手。`T02`の権限方針(013 spec REQ-001〜004)は承認済みで依存は解けていた。決めること5件のうち**2件を開発者へ確認**(FileKind、folder跨ぎ)、**3件はADR-002と決定D-2の制約からAgentが決めた**。004 specへREQ-011の改訂とREQ-015〜019・VER-005を書いた。**実装は`T07`が行う。このtaskはspecの更新と再承認までである。**

## Current state / handoff

- Last checkpoint: **004 specの更新を書き終えた。** `workspace.py check specs`はPASS
- Blocker category: **human approval**
- Waiting for: **004 specの再承認**(REQ-011の改訂、REQ-015〜019とVER-005の追加、REQ-012とREQ-002の注記)
- Requested action: 004 specの承認可否。**承認時に効く差分**は次の3点である
  1. **Androidから「文書」が消える**(REQ-011)。desktopは4つのまま
  2. **Androidで複数folderから集める選択ができなくなる**(REQ-016)。SAFの種類チップで事実上できていた
  3. **Androidの元場所ハンドルがSAF URIから絶対pathへ変わる**(REQ-002の注記。013 ADR-002の帰結)
- Evidence revision: branch `asdd/013-safe-android-rename/T03-define-android-file-browsing`、base は `dev@38bf66d`
- Next Agent action: **承認後、004 specのStatusを承認済みへ更新し、exact rangeの独立reviewを通してPRを作る。** このtaskは実装を含まないので`flutter test`等の実行結果は変わらない
