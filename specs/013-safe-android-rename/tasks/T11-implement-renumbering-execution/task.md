# T11 契約revision 4の実行経路を実装する

## 目的

005 contract revision 4で新設したREQ-023(再採番)、REQ-024(結果の提示)、REQ-025(常に実在確認)を実装する。**desktopを含む全platformが対象である。**

## なぜこのtaskが要るか

**revision 4を承認した時点で、承認済み契約と実装が食い違う状態が`dev`に生まれた。** `lib/data/rename_exec/desktop_rename_executor.dart`はnativeの排他renameを呼ぶだけで、REQ-025が求める実在確認をしていない。005のtaskはT01〜T09すべて`done`で、013の他のtaskはいずれもこの範囲を持たない。

**契約を先に承認し、実装するtaskを作らないまま進める形が一度できていた**(013:T02のreview attempt 2で同型の指摘)。ここで閉じる。

## 入力と依存

- `T04`で承認された005 contract revision 4(REQ-023〜026、OP-001、OP-002、INV-002、INV-003、用語「占有名」「生存名」「確認した目標名」「再採番」)。
- 001の自動解決規則(` (n)`、先頭出現は据え置き、最小の非衝突n)。**001に「任意の名前集合に対する次候補を返す」操作は無い**ので、追加が要る(001 specとcontractの改訂を伴う)。
- 現行実装: `lib/data/rename_exec/`、`test/spec_005_rename_exec/`。

## 変更範囲

- **001**: 生存名を受け取って次候補名を返す操作。純粋Dartのまま。
- **005 実行orchestration**: `OP-001`へ`occupiedNames`、`OP-002`へ`occupiedNames`と`renumber`を通す。生存名の組み立て(5要素)は`execute`が持つ。
- **再採番のループ**: `nameConflict` → 次候補 → 再試行。試行上限と、`renumber`が`null`を返したときの失敗記録。
- **一時名・復旧改名・巻き戻しでは再採番しない**(REQ-023)。**利用者が確認していない名前を内部ステップで作らない。**
- **結果の提示**(REQ-024): 再採番された項目が「確認した名前と異なる」と分かる形。
- **改名ポート**(REQ-025): **常に**実在確認してから改名し、原子的no-replaceがあれば併用する。desktopとAndroidの両方。

## 決めること

- **再採番の試行上限**(contract `open_questions` OQ-001)と、上限に達したときの提示文言。
- **契約の`open_questions` OQ-002(REQ-027の操作面とSM-001の遷移)、OQ-003(`occupiedNames`の全域性)、OQ-005(一時名と再採番の相互回避)をこのtaskで決める。** 決まった内容は**revision 5として契約へ戻す。**
- **`renumber`が`null`を返す条件**(候補が尽きる場合があるか)。

## 被覆した仕様

**`task.json`の`covers`は空にしている。** `covers`は所属plan(013)の`spec.md`へ解決されるため、005契約のREQ IDを書くと**同じ番号の013の別要求と黙って一致する**(`T04/task.md`の規約)。このtaskが実装した005側のIDは次のとおり。

- REQ-023(再採番)、REQ-024(結果の提示)、REQ-025(常に実在確認)
- INV-003(実行結果と実体の一致)、OP-002(実行)、OP-004(改名port)、VER-008

## 受け入れ証拠

