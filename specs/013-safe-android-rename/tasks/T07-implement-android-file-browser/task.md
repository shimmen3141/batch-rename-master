# T07 app内file browserを実装する

## 目的

`T03`で承認された004 specどおり、Androidのfile選択をapp内のbrowserにする。SAFの選択導線を置き換える。

## 入力と依存

- `T03`で承認された004 spec。
- `T06`の権限状態(許可されていなければfilesystemを辿れない)。
- 現行実装: `lib/data/file_source/`、`lib/ui/file_source/file_source_bar.dart`、`lib/ui/file_source/file_kind.dart`。
- **008のUI整合**。008がfile_source_barの構成を触るので、着手時にどちらが先かを確認する。

## 変更範囲

- Android向け`FileSource`実装をSAFからpath baseへ差し替える。
- file browserの画面。
- `FileEntry`のhandleがAndroidで絶対pathになることに伴う周辺の調整。

**desktopは変えない。** OS pickerのままである(ADR-002 / `T03`)。

## 013 REQ-005 / REQ-006 を製品として観測可能にする(`T05`から引き継ぐ)

**`T05`は改名portを作ったが、composition rootは切り替えていない。** したがって
**Androidは今も`SafRenameExecutor`(安全な未対応)のまま**で、`renameat2`は製品の
経路に載っていない。`T05`が切り替えなかった理由は2つある。

1. Androidのハンドルがまだ**SAFのdocument URI**で、pathとして解釈できない。切り替えても
   `p.dirname()`がURIを分解して`notFound`になるだけである。**このtaskが絶対pathを
   供給して初めて成立する。**
2. **005 contract revision 5.1が今なおAndroid SAFを未対応と規定している**
   (REQ-017、OP-004の`errors`、用語「ハンドル」)。いま切り替えると**承認済み契約に
   反する。**

**したがって013 REQ-005 / REQ-006 を製品として観測可能にするのはこのtaskである。**

## 変更範囲(`T05`から引き継いだ分)

- **`platform_rename_executor.dart`から`if (Platform.isAndroid) return const SafRenameExecutor();`の
  行を消す。** これだけでAndroidも`DesktopRenameExecutor`を通る。Android専用のexecutorは
  存在しない — 劣化は native が返す`fallbackRequired`が駆動する([ADR-003](../../decisions/ADR-003-os-identity-at-native-boundary.md))。
  同fileのdoc commentに理由と切り替え条件が書いてある。
- **005 contractの再承認を取る。** REQ-017とOP-004の`errors`から「Android SAF経路は
  revision 2の未対応を維持する」を、用語「ハンドル」の「Androidは SAF の document URI」を、
  実態へ合わせる。**REQ-025も対象へ含める** — 劣化経路の通常renameは既存fileを置換しうる
  ので、「一度も上書きrenameを使わない」がAndroidでは文字どおりには成立しない
  (INV-002の環境依存条項と013 REQ-005が実質を認めているが、**製品経路に載せるのはこのtask
  なので、ここで明文化する**)。**規範を触るので人間の再承認が要る。**
- **`saf_rename_executor.dart`はwiringから外れるが削除しない**(ADR-002の退避経路。
  Playの宣言が却下されたらAndroid未対応へ戻す)。negative testも維持する。

## machine検証する範囲と引き受け先(AGENTS.md の宣言)

このtaskは**CIで実行できない領域**(Androidの実storage、mount、実機のUI)を含む。
**どこまでをこの環境で機械検証するか**と**その外側を誰が引き受けるか**を先に宣言する。
**宣言の外側の指摘は安全網の穴として扱う。**

