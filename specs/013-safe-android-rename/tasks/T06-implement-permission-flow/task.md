# T06 権限取得導線を実装する

## 目的

`T02`で承認された方針どおり、`MANAGE_EXTERNAL_STORAGE`を要求し、許可・不許可の状態を画面へ反映する。

## 入力と依存

- `T02`で承認された仕様。
- `Environment.isExternalStorageManager()`(付与の確認)、`Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION`(設定画面への誘導)。

## 変更範囲

- `AndroidManifest.xml`への`MANAGE_EXTERNAL_STORAGE`宣言。**AI sandboxの境界に触れないことを確認する**(`.github/workflows`や`.devcontainer/`ではないので通常のpushでよい)。
- 権限状態を持つcontrollerと、未許可時の表示。
- 設定画面への誘導と、そこから戻ったときの再確認。

**design土台の適用範囲**: [`docs/design/Bulk Renamer.html`](../../../../docs/design/Bulk%20Renamer.html)に
**該当する画面が無い**(権限の説明帯は土台が想定していない要素である)。読み込み導線の
**上**に帯を足す形にした — 導線そのものを置き換えると、許可されたときに戻す動きが増え、
土台の配置から離れる幅が大きくなる。**土台からの逸脱ではなく、土台の外側への追加**である。

**「なぜこの権限が要るか」を利用者へ説明する文言を必ず置く。** 「すべてのファイルへのアクセス」は強い権限で、説明なく求めるappは信用されない。文言は`T02`で承認された仕様に従う。

## machine検証する範囲と引き受け先(AGENTS.md の宣言)

このtaskは**CIで実行できない領域**(Androidの実行時権限、設定画面への遷移、
`AndroidManifest.xml`の効き方)を含む。**どこまでをこの環境で機械検証するか**と
**その外側を誰が引き受けるか**を先に宣言する。**宣言の外側の指摘は安全網の穴として扱う。**

| 対象 | この環境での検証 | 引き受け先 |
| --- | --- | --- |
| 権限状態に応じたUIの表示・操作可否(REQ-001 / REQ-003) | **widget testで閉じる。** portをfakeにして未許可・許可・拒否後を再現する | — |
| 要求のタイミング(REQ-002: 起動時に飛ばさない、読み込み操作で初めて確認する) | **widget testで閉じる。** portへの呼び出し順を観測する | — |
| 直前確認(REQ-004: 読み込み直前と実行直前に毎回確認する) | **widget test / unit testで閉じる。** 状態を途中で変えて再確認されることを観測する | — |
| **INV-002 / VER-003**(未許可でfilesystemへ書き込まない) | **testで閉じる。** 権限portを未許可に固定し、**書き込み側のportへの呼び出しが1件も無い**ことを観測する | — |
| `MANAGE_EXTERNAL_STORAGE`の実際の付与・取り消し | **できない**(実機が要る)。**2026-08-24にmanualで確認済み** | `013:T08` / [`manual-verification.md`](manual-verification.md) |
| 設定画面への遷移と復帰 | **できない**(実機が要る)。**2026-08-24にmanualで確認済み**(アプリ個別画面が直接開いた。一覧へ落ちる分岐は未確認) | `013:T08` / [`manual-verification.md`](manual-verification.md) |
| `AndroidManifest.xml`の宣言が効くこと、Android build | **できない**(SDK/NDKが無い) | `013:T08`(host側のbuild) |
| platform channel の Kotlin 側実装 | **できない**(compileできない)。Dart側は port の fake で閉じる | `013:T08` |
| Playの審査に通るか | **できない** | 人間(`spec.md`の未解決。通らなければADR-002の退避経路へ) |

## 受け入れ証拠

- 未許可・許可・設定画面から戻った直後の各状態で、表示と操作可否が仕様どおりであることをwidget testで検査する。
- 権限判定をportで抽象化し、testで両状態を再現できるようにする(実機に依存しないこと)。
- **INV-002 / VER-003**(013 spec): 権限portを未許可に固定した状態で読み込みと実行を起動し、**filesystem portへの書き込み呼び出しが1件も発生しない**ことをtestで検査する。
- `flutter test` / `flutter analyze` / `dart format --output=none --set-exit-if-changed .` がPASS。
- [`manual-verification.md`](manual-verification.md)で、実機の許可・拒否・設定画面往復を確認する。
- exact rangeの独立reviewがPASSする。