- 005 spec.mdの例24・26・28・29・30に対応するtestがある(VER-008)。
- **一時名への改名と復旧改名で再採番が起きない**ことをtestで検査する。**片方向だけでは足りない** — 再採番する側としない側の両方を固定する。
- **desktopで実在確認が行われる**ことをtestで検査する(REQ-025)。**Windows / macOS では未検証**(containerはLinuxのみ)。大文字小文字を区別しないfilesystemでの挙動は`T08`と同じ扱いで、実機確認が要る。
- **自己衝突を判定しない**ことをtestで検査する。一時名を経由する経路(case-only / 別の実体 / hard link / 巻き戻し失敗)を、**containerのLinuxで**検査する。**mutationは両方向で行う** — attempt 5で片方向だけの確認を「確認した」と報告した。
- 生存名の5要素すべてが再採番の照合に効くことをtestで検査する。**特に「すでに確定した結果名」**(review attempt 2のP1-2)。
- 005の既存contract testが継続PASSする。
- `flutter test` / `flutter analyze` / `dart format --output=none --set-exit-if-changed .` がPASS。
- **OQ-001とOQ-005が決着している。** ただし**契約revision 5への反映は`T10`が行う**(`T10`の受け入れ証拠に書いた) — `T10`のOQ-004/OQ-006と同時に承認を取るほうが、人間へ一度で問える。**このtaskの完了は「決着したこと」までで、契約への反映を条件にしない。**
- **OQ-002(REQ-027のSM-001遷移)とOQ-003(`occupiedNames`の全域性)は`T10`へ移す。** どちらも占有名の供給元が要り、このtaskの範囲では決められない。
- exact rangeの独立reviewがPASSする.

## 作業記録

- 2026-08-14 / `T04`のreview attempt 2のP1-5を受けて定義。**REQ-023〜025を所有するtaskが無く、承認済み契約を誰も実装しない状態だった。**

- 2026-08-14 / **着手。再採番の実行経路(REQ-023/024)と、常に実在確認(REQ-025)を実装した。**
  - **001**: `nextCandidateName(fullName, taken, {limit})` を追加。`autoResolve` と**同じ規則**(ベース名の末尾へ` (n)`、衝突しない最小の n)で、判定する名前集合を呼び出し側が渡す形。`autoResolve` は選択集合から集合を組み立てる形なので、実行の途中で「その時点の生存名」に対して次候補を求めることを表現できなかった。
  - **005 `executePlan`**: `occupiedNames` / `renumber` / `renumberLimit` / `folderOf` を受け取り、**生存名を組み立てるのは `execute`** とした(OP-002)。`nameConflict` を受けたら次候補で再試行する。
  - **再採番するのは`RenameStepKind.target`だけ**。一時名への改名・停止時の復旧改名・巻き戻しでは再採番しない(REQ-023)。
  - **`SuccessfulRename`へ`confirmedTargetName`と`renumbered`を追加**(REQ-024)。再採番後の名前を`newName`として記録する(INV-003)。
  - **desktop**: 改名の前に目標名の実在を確認する(REQ-025)。**native の排他 rename があっても省かない。**
  - **OQ-001(試行上限)を`8`と決めた。** 事前検出を通ったうえで衝突するのは他processがちょうどその名前を作った場合だけで、それが8回続く状況は「名前が埋まっている」ではなく**別の何かが起きている**(監視appの書き戻し、誤ったerrno等)。試し続けるより止めて理由を見せるほうがよい。
  - **OQ-005(一時名との相互回避)を解いた。** 生存名の(4)を「その時点で存在する一時名」ではなく**計画が使う一時名すべて**にした。これから使う予定の一時名を再採番が先取りすると、後続の一時名への改名が衝突し、REQ-023が一時名を再採番対象から外しているために停止する。
  - test: `test/spec_005_rename_exec/renumbering_test.dart`(16件)と、desktop の REQ-025 を1件。**REQ-025 の test は実装を外すと落ちることを確認した**(vacuousでない)。`flutter test` — PASS (376、+17)。
  - **未着手**: OQ-002(REQ-027のSM-001遷移)、OQ-003(`occupiedNames`の全域性)、REQ-026/027の経路。**`occupiedNames`は現状どこからも渡っていない**(既定は空)。これは`T10`が004/001側から供給する。
  - **`defaultFolderOf`は暫定である。** ハンドルを path とみなして最後の`/`より前を取るだけで、`/`を含まないハンドルでは空文字を返して**すべて同一folder扱い**になる。SAF URIのような形も想定していない。同一性判定の責務はOQ-004(`T10`)。