| 対象 | この環境での検証 | 引き受け先 |
| --- | --- | --- |
| browserの操作(保存場所→近道→階層移動、現在地の提示、上位へ戻る、選択、確定、cancel) | **widget testで閉じる。** 一覧をportにしてfakeで再現する | — |
| 選択が同一folderに限られること(移動で解除。REQ-016) | **widget testで閉じる** | — |
| 絞り込まないこと(隠しfile・サブfolderもそのまま並ぶ。REQ-017) | **widget testで閉じる** | — |
| 改名できない可能性の注記(004 REQ-018)。**どの場所で出し、どこでは出さないかは004 specが正本** | **unit / widget testで閉じる。** pathの判定は純関数 | — |
| 保存場所のrootより上へ辿れないこと(REQ-015) | **testで閉じる。** 上位への遷移可否は純関数 | — |
| 未許可ならbrowserを開かないこと(REQ-019 / 013 REQ-001) | **widget testで閉じる**(`T06`のportをfakeにする) | — |
| `listNames`のAndroid実装(004 REQ-014 / 005 REQ-026) | **実fileで閉じる。** Linuxのtemp directoryで実際に列挙する。**Androidと同じ`dart:io`のAPI**を使う | — |
| Androidで`createPlatformRenameExecutor()`が`DesktopRenameExecutor`を返すこと | **testで閉じる**(写像を純関数へ出す。ADR-003と同じ形) | — |
| **実機のmount構成**(内部共有ストレージ / SDカード / USBの実際のpathと列挙結果) | **できない** | `013:T08` |
| **実機での書き込み可否**(004 REQ-018 が注記であって判定でないのはこのため — 注記が出る場所で成功しうるし、出ない場所で失敗しうる) | **できない** | `013:T08` |
| **実機でのbrowserの操作感**(tap範囲、狭幅、長いpathの見え方) | **できない** | [`manual-verification.md`](manual-verification.md) |
| **CのAndroid分岐の実挙動**(`T05`が受容した残余riskの再判定) | **できない**(NDK・実機が要る) | `013:T08` |
| Playの審査 | **できない** | 人間(`spec.md`の未解決) |

## 受け入れ証拠

- browserの操作(階層移動、選択、確定、cancel)が004 specどおりであることをwidget testで検査する。
- filesystemをportで抽象化し、testが実機に依存しないこと。
- 004の既存test(読み込み契約、置き換え、cancel、警告)が仕様変更後の形で継続PASSする。
- 選択したfileがどのfolderに属するかを保持する。**別の媒体(SDカード、USB)を跨いだ選択でfolderの区別が失われないこと**をtestで検査する。`T10`が対象folderの実在entry名をfolder単位で列挙し占有名を作るため、ここで潰すと衝突判定が正しい単位で行えない。
- **`listNames`(004 REQ-014)がAndroidで成功し、読み込んでいないfileとの衝突が実行前に警告として出ることを確認する**(005 REQ-026 / 例25)。**`T10`はこの受け入れをdesktopでしか満たしていない** — SAFは`pickFiles`で1fileずつの読み取り権限しか取らず親folderを列挙できないため、現在の`SafFileSource.listNames`は理由付きの失敗を返し、REQ-027により実行が止まる。app内browserが持つ列挙権限で`listNames`を実装し直すのはこのtaskである。`plan.md`の全体の受け入れ証拠「**Androidで**、同じことが成立する」はここが証拠元になる。
- `flutter test` / `flutter analyze` / `dart format --output=none --set-exit-if-changed .` がPASS。
- **Androidで`createPlatformRenameExecutor()`が`DesktopRenameExecutor`を返す**ことをtestで検査する(013 REQ-005 / REQ-006 が製品の経路に載る)。- **`T05`が受容した残余riskのうち2件を再判定する。** `T05`の「受容した残余risk」表の1行目(CのAndroid分岐の実挙動)と4行目(劣化経路)は、**このtaskが切り替えた時点で条件1(製品経路に載っている)が成立する**。AGENTS.mdの3条件で判定し直し、満たすものはここで閉じる(満たさないものは`T08`へ渡す)。`platform_rename_executor_test.dart`の「composition rootはまだAndroidを切り替えていない」testは**消さずにこの検査へ置き換える**。
- **`saf_rename_executor.dart`のnegative testが継続PASSする**(退避経路の維持)。
- **005 contractの再承認を得ている**(REQ-017 / OP-004 / REQ-025 / 用語「ハンドル」)。
- [`manual-verification.md`](manual-verification.md)で実機の選択導線を確認する。
- exact rangeの独立reviewがPASSする。