## 決めたこと

| 論点 | 決着 | 理由 |
|---|---|---|
| 「未要求」と「拒否」を分けるか | **分けない**(`denied` の1つ) | 設定画面で与える種類の権限で、1回きりのdialogが無い。013 REQ-003 は拒否後も同じ説明と導線を出し続けることを求めており、**区別しても利用者へ見せるものが同じ**である |
| 確認結果をどこに持つか | **判定には持たない。** 表示のためだけに`_lastSeen`を持つ | 013 REQ-004「一度確認した結果を持ち回らない」。読み込みと実行の可否は毎回`check()`を呼んで決める |
| channelが答えられないとき | **`denied`へ倒す** | 013 INV-002 は「権限が無い状態でfilesystemへ書き込まない」。**分からないときに通す実装はこの不変条件を破りうる**。`null`・型違い・`PlatformException`・`MissingPluginException`をすべて`denied`にした |
| API 30未満の端末 | **`denied`として扱う**(読み込ませない) | `MANAGE_EXTERNAL_STORAGE`はAPI 30で入った権限で、それ未満には**存在しない**。spec D-1の「API levelを対応可否の代理指標にしない」は`renameat2`の話で、こちらは権限そのものが無いので事情が違う |
| 権限確認を`execute`のどこへ置くか | **`_running`を立てた後** | 先に置くと、その`await`の間に2回目の実行が門を通り抜ける(005 REQ-012の二重起動)。**実装中に実際に踏んで、既存testが検出した** |
| 断ったときのundo | **消さない** | 何もしていないのに戻せなくなるのは、利用者から見て実体の損失に近い |

## 検証結果

| 種別 | commandと結果 |
|---|---|
| full regression | `flutter test` = **PASS(540件)**。T06着手前は509件 |
| static analysis | `flutter analyze` = **PASS** |
| format | `dart format --output=none --set-exit-if-changed .` = **PASS** |
| ASDD構造 | `python3 <asdd-plugin>/scripts/workspace.py check specs` = **PASS** |
| OS境界 | `python3 tool/check_platform_boundary.py` = **PASS**(42 file、4 rule) |
| mutation | `M82`〜`M102`(T06分)= **21 KILLED, 0 SURVIVED, 0 SKIPPED**。うち`M94`〜`M98`と`M102`は**独立reviewerが足したもの** |
| **Android build** | **未実施。** AI containerにSDK・NDKが無い |
| **実機確認** | **PASS**(2026-08-24 開発者)。対象commitは **`3576740`**(codeが最後に変わったcommit。以後はdocsのみで、`git diff 3576740..HEAD -- lib android src hook test tool` が空)。手順1〜4がすべて想定どおり。**「設定を開いて許可する」で、このアプリの「すべてのファイルへのアクセス」の画面が直接開いた**(端末によってはアプリ一覧が開きうると書いていたが、この端末では個別画面だった)。**説明文も伝わった** |

**mutationで2件がSURVIVEDしてから直した。** `M84`(権限不足で断ったときにundoを捨てる)は、
断った側しかtestしておらず、**`_clearUndo()`を丸ごと外しても通っていた** — 前回のtimerが
生き残り、2回目のundoを期限前に消す型である。時間を測るtestを足した。
`M91`(channelの失敗を`granted`へ倒す)は、`AndroidStoragePermission`にtestが1本も
無かった。`TestDefaultBinaryMessenger`でLinux上から閉じられるので、**宣言表の
「ここで閉じる」側**へ入れて4種類の失敗を検査した。

## 実装中に踏んだ退行

**権限確認を`_running`より前に置いたら、005 REQ-012(実行中は二重に開始しない)の
既存testがtimeoutで落ちた。** 最初の`await`が門の外にあると、その待ちの間に2回目が
通り抜ける。**実体を二重に変更しうる**ので、これは安全網の穴ではなく成果物の欠陥だった。
`_running`を先に立てる形へ直し、`M83`として表へ入れた。

## 独立review attempt 1 の指摘の始末

