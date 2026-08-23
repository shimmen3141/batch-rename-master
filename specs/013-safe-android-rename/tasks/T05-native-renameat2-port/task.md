# T05 renameat2のnative portを実装する

## 目的

`T04`で承認された契約どおり、Androidの`RenameExecutor`を`renameat2(RENAME_NOREPLACE)`で実装する。

## 入力と依存

- `T04`で承認された005 contract revision 4。
- 検証済みの参照実装: [`../T01-decide-storage-boundary/spike/renameat2_spike.c`](../T01-decide-storage-boundary/spike/renameat2_spike.c)。**syscall番号のarch別fallbackとフラグ定義はここから写せる。**
- 現行のdesktop実装: `lib/data/rename_exec/native_exclusive_rename.dart`、`hook/build.dart`(`native_toolchain_c`)。**Androidも同じnative assets経路に載る見込み。**
- 現行の未対応adapter: `lib/data/rename_exec/saf_rename_executor.dart`。**削除しない**(ADR-002の退避経路)。

## 変更範囲

- **2026-08-23 / 設計変更([ADR-003](../../decisions/ADR-003-os-identity-at-native-boundary.md))**: OS識別をDartから消し、native境界へ閉じ込めた。`usesUtf8NativePath`(OS許可リスト)を削除し、Cが**Androidのときだけ**返す`NativeRenameResult.fallbackRequired`で劣化を決める。Android専用のexecutor factory(`androidRenameOperation` / `createAndroidRenameExecutor`)は**不要になったので削除**し、劣化は`DesktopRenameExecutor._renameOnce`の**単一地点**で行う。`android_rename_executor.dart`は`plain_rename.dart`へ縮小した。**desktopの利用者から見た振る舞いは変わらない**(`unsupported`は従来どおり失敗)。
- Android向けnative renameの実装。**`platform_rename_executor.dart`の分岐の切り替えは`T07`へ送った**(2026-08-22) — Androidのハンドルがまだ SAF の document URI で path として解釈できず、**005 contract revision 5.1 が今なお Android SAF を未対応と規定している**(REQ-017 / OP-004)ため、いま切り替えると承認済み契約に反する。このtaskで入れたのは doc comment と、切り替えていないことを固定する test である。引き継ぎ先は[`T07`](../T07-implement-android-file-browser/task.md)の「013 REQ-005 / REQ-006 を製品として観測可能にする」節。
- `errno`から`RenameErrorKind`への写像(`T04`の決定に従う)。
- 仕様由来testの追加。

**注意**: `renameat2`が**bionicのwrapperとして**公開されたのはAPI 30とされるが、これは検索結果の要約であり原文を読めていない(**[未到達]**)。**生の`syscall(SYS_renameat2, ...)`を使えばwrapperのlevelに依存しない**(`T01`のspike binaryは`android24`向けにビルドして動作した)。制約はlibcではなくkernelとfilesystemの側にある。

`T02`は**「`minSdk`は24のまま、対応可否を実行時に判定する」**と決めた(`spec.md`のD-1、2026-08-13 開発者承認)。生syscallで呼び、動かない端末は実行時に検出する。**API levelを対応可否の代理指標にしない。**

### このtaskの範囲ではないもの

**衝突時の再採番と結果の提示は005側(実行オーケストレーション)が持つ。** ここで作るのは「`renameat2(RENAME_NOREPLACE)`を1回呼んで結果を返す部品」と、`errno`を`RenameErrorKind`へ写す部分だけである。`EEXIST`→`nameConflict`を返せば、呼び出し側が005 contract REQ-023に従って再採番する。

**`renameat2`が使えない端末では、005 contract REQ-025の「実在確認してから改名する」経路へ落とす。** 「対応外」にはしない。

## 受け入れ証拠

- targetが既にある場合に`nameConflict`を返し、**targetの内容が変わらない**ことをtestで検査する。
- 権限が無い場合、対象が無い場合の分類をtestで検査する。
- `EEXIST`が`nameConflict`として返り、**005の再採番へ繋がる**ことをtestで検査する(005 contract REQ-023)。
- `EINVAL`/`ENOSYS`のとき、**実在確認による代替経路へ落ちる**ことをtestで検査する(005 contract REQ-025)。**未対応として利用者へ見せない。**
- **劣化するのはnativeが要求したときだけである**ことをtestで検査する。`unsupported`では劣化しない(desktopの保証を弱めない)。
- **OS判定が境界の外へ漏れていない**ことを`python3 tool/check_platform_boundary.py`で検査する(ADR-003)。
- 例外を投げないこと(REQ-017)をtestで検査する。
- 005の既存contract testが継続PASSする。
- `flutter test` / `flutter analyze` / `dart format --output=none --set-exit-if-changed .` がPASS。
- **Androidのbuildはcontainerで実行できない**(SDK・NDKが無い)。未実施と明記し、host側のbuildを`T08`で行う。
- exact rangeの独立reviewがPASSする。

## 検証結果

