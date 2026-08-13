# Development finding: 要約ツールの言い換えを「一次資料の原文」として引用した

- 観測日: 2026-08-13
- 観測した作業: `013:T01`。Google Playの`MANAGE_EXTERNAL_STORAGE`許可条件を、閉じたallowlistとして`[一次]`タグ付きで引用した
- 改善先: Agentの実行(一次資料の扱い)。ASDD側は`[一次]`という格付けの仕組みまでは持っており、運用が破れた
- 関連artifact: `specs/013-safe-android-rename/tasks/T01-decide-storage-boundary/research-matrix.md`、`specs/013-safe-android-rename/decisions/ADR-002-android-rename-storage-boundary.md`

## 観測した事実

`013:T01`は主張を`[一次]`(公式資料の原文で確認)/`[要spike]`/`[未到達]`で格付けする仕組みを自分で導入した。その上で次を書いた。

> 宣言が許されるのは次のみ:
> File managers / Backup and restore apps / …

`[一次]`タグ付きである。しかし**原文は次のとおり**だった。

> Your app's usage of the permission **must fall within permitted uses** and must be directly tied to the core functionality of the app. If your app includes a use case **similar to any of the following, it's likely that** it can request the `MANAGE_EXTERNAL_STORAGE` permission:

閉じたallowlistではない。「載っているものに**似ている**なら、**おそらく**要求できる」という開いた例示である。規範的な条件は別の文(「permitted usesの範囲に入り、中核機能へ直接結びついていること」)の方にある。そして**その"permitted uses"の定義はこのpageに無く、`support.google.com`にある。containerから到達できない。**

つまり「一括改名appが該当するか」は、**資料で確定できていなかった**。それを「一覧に無いので配布判断」という形に単純化していた。

独立reviewが指摘して発覚した。

## なぜ起きたか

**WebFetchが返した要約をそのまま原文として扱った。**

WebFetchは取得したpageを小さいmodelで要約して返す。その出力は次だった。

> **Only the following apps are permitted to declare this permission:**

これはWebFetch側の言い換えである。原文には`only`も`permitted to declare`も無い。筆者はこの文字列を、**自分がpageを読んで確認したもの**として`[一次]`欄へ写した。

`[一次]`の定義は「公式資料の**原文**で確認した」と自分で書いていた。**要約は原文ではない。** 定義を書いた本人が、その定義に反する運用をした。

同じsessionで`DocumentsProvider.renameDocument`は`curl`でHTMLを取得しtagを剥がして読んでおり、**そちらは逐語一致していた**(reviewが確認)。つまり手段は持っていて、page 1つぶんで手を抜いた。

## 影響とworkaround

- 影響: **ADR-002がこの誤読の上に立っていた。** 「一覧に載っていないので配布判断」という枠組みで人間へ決定を求めた。実際は「似ていると主張できるか」「permitted usesの原文をまだ読めていない」という別の枠組みだった。
- 影響: ADR-002は「宣言理由に本ADRの分析をそのまま使う」と書いていた。**誤読がPlayへの提出物へ流れる経路ができていた。**
- 影響の限定: 採用の結論自体は変わらない。SAF・MediaStoreが使えない論拠は逐語確認済みの引用に立っており、そちらは無傷だった。
- workaround: 原文を`curl`で再取得して修正し、`[未到達]`(permitted usesの定義)を明示した。ADR-002へ「提出前に人間がPlayのpolicy原文と突き合わせること」を加えた。

## 仮説と提案

- **`[一次]`と書く引用は、要約を経由しない経路で取る。** `curl`でHTMLを取得してtagを剥がすか、少なくとも要約の該当箇所を原文へ突き合わせる。**WebFetchの出力は`[二次]`である。**
- **要約modelは、条件文のhedgeを落としやすい。** 「similar to」「it's likely that」「must fall within」のような、**強さを決めている語**が消える。この種の語が結論を左右する文書(policy、契約、仕様)では特に危険である。
- **格付けの仕組みは、格付けする瞬間の規律が無いと機能しない。** `[一次]`欄を作ったこと自体は良かった(reviewがそこを検査できた)。しかしtagは自己申告なので、**根拠のURLと取得方法まで併記する**と検査しやすい。次からそうする。
- 一般化: **「自分で確認した」と書けるのは、自分が確認した経路のときだけ。** 道具の出力を自分の観測として扱わない。これはspike結果を`adb shell`で取ってappの観測として扱わなかったこと(同じtaskで正しくできていた)と同じ規律である。**片方でできて片方でできなかった。**

## 再発(同日、review attempt 2で検出)

**同じ根本原因で2回目を踏んだ。** 今度は資料ではなく**人間の生報告**である。

`adb shell mount`の出力を`$ ...`付きで生出力として貼りながら、実際には (1) `/dev/block/dm-6 on /mnt/pass_through/0/emulated type ext4` の行を注記なく落とし、(2) 2行の順序を入れ替え、(3) option列を別の行へ付け替えていた。

**落とした行が判断に効いていた。** その行は下位filesystemがext4であることを示しており、「FUSEがフラグを透過した」のか「FUSEが下位のext4へ委譲した」のかを切り分ける材料だった。**自分の主張に都合の悪い情報を落としたのではなく、短くしようとして落とした**が、結果は同じである。

`AGENTS.md`は「同じ根本原因が修正後も2回続いたら類似修正を止めて仮定を洗い直す」と定める。洗い直した結果:

- **仮定していたこと**: 「原文をそのまま扱う」規律は、外部資料の引用に適用すればよい。
- **実際**: 適用範囲が狭すぎた。**人間の報告、tool出力、command結果も「原文」である。** 整形・省略・並べ替えをするなら、そうしたと明記する。
- **規律**: 生出力を貼るときは加工しない。長すぎるなら**明示的に抜粋と書く**。`$`付きのblockは「これがそのまま出た」という主張である。

## 改善結果

`research-matrix.md`と`ADR-002`を原文に基づいて修正した。`[未到達]`の範囲(`support.google.com`のpolicy原文)を明示し、ADR-002へ提出前確認を条件として加えた。以後、`[一次]`は要約を経由しない経路で取る。**そして生出力は加工しない。加工したら明記する。**

再発を受けて、`mount`出力を人間の報告どおりに貼り直し(省略した4行は明記)、下位filesystemがext4だったことを「残った未検証」へ加えた。