| 指摘 | 分類 | 始末 |
| --- | --- | --- |
| `undo()`に権限確認が無く、未許可で実際に書き込む | **成果物の欠陥 P1** | **直した。** `undo()`にも実行直前の確認を入れた(`M92`)。**INV-002は戻す方向も例外にしない。** 断ってもundoは消さない(権限が戻れば期限内はまだ戻せる。`M93`) |
| `manual-verification.md`手順3が現revisionのAndroidで成立しない | **成果物の欠陥 P1** | **手順を`T07`へ送った。** いまの版は`listNames`の段階で止まるので、許可の有無を実行経路で観測できない。`T07`への申し送りへ明記した |
| composition rootのport結線を外してもtestが落ちない | **安全網の穴(3条件を満たす)P1** | **型で塞いだ。** `permission`の既定値を外して`required`にし、結線が消えたら**compilerが止める**(`M94`/`M95`)。Linux上で観測できないplatform分岐は`check_platform_boundary.py`の**`required`検査**を新設して固定した(`M96`) |
| manualに内部用語とbranch確認 | 成果物の欠陥 P2 | **直した。** IDと`git branch`を落とし、日本語の観測事実だけにした |
| manualが専用fixtureなしの破壊的操作 | 成果物の欠陥 P2 | **消滅。** 実行の手順自体を`T07`へ送ったので、改名を伴う操作が無くなった |
| dartdocが`ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION`を書いていない | 成果物の欠陥 P2 | **直した。** アプリ個別画面を先に試し、解決できない端末でだけ一覧へ落ちることを書いた |
| `_permissionDenied`が早期returnで持ち回られる | 成果物の欠陥 P2 | **直した。** `execute`/`undo`とも入口で落とす |
| design土台の適用範囲が未記載 | 成果物の欠陥 P2 | **直した。** 土台に該当画面が無く、**土台の外側への追加**であることを書いた |
| 起動直後は未許可でも説明が出ない | 仕様解釈 | **人間の判断へ回す**(下記) |

**受容した残余risk**(AGENTS.mdの3条件を満たさない。引き受け先つき)

| 残余risk | 満たさない条件 | 引き受け先 |
| --- | --- | --- |
| `MainActivity.kt`のcompileと実行、Intentの解決、`AndroidManifest.xml`の効き方、API 30未満の見え方 | 3(実機・SDKが要る) | `013:T08` |
| Play policyの審査 | 3 | 人間(`spec.md`の未解決。通らなければADR-002の退避経路) |
| 種類シートを開いたまま権限を取り消されても再確認しない | 2(いまのAndroidの読み込みはSAFで、この権限を必要としないので権限逸脱にならない) | `013:T07`(読み込み導線をapp内browserへ置き換える側) |
| `prepare()`(`listNames`)が権限確認より前に走る | 2(readでありINV-002の「書き込み」ではない) | `013:T07` |

## 独立review attempt 2 の指摘の始末

| 指摘 | 分類 | 始末 |
| --- | --- | --- |
| 「設定画面から戻ると説明が消える」が**起きない**。manual・comment・testの3箇所が同じ誤りを主張していた | **成果物の欠陥 P1** | **実装を主張へ寄せた。** `openSettings`は`startActivity`が画面を出しただけで即座に返るので、その時点ではまだ許可されていない。`WidgetsBindingObserver`で**app復帰**を見る形にした(`M99`)。**一度も確認していないうちは復帰しても確認しに行かない**(REQ-002。`M100`)。`handleAppLifecycleStateChanged`でLinux上のwidget testに閉じられる |
| composition rootのport選択を素通しへ差し替えてもtestが落ちない | **安全網の穴(3条件を満たす)P1** | **pinを増やさず閉じた。** `UnrestrictedStoragePermission`を`@visibleForTesting`にし、`check_platform_boundary.py`の**`rules`(依存の不在)**側で`lib/`の他fileでの構築を禁じた。**行の存在ではなく依存の不在**を見るので書き換えでは壊れない(`M97`) |
| `check_platform_boundary.py`のdocstringが、自分が新設した`required`と矛盾 | 成果物の欠陥 P2 | **直した。** 「原則は依存の不在。例外は`required`だけで、代償は承知のうえ。だから増やさない」と書いた |
| `Evidence revision`のbaseが実際の分岐点と違う | 成果物の欠陥 P2 | **直した。** `dev@b318251`(`git merge-base`の実測値) |
| manualの節番号と手順番号が衝突 | 成果物の欠陥 P2 | **直した。** 「ボタンを押すと」「アプリへ戻ってきた直後」など、番号に依らない書き方にした |

