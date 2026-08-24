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
| `MANAGE_EXTERNAL_STORAGE`の実際の付与・取り消し | **できない**(実機が要る) | `013:T08` / [`manual-verification.md`](manual-verification.md) |
| 設定画面(`ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION`)への遷移と復帰 | **できない**(実機が要る) | `013:T08` / [`manual-verification.md`](manual-verification.md) |
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
| full regression | `flutter test` = **PASS(530件)**。T06着手前は509件 |
| static analysis | `flutter analyze` = **PASS** |
| format | `dart format --output=none --set-exit-if-changed .` = **PASS** |
| ASDD構造 | `python3 <asdd-plugin>/scripts/workspace.py check specs` = **PASS** |
| OS境界 | `python3 tool/check_platform_boundary.py` = **PASS**(42 file、3 rule、1 required line) |
| mutation | `M82`〜`M96`(T06分)= **15 KILLED, 0 SURVIVED, 0 SKIPPED**。うち`M94`〜`M96`は**独立reviewerが見つけたSURVIVEDを取り込んだもの** |
| **Android build** | **未実施。** AI containerにSDK・NDKが無い |
| **実機確認** | **未実施。** [`manual-verification.md`](manual-verification.md) を人間へ依頼する |

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

## 作業記録

- 2026-08-13 / ADR-002の採用決定を受けて定義。

- 2026-08-24 / **独立review attempt 1 = FAIL(P1が3件、P2が6件)。** 改訂後のAGENTS.md(成果物の欠陥 / 安全網の穴)を適用した判定である。
  - **P1-1(成果物の欠陥)**: **`undo()`に権限確認が無く、未許可の状態で実際に書き込む**(INV-002違反)。しかも「権限不足で断ってもundoを消さない」という**このtask自身の決定**が、「deniedと確認済みなのにundoが生きている」状態を作っている。reviewerがprobeで実測: `executor calls after undo=[rename ..., rename ...]`。
  - **P1-2(成果物の欠陥)**: `manual-verification.md`手順3の期待が**現revisionのAndroidでは発生しない**。実行の前に`prepare()`→`listNames`を通り、`SafFileSource.listNames`は権限に関係なく常に失敗するので、REQ-027の分岐に入って`execute()`へ到達しない。この文面で依頼すると、正しく動いている実装をFAILと報告されうる。
  - **P1-3(安全網の穴。3条件をすべて満たすのでFAIL)**: **composition rootのport結線を外してもtestが1件も落ちない**。`permission`に既定値`UnrestrictedStoragePermission()`があるため、結線が消えるとAndroidでREQ-001とREQ-004の門が**静かに両方消える**。同じfileの`listNames`が「既定値を置かない」理由を既に書いており、**同じ形で閉じられる**。
  - P2: manual手順の内部用語とbranch確認(referenceの明文の禁止)、専用fixtureなしの破壊的操作、dartdocが`ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION`を書いていない、`_permissionDenied`の早期returnでの持ち回り、design土台の適用範囲が未記載、**起動直後は未許可でも説明が出ない**(仕様解釈。人間の判断へ)。
  - reviewerが認めた点: `_running`を最初の`await`より前へ立てた判断、channel失敗を`denied`へ倒して4種を閉じたこと、desktopの振る舞いが変わっていないこと。

## Current state / handoff

- Last checkpoint: **独立review attempt 1 の指摘を反映済み。** `M82`〜`M96`が15 KILLED、`flutter test` = PASS(530)。working treeはclean
- Blocker category: なし
- Waiting for: 独立review attempt 2
- Requested action: なし
- Evidence revision: branch `asdd/013-safe-android-rename/T06-implement-permission-flow`、base は `dev@b318251`(`git merge-base dev HEAD` の実測値)
- Next Agent action: **独立review attempt 2 を起動する。** そのあとPRを作る。 PASSしたら
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
