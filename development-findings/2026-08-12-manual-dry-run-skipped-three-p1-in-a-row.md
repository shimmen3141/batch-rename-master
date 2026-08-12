# Development finding: manualの依頼前dry-runを実行せず、3回連続でP1を出した

- 観測日: 2026-08-12
- 観測した作業: PR #121(移行で落ちたmanual checklistの復元)。独立reviewが3回連続FAIL
- 改善先: 筆者の実行手順、およびASDD plugin(`manual-verification.md`のdry-run節の実効性)
- 関連artifact: `/home/dev/.claude/skills/asdd/skills/asdd-setup/references/manual-verification.md`の「依頼前のdry-run」節、`specs/004-file-source/tasks/T10-verify-target-platforms/manual-verification.md`

## 観測した事実

`004:T10`のmanual checklistについて、独立reviewが3回連続でFAILした。3件のP1は種類が違うが、**いずれもrepository内の情報だけで防げた**。

| attempt | P1 | 種類 |
|---|---|---|
| 1 | 1回のpicker sessionで2 folderから選ばせるstepが実行不能 | platform挙動の誤認 |
| 2 | attempt 1の是正commitがAndroidのcancel確認stepを削除 | 書き直しによる退行 |
| 3 | 設定画面のアプリ名を`一括リネーム（デモ）`と書いたが、実際は`batch_rename_master` | UI文言の誤り |

attempt 3のP1は、attempt 2のP2-f「アプリ表示名が書かれていない」への是正で混入した。**修正前の`このアプリ`という曖昧な表記の方が正しかった。** `一括リネーム（デモ）`は`lib/main.dart:44`の`MaterialApp.title`で、これはRecents(最近使ったアプリ)の表示名である。設定→アプリの一覧に出るのは`android/app/src/main/AndroidManifest.xml:3`の`android:label="batch_rename_master"`。

3回のうち2回(attempt 2・3)は、**是正commitが新しい欠陥を持ち込んだ**ものである。

## 根本原因

skillの`manual-verification.md`は「依頼前のdry-run」として次を求めている。

> 記載したボタン名、画面文言、path、commandがcurrent revisionに存在する。

**筆者はこれを実行していなかった。これが原因である。**

3件のP1は、いずれも**repository内の情報だけで防げた**。

- attempt 3(アプリ表示名): `git grep -n 'android:label' android/` の1行。
- attempt 1(folder跨ぎ選択): `specs/004-file-source/tasks/T07-redesign-selection-flow/task.md`に、DocumentsUIはフォルダ移動で選択が解除されるとprojectが既に記録していた。
- attempt 2(cancel step削除): 編集前後のstepを突き合わせるだけ。外部情報は不要。

### 実行環境が無いことは原因ではない(当初の記述の訂正)

筆者は当初、「Android実機もdesktop appも起動できないため、唯一の事実源がrepositoryである」ことを**より根深い原因**として書いた。これは不正確なので訂正する。

上記のとおり、**3件ともrepositoryで足りた**。実機を起動していたとしても、`android:label`は設定アプリを開いて確かめるより`git grep`の方が速く確実である。skillのdry-runは、実行環境を持たないAgentのために「repositoryを事実源にせよ」と定めた条文であり、環境の欠如を前提に**すでに設計されている**。したがって環境の欠如は言い訳にならず、原因でもない。

環境の欠如が実際に効くのは別の点である。**偶発的なfeedbackが無くなること。** appを起動できる書き手なら、手順を書きながら画面を見るので、実在しないアプリ名や実行できない操作にその場で気づく。筆者にはそれが無いため、**dry-runが唯一の安全網**になる。つまり環境の欠如は、誤りを不可避にするのではなく、**dry-runを省いたときの回復手段を奪う**。省略のコストが他の書き手より高い、というだけである。

今回はその安全網を外したまま人間へ渡そうとし、独立reviewをdry-runの代わりに3回消費した。

## 期待していた動きと実際の動き

- 期待: dry-runを通してから人間へ渡すので、実在しないUI名や実行不能な操作は残らない。
- 実際: dry-runを飛ばし、reviewを実質のdry-run代わりに使った。結果、3往復を消費した。

## 影響とworkaround

- 影響: `004:T10`が3回FAIL規律に触れ、`blocked`になった。人間の判断が要る状態を、Agent側の手順不履行で作った。
- 影響: reviewを3回起動した(1回あたり約7分、subagent tokenも消費)。dry-runは`git grep`数回で済む。
- 影響: 「復元」という作業の信頼性が下がった。復元した内容が正しくても、周辺の記述で人間が詰まれば実施できない。
- workaround: 無い。dry-runを実行するしかない。

## 仮説と提案

- **dry-runをcommandへ落とす。** 現在の条文は「存在する」という状態の記述で、実行手順ではない。次のような具体化があれば飛ばしにくい。
  - manualに登場する画面文言・ボタン名を列挙し、それぞれ`git grep -n`でrepositoryに存在することを示す。
  - Androidの設定画面に出る名前は`AndroidManifest.xml`の`android:label`、アプリ内タイトルは`MaterialApp.title`/`AppBar`と、**出所を対応付ける**。同じアプリでも文脈で名前が違う。
  - manualが依存するplatform挙動(pickerの選択保持、権限モデル等)について、`specs/`と`development-findings/`に既存の観測記録が無いかを検索する。
- **書き直し時の突き合わせ。** section単位で書き直す編集は、追記と違って項目を落とす。編集前後のstepを機械的に対応付ける手順を、dry-runへ加える。attempt 2はこれで防げた。
- **是正commitもdry-runの対象**である。3回のうち2回が是正由来だった。「指摘を直す」作業は小さく見えるため、dry-runが省かれやすい。
- 一般化: 実行環境を持たないAgentが人間向けmanualを書くとき、repositoryが事実源であると同時に**唯一の安全網**でもある。自然な文章を書くことより、各記述の出所を確認することを優先する。

## 改善結果

2026-08-12、人間が「(a) Agentが直して続行」を選んだ(3回FAIL規律の解除)。P1-1を`android:label`の値へ直し、**今回は先にdry-runを実行した**。004 manualの画面文言9件(「ファイルを選ぶ」「画像」「動画」「文書」「すべて」「元の名前順」「作成日時順」「作成日時: 不明」「batch_rename_master」)と007 manualの5件を`git grep`でrepository内の出所と突き合わせ、全件一致を確認してからcommitした。

以後、manualを書く・直すときは、是正commitであってもこのgrep突き合わせを先に行う。ASDD plugin側へのdry-run条文の具体化は未対応。
