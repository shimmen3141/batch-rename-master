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
| ADR-003のallow listを広げるか | **`lib/main.dart`を`Platform.is`のallowへ足した** | app全体のcomposition rootで、どのportを配るかをここで決める(種類の写像`fileKindsFor(isAndroid:)`)。**ガードレールを1file分広げた**ので記録する(独立review attempt 2 のP2-6)。`platform_file_source.dart`側へ寄せれば広げずに済んだが、種類はUIの関心なのでcomposition rootに置いた |
| 選んだ直後に消えていたfile | **落とす**(`Picked`に含めない) | 読めないものをentryにすると、以後の経路が`notFound`で落ちる。**空リストで「決定した」と混同しない**型は保たれる |

## 検証結果

| 種別 | commandと結果 |
|---|---|
| full regression | `flutter test` = **PASS(589件)**。T07着手前は540件 |
| static analysis | `flutter analyze` = **PASS** |
| format | `dart format --output=none --set-exit-if-changed .` = **PASS** |
| ASDD構造 | `python3 <asdd-plugin>/scripts/workspace.py check specs` = **PASS** |
| 規範の書き写し | `python3 tool/check_normative_terms.py` = **PASS** |
| OS境界 | `python3 tool/check_platform_boundary.py` = **PASS**(46 file、4 rule) |
| mutation | `M103`〜`M121`(T07分)= **19 KILLED, 0 SURVIVED, 0 SKIPPED**。うち`M113`〜`M116`と`M119`〜`M121`は**独立reviewerが足したもの**(`M115`/`M116`/`M121`は対照) |
| **Android build** | **未実施。** AI containerにSDK・NDKが無い |
| **実機確認** | **実施済み(2026-08-25)。** [`manual-verification.md`](manual-verification.md) の手順1〜6が期待どおり。環境 `sdk_gphone16k_x86_64`、対象commit `56b6a0e`(下の「manual 実行2回目」) |

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

## 独立review attempt 1 の指摘の始末(2026-08-25)

| # | 始末 |
| --- | --- |
| P1-1 / P1-2 | **contract を revision 6.1 として記述訂正**(2026-08-25 開発者承認、案A)。`scope.in` と `OP-004.nondeterminism` の「Android SAF **production**経路」を「SAFのrename APIを呼ぶ改名経路を**退避経路として保持する**」へ言い直した。005 `spec.md`(Status行の版列挙、外部依存表、代表例23、「未完成な点」、検証節、`createdAt`の理由文)と `product-map.md` を revision 6 へ追随させた。**要求(must)は1つも変えていない** |
| P1-3 | **testを `test/spec_004_file_source/` へ移した。** 004 spec の VER が成果物を「ディレクトリ + 種別」で指定しており、そこが規範側のlocatorである。spec を触らずに済む側を採った |
| P1-4 | **`android_storage_browser_test.dart` を新設**(12件)。temp directory を保存場所に見立てて、保存場所の列挙・近道の実在確認・絞り込まないこと・**「読めなかった」と「entryが無い」の区別**を実 file で閉じた。reviewer の `RV01`〜`RV04` を `M113`〜`M116` として取り込んだ(`RV03`/`RV04` は**対照**として残す) |
| P2-1 | `Evidence revision` の base を実測値 `57c5e69` へ直した |
| P2-2 | **実装を代表例26dへ寄せた。** root では「上へ」を出さず、保存場所を選び直す導線に替えた(`M117`)。manual の期待も直した |
| P2-3 | `main.dart` と `file_source_bar.dart` の stale な doc comment(「Android=SAF」「文書」)を直した |
| P2-4 | manual を直した。§3 は元の名前を含むルールにして重複ダイアログを避け、§4 は**fixture の reset を明記**、§5 は `/Android` 直下に file が無いこと・`data` が開けないことがあることを**期待に含めた** |
| P2-5 | **受容する**(下記) |
| P2-6 | `task.json.covers` を `task.md` の指示どおり `[]` にした |
| P2-7 | ADR-003 追補の注記を戻した |
| P2-8 | **行の「場所」を人間可読にした。** browser が保存場所名を composition root へ知らせ、`AndroidFileSource` がそれを使う(`M118`)。root の basename `0` は出ない |

**mutationで2件がSURVIVEDしてから直した。** `M118`(表示用の場所)は test が無かった。
`M109` は代表例26d対応で対象が到達不能になったので、**冗長な処理を外して**
「近道は保存場所の始まりだけに出す」へ差し替えた。