**reviewerが認めた点**(ただし「`required`にしたことによる別の抜け道が無い」はattempt 3で覆った — 下記): `undo()`のゲートが**すべての書き込み経路を覆っている**こと
(`_shiftModifiedAtOfSuccesses`は`execute`のゲート後、一時名は`executePlan`の内側、
`prepare()`はread)、`required`にしたことによる別の抜け道が無いこと、既存testへ足した
`permission`の明示が**変更前の既定値と同じ値**でassertionを1つも緩めていないこと、
005 REQ-012とundo期限とdesktopの振る舞いが保たれていること。

**`M88`の対象は消えた。** 復帰時の再確認を入れたことで、`openSettings`の直後の確認は
状態を変えない処理になった(`startActivity`は画面を出しただけで即座に返るので、
押す前と同じ状態を読むだけ)。**観測できない処理を残すより取り除き**、`M88`は
「開けなかったことを表示へ反映しない」変異へ差し替えた。

**`M98`は attempt 3 で対象が変わった。** `required`を撤去したので「意味を変えない書き換えでも
落ちる」対照は不要になり、「写像でdesktopをAndroid側へ倒す」変異へ差し替えた。

**受容した残余risk(追加)**

| 残余risk | 満たさない条件 | 引き受け先 |
| --- | --- | --- |
| `execute-permission-denied` / `undo-permission-denied`のSnackBar分岐にtestが無い | 2(通り抜けても「黙って何も起きない」だけで、実体には触れていない) | `013:T07`(実行経路がAndroidで観測可能になる時点でまとめて) |
| 既存test 6 fileのimport順 | — (`directives_ordering`を有効にしていないので機械検出されない) | 次に触るときに直す |

## 独立review attempt 3 の指摘の始末

**成果物の欠陥のP0/P1は無かった。** FAILの理由は安全網の穴1件(3条件をすべて満たす)である。
**AGENTS.mdの「安全網の穴だけのFAIL」の1回目**にあたる — 次も同種なら3回目は起動せず、
残余riskとして受容して人間へ報告する運用になる。

| 指摘 | 分類 | 始末 |
| --- | --- | --- |
| `required`検査は**コメント行を除外しない**ので、Android分岐を関数の外へ出して同じ行をdoc commentへ残せば騙せる | **安全網の穴(3条件を満たす)P1** | **解き方を変えた**(下記) |
| `required`の保証が実際より強く書かれている(コメント一致で「在る」と判定することが限界に書かれていない) | 成果物の欠陥 P2 | **消滅。** `required`自体をやめた |
| `undo()`の`_clearUndo()`が`await`の後ろへ移り、期限判定に窓ができた | 成果物の欠陥 P2 | **直した。** `check()`のあとで期限を読み直す(`M101`) |
| manualの「設定→アプリ→…」が機種によって辿れない | 成果物の欠陥 P2 | **直した。** 「特別なアプリアクセス」経由の代替を足した |
| manual手順2の期待は単独では反証にならない(再起動でも同じ見え方) | 観察 | **手順3が対照であることを明記した** |

**解き方の変更(3周目なのでpinを足すのをやめた)。**

同じ根本原因 —「composition rootのplatform分岐が消えたことをLinux上で観測できない」— が
attempt 1(結線を`required`へ)→ attempt 2(port選択を`rules`へ)→ attempt 3(その`required`が
騙せる)と**3周した**。行の存在を文字列で見る限りこの往復は終わらない。

- **写像を純関数`storagePermissionFor({required bool isAndroid})`へ切り出した。**
  「Androidならどのportか」は文字列一致ではなく**振る舞い**で固定できる(`M96`/`M98`)。
- **`required`検査を撤去した。** (a)意味を変えない書き換えでも落ち、(b)コメントで騙せる。
  代償だけが残る仕組みだった。`rules`(依存の不在)側は残す — こちらは書き換えで壊れない。
- **残るのは`createPlatformStoragePermission`の実引数1箇所だけ**である。これは
  **兄弟のcomposition root(`createPlatformFileSource` / `createPlatformRenameExecutor`)が
  元から抱えているのと同じ露出**で、それらにpinは無い。**このtaskだけ3つのうち1つを、
  実際には保持しない仕組みで守る**のは整合しないので、同じ扱いに揃えて受容する。

**受容した残余risk(追加)**