- Review attempt 1: `691d3f5..1734f6f` — FAIL — P1×3、P2×7。無限ループ・データ破壊・INV-002/INV-003違反は無いと確認された。mutation検査で、主要なtestがvacuousでないことも確認された。
  1. **P1: 再採番が` (n)`のnを進めず、接尾辞を入れ子にしていた。** `renumber`へ**直前の試行名**を渡していたため、`x.jpg` → `x (1).jpg` → **`x (1) (1).jpg`**(正しくは`x (2).jpg`)。契約の`OP-002`が`renumber: (改名要求, 生存名)`と書いているのは、**毎回「確認した目標名」から数え直す**ためだった。**signatureを`(String, Set)`に変えたときに意図を落とした。** → `RenumberCandidate`を`(RenameRequest, Set<String>)`へ戻し、実行時に観測した衝突名を照合集合へ足すようにした。
  2. **P1: 大文字小文字を区別しないfilesystemで、case-onlyの改名が`nameConflict`になっていた。** `destination != handle`という生の文字列比較だったため、Windows/macOSでは`img_01.JPG → img_01.jpg`が**自分自身を衝突と誤判定**し、再採番で`img_01 (1).jpg`が確定する。**このPRが持ち込んだ振る舞いの変化である。** → `p.equals`で同一実体を判定するようにした。**containerはLinuxのみなので、この経路の実測はできていない。**
  3. **P1: REQ-024の「利用者へ提示」が実装されていなかった。** `renumbered`/`confirmedName`を読むcodeが`lib/`に1つも無く、利用者は確認した名前と違う結果になった事実に気づけない。**PR本文は「UIから読める」と書いており、事実より広い説明だった。** → 結果トーストへ「実行中に名前が使われていたため N 件の名前が変わりました(旧 → 新)」を出し、widget testを2件(出る側・出ない側)追加した。
  - P2×7も解消(`unchanged`分岐が`recordSettled`を呼ばない依存の明示、`nextCandidateName`と`autoResolve`の拡張子境界の違いをdocへ、構造ガードtestの位置づけをcommentへ、group名、`defaultFolderOf`の暫定性、契約revision 5の所有を`T10`へ明記、PR本文のstatus)。

- Review attempt 2: `691d3f5..39183a9` — FAIL — P1×2、P2×6。attempt 1のP1-1(接尾辞の入れ子)とP1-3(REQ-024の提示)は**mutationで解消を確認**された。
  1. **P1: `p.equals`は大文字小文字を無視しない。** `package:path`のcase非依存比較は**Windows styleにしか実装されていない**(`windows.dart`にしかoverrideが無く、macOSは`posix` style)。reviewerが`Style.platform`と`equals`を実測して示した。**私の修正はWindowsでしか効かず、コメントとtask.mdは「macOS(APFS既定)も」と事実より広く書いていた。** macOSでは`Photo.jpg -> photo.jpg`が再採番され、`photo (1).jpg`が確定する。**これはattempt 1でこのPRが新設した経路である**(それ以前は失敗として止まっていた)。
    - 対処: **同一実体の判定をやめた。** Dartからinodeを見る手段が無く、判定を誤ると**別の実体を上書きする**。代わりに**実行orchestration側で「大文字小文字だけの改名は再採番しない」**を保証する(`_isCaseOnlyChange`)。衝突したら失敗として提示し、利用者に判断させる — attempt 1以前の振る舞いへ戻る。**Windows / macOSが未検証であることをcode・task.md・PR本文の3箇所へ書いた。**
  2. **P1: REQ-024の提示が4件目以降を落としていた。** `take(3)` + 「ほか」で、**残りは黙って別の名前になる**。`occupiedNames`がまだ供給されていない現状では、folderに読み込んでいない同名fileがあるだけで多数同時に起きるため、**再採番が最も起きやすい今の状態で提示が打ち切られる**。→ 全件を並べ、多いときは高さを制限してスクロールさせる。4件のwidget testで固定した(`skipOffstage: false`で数える — 主眼は「打ち切らない」ことであって画面内の見た目ではない)。
  - P2×6も解消(OQ-002/OQ-003のownerを`T10`へ移動、`T11`の受け入れ証拠から「revision 5として反映」を外す、005 `spec.md`のtest未存在の記述、`covers`、失敗時の提示文言はOQ-001の未決着分として残す旨)。