## 仕様被覆

`T03`が004 specへ定義し、開発者が承認したREQを実装する。**表はID だけを持つ。** 何を要求しているかは正本を読むこと — **説明を書き写すと、正本を直したときにここが古くなる**(`013:T03`で3回続いた。[finding](../../../../development-findings/2026-08-22-restating-a-requirement-outside-its-row-went-stale-twice.md))。`tool/check_normative_terms.py`が書き写しを機械的に検出する。

**`013`の権限のREQ-001〜004は`T06`と分担する。** 分担の内容は`T06`の`task.md`を見ること。

**このtaskが持つのはAndroid側だけである。** 004 REQ-011はdesktopの種類選択も、REQ-014はdesktopの`listNames`も規定しており、そちらは既に`004:T09`と`013:T10`が実装済みである。**どこがAndroid側かは004 specのVER-005が示す。**

**この表と機械検査は書き写しの一部しか止めない。** 検査(`tool/check_normative_terms.py`)が見るのは登録した literal の一致だけで、要求の**強さ**やliteralを持たない要求の範囲は検出できない。**実装前に正本を読むこと。****`task.json`の`covers`は空のままにする** — このworkspaceの構造検査は`covers`を**所有planのspec.mdのID**として引くので、他featureのIDを書くと未解決参照の警告になる(`013:T10`で観測。[finding](../../../../development-findings/2026-08-21-covers-cannot-express-cross-feature-coverage.md))。

| 正本 | 被覆するID |
|---|---|
| 004 spec | REQ-011、REQ-014、REQ-015、REQ-016、REQ-017、REQ-018、REQ-019、VER-005 |
| 013 spec | REQ-001、REQ-002、REQ-003、REQ-004、REQ-005、REQ-006 |

**`listNames`(004 REQ-014)のAndroid実装はこのtaskが持つ。** `013:T10`はdesktopでしか占有名を供給できておらず、`plan.md`の全体の受け入れ証拠「**Androidで**、読み込んでいないfileとの衝突が実行前に警告として出る」の証拠元はここである。

## `T05`が受容した残余riskの再判定(2026-08-24)

**このtaskがcomposition rootを切り替えたので、条件1(製品経路に載っている)が成立した。**
AGENTS.mdの3条件で判定し直した。

| `T05`が受容した穴 | 1. 製品経路 | 2. 失敗の種類 | 3. CIで閉じる | 判定 |
| --- | --- | --- | --- | --- |
| CのAndroid分岐(生syscall、flag、errno写像)の**実挙動** | **✓ 成立した** | ✓ 無断置換・偽の成功 | **✗** NDK・実機が要る | **受容を維持。** `013:T08`が引き受ける。**Dart側から見える範囲は`T05`が実行して閉じている**(shim harnessでerrno全域)ので、残るのは「Androidの実kernelで本当に効くか」だけである |
| 劣化経路(`plain_rename.dart`、`_renameOnce`の劣化枝、`_nativeError`の`fallbackRequired`)が**今日は到達しない** | **✓ 成立した** | ✓ | ✓ | **閉じた。** Androidが`DesktopRenameExecutor`を通るようになり、劣化経路は製品経路上にある。`M44`〜`M56`が既に固定しており、**新たに足すものは無い** |

**`T05`の宣言表のうち、このtaskで状況が変わったもの。**

- 「composition rootがAndroidで`DesktopRenameExecutor`を返すこと」は`T05`では「しない」
  だったが、**このtaskで閉じた**(`M103`)。