### 受容した残余risk

| 残余risk | 満たさない条件 | 引き受け先 |
| --- | --- | --- |
| Android側の`sourceFolder`を正規化していない(desktopは`folderHandleOf`で正規化する)。**今日は割れない** — browserがfolder文字列を作る経路は`StorageLocation.root`と`Directory.list`の返すpathだけで、`list(followLinks: false)`によりsymlinkは`Directory`と判定されず**辿れない**ので、同じ場所への表記は1つしか生じない | 3(**割れる表記が実際に現れるかが実機のmount構成に依存する**。`/storage`直下に`sdcard0`のようなlegacy symlinkがある端末では、同じボリュームが2つの保存場所として並びうる) | `013:T08`(宣言表の「実機のmount構成」に含まれる) |
| `SafFileSource`もwiringから外れたが、`saf_file_source.dart`とtestは残している。**ADR-002が退避経路として明記しているのは改名側だけ** | — | **読み込み側も同じ理由で残す。** Playの宣言が却下されたらAndroid未対応へ戻すので、改名側だけ残しても復帰できない。ADR-002の趣旨に沿う判断であり、`013:T08`の実機確認が済むまで削除しない |

## 独立review attempt 2 の指摘の始末(2026-08-25)= PASS

**未解決のP0/P1は無く、P2が6件**だった。reviewerは attempt 1 の P1 4件がすべて閉じたことを
確認している — contract revision 6.1 の差分を切り出して「**`requirements[]` の `statement` は
1つも変わっていない。記述訂正だけは事実**」と検証し、`android_storage_browser_test.dart` の
assertion が弱くないこと、`RV01`〜`RV04` の取り込みが意味を弱めていないことも確かめた。

| 指摘 | 始末 |
| --- | --- |
| **P2-1**: 行の「場所」が、どのfolderから読み込んでも保存場所名になる | **直した。**「保存場所名 + rootからの相対」にした(`内部ストレージ/DCIM/Camera`)。**attempt 1 の P2-8 でrootを直したときに非rootを壊していた**(`M119`/`M120`) |
| **P2-2**: manual §4 がそのとおり実行しても警告が出ない | **直した。**(a) 拡張子は変わらないので**`.txt`を読み込む**と明記、(b) 007のルール永続化で前回のルールが復元されるので**トークンを全部外してから作り直す**と明記 |
| **P2-3**: manual に current revision に無いUI名 | **直した。**「＋ 元の名前」「＋ 自由テキスト」(実装と一致を確認)、保存場所を選び直すアイコンの説明 |
| **P2-4**: `product-map.md` の013行が追随漏れ | 直した |
| **P2-5**: 外部依存表の新しい行の出典が観測ではなく契約の版 | **直した。**「Dart側は`013:T05`のshim harnessで観測。実機は`013:T08`が未実施 — この行はまだ実機で確かめた事実ではない」 |
| **P2-6**: ADR-003 の allow list を広げたことが記録に無い | **直した。**「決めたこと」表へ足した |

**`RV05`〜`RV07` を `M119`〜`M121` として取り込んだ**(`RV07` は対照)。P2-1 を直したので
`RV05`/`RV06` は KILLED になった。

## manual の準備手順を PowerShell へ置き換えた(2026-08-25)

**エミュレータのファイルアプリでは新しいファイルを作れない**ことを、人間が実際に
試して確認した。[`manual-verification.md`](manual-verification.md) は fixture の用意を
「PC から転送しても、端末のファイルアプリで作ってもよい」としていたため、**そのままでは
手順1に入れなかった。**

`005:T05` と `docs/development/emulator-verification.md` の先例に合わせ、`adb` を
`$adbPath` へ束ねた PowerShell を各手順へ置いた。

- 準備: `test1.txt` / `test2.jpg` / `test3.pdf` を temp へ作って `adb push` する。
- 手順3・手順4の確認: **ファイルアプリではなく `adb shell ls -l` と `cat` を正とする**。
  `adb push` したファイルは端末のメディア索引にすぐ載らず、ファイルアプリの表示が
  実体と食い違うためである(アプリ側は索引ではなく filesystem を直接見るので影響を
  受けない — **選択画面に出なければ不具合**、と手順書へ書いた)。