- Review attempt 3: `691d3f5..ea8ab61` — FAIL — P1×3、P2×6。attempt 2のP1-B(`take(3)`)は解消と確認された。4つの新規testはすべてmutationで落ちることも確認された。
  1. **P1: `_isCaseOnlyChange`が、case-sensitiveなfilesystemで正当な再採番まで止めていた。** reviewerが実FS(Linux/ext4)で実測: `Photo.jpg`(target `photo.jpg`)と**別実体の**`photo.jpg`がある状況で、再採番せず失敗して**実行全体が停止**する。REQ-023は`photo (1).jpg`への再採番を要求しており、除外条項は閉じた4項でcase-onlyを含まない。**plan 013が対象とするAndroid内部ストレージがまさにcase-sensitiveである。**
  2. **P1: その除外条項が契約にもrevision 5の範囲にも登録されていなかった。** `T10`へ移したのはOQ-001とOQ-005(どちらも実装が契約より**広い**側)だけで、**狭い側を記録した成果物がゼロ**だった。
  3. **P1: 同じ穴が正規化(NFC/NFD)の軸に残っている。** APFSはcaseだけでなくnormalization-insensitiveでもあるため、`toLowerCase()`比較では塞げない。macOS実測はできていないが、**guardの存在理由と同じ根拠**である。
- 2026-08-14 / **3回連続FAILのため、AGENTS.mdに従い自動修正を停止し人間へ報告した。**
  - **否定された仮定**: 「filesystemのcase感度・正規化感度を、アプリ側が名前の比較で代用できる」。**代用できない。** 3回とも「アプリが知らない情報を推測で埋める」形の修正だった(`destination != handle` → `p.equals` → `toLowerCase()`)。**判定できるのはfilesystemに触るport側だけである。**
  - **見つけた解**: `dart:io`の**`FileSystemEntity.identical(path1, path2)`**が、まさに「2つのpathが同じ実体を指すか」を返す。containerで実測した — 同一pathで`true`、別実体で`false`、片方が無いと`PathNotFoundException`。**これを使えばcase感度も正規化感度も推測せずに済み、`_isCaseOnlyChange`という契約に無い除外条項ごと削除できる**(P1-1〜P1-3が同時に消える)。
  - **勝手に適用しない。** 3回連続FAILの直後に4つ目の修正を当てるのは、これまでと同じ形である。人間の判断を待つ。

- 2026-08-14 / **開発者の判断で`FileSystemEntity.identical`案を採った。**
  - **自己衝突の判定をport側へ移した。** `FileSystemEntity.identical(handle, destination)`がfilesystemへ問い合わせて同一実体かを返す。**case感度も正規化感度もアプリ側で推測しない。**
  - **自己衝突と分かったら排他renameを使わない。** macOSの`renamex_np(RENAME_EXCL)`はこの場合も`EEXIST`を返すため、排他renameのままでは塞げなかった。同一実体だと確認済みなので、通常のrenameで上書きされる相手は存在しない(INV-002を破らない)。
  - 判定できない場合(`FileSystemException`)は**「別の実体」として扱う**。誤って同一とみなすと既存を上書きするので、安全側へ倒す。
  - **`_isCaseOnlyChange`を削除した。** 契約に無い除外条項が消え、attempt 3のP1-1(case-sensitiveで正当な再採番まで止める)、P1-2(契約に登録されていない狭め)、P1-3(正規化の軸)が同時に解消した。**実行orchestrationへ届く`nameConflict`は本物の衝突である**と言い切れるようになった。
  - test: portとorchestrationの各経路。**当初「Linuxでは自己衝突の経路を通らないので回帰ガードにすぎない」と書いたが、これは誤りだった**(review attempt 4のP1-2)。hard linkがあれば`identical`は真を返すので、**Linuxからその分岐へ到達できる。そして到達した先が誤動作していた**(下記)。