| 種別 | commandと結果 |
|---|---|
| full regression | `flutter test` = **PASS(505件)**。T05着手前は464件。ADR-003の適用で**testは1件減った** — 消えたのは`usesUtf8NativePath`のようなOS分岐を見るtestで、**分岐自体が無くなった**からである |
| static analysis | `flutter analyze` = **PASS** |
| format | `dart format --output=none --set-exit-if-changed .` = **PASS** |
| ASDD構造 | `python3 <asdd-plugin>/scripts/workspace.py check specs` = **PASS** |
| 規範の書き写し | `python3 tool/check_normative_terms.py` = **PASS**(`flutter test`から呼ばれる) |
| C(Linux分岐) | `gcc -fsyntax-only src/native_exclusive_rename.c` = **exit 0** |
| C(Android分岐) | `gcc -fsyntax-only -D__ANDROID__ src/native_exclusive_rename.c` = **exit 0**。**NDKが無いのでglibcのheaderで代用した syntax 検査であって、NDKでのコンパイルではない**。ただし`_Static_assert`が入ったので、**その位置でのflag値とsyscall番号が実kernel headerと違えばここで落ちる**。**実際に渡る値**は`native_behaviour_test.dart`がshim経由で観測する |
| OS境界 | `python3 tool/check_platform_boundary.py` = **PASS**(39 file、3 rule。`flutter test`から呼ばれる) |
| syscall番号 | **testが毎回照合する**(`native_constants_test.dart`)。archごとに`gcc -E -dM -nostdinc -D<arch>`で値を取り出し、**独立TUの`_Static_assert`**で実kernel headerと突き合わせる。`x86_64=316`(`asm/unistd_64.h`)、`i386=353`(`asm/unistd_32.h`)、`aarch64=276`(`asm-generic/unistd.h`)が一致。**未照合は`__arm__`(382)だけ**(この環境に32bit ARMのheaderが無い。出典は`T01`のspike) |
| mutation | 表全体 = **76 mutations: 76 KILLED, 0 SURVIVED, 0 SKIPPED**(`M44`〜`M76`が`T05`分。うち`M63`〜`M76`は**独立reviewerが見つけたSURVIVEDを取り込んだもの**)。**独立review attempt 3 でreviewerが見つけた4件のうち3件は、mutation pointごと消滅した**(下表)。残る`X1`は`M55`としてKILLEDである |
| **Android build** | **未実施。** AI containerにSDK・NDKが無い |
| **実機確認** | **未実施。** `T08`が行う |

**mutationで2件がSURVIVEDしてから直した。**(以下のIDは**当時の表**のもので、現在の表とは対応しない。通常renameのnotFound分類は現在`M54`である。)当時の`M46`(通常renameのnotFound分類)は
`expect([notFound, io], contains(result))`という曖昧なassertionで、どちらでも通って
いた。`M47`(**AndroidのRENAME_NOREPLACEを外す**)は`expect(source, contains('RENAME_NOREPLACE'))`
がfile全体を見ており、`#define`の行があるので**呼び出しからflagが消えても通っていた**。
**M47は置換renameになる = 005 INV-002が全面的に破れる**変更なので、これを見逃す
testは意味がない。呼び出し部分だけを切り出して検査する形へ直した。

## 決めたこと

| 論点 | 決着 | 理由 |
|---|---|---|
| wrapperか生syscallか | **生のsyscall** | bionicのwrapperはAPI 30とされるが、013 spec D-1は「minSdkは24のまま、対応可否を実行時に判定する」と決めている。**API levelを対応可否の代理指標にしない** |
| `EINVAL` / `ENOSYS` の扱い | **Androidのときだけ`BRM_RENAME_FALLBACK_REQUIRED`へ写す**(2026-08-23 ADR-003で更新。当初は`unsupported`だった) | `renameat2`はfilesystemがflagを解釈できないとき`EINVAL`を返す。Androidは共有storageがFUSEを経由するので現実的に起きる。**`unsupported`と別の値にする**のは、あちらが「機能が無い」であって「落としてよい」とは言っていないからである。**desktopの写像は変えない** — desktopは従来どおり`ENOSYS`/`ENOTSUP`で`unsupported`を返し、劣化しない(013 spec の範囲外に「desktopの振る舞い。何も変えない」とある) |
| 劣化をどこに置くか | **`DesktopRenameExecutor._renameOnce`(単一地点)**(2026-08-23 ADR-003で更新。当初はAndroid専用のport側だった) | 当初は「desktopの実装を1文字も変えない」ことを優先してport側へ置いたが、**その分離のためにoptionalな既定引数の合成が要り、それが3回続いた「productionが通る合成をtestが一度も通らない」の温床だった**。ADR-003では逆に、劣化を共有経路の1箇所へ集めて**Android専用の合成を無くした**。**desktopの利用者から見た振る舞いは変わらない**(`fallbackRequired`をdesktopのCが返さない)が、**実装は変わった** — `_renameOnce`、`_plainRename`、constructor引数が入った |
| composition rootの切り替え | **このtaskでは行わない** | Androidのハンドルはまだ**SAFのdocument URI**で、pathとして解釈できない。いま切り替えると、実体は壊れないが(対象が見つからず失敗する)revision 2以来の「理由付きの安全な未対応」より分かりにくい失敗になる。**`T07`が絶対pathを供給してから切り替える。** `platform_rename_executor.dart`のdoc commentとtestで固定した |

## この実装で残る限界

- **Androidで実際に動くかは未確認である。** container にSDK・NDKが無く、compileすら
  していない(`gcc -fsyntax-only`はglibcのheaderでの構文検査)。**`T08`が実機で見る。**
- **他 arch の syscall 番号は host 上で実行検証できない。** shim harness は host(x86_64)で
  しか動かないので、`aarch64` / `__arm__` / `__i386__` の番号が**実際に呼ばれるところ**は
  見ていない。`native_constants_test.dart` が実 kernel header と `_Static_assert` で
  突き合わせるところまでが限界で、**`__arm__` はその照合すらできない**(header が無い)。
  `013:T08` の実機確認が引き受ける。
- **`__arm__`のsyscall番号だけ照合できていない。** 出典は`T01`のspikeである。
  `x86_64=316`(`asm/unistd_64.h`)、`asm-generic=276`(aarch64)、`i386=353`
  (`asm/unistd_32.h`)はこの環境のkernel headerと一致した。**32bit ARM の header は
  この環境に無い。**
- **`hook/build.dart`からAndroidを未対応対象外にしたので、`dev`のAndroid buildは`T08`まで無検証になる。** CI(`.github/workflows/ci.yml`)はformat / analyze / testだけでAndroidをbuildしない。**受容する**(独立review attempt 1 の P2-4、Agent判断) — Androidは現状`SafRenameExecutor`で改名自体が未対応であり、buildが壊れても**製品機能の後退は無い**。`T08`の受け入れ証拠に「host側のAndroid buildが成功する」が既にあるので追加の手当ては要らない。**保留する案(build設定だけ`T08`直前まで遅らせる)は採らない** — Cとbuild設定を別のtaskへ分けると、`T08`が2つのtaskの成果を同時に検証することになり、失敗の切り分けが難しくなる。
- **劣化経路(`plainRenameFile`)は既存fileを置換しうる。** 呼び出し側が直前に実在確認を
  していることが前提で、`DesktopRenameExecutor`が005 REQ-025でそれを保証する。
  **単体で使うと黙って上書きする。** doc commentへ明記した。