| 残余risk | 満たさない条件 | 引き受け先 |
| --- | --- | --- |
| `createPlatformStoragePermission`の`Platform.isAndroid`が消えても、Linux上のCIでは気づけない | 3(**行の存在を文字列で見る以外の手段が無く、それは2回defeatされた**。兄弟2つも同じ露出を持つ) | `013:T08`(実機で門が効くことを確認する) |
| `lib/`に`implements StoragePermissionPort`の素通しclassを自作してcomposition rootで配る | 3(抜け道の列挙に終わりが無い。**新しいproduction classの追加は差分reviewで必ず見える**) | `013:T07`(同じportをapp内browserへ配る側) |
| `AndroidStoragePermission`をdesktopで直接構築する | 2(channelの相手が居ないので`denied`へ倒れ、desktopが読み込めなくなって**すぐ気づく**。門が静かに消える型ではない) | — |

## 独立review attempt 4 の指摘の始末(判定は PASS)

**成果物の欠陥のP0/P1は無く、3条件をすべて満たす安全網の穴も無かった。** 残ったP2 3件を直した。

| 指摘 | 分類 | 始末 |
| --- | --- | --- |
| `undo()`の期限再評価が`canUndo`より1瞬だけ厳しい(`now == deadline`でボタンが出ているのに黙って戻らない) | 成果物の欠陥 P2 | **直した。** 005 contractの用語「巻き戻し期限」は「期限を**過ぎた**ら巻き戻せない」なので、ちょうどはまだ内側である。**述語`isWithinUndoWindow`を切り出して両方が同じものを使う**形にし、境界をtestで固定した(`M102`) |
| `normative_platform.json`の説明配列に空文字列の残骸 | 成果物の欠陥 P2 | 直した |
| manualが「この版のbuildがインストール済み」を前提にしていた | 成果物の欠陥 P2 | **直した。** 「すべてのファイルへのアクセス」の項目はこのアプリを入れて初めて設定画面に現れる。先に入れて一度起動する手順を足した |

**reviewerの`R02`を`M102`として取り込んだ。** reviewerは「到達しない差なのでtestで固定
できない」と見ていたが、**述語を切り出せばLinux上で固定できる**ので、対照(SURVIVEDが
期待値)ではなくKILLEDになる形にした。`R01`(説明文を空にする)は下の残余riskに記録する。

**受容した残余risk(追加。reviewerが3条件で整理したもの)**

| 残余risk | 満たさない条件 | 引き受け先 |
| --- | --- | --- |
| 将来`loadFilesInto` / `executePlan`の**新しい呼び出し元**が足されても、門を通っているかをCIが見ない | 3(呼び出しの**場所**はpinできても**門が先に通ること**は固定できない。`required`がdefeatされたのと同じ型) | `013:T07` |
| REQ-001の説明文の**中身**がpinされていない(空にしてもtestが落ちない。reviewerの`R01`) | 2(伝わらないだけで、データ損失・無断置換・偽の成功・権限逸脱・互換性破壊のいずれでもない) | **現在の文面は2026-08-24の実機確認で「伝わった」と確認済み。**今後の変更は`013:T08`のmanualが見る |

## 実機確認の結果(2026-08-24)

**対象commit `3576740`。** 以後のcommitはdocsのみで、`lib` / `android` / `src` / `hook` /
`test` / `tool` に差分が無いことを確認済み(証拠は現在のHEADに対応する)。

- **手順1〜4はすべて想定どおり。** 未許可でシートが開かず説明が出ること、許可して戻ると
  押し直さずに説明が消えること、許可せず戻ると残ること、狭い画面での見え方。
- **「設定を開いて許可する」で、このアプリの「すべてのファイルへのアクセス」の画面が
  直接開いた。** `MainActivity.kt` が先に試す
  `ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION` が解決されている。
  一覧へ落ちる分岐は**この端末では通っていない**ので、そちらは未確認のまま
  (`013:T08` が別端末で見る)。
- **説明文は伝わった。** `R01`(説明文を空にしてもtestが落ちない)の残余riskは、
  少なくとも現在の文面については実機で確かめられた。

**手順2が対照(手順3)とセットで成立したので、「復帰時に確認し直している」ことが
実機で観測できた** — 独立review attempt 2 の F1 で入れた仕組みが効いている。

## 作業記録