- Review attempt 4: `691d3f5..ba890ea` — FAIL — P1×2、P2×2。`_isCaseOnlyChange`の削除は正しい方向と確認され、symlinkは安全側、再採番orchestrationのtestは本物、PR本文の範囲説明も今回は一致と確認された。
  1. **P1: `FileSystemEntity.identical`は「同じ実体(dev+inode)か」であって「同じdirectory entryか」ではない。** hard linkは別の名前が同じinodeを指すので真を返す。それを自己衝突とみなして通常のrenameへ進むと、**POSIXの`rename()`は「同じfileの別entry」に対して何もせず成功を返す**ため、実体が動いていないのに改名済みとして記録される(**INV-003違反**)。reviewerが実FSで再現した。**この経路はこのPRが新設した。**
    - 対処: 判定を2段にした。(1) `identical`で同じ実体か、(2) **親directoryの実際のentry名にbyte一致で存在するか**。hard linkは(2)で真になり衝突側へ、case/正規化の別名は保存されている名前とbyte一致しないので自己衝突側へ落ちる。
  2. **P1: 自己衝突の分岐に能動的なtestが1件も無かった。** `identical`の呼び出しを削除してもCIが緑だった。しかも**「Linuxでは自己衝突の経路を通らない」という私の自己申告が、そのままP1-1を隠していた。**
    - 対処: **`DesktopPathProbe`を導入し、3つの述語(実在 / 同一実体 / byte一致のentry)を注入可能にした。** case感度・正規化感度はcontainerの実FSでは再現できないので、条件そのものを注入する。あわせてhard linkの実FS testも足した。~~mutationで、3つの述語それぞれを外すとtestが落ちることを確認した。~~ **これは誤りだった**(attempt 5のP1-1)。確認したのは`isSameEntity`を`false`へ倒す方向だけで、**`true`へ倒す方向は1件も落ちない**。自分で再実測して確かめた。
  - P2×2も解消(自己衝突経路のTOCTOUを「無い」と断言していたのを撤回し窓の存在をcodeへ明記、OQ-001の`status`を`partially decided`にして提示文言が未決着であることを残した)。
  - `flutter test` — PASS (386、+27)。

- Review attempt 5: `691d3f5..2b5f751` — FAIL — P1×3、P2×4。再採番ループ・試行上限・REQ-024の提示・INV-003の記録には退行なしと、11個のmutationで確認された。注入testがproduction経路を通っていることも確認された。
  1. **P1: 「3述語それぞれを外すとtestが落ちる」という私の申告が事実と違った。** 確認したのは`isSameEntity`を`false`へ倒す方向だけで、**`true`へ倒すと386件すべてPASSする。** 自分で再実測して確かめた。その述語は`(exists:true, sameEntity:false, exactEntry:false)`= **別実体との衝突**を止めており、外すと上書きする`File.rename`が別fileを破壊する。**INV-002のdata lossを一枚で止めている述語が、外しても誰も気づかない状態だった。** attempt 4のP1-2と同じ形が、注入testを足した後の面で再発した。
  2. **P1: 2段判定は「case/正規化だけ名前が違うhard link」を今も自己衝突と誤判定する。** case-insensitiveなFSで`a.txt`とhard link`B.txt`があるとき、`a.txt → b.txt`は`exists=true`(`B.txt`へfold)/`sameEntity=true`(同一inode)/`hasExactEntry=false`(保存名は`a.txt`と`B.txt`でbyte一致しない)となり、**自己衝突分岐へ落ちる**。attempt 4で塞いだのは「byte一致するhard link」だけだった。
  3. **P1: 自己衝突の例外がspecsのどこにも登録されていない。** 承認済みREQ-025は無条件で「実体があると判定できたら`nameConflict`を返す」と書いており、実装は**契約に無い例外**を持つ。attempt 3のP1-2は「除外条項が契約に登録されていない」だった。**除外がorchestrationからportへ移っただけで、未登録である状態は同じ。** PR本文の「契約より狭い箇所は無い」も事実と違う。
- 2026-08-15 / **5回連続FAILのため、AGENTS.mdに従い自動修正を停止し人間へ報告した。**
  - **否定された仮定**: 「判定条件を増やせば、改名の前に自己衝突かどうかを言い当てられる」。**言い当てられない。** 5回とも「条件を1つ増やす → 増やした条件の外側に反例が見つかる」だった(`!=` → `p.equals` → `toLowerCase` → `identical` → `identical + byte一致`)。**filesystemの同一性規則をアプリ側で先に決め切ろうとしている点は、契約を実装なしで磨いて5回FAILしたのと同じ形である。**
  - **reviewerが示した別の型の解**: 判定を増やすのではなく、**改名したあとに結果を確認する**。`File.rename`のあとで「元の名前のentryが消え、目標名のentryができた」をfilesystemへ問い合わせ、満たさなければ`Renamed`を返さない。**hard linkのno-opも、case-only renameを黙って無視するFSも、同時に「成功として記録しない」側へ倒れる。** 予測をやめて観測にする。
  - **勝手に適用しない。** 6つ目の条件を足すのと、判定の型を変えるのは違うが、5回連続の直後である。

