# Development finding: 人間が実行する手順を、Agent向け文書の中へ書いてしまった

- 観測日: 2026-08-13
- 観測した作業: `013:T01`(Androidのstorage・permission境界の調査)。実機spikeの手順を`research-matrix.md`へ書き、人間から「manualと同様の手順書にしてほしい」と指摘された
- 改善先: ASDD plugin(`create-plan` / `run-plan`と`manual-verification.md` reference)、および筆者の実行
- 関連artifact: `specs/013-safe-android-rename/tasks/T01-decide-storage-boundary/research-matrix.md`、同`manual-verification.md`、同`task.json`

## 観測した事実

`013:T01`の受け入れ証拠には「候補API/version/providerを固定した**再現可能なspike結果**」がある。spikeはAndroid SDKと実機を要するので、**実行するのは人間**である。

にもかかわらず筆者は次のようにした。

- `task.json`の`manualVerification`は`null`のまま。
- 手順を`research-matrix.md`(Agent向けの調査文書)の一節として書いた。
- 内容は「NDKから`renameat2(AT_FDCWD, ..., RENAME_NOREPLACE)`を呼ぶ」という**API記述**で、実行できるコマンドではなかった。
- 依頼をPR本文と会話で行い、**GitHubのweb URL**でその節を指した。

人間からの指摘。

> research-matrix.md の確認手順の説明が人間向けになっていません。マニュアルと同様に人間が確認しやすい手順書にしてください
> これまでマニュアルは比較的分かりやすく記述していた(powershellコマンドを示すなど)のになぜresearch-matrix.mdでは書き方が変わったのですか
> これまでプロジェクト内のリンクだったのにwebのリンクにしたのはなぜですか

## 期待していた動きと実際の動き

- 期待: 人間が実行する検証は、`manual-verification.md`という決まった器に、実行できるコマンドで書かれる。005や004ではそうしていた。
- 実際: 器を作らず、Agent向け文書へAPI記述として書いた。同じsessionの中で**同じ筆者が書き方を変えた**。

## 根本原因

### 1. 文書の読み手が途中ですり替わったことに気づかなかった(筆者の問題)

`research-matrix.md`は「候補を比較してAgentが判断するための文書」として書き始めた。spikeの節は**その判断に必要な入力**なので、同じ文書へ続けて書いた。**書いている間、読み手が人間へ変わったことを意識していない。**

これまでmanualが具体的だったのは筆者が丁寧だったからではなく、**`manual-verification.md`という器が読み手を固定していた**からである。器が無い場所では、同じ筆者が同じ日にAPI記述を書いた。**規律は個人の注意力ではなく器に宿っていた。**

### 2. 「調査task」に人間の実行が要ることを、ASDDの構造が拾わない

`013:T01`は実装taskではなく調査taskである。ASDDの`manualVerification`は「実装した振る舞いを実機で確認する」文脈で説明されており、**「Agentが実行できない調査を人間に代行してもらう」場合も同じ器を使う**とはどこにも書かれていない。

結果として次の矛盾が残り、**誰も検出しなかった**。

- `task.md`の受け入れ証拠: 「再現可能なspike結果」= 人間の実行が必要
- `task.json`: `"manualVerification": null`
- `workspace.py check`: PASS

**受け入れ証拠が人間の実行を要求しているのに`manualVerification`が`null`という組み合わせは、構造的な矛盾として検出できるはずである。**

### 3. link形式の規約を、読んだ当日に破った(筆者の問題。ASDDの穴ではない)

`AGENTS.md`(#130で更新)は次を定めている。

> task固有manualを依頼するときは、対象`NNN / TNN`とtask名、クリック可能なrepository-relative linkを示す。

筆者はPR本文を書く流れでGitHubのweb URLを組み立て、そのまま会話の報告にも使った。**PR本文でもrepository-relative linkは機能する**ので、web URLにする理由は無かった。規約を同じ日に読んでいる。

## 影響とworkaround

- 影響: 人間が実機確認に着手できなかった。**依頼として成立していなかった。**
- 影響: 「NDKから呼ぶ」だけでは、確認用appを作る作業を人間へ押し付けることになっていた。実際にはappは不要で、`adb shell`と小さなCプログラムで足りる。**Agentが手順を詰めていれば人間の負担は15分程度で済む**のに、それを詰めずに投げた。
- workaround: `manual-verification.md`を新設し、観測用のCプログラム(`spike/renameat2_spike.c`)をrepositoryへ置いた。人間はコンパイル・push・実行の3手で済む。`task.json`の`manualVerification`も設定した。

## 仮説と提案

- **ASDD側**: `manual-verification.md`は「実装の実機確認」だけでなく、**「Agentが実行できない検証を人間へ委譲する場合」全般の器**であると明記する。調査task・spike・外部サービスの確認も含む。
- **ASDD側**: `workspace.py check`へ検査を足す。`task.md`の受け入れ証拠が人間の実行を要求する語(実機、spike、手動、端末など)を含むのに`manualVerification`が`null`なら警告する。機械的には難しければ、`create-plan`のchecklistに「この受け入れ証拠をAgentだけで満たせるか。満たせないなら`manualVerification`を設定する」を入れる。
- **ASDD側**: `manual-verification.md` referenceに、**手順の具体度の基準**を書く。「API名ではなく実行できるコマンド」「所要時間の目安」「前提の確認方法」「期待する出力」。今回はこれが暗黙知だった。
- **筆者**: 文書を書く前に読み手を決め、**途中で変わったら文書を分ける。** 「同じ話題だから同じ文書」ではない。
- **筆者**: 人間へ依頼する前に、**その手順を自分で可能な限り実行して詰める。** 今回はCプログラムをcontainer内でコンパイル・実行し、期待出力を確認してから渡した(dry-run)。最初からそうすべきだった。
- **筆者**: 依頼のlinkはrepository-relativeで書く。PR本文でも会話でも同じ。

## 改善結果

`013:T01`に`manual-verification.md`と`spike/renameat2_spike.c`を作り、`task.json`の`manualVerification`を設定した。Cプログラムはcontainer内(x86_64/ext4)でコンパイル・実行し、`A) RENAME_NOREPLACE は有効`を出すこと、fixtureを自分で片付けることを確認済み。

ASDD plugin側の3点は未対応。