## 独立review attempt 3 の指摘の始末

reviewerが自分で足した5件(control 1件を含む)のうち**4件がSURVIVED**した。ADR-003を
適用した結果、それぞれ次のようになった。**「潰した」ものと「消えた」ものを分けて書く。**

| reviewerの変異 | 内容 | 始末 |
| --- | --- | --- |
| `X1` | 劣化経路の一般IO失敗を成功として返す(改名していないのに`Renamed`) | **潰した。** `M55`として表に入れ、非空directoryを目標にする test(`EISDIR`)でKILLED |
| `X2` | 想定外の例外をそのまま投げさせる(005 REQ-017が破れる) | **受容する。** `dart:io`経由で非`FileSystemException`を起こす手段が無く、注入なしでは殺せない。catch-allは残す(消すと本当に投げるようになる)。**P2として明記** |
| `X3` | 呼び出し側を旧形へ戻す(純関数を使わなくなり、Androidからnativeが消える) | **消滅。** `usesUtf8NativePath`も呼び出し側の分岐も存在しない(ADR-003) |
| `X4` | 実OSを渡さず固定値にする | **消滅。** 同上。`Platform.operatingSystem`は`tool/check_platform_boundary.py`が禁止する |
| `X5`(control) | probeの受け渡しを切る | 元からKILLED |

**`X2`を受容する理由。** これは「testが足りない」ではなく「この環境では起こせない」型で
ある。無理に殺すと注入用の穴を production へ開けることになり、**それこそが4回続いた型の
作り方**である(ADR-003 の Why not)。

## 独立review attempt 4 の指摘の始末

reviewerが自分で足した7件のうち**5件がSURVIVED**した(control 2件はKILLED)。
**同じ型が3件残っていた**が、reviewerは「性質が違う」と判定した — 前3回は劣化を駆動する
**合成そのもの**が未実行だったのに対し、今回は中核(`fallbackRequired`→通常rename)が
fake無しで実行されており、残ったのは**周辺3点**だった。「解き方の変更は要らず、
この3点を足せば閉じる」。

| reviewerの変異 | 内容 | 始末 |
| --- | --- | --- |
| `X-A` | 一時名経路の**2段目(前進)**だけ劣化を通さない | **潰した。** `M57`。`_VanishingProbe`(1回目だけ実在)でcase-only改名を模すtestを足してKILLED |
| `X-C` | AndroidのENOSYSを劣化要求から外す | **潰した。** `M58`。source assertが`EINVAL`しか見ていなかった(**test名は「EINVAL / ENOSYS」なのに**)。3つのerrnoを見るよう直してKILLED |
| `X-F` | Dart enumの`io`と`fallbackRequired`を入れ替える | **潰した。** `M59`。C enumの`= 数値`を読んでDartの`index`と突き合わせるtestを足してKILLED。**ADR-003が「indexは変えない」と書きながら、それを守るものが無かった** |
| `X-E` | 劣化されなかった`fallbackRequired`を`nameConflict`へ写す | **表へ足さない。** `_renameOnce`が必ず先に劣化させるので**production では到達不能**な防御である。到達不能な分岐にtestを当てると、そのために注入穴を開けることになる |
| `X-G` | `Platform.isWindows`分岐を潰す | **受容。** Linux上でWindows分岐は実行できない。**変更前と同型でregressionではない**(reviewerも同判定) |
| `X-B` / `X-D`(control) | 巻き戻し / EINVAL | 元からKILLED |

**`X-F`が一番重い。** 入れ替わると**desktopで本物のI/O失敗が「劣化してよい」と解釈され**、
013が「何も変えない」と宣言した当のdesktopで005 INV-002の原子的保証が黙って外れる。
`fallbackRequired`を足したことで、enumの順序が「単なる値の並び」から**劣化するかどうかを
決める負荷のかかった対応**へ変わっていた。

## 独立review attempt 5 の指摘の始末

reviewerは主張した検証結果を**すべて再現**し、`M57`/`M58`/`M59`が`X-A`/`X-C`/`X-F`を
忠実に写していること(弱い変異へのすり替えが無いこと)を1件ずつ確認したうえで、
**P1を1件**見つけた。

| reviewerの変異 | 内容 | 始末 |
| --- | --- | --- |
| `Y2`(**P1**) | `RENAME_NOREPLACE`の**自作定義値**を`(1 << 1)`(= `RENAME_EXCHANGE`)へ | **潰した。** `M60`。効くと**2つのfileが黙って入れ替わる**(005 INV-002 / OP-004) |
| `Y4`(P2) | desktop側の`case ENOSYS:`を外す | **潰した。** `M61`。「desktopの写像は変えない」という宣言を守るものが無かった |
| `Y8` | 範囲外のnative戻り値をsuccessとして扱う | **表へ足さない。** reviewerが「`M59`のenum対応testが7値であることを不変条件として押さえたので、到達不能であること自体が裏打ちされた。逃げではない」と判定 |
| `Y1`/`Y3`/`Y6`/`Y7`(control) | 巻き戻し / C enumずらし / build hook / composition root | 元からKILLED |

**`Y2`の根本原因は`X-C`(attempt 4)と同じである** — 「Cの Android 分岐にある**自作の定数**が、
代用のsource assertから漏れている」。attempt 4 は errno 1件を足して閉じたが、**類は閉じて
いなかった**。AGENTS.md の「同じ根本原因が修正後も2回続いたら、同じ種類の修正を繰り返さず
解き方を変える」に該当するので、**1件ずつ`contains`するのをやめて表にした**。