- 2026-08-15 / **開発者が第3案(一時名を経由する2段階rename)を選択。** 別のAIへ問い合わせて出てきた案で、**私が5回の間一度も検討しなかった型**である([finding](../../../../development-findings/2026-08-15-asking-another-ai-broke-a-five-attempt-deadlock.md))。
  - **判定を持たない形にした。** 目標名に実体があるとき、自分自身かどうかを**言い当てず、一時名を経由して確かめる**。
    1. 排他renameで**一意な一時名**へ退避(一意なので衝突しない)
    2. 排他renameで一時名 → 目標名。**成功なら自分自身だった**(case-only改名)
    3. `nameConflict`なら**別の実体**。排他renameで元の名前へ巻き戻し、`nameConflict`を返す
  - **一度も上書きrenameを使わない。** どちらの段も排他rename(`RENAME_NOREPLACE`相当)である。
  - **`_isCaseOnlyChange`・`identical`・byte一致の判定をすべて削除した。** attempt 3のP1-2/P1-3(契約に無い除外条項が未登録)と、attempt 5のP1-1/P1-2/P1-3が同時に解消した。**契約に無い例外が無くなり、REQ-025を字面どおり満たす。**
  - **提案は「小文字比較でcase-onlyと判定したときだけ2段階」だったが、`EEXIST`(目標名が実在)を引き金にする形へ変えた。** 判定が完全に消え、小文字比較では拾えない**正規化の軸**も同じ経路で通る。
  - **containerのLinuxで全ケースをtestできるようになった** — 判定を持たないので「case-insensitive FSを再現しないと検査できない」が消えた。case-only(注入)、別の実体、hard link、巻き戻し失敗の4件。**一時名経路を通らない改変で2件、巻き戻しをしない改変で5件が落ちることをmutationで確認した。**
  - **異常終了で一時名が残る窓**については、005 `spec.md`へ「一時名が残ったときの提示」節を追加した。**実行中の失敗は提示できる**(巻き戻し失敗時に現在名を理由へ含める)。**process強制終了・電源断は提示する仕組みが無い**ので対象外とし、product-mapの将来候補へ入れた。**元の名前は空くので次回の実行を妨げない** — preflightの残骸と違い恒久的な阻害にならない。
  - `flutter test` — PASS (385)。