- 「`__arm__`のsyscall番号」「Android向けの実compile」「実機での`renameat2`の挙動」は
  **変わらず`013:T08`**である。

## 他の正本への申し送り

- **004 spec の SAF 由来の理由文が2箇所 stale になる。** REQ-003 の「SAF には作成日時の列が無いため」と検証節の「SAF は常に不明を返すため」は、Android が直接 path access へ移ると前提が変わる(`stat` にも作成時刻は無いので**結論は変わらない**が、理由が違う)。**要求そのものは有効**なので `T03` では触っていない。このtaskで Android の実装を入れる時点で理由文を直すこと。
- **005 contract の用語「ハンドル」が stale になる。** 現在の定義は「004 が供給する不透明な識別子(**Android は SAF の document URI**、デスクトップは絶対 path)」だが、`013:T03` の 004 REQ-002 で **Android も絶対 path へ変わる**。**規範部分ではない**(用語の例示)ので `T03` では触っていない。**このtaskが Android の実装を入れる時点で、005 contract の用語を更新して再承認を取ること。** 実装と用語が食い違ったまま残すと、契約を読んで実装する次のAgentが誤る(`013:T10` の OQ-007/008 と同じ型)。

## 作業記録

- 2026-08-13 / ADR-002の採用決定を受けて定義。
- 2026-08-24 / **着手。** `008`は全taskが未着手なので、**`013:T07`が先**である(`task.md`の「008との作業重複を先に確認する」への回答)。`008:T08`の「T07との分担」節が「T07が先の場合、T08は重複しない粒度を選ぶ」と定めているので、**行ごとの場所の提示はこのtaskが確定させ、一覧全体の提示は`008:T08`が後から合わせる**。

## 決めたこと

| 論点 | 決着 | 理由 |
|---|---|---|
| browserのUIをportにするか | **一覧だけをportにし、画面はUI層に置く** | `FileSource`が`Navigator`を知ると、testがwidgetを要るようになる。`BrowserPicker`(選択を返す関数)だけを受け取れば、`AndroidFileSource`は実fileで閉じられる |
| rootより上へ辿らせない方法 | **辿れないことで達成する**(絞り込みで隠さない) | 004 REQ-015の要求そのもの。rootで「上へ」を押すと保存場所の一覧へ戻り、`/storage`を列挙しに行かない — testで確認済み |
| 保存場所の列挙 | **`/storage`の中身から作る**(`emulated`と`self`は除く) | 内部共有ストレージは`/storage/emulated/0`、取り外し可能なボリュームは`/storage/<id>`。**列挙に失敗しても内部ストレージだけは返す** — 空にすると「保存場所が無い」と見える |
| 並び順 | **フォルダが先、その中で名前順** | 辿るための並べ替えであって、絞り込み(REQ-017が禁じている)ではない |
| 作成日時 | **取得しない**(`null`) | POSIXの`stat`に作成時刻が無い。**SAFに列が無かったのと結論は同じだが理由が違う**ので、004 specの理由文を言い直した |
| 選んだ直後に消えていたfile | **落とす**(`Picked`に含めない) | 読めないものをentryにすると、以後の経路が`notFound`で落ちる。**空リストで「決定した」と混同しない**型は保たれる |

## 検証結果

| 種別 | commandと結果 |
|---|---|
| full regression | `flutter test` = **PASS(571件)**。T07着手前は540件 |
| static analysis | `flutter analyze` = **PASS** |
| format | `dart format --output=none --set-exit-if-changed .` = **PASS** |
| ASDD構造 | `python3 <asdd-plugin>/scripts/workspace.py check specs` = **PASS** |
| 規範の書き写し | `python3 tool/check_normative_terms.py` = **PASS** |
| OS境界 | `python3 tool/check_platform_boundary.py` = **PASS**(46 file、4 rule) |
| mutation | `M103`〜`M112`(T07分)= **10 KILLED, 0 SURVIVED, 0 SKIPPED** |
| **Android build** | **未実施。** AI containerにSDK・NDKが無い |
| **実機確認** | **未実施。** [`manual-verification.md`](manual-verification.md) を人間へ依頼する |

