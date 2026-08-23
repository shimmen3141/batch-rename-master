# T05 renameat2のnative portを実装する

## 目的

`T04`で承認された契約どおり、Androidの`RenameExecutor`を`renameat2(RENAME_NOREPLACE)`で実装する。

## 入力と依存

- `T04`で承認された005 contract revision 4。
- 検証済みの参照実装: [`../T01-decide-storage-boundary/spike/renameat2_spike.c`](../T01-decide-storage-boundary/spike/renameat2_spike.c)。**syscall番号のarch別fallbackとフラグ定義はここから写せる。**
- 現行のdesktop実装: `lib/data/rename_exec/native_exclusive_rename.dart`、`hook/build.dart`(`native_toolchain_c`)。**Androidも同じnative assets経路に載る見込み。**
- 現行の未対応adapter: `lib/data/rename_exec/saf_rename_executor.dart`。**削除しない**(ADR-002の退避経路)。

## 変更範囲

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
- 例外を投げないこと(REQ-017)をtestで検査する。
- 005の既存contract testが継続PASSする。
- `flutter test` / `flutter analyze` / `dart format --output=none --set-exit-if-changed .` がPASS。
- **Androidのbuildはcontainerで実行できない**(SDK・NDKが無い)。未実施と明記し、host側のbuildを`T08`で行う。
- exact rangeの独立reviewがPASSする。

## 検証結果

| 種別 | commandと結果 |
|---|---|
| full regression | `flutter test` = **PASS(487件)**。T05着手前は464件 |
| static analysis | `flutter analyze` = **PASS** |
| format | `dart format --output=none --set-exit-if-changed .` = **PASS** |
| ASDD構造 | `python3 <asdd-plugin>/scripts/workspace.py check specs` = **PASS** |
| 規範の書き写し | `python3 tool/check_normative_terms.py` = **PASS** |
| C(Linux分岐) | `gcc -fsyntax-only src/native_exclusive_rename.c` = **exit 0** |
| C(Android分岐) | `gcc -fsyntax-only -D__ANDROID__ src/native_exclusive_rename.c` = **exit 0**。**NDKが無いのでglibcのheaderで代用した syntax 検査であって、NDKでのコンパイルではない** |
| syscall番号 | arch表を**kernelのuapi headerと照合**した。`x86_64=316`(`asm/unistd_64.h`)、`asm-generic=276`(aarch64が使う)、**`i386=353`(`asm/unistd_32.h`)**が一致。**未照合は`__arm__`(382)だけ**(出典は`T01`のspike)。※当初「i386も未照合」と書いていたが誤りで、この環境に header がある(独立review attempt 1 の P2-1) |
| mutation | 表全体 = **53 mutations: 53 KILLED, 0 SURVIVED, 0 SKIPPED**(`M44`〜`M53`が`T05`分) |
| **Android build** | **未実施。** AI containerにSDK・NDKが無い |
| **実機確認** | **未実施。** `T08`が行う |

**mutationで2件がSURVIVEDしてから直した。** `M46`(通常renameのnotFound分類)は
`expect([notFound, io], contains(result))`という曖昧なassertionで、どちらでも通って
いた。`M47`(**AndroidのRENAME_NOREPLACEを外す**)は`expect(source, contains('RENAME_NOREPLACE'))`
がfile全体を見ており、`#define`の行があるので**呼び出しからflagが消えても通っていた**。
**M47は置換renameになる = 005 INV-002が全面的に破れる**変更なので、これを見逃す
testは意味がない。呼び出し部分だけを切り出して検査する形へ直した。

## 決めたこと

| 論点 | 決着 | 理由 |
|---|---|---|
| wrapperか生syscallか | **生のsyscall** | bionicのwrapperはAPI 30とされるが、013 spec D-1は「minSdkは24のまま、対応可否を実行時に判定する」と決めている。**API levelを対応可否の代理指標にしない** |
| `EINVAL`の扱い | **Androidのときだけ`unsupported`へ写す** | `renameat2`はfilesystemがflagを解釈できないとき`EINVAL`を返す。Androidは共有storageがFUSEを経由するので現実的に起きる。**desktopの写像は変えない**(013 spec の範囲外に「desktopの振る舞い。何も変えない」とある) |
| 劣化をどこに置くか | **`androidRenameOperation`(port側)** | `DesktopRenameExecutor`へflagを足す案もあったが、**desktopの実装を1文字も変えない**方を採った。`tool/mutations.json`の17件がこのfileを対象にしており、触ると表ごと揺れる |
| composition rootの切り替え | **このtaskでは行わない** | Androidのハンドルはまだ**SAFのdocument URI**で、pathとして解釈できない。いま切り替えると、実体は壊れないが(対象が見つからず失敗する)revision 2以来の「理由付きの安全な未対応」より分かりにくい失敗になる。**`T07`が絶対pathを供給してから切り替える。** `platform_rename_executor.dart`のdoc commentとtestで固定した |