- `#define` を全件抽出し、**値まで含めて**表と**完全一致**で突き合わせる。
- `errno`写像を`__ANDROID__` guardの内外で分けて全件抽出し、写像先まで表と完全一致で
  突き合わせる。
- **完全一致なので、表に載せ忘れた定数が増えれば「未登録」で落ちる。** 1件ずつの
  `contains`では、増えた分は黙って通っていた。
- `M62`(arch別のsyscall番号を1つずらす)を足して、表そのものが効いていることを確認した。

**P2 4件も直した。** うち`P2-2`は「`task.md`が『直した』と書いたP2が実diffに無い」という
指摘で、原因は**mutation実行中にその fileを編集し、runnerの復元で消えたこと**だった。
別途 [`development-findings/2026-08-23-edited-a-file-while-a-mutation-runner-was-restoring-it.md`](../../../../development-findings/2026-08-23-edited-a-file-while-a-mutation-runner-was-restoring-it.md) へ記録した。

## 独立review attempt 6 の指摘の始末(案A′の適用)

reviewerは`Z11`(desktopの呼び出しからflagを外す)がKILLEDになることで**Cが各mutationで
実際にrecompileされ、desktopの挙動が本当にtestで観測されている**ことを確認し、
「**ADR-003の構造変更は有効で、解き方を戻す必要はない**」と判定した。そのうえで、
**表駆動の抽出器がfail-open(認識できない行を黙って捨てる)**なので「完全一致」という
主張が成立していないことを5件の変異で示した。

**2026-08-23 開発者決定: 案A′(検査のoracleを文字列からcompilerと実kernel headerへ移す)。**

| reviewerの変異 | 内容 | 始末 |
| --- | --- | --- |
| `Z15`(**P1**) | desktop分岐へ**1行形式**で`case EINVAL: return ...;`を足す | **潰した。** `M63`。preprocess後は書式差が消えるので構造的に見える |
| `Z6` | `default:` armを劣化要求へ(**表に1行も無かった**) | **潰した。** `M64`。`default`を`-1`として表へ載せ、**必ず現れる**ようにした |
| `Z14` | 1行形式で`EXDEV`を劣化要求へ(抽出器に**完全に不可視**) | **潰した。** `M65` |
| `Z5` | `#  define`(空白入り)でflag値を差し替え | **潰した。** `M66`。値は実kernel headerと`_Static_assert`で突き合わせる |
| `Z8` | 実装の`#define`をコメント内へ移して別値を定義 | **消滅。** preprocessorはコメントを見ないし、`#ifdef`で選ばれた値しか出さない |
| `Z9`(P2-1) | x86_64とi386の番号を**入れ替える**(値の集合は同じ) | **潰した。** `M67`。archごとに**独立TU**で実headerと突き合わせるので対応まで固定される |
| `Z11`/`Z1`/`Z3`/`Z7`/`Z13`(control) | — | 元からKILLED |

**何を変えたか。**

1. **ABI定数を`src/brm_renameat2_abi.h`へ切り出した。** この headerは**何もincludeしない**ので、
   `gcc -E -dM -nostdinc -D<arch>` だけでarchごとの値を取り出せる。system headerを含むと、
   arch macroを差し替えた時点でheader側が壊れて値を取り出せない(**実測した**)。
2. **自前の名前を持たせた**(`BRM_RENAME_NOREPLACE` / `BRM_SYS_RENAMEAT2`)。従来の
   `#ifndef RENAME_NOREPLACE`で system に譲る形だと、**system が定義している環境では
   自前の値がそもそも展開されず、間違っていても誰も気づけない**。
3. **`_Static_assert`が実kernel headerと突き合わせる。** `x86_64`=316(`asm/unistd_64.h`)、
   `i386`=353(`asm/unistd_32.h`)、`aarch64`=276(`asm-generic/unistd.h`)、flag値=
   `RENAME_NOREPLACE`。**独立TUで見る**ので、他archのheaderが先に読まれて別の値へ
   解決されることがない。`__arm__`(382)だけはこの環境にheaderが無く未照合である。
4. **errno写像は`gcc -E -P`の出力を数値で突き合わせる。** コメント・`#if`・macro・書式差が
   すべて解決済みで、`case 17:`のように数値になる。**fail-closed**にしてあり、switch本体に
   既知でないtokenが出たら**例外を投げてtestが落ちる**。
5. **source文字列を正規表現で読む検査は削除した。**
6. **`tool/*.py`の検査を`test/tooling/repo_checks_test.dart`から呼ぶようにした。**
   `.github/workflows`は人間の作業なので触らず、CIが必ず走らせる`flutter test`から閉じる。

**finding の改善案3(reviewerが足した変異を実装側の表へ取り込む)を初めて実施した。**
6回連続で未実施のまま同じ結果を生んでいた。

## 独立review attempt 7 の指摘の始末(「読む」から「実行する」へ)

reviewerは`M44`〜`M68`の25件すべてKILLEDを再現し、「ADR-003の構造変更と案A′の道具立ては
**有効であり、戻す必要はない**」と判定した。そのうえで、**漏れが「書き方の差」ではなく
「検査している領域の外」へ移った**ことを4件の変異で示した。

| reviewerの変異 | 内容 | 始末 |
| --- | --- | --- |
| `W1`(**P1**) | `switch`の**前**に`if (error == EINVAL) return FALLBACK_REQUIRED;` | **潰した。** `M69` |
| `W2`(**P1**) | 写像関数の**外**(呼び出し側)で同じことをする | **潰した。** `M70` |
| `W3`(**P1**) | `_Static_assert`の**後**で`#undef`して再定義(実際に渡る値が`2`=交換になる) | **潰した。** `M71` |
| `W4`(**P1**) | 呼び出しに`| RENAME_EXCHANGE`を足す(名前は残るのでsource assertは通る。渡る値が`3`) | **潰した。** `M72` |
| `W5`/`W6`(reviewer追加) | `enum`で定数化 / 行継続`\` | 元からKILLED |

**なぜ案A′でも漏れたか。** `native_constants_test.dart`のerrno読み取りは
「`switch`本体の中だけ」をfail-closedにしていた。**fail-openがtoken単位から領域単位へ
移動しただけ**で、関数の入口から`switch`までの区間、`switch`の外、呼び出し側は1 tokenも
読まれていない。同様に`_Static_assert`は「その位置でのmacro値」しか固定しないので、
後で`#undef`されれば効かない。