**mutationで2件がSURVIVEDしてから直した。** `M111`(所属folderをハンドルから導出する)は
`sourceFolder`と`p.dirname(handle)`が一致するfixtureしか使っておらず、**導出に変えても
通っていた**。`.`を含むpathで区別できるようにした。`M112`(Androidにも「文書」を出す)は
`fileKindsFor`にtestが1本も無かった。

## 独立review attempt 1 の結果(2026-08-24)= FAIL

range は **`57c5e69...b42e116`**(reviewerが実測した `git merge-base dev HEAD`)。
**依頼時に渡した `b318251` は誤り**で、T06 merge 後の分岐点は `57c5e69` である(P2-1)。

**中核は仕様どおりと確認された。** browserの階層・選択・注記・`listNames`・composition root の
切り替えはいずれも反証を通り、`M103`〜`M112` の10件も再現された。**005 contract revision 6 の
REQ-025 への追記は「既に受容済みの窓の明文化であって、新しい保証の緩和ではない」と判定された**
(INV-002 の環境依存条項と同一の窓であること、他の要求を1つも削っていないこと、
非劣化時の強さが保たれることを根拠に挙げている)。

| # | 指摘 | 分類 | 対応方針 |
| --- | --- | --- | --- |
| P1-1 | **005 contract が自己矛盾している。** `scope.in` と `OP-004.nondeterminism` に「Android SAF **production経路**は未対応/成功を返さない」が revision 2 のまま残る | 成果物の欠陥 | **案(A)で直す**(下記)。規範なので**人間の承認が要る** |
| P1-2 | **005 `spec.md` が revision 6 に一切追随していない。** Status行の版列挙、外部依存表(出典のREQ-017/OP-004から消えた文を引用)、代表例23、「未完成な点」、検証節、`createdAt` の理由文。`product-map.md:15` も同型 | 成果物の欠陥 | 同上 |
| P1-3 | **004 spec の VER-004 / VER-005 が指す成果物ディレクトリ(`test/spec_004_file_source/`)に、その検査が無い。** 新testは `test/spec_013_android_rename/` に置いた。先例(`013:T10`)は004側へ置いている | 成果物の欠陥 | **testを `test/spec_004_file_source/` へ移す**(spec を触らずに済む側を採る) |
| P1-4 | **`AndroidStorageBrowser` に test が1本も無い。** reviewerの`RV01`(列挙失敗を空の一覧へ落とす=**読めないfolderが空のfolderに見える**)がSURVIVED。**3条件をすべて満たす**(製品経路 ✓ / 偽の成功 ✓ / `primaryRoot`が注入可能なのでtempで閉じられる ✓) | 安全網の穴(FAIL) | **temp directoryを root にした test を足す。** `RV01`〜`RV04` を表へ取り込む(`RV03`/`RV04`は対照として残す) |
| P2-1 | `Evidence revision` の base が「実測値」と称して実測と違う | 成果物の欠陥 | 直した |
| P2-2 | **004 代表例 26d は「root で上位へ戻る操作は無いか無効」**だが、実装は有効なまま出して保存場所一覧へ戻る。安全側(`/storage`へ辿れない)は満たす | 成果物の欠陥 | **実装を代表例へ寄せる**(root では `browser-up` を出さない)。manual の該当期待も直す |
| P2-3 | `lib/` に stale な doc comment(`main.dart` の「Android=SAF」、`file_source_bar.dart` の「Android SAF」「文書」) | 成果物の欠陥 | 直す |
| P2-4 | **manual が現revisionでは観測できない期待を含む。** §5 の `/Android` 直下は通常 file が無く、`data`/`obb` は列挙が拒まれうる。§3 の重複警告、§4 の fixture reset が未記載 | 成果物の欠陥 | 直す。**PASS するまで人間へ渡さない** |
| P2-5 | Android 側の `sourceFolder` を正規化していない(desktop は `folderHandleOf` で正規化)。**今日は割れない**が、その論拠がどこにも無い | 記録の欠陥 + 安全網の穴 | **論拠を書いて受容**(`list(followLinks: false)` により symlink を辿れず、folder 文字列の出所が2つしか無い)。legacy symlink 端末は `013:T08` |
| P2-6 | `task.json.covers` と `task.md` の記述が三方向で食い違う(`[]` にすると書きながら `["REQ-001","REQ-005","REQ-006"]`) | 成果物の欠陥 | 直す |
| P2-7 | 置き換えで ADR-003 追補の注記が巻き添えで消えた | 記録の欠陥 | 戻す |
| P2-8 | 内部共有ストレージ root から選ぶと行の「場所」が `0` になる(004 REQ-009 は人間可読を要求) | 成果物の欠陥(軽微) | 直す(browser と同じく保存場所名へ置き換える) |