## この実装で残る限界

- **Androidで実際に動くかは未確認である。** container にSDK・NDKが無く、compileすら
  していない(`gcc -fsyntax-only`はglibcのheaderでの構文検査)。**`T08`が実機で見る。**
- **`__arm__`のsyscall番号だけ照合できていない。** 出典は`T01`のspikeである。
  `x86_64=316`(`asm/unistd_64.h`)、`asm-generic=276`(aarch64)、`i386=353`
  (`asm/unistd_32.h`)はこの環境のkernel headerと一致した。**32bit ARM の header は
  この環境に無い。**
- **`hook/build.dart`からAndroidを未対応対象外にしたので、`dev`のAndroid buildは`T08`まで無検証になる。** CI(`.github/workflows/ci.yml`)はformat / analyze / testだけでAndroidをbuildしない。**受容する**(独立review attempt 1 の P2-4、Agent判断) — Androidは現状`SafRenameExecutor`で改名自体が未対応であり、buildが壊れても**製品機能の後退は無い**。`T08`の受け入れ証拠に「host側のAndroid buildが成功する」が既にあるので追加の手当ては要らない。**保留する案(build設定だけ`T08`直前まで遅らせる)は採らない** — Cとbuild設定を別のtaskへ分けると、`T08`が2つのtaskの成果を同時に検証することになり、失敗の切り分けが難しくなる。
- **劣化経路(`plainRenameFile`)は既存fileを置換しうる。** 呼び出し側が直前に実在確認を
  していることが前提で、`DesktopRenameExecutor`が005 REQ-025でそれを保証する。
  **単体で使うと黙って上書きする。** doc commentへ明記した。

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

**解き方の変更(test を足すのをやめた)。**

1. **既定の束縛を1箇所へ集約した。** `androidRenameOperation` の中だけで `?? 既定`
   を書き、`createAndroidRenameExecutor` は引数を素通しする。束縛点が1つなら
   「既定をすり替える」mutation は必ずその1箇所を指し、生き残れば必ず test が落ちる。
2. **fake を1つも注入しない test group を置いた。** 実 file に対して
   `createAndroidRenameExecutor()` と `androidRenameOperation()` を**引数なし**で
   呼ぶ。production の合成そのものが実行経路に入る。
   - `androidRenameOperation()` を直接呼ぶ test が別に要る理由: executor は
     005 REQ-025 の実在確認で先に止まるので、**排他 rename が通常 rename へ
     すり替わっても executor 経由の結果は変わらない**。

## 作業記録

- 2026-08-13 / ADR-002の採用決定を受けて定義。
- 2026-08-22 / 着手。`T04`の契約承認(revision 4、さらに5 / 5.1)は済んでおり依存は解けていた。C へ Android 分岐(生syscall + arch表 + Android限定の`EINVAL`写像)、`hook/build.dart`からAndroidを未対応対象外へ、`android_rename_executor.dart`(劣化経路)を追加した。**composition rootは切り替えていない**(上表)。
- 2026-08-22 / mutation `M44`〜`M47`を追加し、**2件がSURVIVEDしたのでtestを直した**(上記)。
- 2026-08-23 / **独立review attempt 1 = FAIL(P1が3件、P2が4件)。** **reviewerが自分でmutationを2件足してSURVIVEDを見つけた** — `M47`で直したのと**同じ型が2つ残っていた**。(1) `createAndroidRenameExecutor`の既定wiringを通るtestが無く、**外すとproductionから劣化経路が丸ごと消える**のに緑のままだった。(2) `renameFileWithoutOverwrite`のAndroid分岐が固定されておらず、**外すとrenameat2が製品から消える**のに緑のままだった。factoryの引数を分解し、platform分岐を純関数`usesUtf8NativePath`へ切り出して両方をfactory経由/直接検査できるようにし、`M48`/`M49`として表へ足した。(3) composition rootを切り替えない判断は**妥当と認められた**(reviewerは005 contract revision 5.1がAndroid SAFを未対応と規定していることを根拠に加えた)が、**受け取り側の`T07`に1行も記録が無く**、`T05`がdoneになると013 REQ-005 / REQ-006を製品として観測可能にするtaskが消える状態だった。`T07`へ節を追加した。P2も4件直した。
- 2026-08-23 / **独立review attempt 2 = FAIL(P1が1件、P2が3件)。** reviewerが`R1`〜`R5`を足し、**`?? 既定`の右辺が一度も評価されない**ことでSURVIVEDを4件見つけた。attempt 1 と同じ型が3回目なので、reviewerは「表へ行を足すだけの対応にしないこと」「なぜ2回とも同じ型を作ったかを先に整理すること」を条件に付けた。上の節へ整理し、**既定の束縛を1箇所へ集約**して**fakeを注入しないtest group**を置いた。表は`M50`〜`M53`まで拡張し、集約に伴い`M45`/`M49`/`M50`/`M51`のfind文字列を新実装へ追随させた。P2(`__i386__`の記述、`flutter test`件数、handoff)も直した。
- 2026-08-23 / **独立review attempt 3 = FAIL(P1が2件、P2が1件)。3回目のFAILなのでAGENTS.mdに従い`blocked`とする。** reviewerは表の追随(`M45`/`M49`/`M50`/`M51`)に意味の弱化が無いことと、主張した検証結果すべてを再現したうえで、**自分で足した5件のうち4件がSURVIVEDした**(control 1件はKILLED)。同じ型が**4回目**である。(P1-1) `native_exclusive_rename.dart:69`の呼び出し側を旧形へ戻しても487件が緑 — 純関数`usesUtf8NativePath`は固定したが、**分岐がその関数を使っていること**は誰も固定していない。attempt 1 の P1-2 が純関数の外側へ移動しただけだった。(P1-2) `plainRenameFile`の`on FileSystemException → io`を`success`へ変えても緑。`EISDIR`(errno 21)等が実際にこの分岐へ落ちることをreviewerが実測しており、**改名していないのに`Renamed`が返る**(005 OP-004 / INV-003)。劣化経路4分岐のうちtestが通っているのは2つだけだった。(P2-1) `catch (_)`のcatch-allが未検査。