**解き方の変更(4回目なので、読み取りを賢くする方向をやめた)。**

`test/native/renameat2_harness.c` が `syscall` / `renameat2` を shim へ差し替え、
**製品の関数をそのままLinux上で呼ぶ**。観測するのは**この関数の入口と出口**である —
渡った syscall 番号・flag・dirfd・path、呼び出し回数、errno から返る結果。
**sourceの書き方には依存しない** — `if`文でも、呼び出し側でも、`#undef`でも、
補助関数でも、渡る値が変われば落ちる。

**この検査で見ていないもの**(2026-08-23 attempt 9 の指摘を受けて書き直した)。

- **host(x86_64)以外の arch の syscall 番号。** host 上でしか実行できない。他archは
  `native_constants_test.dart` が実 kernel header と `_Static_assert` で突き合わせ、
  `__arm__` は照合手段が無いので `013:T08` が引き受ける。
- **Android 向けの実 compile と実機挙動。** NDK が無い。`013:T08` が見る。
- **Windows 分岐。** この環境で compile できない。

**それ以外は、errno を 0〜255 まで全走査して観測している**ので、`if`文でも、呼び出し側でも、
`#undef`でも、補助関数でも、**表に無い errno でも**、渡る値・返る値が変われば落ちる。

    Android: gcc -D__ANDROID__ -Dsyscall=brm_test_syscall  <source> <harness>
    desktop: gcc -Drenameat2=brm_test_renameat2            <source> <harness>

`-D`はidentifierごと置き換えるので、system headerの宣言もshimを指す。
**製品の呼び出しはそのままで、行き先だけが差し替わる。**

観測結果(baseline): Android は `nr=316 flags=1`、`EINVAL`/`ENOSYS`/`ENOTSUP`→`fallbackRequired`。
desktop は `EINVAL`→`io`、`ENOSYS`/`ENOTSUP`→`unsupported`、**劣化を一度も要求しない**。

`native_constants_test.dart` の arch別`_Static_assert`と`#error`の検査は**有効なので残す** —
他archの番号はhost上で実行できないため、あちらが唯一の照合手段である。

## 独立review attempt 8 の指摘の始末

reviewerは**shimが本物であることを確認した** — `gcc -E` の出力に
`result = (int)brm_test_syscall(316, ...)` が現れ、**製品の呼び出し式そのもの**が
置き換わっている。別経路の再実装ではない。attempt 7 の`W1`〜`W4`も再度当てて全KILLED。

そのうえで、**harnessが6引数のうち2つ(番号とflag)しか観測せず、しかも最後の1回しか
見ていない**ことを見つけた。

| reviewerの変異 | 内容 | 始末 |
| --- | --- | --- |
| `N11`(**P1**) | Android分岐で`source`と`destination`を**実行時に**入れ替える(source文字列は1 byteも変わらない) | **潰した。** `M75`。効くと改名が逆向きになり、**013 REQ-005 / REQ-006が製品として一切成立しない**(常に`notFound`) |
| `N10`(**P1**) | `AT_FDCWD`を`0`へ再定義する | **潰した。** `M74`。相対pathの基準が壊れる |
| `N06`(**P1**) | **先に**`RENAME_EXCHANGE`で1回呼び、後から正しいflagで呼ぶ | **潰した。** `M73`。効くと2つのfileが黙って入れ替わる |
| `N09`(P2) | `hook/build.dart`の`includes: ['src']`を取り除く | **潰した。** `M76`。testへ1行足した |
| `N12` | Android armでのみsyscall番号をx86_64の値へ固定する | **殺せない。** host上でしか実行できない。**主張の方を実力へ書き直した**(下記) |
| `N01`〜`N05`/`N07`/`N08`(control) | — | 元からKILLED |

**直したこと。** harnessが`olddirfd` / `oldpath` / `newdirfd` / `newpath` / **呼び出し回数**も
記録し、`AT_FDCWD`を**harness側のheaderから**独立に取って出力する。testは
「現在のdirectory基準で`source`を`destination`へ**1回だけ**」を両分岐で検査する。

**主張を実力へそろえた。** 「渡る値が変われば必ず落ちる」「値の正しさはすべて実行側が持つ」は
**host arch についての主張**である。他archのsyscall番号は`native_constants_test.dart`が
実kernel headerと`_Static_assert`で突き合わせるところまでが限界で、`__arm__`はその照合も
できない(headerが無い)。`013:T08`が引き受ける。harness、`native_behaviour_test.dart`、
`task.md`、PR本文の4箇所を直した。

## 同じ型を2回作った理由(独立review attempt 2 の要求)

**3回とも同じ型である**: 「production が実際に通る合成を、test が一度も通らない」。
場所だけが違った。

| 回 | 見つけた側 | 未実行だった合成 |
| --- | --- | --- |
| 1 | 自分(`M46`/`M47`) | Android 分岐の C 実装。test は fake を注入して分類だけ見ていた |
| 2 | reviewer(`X5`/`X6`) | `createAndroidRenameExecutor` の既定 wiring と、Dart 側の platform 分岐 |
| 3 | reviewer(`R1`/`R2`/`R3`/`R5`) | `?? 既定` の**右辺**。test が必ず引数を渡すので一度も評価されない |

**なぜ繰り返したか。**

- 直し方が毎回「指摘された束縛点へ test を1本足す」だった。**束縛点を自分で数えて
  いなかった**ので、残りの束縛点はそのまま次の指摘になる。
- mutation を「test が本物かの検査」ではなく「指摘の穴埋め」に使っていた。表へ行を
  足す作業は塞いだ穴の記録にしかならず、**穴の作り方**は変わらない。