- 2026-08-13 / ADR-002の採用決定を受けて定義。
- 2026-08-24 / **開発者が案(a)を承認。** 013 spec の REQ-001 へ「利用者が読み込もうとして以降」を明記した。**要求の範囲は変えず、曖昧だった点を確定させただけ**である(実装もtestも変わらない)。
- 2026-08-24 / **実機確認 PASS**(上記)。

- 2026-08-24 / **独立review attempt 1 = FAIL(P1が3件、P2が6件)。** 改訂後のAGENTS.md(成果物の欠陥 / 安全網の穴)を適用した判定である。
  - **P1-1(成果物の欠陥)**: **`undo()`に権限確認が無く、未許可の状態で実際に書き込む**(INV-002違反)。しかも「権限不足で断ってもundoを消さない」という**このtask自身の決定**が、「deniedと確認済みなのにundoが生きている」状態を作っている。reviewerがprobeで実測: `executor calls after undo=[rename ..., rename ...]`。
  - **P1-2(成果物の欠陥)**: `manual-verification.md`手順3の期待が**現revisionのAndroidでは発生しない**。実行の前に`prepare()`→`listNames`を通り、`SafFileSource.listNames`は権限に関係なく常に失敗するので、REQ-027の分岐に入って`execute()`へ到達しない。この文面で依頼すると、正しく動いている実装をFAILと報告されうる。
  - **P1-3(安全網の穴。3条件をすべて満たすのでFAIL)**: **composition rootのport結線を外してもtestが1件も落ちない**。`permission`に既定値`UnrestrictedStoragePermission()`があるため、結線が消えるとAndroidでREQ-001とREQ-004の門が**静かに両方消える**。同じfileの`listNames`が「既定値を置かない」理由を既に書いており、**同じ形で閉じられる**。
  - P2: manual手順の内部用語とbranch確認(referenceの明文の禁止)、専用fixtureなしの破壊的操作、dartdocが`ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION`を書いていない、`_permissionDenied`の早期returnでの持ち回り、design土台の適用範囲が未記載、**起動直後は未許可でも説明が出ない**(仕様解釈。人間の判断へ)。
  - reviewerが認めた点: `_running`を最初の`await`より前へ立てた判断、channel失敗を`denied`へ倒して4種を閉じたこと、desktopの振る舞いが変わっていないこと。

## Current state / handoff

- Last checkpoint: **実機確認 PASS(2026-08-24、対象commit `3576740`)。** 独立review attempt 4 = PASS、`M82`〜`M102`が21 KILLED、`flutter test` = PASS(540)
- Blocker category: なし
- Waiting for: なし
- Requested action: なし
- Evidence revision: PR #149、branch `asdd/013-safe-android-rename/T06-implement-permission-flow`、base は `dev@b318251`(`git merge-base dev HEAD` の実測値)
- Next Agent action: **auto-mergeの7条件を確認してPR #149 をmergeする。** そのあとPRを作り、reviewがPASSしてから[`manual-verification.md`](manual-verification.md)を人間へ依頼する。 PASSしたら
  [`manual-verification.md`](manual-verification.md) を人間へ依頼する(reviewの指摘でcodeが
  変わると証拠が失効するので、**reviewを先に通す**)。
- **`T07`への申し送り(1)**: **実行直前の権限確認(REQ-004の後半)とundoの確認は、Androidでは
  end-to-endで観測できない。** 実行の前に`prepare()`→`listNames`を通り、`SafFileSource.listNames`は
  権限に関係なく常に失敗するのでREQ-027の分岐で止まり、`execute()`へ到達しないためである。
  **app内browserが`listNames`を実装し直した時点で観測可能になる**ので、`T07`のmanualへ含めること。
  unit testでは固定済み(`storage_permission_flow_test.dart`)。
- **`T07`への申し送り(2)**: app内file browserも**読み込み導線**なので、013 REQ-001が同じく効く。
  `FileSourceBar`と同じく、browserを開く前に`StoragePermissionPort.check()`を通すこと。
  port は composition root(`main.dart`の`_permission`)から配られている。
- **`T08`への申し送り**: 実機での付与・取り消し、設定画面への遷移と復帰、
  `AndroidManifest.xml`の宣言が効くこと、Kotlin側(`MainActivity.kt`)が動くこと。
  API 30未満の端末での見え方も見られるとよい(`denied`固定で読み込ませない)。