- 手順4: fixture の reset と `keep.txt` の設置を1つの block にまとめ、衝突後の期待を
  `keep (1).txt`(`_withSuffix` の実装)まで具体化した。
- 手順5: **fixture は用意しない**と明記した。注記が出る側はアプリから読めないことが
  多く、置いても手順3と同じ「開けませんでした」になるだけである(実機の境界は `013:T08`)。
  **一度は `Android` 配下へ file を置く block を書いたが、`tool/check_normative_terms.py`
  が5件の違反として落とした** — 注記の範囲は 004 spec が正本で、path の literal を manual
  へ書けない。**自分の task file を allow へ足すのは `013:T03` attempt 4 が指摘した
  自己免罪の型なので採らず、手順を元の形へ戻した。**
- 後片付けの block を足した。

経緯は [finding](../../../../development-findings/2026-08-25-manual-preconditions-were-not-executable-on-the-verification-device.md) へ記録した。

**変更したのは manual だけで、実装・test・仕様は触っていない。** attempt 2 の PASS 判定は
実装差分に対するものなので取り消さないが、**この差分は `final-evidence` の review 範囲に
含まれる**(base は変わらず `dev@57c5e69`)。

## manual 実行1回目(2026-08-25)= 旧buildのため無効

**人間が6手順すべてを実行したが、端末に入っていたアプリは `dev`(`57c5e69`)のbuild
だった。** このtaskの成果は1つも観測されていない。**再実行が要る。**

旧buildと一致した観測(参考として残す)。

| 手順 | 観測 | 旧buildの何か |
| --- | --- | --- |
| 1 | ハンバーガーメニュー、サイドバー、パンくず、`sdk_gphone16k_x86_64`、前回の場所を復元、上向き矢印が無い | **Android標準のファイル選択画面**。`createPlatformFileSource()` が `SafFileSource` を返す `dev` の wiring |
| 3 / 4 | 「フォルダ内のファイル名を確認できないため実行しませんでした。`content://com.android.externalstorage.documents/...`: SAF ではフォルダ内のファイル名を一覧できません」 | `saf_file_source.dart:99`。**`013:T10` が入れた仕様どおりの停止**(005 REQ-027)であり、旧buildとしては正しい |
| 5 | `Android` 直下でも注記が出ない、`data` が無い | 注記も階層も app 内 browser の機能。旧buildには無い |
| 6 | 1つ目のtapでそのまま確定、複数選択に長押しが要る | DocumentsUI の挙動 |

**このbranchの wiring は正しい**ことを確認した — `lib/main.dart:94` が
`StorageBrowserView(browser: const AndroidStorageBrowser())` を渡し、
`platform_file_source.dart:25` が `AndroidFileSource` を返す。`dev` 側は
`SafFileSource()` である(`git show dev:lib/data/file_source/platform_file_source.dart`)。

**manual へ `## 0. いま動いているのが、このタスクのビルドか確かめる` を足した。**
新旧の画面を両方書き、旧buildだと手順3でどう見えるかまで書いた。経緯は
[finding](../../../../development-findings/2026-08-25-manual-verification-ran-against-a-stale-build.md)。

**`git branch --show-current` では検出できない事故である** — host と container は作業
ツリーを共有しているので **branch は最初から正しかった**。古いのは端末の APK だけで、
`docs/development/emulator-verification.md` の既存の警告(2026-08-05)は branch の確認で
閉じている。

## manual 実行2回目(2026-08-25)= 全手順が期待どおり

**このtaskの受け入れのうち、実機でしか確かめられないものが観測された。**

| 項目 | 値 |
| --- | --- |
| 環境 | Android emulator(`sdk_gphone16k_x86_64`)。Windows host、`flutter run` |
| 対象commit | `56b6a0e`(手順0で確認を求めた値)。**`287a03d` 以降 `lib/` `android/` `test/` `pubspec.*` に差分は無い**ので、この範囲のどのcommitでbuildしても同じcodeである |
| 実行者 | 開発者(人間) |