- 構造側の原因: 既定を `?? 既定` の形で**複数箇所へ置ける設計**だった。test は必ず
  引数を渡すため、既定の側は構造的に未実行になる。「足りない test」ではなく
  「test が届かない場所を作れる設計」が根本原因である。

**当時の解き方の変更(test を足すのをやめた)。以下は 2026-08-22 時点の設計であり、
ADR-003 で `androidRenameOperation` と `createAndroidRenameExecutor` は削除された。
現在の形は「独立review attempt 6 の指摘の始末」以降の節を読むこと。**

1. **既定の束縛を1箇所へ集約した。** `androidRenameOperation` の中だけで `?? 既定`
   を書き、`createAndroidRenameExecutor` は引数を素通しする。束縛点が1つなら
   「既定をすり替える」mutation は必ずその1箇所を指し、生き残れば必ず test が落ちる。
2. **fake を1つも注入しない test group を置いた。** 実 file に対して
   `createAndroidRenameExecutor()` と `androidRenameOperation()` を**引数なし**で
   呼ぶ。production の合成そのものが実行経路に入る。

## 作業記録

- 2026-08-13 / ADR-002の採用決定を受けて定義。
- 2026-08-22 / 着手。`T04`の契約承認(revision 4、さらに5 / 5.1)は済んでおり依存は解けていた。C へ Android 分岐(生syscall + arch表 + Android限定の`EINVAL`写像)、`hook/build.dart`からAndroidを未対応対象外へ、`android_rename_executor.dart`(劣化経路)を追加した。**composition rootは切り替えていない**(上表)。
- 2026-08-22 / mutation `M44`〜`M47`を追加し、**2件がSURVIVEDしたのでtestを直した**(上記)。
- 2026-08-23 / **独立review attempt 1 = FAIL(P1が3件、P2が4件)。** **reviewerが自分でmutationを2件足してSURVIVEDを見つけた** — `M47`で直したのと**同じ型が2つ残っていた**。(1) `createAndroidRenameExecutor`の既定wiringを通るtestが無く、**外すとproductionから劣化経路が丸ごと消える**のに緑のままだった。(2) `renameFileWithoutOverwrite`のAndroid分岐が固定されておらず、**外すとrenameat2が製品から消える**のに緑のままだった。factoryの引数を分解し、platform分岐を純関数`usesUtf8NativePath`へ切り出して両方をfactory経由/直接検査できるようにし、`M48`/`M49`として表へ足した。(3) composition rootを切り替えない判断は**妥当と認められた**(reviewerは005 contract revision 5.1がAndroid SAFを未対応と規定していることを根拠に加えた)が、**受け取り側の`T07`に1行も記録が無く**、`T05`がdoneになると013 REQ-005 / REQ-006を製品として観測可能にするtaskが消える状態だった。`T07`へ節を追加した。P2も4件直した。
- 2026-08-23 / **独立review attempt 2 = FAIL(P1が1件、P2が3件)。** reviewerが`R1`〜`R5`を足し、**`?? 既定`の右辺が一度も評価されない**ことでSURVIVEDを4件見つけた。attempt 1 と同じ型が3回目なので、reviewerは「表へ行を足すだけの対応にしないこと」「なぜ2回とも同じ型を作ったかを先に整理すること」を条件に付けた。上の節へ整理し、**既定の束縛を1箇所へ集約**して**fakeを注入しないtest group**を置いた。表は`M50`〜`M53`まで拡張し、集約に伴い`M45`/`M49`/`M50`/`M51`のfind文字列を新実装へ追随させた。P2(`__i386__`の記述、`flutter test`件数、handoff)も直した。
- 2026-08-23 / **独立review attempt 3 = FAIL(P1が2件、P2が1件)。3回目のFAILなのでAGENTS.mdに従い`blocked`とする。** reviewerは表の追随(`M45`/`M49`/`M50`/`M51`)に意味の弱化が無いことと、主張した検証結果すべてを再現したうえで、**自分で足した5件のうち4件がSURVIVEDした**(control 1件はKILLED)。同じ型が**4回目**である。(P1-1) `native_exclusive_rename.dart:69`の呼び出し側を旧形へ戻しても487件が緑 — 純関数`usesUtf8NativePath`は固定したが、**分岐がその関数を使っていること**は誰も固定していない。attempt 1 の P1-2 が純関数の外側へ移動しただけだった。(P1-2) `plainRenameFile`の`on FileSystemException → io`を`success`へ変えても緑。`EISDIR`(errno 21)等が実際にこの分岐へ落ちることをreviewerが実測しており、**改名していないのに`Renamed`が返る**(005 OP-004 / INV-003)。劣化経路4分岐のうちtestが通っているのは2つだけだった。(P2-1) `catch (_)`のcatch-allが未検査。
- 2026-08-23 / **外部AI 2件へ一般解を尋ね(人間の作業)、前提を照合して案B′を採用した**([ADR-003](../../decisions/ADR-003-os-identity-at-native-boundary.md))。2件は独立に同じ結論へ収束した — 「Dart側のOS分岐を消し、OS identityをnative境界へ閉じ込める」。**そのままは採らず**、片方が推した「全platform共通UTF-8 ABI」は**採らなかった**(testできる`_extendedWindowsPath`をsyntax checkすらできないCへ移すことになり、目的と逆。unpaired surrogateも検証手段が無い)。適用したのは、(1) OS許可リストの削除、(2) `fallbackRequired`による劣化の駆動、(3) 劣化地点の単一化、(4) 脆いsource assertの依存検査への置き換え。**Android専用のexecutor factoryは消滅し、`T07`の切り替えは「`isAndroid`の行を消す」だけになった。**
- 2026-08-23 / mutation表を`M56`まで作り直し、**56 KILLED / 0 SURVIVED / 0 SKIPPED**。reviewerの`X1`は`M55`としてKILLED、`X3`/`X4`は**対象消滅**、`X2`はP2として受容(上表)。**testは1件減った**(483件) — 消えたのはOS分岐を見るtestで、分岐自体が無くなったからである。
- 2026-08-23 / **独立review attempt 4 = FAIL(P1が4件、P2が6件)。** reviewerは主張した検証結果を**すべて再現**し、`M44`〜`M56`が全KILLEDであること、ADR-003の構造変更が有効に効いていることを確認したうえで、**周辺3点**(上表の`X-A`/`X-C`/`X-F`)と、**正本同士の矛盾**を指摘した。矛盾は、attempt 1 の対応で新設した`T07`の申し送りが**ADR-003適用に追随せず、削除済みの`createAndroidRenameExecutor()`を受け入れ証拠として指していた**もの。`T07`と`T05`の申し送りを「`Platform.isAndroid`の行を消す」へそろえ、`grep -rn "createAndroidRenameExecutor" specs/`の残りが、日付つきの作業記録と**削除済みと明記した当時の設計の説明**だけであることを確認した。P2は6件とも直した(「決めたこと」表2行、PR本文の1文、`T07`の再承認対象へREQ-025追加、`plainRenameFile`のdirectory限界注記、findingへの結果追記、`check_platform_boundary.py`の限界追記)。
- 2026-08-23 / **独立review attempt 5 = FAIL(P1が1件、P2が4件)。** P1は`RENAME_NOREPLACE`の自作定義値が未検査だったこと(`(1 << 1)`にすると**2つのfileが黙って入れ替わる**)。**根本原因がattempt 4のP1-2と同じ**だったので、1件ずつ`contains`する解き方をやめ、**C で自作した定数(`#define`全件と`errno`写像全件)を表と完全一致で突き合わせる**形にした。P2は、desktop側`ENOSYS`の未検査(`M61`)、**「直した」と書いたP2が実diffに無かった件**(原因はmutation実行中の編集。finding化)、`T07/task.json`の`covers`追随漏れ、handoffの内部矛盾。
- 2026-08-23 / **独立review attempt 6 = FAIL(P1が2件、P2が4件)。ADR-003適用後3回連続FAILなので、AGENTS.mdに従い再び`blocked`とする。** reviewerは`Z11`(desktopの呼び出しからflagを外す)がKILLEDになることで**Cが各mutationで実際にrecompileされ、desktopの挙動が本当にtestで観測されている**ことを確認し、「ADR-003の構造変更は有効で、解き方を戻す必要はない」と判定した。そのうえで、**表駆動の抽出器が「認識できなかった行を黙って捨てる」**ため「完全一致」という主張が成立していないことを5件の変異で示した — `default:` armが表に1行も無い(`Z6`)、1行形式の`case X: return Y;`が**完全に不可視**(`Z14`/`Z15`)、`#  define`(空白入り)を見落とす(`Z5`)、**コメント内の`#define`を実装として読む**(`Z8`)。**Cの自作定数・写像が代用assertから漏れるのは3回目**であり、「1件ずつ足す」対応は禁じられた。
- 2026-08-23 / **開発者が案A′を選択。適用した。** 着手前に実測した前提はすべて成立した — `gcc -E -P`はerrno写像を数値で返し、`gcc -E -dM -nostdinc -D<arch>`はarchごとの定数を返し、独立TUの`_Static_assert`は値を1ずらすと**compile errorになる**。reviewerがSURVIVEDさせた5件を含む12件を表へ取り込み、**12件ともKILLED**を確認した。P2 4件も直した(ADR-003の記述を道具の実力へ合わせる、`task.md`の古いmutation ID参照、tool検査のCI接続、`M46`参照)。
- 2026-08-23 / **独立review attempt 7 = FAIL(P1が2件、P2が3件)。** 漏れが「書き方の差」から「**検査している領域の外**」へ移った — `switch`の前、呼び出し側、`_Static_assert`の後での再定義、呼び出しへのflag追加。**4回目なので読み取りを賢くする方向をやめ、shimで製品の関数を実際に呼んで観測する形にした。** reviewerの`W1`〜`W4`を`M69`〜`M72`として取り込み、15件の部分表が全KILLED。P2も3件直した(`hook/build.dart`へ`includes`を足してheader編集で再buildされるように、PR本文とheader docの「compile時に確かめる」の範囲を実力へ)。
- 2026-08-23 / **独立review attempt 8 = FAIL(P1が1件、P2が2件)。** reviewerは**shimが本物である**ことを`gcc -E`の出力で確認し(製品の呼び出し式そのものが置き換わっている)、attempt 7 の`W1`〜`W4`も全KILLEDを再現したうえで、**harnessが6引数中2つしか観測せず、最後の1回しか見ていない**ことを見つけた。引数の入れ替え・`AT_FDCWD`の差し替え・「先に別flagで1回呼ぶ」が素通りしていた。6引数と呼び出し回数を観測する形へ直し、`N06`/`N10`/`N11`/`N09`を`M73`〜`M76`として取り込んで全KILLEDを確認した。**host arch以外のsyscall番号は実行検証できない**ので、その旨を4箇所の主張へ明記した。
- 2026-08-23 / **独立review attempt 9 = FAIL(P1が2件、P2が7件)。`blocked`。** reviewerは`M44`〜`M76`の33件すべてKILLEDを再現し、**attempt 8 のP1-1(観測する引数の範囲)は閉じている**と判定した。そのうえで、**穴が「引数の範囲」から「errnoの範囲」へ移っただけ**であることを**対照つき**で示した — `R07`(`switch`の前で`ENOSPC`を成功として返す)はSURVIVED、`R09`(**まったく同じ形**で`EEXIST`にしただけ)はKILLED。**差は「その errno が harness の手書き表に載っているか」だけ**である。実害は`ENOSPC`(disk full)で失敗したのに`Renamed`が返ること(005 INV-003 / OP-004)。P1-2は「観測できないのは他archのsyscall番号だけ」という4箇所の主張が**過大**であること。P2は7件(未対応platform分岐が未固定、`hook/build.dart`のliteral依存、`task.md`の古い件数、削除済み設計を現在形で説明、存在しないmethod名のdoc、findingの未追随、full表実行の記録)。**P2のうち3件(古い件数、削除済み設計の断り書き、method名)は先に直した。**