- Review attempt 6: `691d3f5..2d3e4f9` — FAIL — P1×5、P2×4。**設計変更そのものは正しい方向と確認された** — 「判定の外側に反例が出る」型の穴は**このrangeで1件も見つからなかった**(5回続いていた)。2段階renameに上書き・データ破壊の経路は無く、一時名の名前空間の衝突も無いことが実測された。再採番・試行上限・生存名(2)(3)(4)・REQ-024の提示・INV-003の記録も8個のmutationで退行なしと確認された。
  1. **P1: `_renameViaTemporary`を`await`していなかった。** `try { return future; }` はfutureをtryの外で待つので、**新設した経路だけが`catch`の保護外**だった。例外が`rename()`の呼び出し側へ抜け、実行全体を貫通する — fileは一時名のまま、結果トーストも出ず、**同じbatchで成功済みの改名をundoできない**(REQ-017違反)。→ `return await`。回帰testを追加した。
  2. **P1: 巻き戻し失敗時に`OP-004`の事後条件「失敗時、実体は変化しない」を破るのに、その食い違いが未登録だった。** OQ-007は「異常終了で一時名が残ること」しか書いていなかった。→ OQ-007へ追記し、005 `spec.md`の節にも書いた。**契約から外れた箇所の未登録は3回目**(attempt 3のP1-2、attempt 5のP1-3と同型)。
  3. **P1: REQ-025の実在確認を検証しているtestが1件も無かった。** `_RealPathProbe.exists`を`true`にも`false`にも倒して385件すべてPASSした。分岐の存在は注入testが守っていたが、**productionの述語が実際に参照されているか**は誰も見ていなかった。→ 既定のprobeのままrename呼び出し**回数**を固定するtestを追加(実在する目標名→3回、空いている→1回)。**両方向のmutationで落ちることを確認した。**
  4. **P1: 生存名の第5要素のtestがvacuousだった。** 確定名が「未実行の目標名」としても集合へ入るfixtureだったため、`recordSettled`を消しても落ちない。**attempt 2で指摘され、受け入れ証拠に明記した項目が満たされていなかった。** → **先行要求自身を再採番させて確定名 ≠ targetName にする**fixtureへ変えた。
  5. **P1: `handoff`がattempt 4のままで、削除済みの「2段判定」を現在地として指していた。** そこから再開するAgentは**判定を足す方向へ戻る** — `Next Agent action`が禁じている動きをhandoff自身が誘導していた。
  - P2×4も解消(巻き戻し成功後の理由文が存在しない一時名を含んでいた、二重の一時名のケースを005 specへ、PR本文の「contractに無い例外が無くなった」が同本文のOQ-007と矛盾、契約をrevision据え置きで編集した件)。
  - `flutter test` — PASS (387)。

- Review attempt 7: `691d3f5..17fc284` — FAIL — P1×3、P2×4。**設計そのものは今回も正しい方向**と確認された — data lossにつながる経路・上書きrename・INV-002/INV-003違反はこのrangeに無く、「判定の外側に反例が出る」型の穴も見つからなかった。**私が申告した4つのmutationはすべて再現された**(failure mode 6の再発なし)。
  1. **P1: 1段目を通ったあとの例外で、巻き戻さずに抜けていた。** 実体は一時名にあるのに、理由文に名前が出ない。**attempt 6で新設した回帰testが、この経路を通しながら`isA<RenameFailed>()`しか見ておらず、自分が作り出した残骸状態を1行も観測していなかった。** さらに、同じrangeで登録したばかりのOQ-007が**すでに実装より狭かった**(「巻き戻しにも失敗した場合」しか書いていない)。→ 例外時も巻き戻すようにし、`_rollbackAfter`へ集約した。testは残骸が消えることまで見る。
  2. **P1: 生存名の第2要素(未実行の目標名)にtestが無かった。** 除去しても387件すべてPASS。**先行fileが後続fileの確認済み目標名を横取りし、`x (1) (1).jpg`が確定する** — attempt 1のP1-1で直した症状そのものが、無言で再発しうる状態だった。**attempt 6の修正が「(5)のfixtureを直す」に閉じ、受け入れ証拠が要求する「5要素すべて」へ届いていなかった。** → (2)と(3)のtestを追加し、mutationで落ちることを確認した。
  3. **P1: attempt 6のP1-5(handoff)が解消されていなかった。** 更新されたのは`Next Agent action`の1行だけで、`Last checkpoint`は削除済みの「2段判定」を、`Waiting for`は3回前のattemptを指したままだった。**作業記録には解消済みと書いていた。** → `- Review attempt 8: `691d3f5..29e9d5d` — FAIL — P1×2、P2×3。attempt 7のP1×3は解消と確認された(`_rollbackAfter`の4経路、生存名の5要素すべてがmutationで落ちる、handoffの更新)。
  1. **P1: 実在を肯定的に検出した目標名へ、no-replaceフラグだけを頼りにrenameしていた。** 1段目のあとに再観測が無く、**フラグを黙って無視する環境では2段目が成功して、実在を確認済みの別の実体を上書きする**。**REQ-025の存在理由そのものが「フラグを黙殺する環境」なのに、`exists`と分かった側だけ塞げていなかった。** → **1段目のあとに目標名をもう一度観測する。** 空いていれば自分自身だったので前進、まだ実在するなら別の実体なので2段目を実行せず巻き戻す。**判定は一切増えない** — 観測するだけである。
  2. **P1: `return await`を守るtestが失われ、PR本文のmutation申告が事実と違った。** attempt 7で例外処理を`_renameViaTemporary`の内側へ移した結果、attempt 6の回帰testが内側のcatchを通るようになり、**外側の`await`を検証しなくなった**。`await`を外しても390件すべてPASSする状態で、PR本文には「いずれも落ちる」と書いていた。**確認漏れの4回目。** → 内側でcatchを持たない唯一の箇所(再観測)で例外を投げるtestを足し、`await`除去で落ちることを実測した。
  - P2×3も解消(別folderの改名要求を生存名から除く検査、一時名確保ループの2分岐の検査、OQ-001/005/007のownerを「`T11`が決着 / `T10`がrevision 5へ反映」で統一)。
  - **mutationは11種を両方向で実測した** — `await`除去、再観測除去、1段目の例外catch除去、確保ループの上限、非`nameConflict`の早期return、巻き戻し(4経路)、生存名(1)〜(5)、folder絞り。**すべて落ちる。**
  - `flutter test` — PASS (397)。

## Current state / handoff`のblock全体を書き直し、**読み返して確認した。**
  - P2×4も解消(`covers`が空である理由を「被覆した仕様」節へ明記、生存名の第3要素のtest、findingの改善結果を実際の採用案と結果へ更新、PR本文のmutation件数は再測定した値へ)。