## Current state / handoff

- Last checkpoint: **独立review attempt 3 = FAIL。`blocked`。** 表全体は 53 KILLED / 0 SURVIVED / 0 SKIPPED だが、**reviewerが足した4件がSURVIVEDした**ので、これは「表が尽きている」ことを意味しない
- Blocker category: **人間の判断**(AGENTS.md「同じtaskで独立reviewが合計3回FAIL」)
- Waiting for: **解き方の選択(下記A / B / C)**
- Requested action: A / B / C から1つ選ぶこと。**manual確認・実機作業は不要**、branch移動も不要(working treeはcleanで維持する)

### 人間へ返す選択肢

同じ型(production が通る合成を test が一度も通らない)が**毎回別の場所で再生産**されている。
現路線は「指摘された seam へ test を1件足す」であり、次の seam が次の指摘になる。

- **A. 現路線を続ける。** `X1`(劣化経路の一般IO失敗)と`X3`(分岐の呼び出し側)を潰し、
  P2-1の受容理由を書いて attempt 4 へ。最小コストだが、**Dart側にplatform分岐が残る限り
  同じ型の seam は残る**。
- **B(reviewer推奨). 枠組みを変える — Dart側のplatform allow-listを消す。**
  `renameFileWithoutOverwrite` を「Windowsなら UTF-16、**それ以外は常にUTF-8 symbolを呼ぶ**」に
  し、「対応するか」の判断を **C と `hook/build.dart` の1層だけ**へ集める(iOSは
  `BRM_UNSUPPORTED_PLATFORM` で C が `UNSUPPORTED` を返すので**結果は今と同じ**)。
  `usesUtf8NativePath` は不要になり、`X3`/`X4`/`M48` の seam は潰すのではなく**消える**。
  確認が要るのは未知OS(fuchsia等)でのsymbol解決だけ。
- **C. この経緯を知らない相手へ一般解を尋ねる。** 「実行環境で走らせられないplatform分岐を、
  regressionを検出できる形で書く一般的な方法」を外部へ聞き、得た案を**ケース表で前提照合して
  から**採る。A / B のどちらとも併用できる。

**どの案でも `X1`(劣化経路の偽の成功)は塞ぐ必要がある** — これは platform 分岐とは別の
seam であり、B で消えるのは `X3`/`X4` 側だけである。
- Evidence revision: branch `asdd/013-safe-android-rename/T05-native-renameat2-port`、base は `dev@8eeab82`(merge-base を実測した値。当初`601ecbb`と書いていたのは誤り)
- Next Agent action: **選択が返るまで実装を進めない。** 返ったら `X1`〜`X4` を `tool/mutations.json` へ正式に取り込み(B なら `X3`/`X4`/`M48` は対象消滅として外す理由を書く)、修正後に**表全体**を回して生出力をここへ貼り、attempt 4 を起動する。**PR #146 はDraftのまま。**
- **`T07`への申し送り**: `platform_rename_executor.dart`のAndroid分岐を`createAndroidRenameExecutor()`へ切り替えるのは`T07`である。同fileのdoc commentに理由を書いてある。切り替えたら`saf_rename_executor.dart`は**wiringから外れるが削除しない**(ADR-002の退避経路)。
- **`T08`への申し送り**: NDKでのcompileと実機での`renameat2`挙動の観測。`__arm__`のsyscall番号の照合もここで取れる。