## Current state / handoff

- Last checkpoint: **独立review attempt 9 = FAIL。`blocked`。** 表全体は 76 KILLED / 0 SURVIVED / 0 SKIPPED だが、**reviewerが足した6件がSURVIVED**した(対照3件はKILLED)
- Blocker category: **人間の判断**(AGENTS.md「同じtaskで独立reviewが合計3回FAIL」。9回目である)
- Waiting for: **errno 写像の検証枠組みの選択(下記 A′′ / B / C)**
- Requested action: A′′ / B / C から1つ選ぶこと。**manual確認・実機作業は不要**、branch移動も不要(working treeはcleanで維持する)

### 人間へ返す選択肢(attempt 9)

**問題**: errno から結果への写像を検証する2つの oracle が、どちらも**有限の範囲**しか見ていない。

| oracle | 見ている範囲 | 外へ出る方法 |
| --- | --- | --- |
| `native_constants_test._errnoMapping`(preprocessor) | `brm_result_from_errno` の**`switch`本体だけ** | `switch`の前、関数の外、呼び出し側 |
| `renameat2_harness.c` + `native_behaviour_test`(実行) | **手書きの14 errnoだけ** | 表に無いerrno(`ENOSPC`、`EBUSY`、`EISDIR`、`ELOOP`…) |