**reviewerの補足**: `SafFileSource` も wiring から外れたが、ADR-002 が退避経路として明記して
いるのは**改名側だけ**である。読み込み側も残す理由を1行書くとよい。

### P1-1 / P1-2 の方針(人間の承認が要る)

**案(A)を採る**: **005 contract を revision 6.1 とし、記述訂正だけを行う。**

- `scope.in` と `OP-004.nondeterminism` の「Android SAF **production**経路は未対応」を、
  **退避経路として保持する**という書き方へ言い直す。
- 005 `spec.md` の Status 行・外部依存表・代表例23・「未完成な点」・検証節・`createdAt` の
  理由文と、`product-map.md` の 005 行を revision 6 へ揃える。
- **要求(must)は1つも変えない。** revision 5.1 と同じ「記述訂正だけ」の扱いにできる。

**案(B)(spec.md を後続taskへ送る)を採らない理由**: merge 後しばらく契約と spec.md が
食い違ったまま `dev` に載る。013 の残 task がこの spec.md を読むので、`013:T10` の
OQ-007/008 と同じ型の誤りを招く。

**案(C)(spec.md の該当表を契約から生成する / 出典列を機械検査へ入れる)は今回採らない**が、
**この型の指摘が `013:T03` から繰り返し出ている**のは事実なので、finding へ記録して
plan完了時に判断する。

## Current state / handoff

- Last checkpoint: **独立review attempt 1 = FAIL(P1が4件、P2が8件)。** 中核は仕様どおりと確認された。指摘の対応方針は上表のとおり決めてある
- Blocker category: なし
- Waiting for: **P1-1 / P1-2 の方針(案A)の承認**。それ以外は承認を待たずに着手できる
- Requested action: なし
- Evidence revision: branch `asdd/013-safe-android-rename/T07-implement-android-file-browser`、base は `dev@57c5e69`(`git merge-base dev HEAD` の実測値。当初 `b318251` と書いたのは誤りで、T06 merge 後の分岐点はこちらである)
- Next Agent action: **上表の対応方針どおり直す。** 順序は (1) P1-4 の test と `RV01`〜`RV04` の取り込み、(2) P1-3 の test 移動、(3) P2-2〜P2-8、(4) 承認が下りたら P1-1 / P1-2 を revision 6.1 として直す。そのあと attempt 2 を起動し、PASS してから manual を依頼する。**range は `57c5e69...HEAD` で取ること。**
- **`T08`への申し送り**: このtaskで**Androidが`DesktopRenameExecutor`を通るようになった**ので、`T05`が受容した「CのAndroid分岐の実挙動」は**製品経路上のrisk**になった。実機で`renameat2`が効くか、効かない端末で通常renameへ落ちるかを確認すること。あわせて**実機のmount構成**(保存場所の一覧が正しいか)と**`/Android/`配下の実際の書き込み可否**も見ること。