| 手順 | 結果 |
| --- | --- |
| 1 保存場所と階層 | **期待どおり。** 近道(Download / DCIM / Pictures / Documents / Movies / Music)が上に並び、階層を辿れ、現在地が出て、rootより上へは行けない |
| 2 選択して読み込む | **期待どおり。** 絞り込まれず、選んだ分だけが一覧に入る |
| 3 名前を変更する | **期待どおり。Androidで実際にfileの名前が変わった**(013 REQ-005 / REQ-006 が製品経路で観測された) |
| 4 読み込んでいないfileとの衝突 | **期待どおり。** 実行前に警告が出て、`keep.txt` は上書きされず番号が付いた(004 REQ-014 / 005 REQ-026 がAndroidで成立)。Download に過去のfolderが残っていたが影響なし |
| 5 アプリごとの保存領域 | **期待どおり。** 注記が出て、`data` は「このフォルダを開けませんでした」になった(REQ-018 / REQ-014 の区別) |
| 6 操作感 | 手順書の項目は問題なし。**別途UIの改善点を6件受領**(下記) |

**1回目(旧build)の観測は無効である。** 上の表が有効な証拠である。

### 受領したUIの改善点(このtaskでは直さない)

**`008` が受け皿である**(`008/plan.md`「実機で触って出るUIの指摘は今後も増える前提で、
新しい指摘は原則このplanへtaskとして足す」)。**ここで直すと、いま得た実機証拠が
対象commitに対応しなくなり、manualをもう一度依頼することになる**(AGENTS.md
「manual証拠は対象commit以後にcode、dependency、build設定が変わったら再利用しない」)。

| # | 指摘 | 送り先 |
| --- | --- | --- |
| U1 | 保存場所が1つしかないなら、最初からその中に入った状態にしたい | **`008`(004 REQ-015 の変更を伴う)。** 現在の REQ-015 は「保存場所の一覧から始まる」を **must** で要求しており、**実装の裁量では変えられない**。仕様更新taskと実装taskを分ける |
| U2 | 近道(★)と実体のfolderが同じ列に並び、区別が付かない。**★を通常のfileだと思った**。同名のfolderが下にも出るので違和感がある | **`008`。** REQ-015 は「近道を示す」までを要求し、示し方は規定していない |
| U3 | 上へ戻る矢印は `↑` より `←` の方が馴染む | `008` |
| U4 | fileのcheckboxに加えて、画像やテキストのpreviewを出したい | `008`(新規の提示。**MediaStore を使わない範囲で何ができるかの調査が要る**) |
| U5 | modalの文言と見せ方に改善の余地 | `008`(**どのmodalかの特定が要る**) |
| U6 | 「すべて」を開き直すと毎回rootへ戻る。前回の場所と選択を復元したい | **将来候補**(本人が「ふとした思い付き」と明示)。`product-map.md` の将来候補へ置く |

**`008` への登録はこのPRでは行わない** — T07 の review 範囲へ別 plan の task を混ぜない。
**merge 後に `dev` から別branchで登録する。**(2026-08-25 merge 済み。登録は`008`側の作業)

## 独立review attempt 3(`final-evidence`、2026-08-25)= PASS

range は `57c5e69...5393e06`。**未解決のP0/P1は無く、P2が3件。** reviewer は
**実機証拠の真正性**を自分で確かめている — 「`287a03d` 以降 code 差分なし」を実測し、
`56b6a0e..HEAD` が `task.md` 1件だけであること、**人間が読んだ手順書と現在の手順書が
同一**であること、手順書に書いたUI文言・`keep (1).txt` の形式・失敗表示が
current revision に実在することを file:line で確認した。**観測していないことを観測した
ように書いた箇所は無い**と判定している。

**U2(近道★の見分け)は 004 REQ-015 違反ではない**と判定された。REQ-015 が課すのは
「実在する既知の場所への近道を**示し**、そこから階層を辿れる」ことで、手順1の観測で
成立している。**近道の並べ方・選択の示し方は 004 spec が自由と明示している範囲**
(`specs/004-file-source/spec.md:135`)であり、★という示し方は実装裁量の側にある。
「認識できること」を規範にしたいなら REQ-015 の変更(=仕様更新task)が要る、という
整理も支持された。**U1〜U6 の送り先はいずれも妥当**と判定されている。

**auto-merge の7条件はすべて充足**と判定された(CI `check` = success on `5393e06`、
`mergeStateStatus: CLEAN`、未解決thread 0、`origin/dev` = `57c5e69` で分岐なし、
`flutter test` = 589 PASS、変更pathに `.github/workflows/` も権限規約も含まない)。