- Review attempt 8: `691d3f5..29e9d5d` — FAIL — P1×2、P2×3。attempt 7のP1×3は解消と確認された(`_rollbackAfter`の4経路、生存名の5要素すべてがmutationで落ちる、handoffの更新)。
  1. **P1: 実在を肯定的に検出した目標名へ、no-replaceフラグだけを頼りにrenameしていた。** 1段目のあとに再観測が無く、**フラグを黙って無視する環境では2段目が成功して、実在を確認済みの別の実体を上書きする**。**REQ-025の存在理由そのものが「フラグを黙殺する環境」なのに、`exists`と分かった側だけ塞げていなかった。** → **1段目のあとに目標名をもう一度観測する。** 空いていれば自分自身だったので前進、まだ実在するなら別の実体なので2段目を実行せず巻き戻す。**判定は一切増えない** — 観測するだけである。
  2. **P1: `return await`を守るtestが失われ、PR本文のmutation申告が事実と違った。** attempt 7で例外処理を`_renameViaTemporary`の内側へ移した結果、attempt 6の回帰testが内側のcatchを通るようになり、**外側の`await`を検証しなくなった**。`await`を外しても390件すべてPASSする状態で、PR本文には「いずれも落ちる」と書いていた。**確認漏れの4回目。** → 内側でcatchを持たない唯一の箇所(再観測)で例外を投げるtestを足し、`await`除去で落ちることを実測した。
  - P2×3も解消(別folderの改名要求を生存名から除く検査、一時名確保ループの2分岐の検査、OQ-001/005/007のownerを「`T11`が決着 / `T10`がrevision 5へ反映」で統一)。
  - **mutationは11種を両方向で実測した** — `await`除去、再観測除去、1段目の例外catch除去、確保ループの上限、非`nameConflict`の早期return、巻き戻し(4経路)、生存名(1)〜(5)、folder絞り。**すべて落ちる。**
  - `flutter test` — PASS (397)。

## Current state / handoff

- Last checkpoint: attempt 8のP1×2・P2×3を解消。1段目のあとに目標名を再観測する形にした
- Blocker category: なし
- Waiting for: 独立review(attempt 9)
- Requested action: なし
- Evidence revision: `dev@691d3f5` + 005 contract revision 4(approved 2026-08-14)
- Next Agent action: attempt 9を起動する。次の3点を守る。
  - **判定を足す方向の修正が出てきたら、それは元の型への逆戻りである。**
  - **契約のrevision 5更新(OQ-001 / OQ-005 / OQ-007の反映)は`T10`が自分のOQと一緒に行う。** 実装が契約と食い違う状態を放置しない。
  - **case-insensitiveなfilesystemの実測は`T08`と同じ扱いで人間の作業として残る。**