2つの穴の**交点**だけが閉じている。

- **A′′(推奨). harnessから手書きの errno 表を消し、errno 空間を全走査する。**
  `for (int e = 0; e <= 255; e++)` を回して1行ずつ出力し、Dart側は
  **preprocessor oracle(`_errnoMapping`)から導いた期待表と全域で突き合わせる**。
  2つの oracle が互いを検算することになり、**「switchの外」と「表に無いerrno」が同時に消える**。
  Linuxのerrnoは`EHWPOISON`=133までなので255まで見れば全域である。
  reviewerは「5世代目の同じ路線」と評したが、**手書きの列挙が1つも残らない**点で性質が違う —
  範囲を広げるのではなく、**列挙をやめる**。
- **B. Cの分類を宣言表からの lookup 1式に落とす。** `switch`の外に分類を書ける場所を無くす。
  Cとtestが同じ表を読む。
- **C(reviewer推奨だが前提が衝突する). 分類をCからDartへ移す。** Cは「成功したか」と
  **生の`errno`**だけを返し、写像はDartの純関数が持つ。**衝突**: Windowsは`GetLastError`で
  **errnoとは別の名前空間**の値を返す(`brm_result_from_windows_error`)。生の値を返すと
  **Dartが「どちらの空間か」を判定することになり、ADR-003が消したplatform分岐がDartへ戻る**。
  採るなら、Windowsも errno 相当へ正規化する層をCに残す(=分類がCに残る)か、
  ADR-003を部分的に取り消すかの判断が要る。

**どの案でも P1-2(4箇所の主張が過大)と P2 の残り4件は直す。**

- Evidence revision: branch `asdd/013-safe-android-rename/T05-native-renameat2-port`、base は `dev@8eeab82`
- 未解決P2: `X2`(`plainRenameFile`のcatch-allが未検査。attempt 4 のreviewerが受容を**妥当と判定**)、`X-G`(`Platform.isWindows`分岐がLinuxで固定できない。**変更前と同型でregressionではない**)、`Y8`(`_resultOf`の範囲外分岐。attempt 5 のreviewerが「enum対応testが7値を不変条件として押さえたので到達不能であることが裏打ちされた」と判定)
- 残余risk: **`__arm__`(382)のsyscall番号だけ照合できない。** この環境に32bit ARMのkernel headerが無い。`013:T08`の実機確認が引き受ける。**Androidの実compileと実機挙動**も同様。target OS別のbuild CIは**入れない**(2026-08-23 開発者決定、`.github/workflows`は人間のみ)
- 新しい依存: **この検査は`gcc`を必要とする**(`native_constants_test.dart`、`native_behaviour_test.dart`)。AI containerとCIの`ubuntu-latest`にはある。**無い環境では黙ってskipせず`flutter test`が落ちる**(独立review attempt 7 が確認済み)
- **人間へ回す判断(このtaskのFAIL理由ではない。`T07`/`T08`の後でよい)**: `fallbackRequired`という汎用の劣化機構ができたことで、**desktopで同じ状況が起きても劣化しない**ことが設計選択として可視化された。LinuxでNFS / CIFS / 一部FUSE上のfileを改名すると`renameat2`は`EOPNOTSUPP`を返し、現在は`unsupported`=改名が失敗する(**変更前から同じでregressionではない**)。(A) 現状維持[reviewer推奨] / (B) desktopのCでも劣化させる(005 contract再承認が要る) / (C) 劣化したことを結果として利用者へ提示する(005 / 001の仕様追加)
- Next Agent action: **選択が返るまで P1 に着手しない。** 返ったら reviewer の `R01`〜`R09` を `tool/mutations.json` へ取り込み(`R09` は**対照**なので落とさない)、修正後に**表全体**を回して生出力をここへ貼り、attempt 10 を起動する。**PR #146 はDraftのまま。**
- **`T07`への申し送り**: `platform_rename_executor.dart`から`if (Platform.isAndroid) return const SafRenameExecutor();`の行を消すのは`T07`である。**Android専用のexecutorは存在しない**(ADR-003) — 消すだけでAndroidも`DesktopRenameExecutor`を通り、劣化はnativeが返す`fallbackRequired`が駆動する。同fileのdoc commentに理由を書いてある。切り替えたら`saf_rename_executor.dart`は**wiringから外れるが削除しない**(ADR-002の退避経路)。
- **`T08`への申し送り**: NDKでのcompileと実機での`renameat2`挙動の観測。`__arm__`のsyscall番号の照合もここで取れる。