| 指摘 | 分類 | 始末 |
| --- | --- | --- |
| **P2-1**: 検証結果表の「実機確認 = 未実施」が、後半の manual 記録と矛盾する。PR本文にも同じstaleが残る | 成果物の欠陥(記録) | **直した。** 表を実施済み(環境・対象commit つき)へ更新し、PR本文の該当行も落とした。**Android build 未実施の行はそのまま** |
| **P2-2**: 004 spec の Status 行に、このtaskが 2026-08-24 に入れた理由文訂正が載っていない。005 は revision を承認日つきで列挙しており、扱いが揃っていない | 成果物の欠陥(記録) | **直した。** 既存の追記形式に合わせ、「要求(must)を変えない範囲」と明記して一文を足した。**再承認は求めていない** |
| **P2-3**: `android_storage_browser_test.dart:3` が存在しない file 名を参照(`storage_browser_test.dart` → `storage_browser_view_test.dart`) | 成果物の欠陥(記録) | **直した** |

**P2-3 は `test/` の comment 1行だが、実機証拠の identity は保たれる。** `lib/` と
`android/` に差分は無く、**app の build に一切入らない**ためである(AGENTS.mdが再利用を
禁じるのは「code、dependency、build設定が変わったとき」で、ここで変わったのは test の
説明文である)。念のため `flutter test` を再実行して589件のPASSを確認した。

## merge(2026-08-25)

**PR #151 を merge した**(`dev@019775d`、merge commit)。AGENTS.md の auto-merge 7条件は
`final-evidence` の独立reviewが充足を確認しており、CI `check` は最終HEAD `d9fa1a6` で
success、`mergeStateStatus` は `CLEAN`、未解決threadは無かった。

merge 後の `dev` で `flutter test` = **PASS(589)** を確認した。

**`013:T08`(実機での検証範囲)がこれで着手可能になった。**

## 後から分かった欠陥(2026-08-26、`T08` の実機観測)

**この実装は、装着されている SD カード・USB を保存場所として並べられない。**
`AndroidStorageBrowser.locations()` は `/storage` の中身から保存場所を作るが、
**app からは `EACCES` で列挙できない**(全ファイルアクセス権限があっても)。
004 REQ-015 と代表例26e に対する欠陥である。

**この環境では検出できなかった。** 宣言表の「実機の mount 構成」を `013:T08` へ渡して
いた範囲そのもので、`T08` がその役割を果たした形である。

**`013:T12` が引き受ける**(2026-08-26、開発者の判断で新設)。要求は変えず、列挙の手段
だけを差し替える。

## Current state / handoff

- Last checkpoint: **PR #151 を merge した(`dev@019775d`)。** `dev`上で `flutter test` = PASS(589) を確認済み。その前が独立review attempt 3(`final-evidence`)= PASS と、**manual 実行2回目 = 全手順が期待どおり**(2026-08-25、`sdk_gphone16k_x86_64`、`56b6a0e`)。**Androidで実際に改名できることを初めて実機で確認した。** UIの改善点6件は `008` と将来候補へ送る(このPRでは直さない)その前は**独立review attempt 2 = PASS**で、そのP2 6件も反映済み。`M103`〜`M121`が19 KILLED、`flutter test` = PASS(589)。005 contract は revision 6.1(2026-08-25 開発者承認)。working treeはclean
- Blocker category: なし
- Waiting for: なし(done)
- Requested action: なし
- Evidence revision: PR #151、branch `asdd/013-safe-android-rename/T07-implement-android-file-browser`、base は `dev@57c5e69`(`git merge-base dev HEAD` の実測値。当初 `b318251` と書いたのは誤りで、T06 merge 後の分岐点はこちらである)
- Next Agent action: なし。**このtaskは完了した。** 受領したUIの改善点(U1〜U6)の登録は`008`側の作業として別branchで行う。実機で覆えていない範囲(mount構成、`/Android/`配下の書き込み可否、CのAndroid分岐、Android build)は`013:T08`が引き受ける。
- **`T08`への申し送り**: このtaskで**Androidが`DesktopRenameExecutor`を通るようになった**ので、`T05`が受容した「CのAndroid分岐の実挙動」は**製品経路上のrisk**になった。実機で`renameat2`が効くか、効かない端末で通常renameへ落ちるかを確認すること。あわせて**実機のmount構成**(保存場所の一覧が正しいか)と**`/Android/`配下の実際の書き込み可否**も見ること。
