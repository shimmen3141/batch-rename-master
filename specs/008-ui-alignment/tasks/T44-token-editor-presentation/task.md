# T44 トークンの設定(連番など)を参考デザインの中央のダイアログへ整える

## 目的

トークンの追加・編集のエディタ(`lib/ui/rule_builder/token_editors.dart`)、特に**連番の設定シート**の見た目と操作を、開発者が挙げる改善点に沿って整える。判定・入力範囲(003 REQ-012〜014)は変えない。

## 受領した要望(2026-09-29、原文)

> なお、連番の設定シートのUIなど、かなり改善点がありますが、これは別タスクとして設定されていますよね？

観測の出所は`014:T04`のエミュレータ確認(ゼロ埋めのスイッチと桁数の下限を足した直後)。**具体的な改善点はまだ受け取っていない。**

## 既存taskとの境界

- `008:T14`(modalの文言と見せ方): tokenのエディタについては**形**(bottom sheetか中央のdialogか)だけを尋ねる。中身は`T05`/`T06`へ送ると書いているが、両方ともdone。**中身(並び・入力部品・文言・余白)はこのtaskが持つ。** 形を変える判断は`T14`のまま — 先に着手した側が入れ物を決め、後の側が合わせる。
- `008:T10`(余白・階層・typography): 画面全体の揃え。このtaskのエディタ内の調整と食い違わないよう、先に着手した側の値に合わせる。
- 003 spec: エディタの形・レイアウト・確定ボタンの文言は「自由とする点」。REQ-008〜014(確定手順、確定できない入力、ゼロ埋めの切り替え、桁数の下限と引き上げ)は変えない。
- 見た目の土台は`docs/design/Bulk Renamer.html`(正本ではない)。`014:T04`で土台から離れた点(ゼロ埋めのスイッチ、下限の理由の文)は[`014:T04`のtask.md](../../../014-sequence-zero-padding/tasks/T04-editor-padding-and-min-digits/task.md)にある。

## 着手時に開発者へ確かめること

1. 改善点の具体(どのエディタの、どこを、どうしたいか)。スクリーンショットがあれば受け取る。
2. 連番以外のエディタ(テキスト / 区切り / 日時)も対象か。

## 受け入れ証拠(着手時に改善点に合わせて具体化する)

- widget test(003 REQ-008〜014を失っていないこと)、full test・analyze・format。
- Androidエミュレータでの手動確認(`manual-verification.md`を着手後に作る)。

## 土台(`docs/design/Bulk Renamer.html`)の適用範囲と離れた点

適用範囲: トークンの設定のダイアログ(`dialog.kind == 'token'`)。

取り込んだもの: 中央のダイアログ(暗い背景・角丸18・枠線のカード、最大幅420)、見出しと説明、枠のついた四角い −/＋ とシアンの値、選択肢のチップ(選ばれるとシアンの枠と文字)、区切り線の下の緑の表示例、区切り線の下に横に並ぶキャンセル / 確定(確定が広い)、文字列の入力欄(暗い面にシアンの枠、`"作成資料" や "旅行_" など`)、各種別の説明文。

離れた点と理由:

- **確定ボタンの文言**: 土台は「完了」。追加は「追加」、編集は「確定」のまま(003 の自由とする点は文言を自由にしているが、「追加と編集が区別できること」を求める。`008:T06`で決めた文言とtestを保つ)。
- **連番の説明**: 土台は「チェック済みファイルの上から順に振られます。」。`008:T03`で行のチェックが無くなったので「一覧の上から順に振られます。」。
- **連番の欄**: 土台は開始番号と「桁数（ゼロ埋め）」だけ。`014:T04`のゼロ埋めのスイッチ・桁数の下限・増分(003 REQ-013/014)を保つ。表示例は土台と同じ「最初 ～ 最後」だが、増分とゼロ埋めの有無を反映する。
- **区切りの記号**: 土台は `_` `-` 空白 `.` `・`。003 の決定済み事項(開発者指示)の4種(ハイフン / アンダーバー / 半角空白 / 全角空白)のまま。見せ方だけ土台に合わせて「名前 記号」にした。
- **文字列のエディタ**: 土台は自由テキストが入力欄だけ、区切りが記号だけ。003 REQ-011 により**既存の文字列の編集は両方を持つ**ので、どの入口でも入力欄と記号の両方を出し、見出しと説明だけ入口で変える(自由テキスト / 区切り文字 / 編集は「自由テキスト / 区切り文字」)。
- **日時のフォーマット**: 土台はプリセットのチップだけ。003 の決定済み事項(プリセット＋自由入力)により、チップの下に自由入力の欄を置く。
- **日時の表示例**: 土台と同じく一覧の1件目で描く。作成日時が不明なら「（日時が不明）」(001 INV-006。別の日時で代えない)。現在日時は「表示例（現在日時）」。
- **元のファイル名のダイアログ**(大文字・小文字): 土台にはあるが、003 は元名に設定項目を持たない(REQ-010。大小変換は将来)ので出さない。

## 作業記録

着手は Claude Opus 5.5(2026-09-29)。branch `asdd/008-ui-alignment/T44-token-editor-presentation`、起点`dev`@`9806d96`。code `cefa597`。

- `lib/ui/rule_builder/token_editors.dart`: `showTokenEditor`を`showModalBottomSheet`から`showDialog`へ(外のタップで閉じる)。`_EditorScaffold`を土台のカードに作り直し、見出し・説明・表示例を足した。`LiteralEntry`(入口)と`sampleFile`(一覧の1件目)を受け取る。判定のロジック(`sequenceMinDigits`、引き上げ、確定するまで`tokens`を変えない)は変えていない。
- `lib/ui/rule_builder/rule_builder_view.dart`: `RuleBuilderView.sampleFile`(getter)。追加は入口(`＋ 区切り`なら`LiteralEntry.separator`)を渡す。
- `lib/ui/rule_builder/rule_builder_workspace.dart`: 狭幅のシートと広幅の2ペインの両方へ`sampleFile: _firstFile`(`fileList.rows.first.source`、表示順の1件目)。
- **testの変更**: `token_add_confirm_test.dart`の REQ-009 の閉じ方から**`drag`(下方向のスワイプ)を外した**。ダイアログにはスワイプで閉じる操作そのものが無いため(003 spec はエディタの形を自由とし、REQ-009 は「確定以外のすべての閉じ方」)。キャンセル・戻る・外のタップは残る。ほかは見出し(「自由テキスト / 区切り文字」)・記号の文言(「アンダーバー _」)・ステッパーのicon(`Icons.remove`/`add`)の追随だけで、assertionは緩めていない。
- 新しいtest: `test/spec_003_rule_builder/token_editor_dialog_test.dart`(15件。ダイアログであること、入口ごとの見出し、編集は入力欄と記号の両方、連番・日時の表示例と追随、不明な日時、一覧が空、狭幅・広幅から1件目が届くこと)。
- 検証: `flutter test` 1055件PASS、`flutter analyze`・`dart format` PASS。

### mutation

- **`M242`・`M256`は`014:T04`で`find`が古くなっていた**(`showTokenEditor`の呼び出しに引数を足したとき追随が漏れ、一致しない = 何も守っていなかった)。追随させた。`M247`はボトムシートの`isDismissible`からダイアログの`barrierDismissible`へ追随させた。`M248`(下方向のスワイプで閉じられなくする対照)は、ダイアログに操作が無いので外した。
- `M512`〜`M518`を足した(表示例・1件目の経路・入口の見出し)。
- 表の書式を揃えるだけのcommit(`json.load`の結果が同一であることを確かめた)を分けてある。
- 触った3ファイルを`file`に持つ35件の`find`が、すべてちょうど1回一致することを確かめた。**表全体では他のtaskの16件が一致しない**([finding](../../../../development-findings/2026-09-29-stale-mutation-finds-go-unnoticed.md))。このtaskの範囲の外で、扱いは開発者へ尋ねる。

`command`を`flutter test test/spec_003_rule_builder`へ絞った10件の生出力(NOTEは省いた):

```text
M242 | KILLED | lib/ui/rule_builder/rule_builder_view.dart | exit 1
M247 | KILLED | lib/ui/rule_builder/token_editors.dart | exit 1
M256 | KILLED | lib/ui/rule_builder/rule_builder_view.dart | exit 1
M512 | KILLED | lib/ui/rule_builder/token_editors.dart | exit 1
M513 | KILLED | lib/ui/rule_builder/token_editors.dart | exit 1
M514 | KILLED | lib/ui/rule_builder/token_editors.dart | exit 1
M515 | KILLED | lib/ui/rule_builder/rule_builder_workspace.dart | exit 1
M516 | KILLED | lib/ui/rule_builder/rule_builder_workspace.dart | exit 1
M517 | KILLED | lib/ui/rule_builder/rule_builder_workspace.dart | exit 1
M518 | KILLED | lib/ui/rule_builder/rule_builder_view.dart | exit 1
10 mutations: 10 KILLED, 0 SURVIVED, 0 SKIPPED
```

## machine検証範囲と引き受け先

- **CIで閉じる**: widget test(形・見出し・表示例・経路、確定手順REQ-008〜014)とmutation。
- **このtaskのmanual(Androidエミュレータ)**: 見た目(参考デザインとの見比べ)と操作。引き受け先のtaskは無い。

## manual 1回目(2026-09-29、code `cefa597`)

受領: 会話。開発者(原文): 「確認事項は概ね問題なかったが、キーボードが下からせりあがってくるようになっていなかったので、設定で確認します。また、UIの改善点もいくつかあるので、後で指摘します。」

- 手順書の1.・2.・3.(キーボード以外)・4.・5.は問題なし(「概ね問題なかった」)。
- **3.3(キーボードを出してスクロール)は未確認**。画面のキーボードが出なかった。エミュレータでhostのキーボードが物理キーボードとして扱われ、画面キーボードが出ない設定だった可能性が高い(アプリの不具合かは未確定)。開発者が設定を変えて確かめる。Agentは設定の変え方を伝えた(端末の「物理キーボード → 画面キーボードの使用」、またはAVDの `hw.keyboard`)。
- **UIの改善点**: 開発者があとで挙げる。受け取ったら、このtaskで扱うもの(トークンの設定のダイアログ)と`T45`(ルール構築シート)へ振り分ける。

### 3.3の結果とUIの改善点(2026-09-29、受領: 会話。原文)

> 画面キーボードの挙動も含め、問題ありませんでした。
> UIの改善点について：
>     - 連番のゼロ埋めのトグルは開始番号の上に持ってきてください。
>     - 連番の説明を「リネームリスト一覧の上から順に番号を振ります。」にしてください。
>     - 日時のフォーマットについて、入力欄による自由記述は、「詳細に記述」というチップを用意し、それを選択したときだけ入力欄が表示されるようにしてください。縫う力欄には、直前に選択されていたフォーマットが初期値として入るようにしてください。
>     - 連番のゼロ埋めのトグルや日時の入力欄の有無で高さが急に変わるのを修正したい。高さが変わること自体は良いが、アニメーションで滑らかに変えてください。

- manual 1回目(code `cefa597`)は**手順書1.〜5.すべて問題なし**(3.3のキーボードとスクロールを含む)。
- 改善点4つはすべて**トークンの設定のダイアログ**なので、このtaskで直す(`T45`へ送るものは無い)。「縫う力欄」は「入力欄」と読む。codeを変えるので、manualは直したbuildでやり直す。

### 改善点の実装(2026-09-29、code `967a912`)

- 連番: ゼロ埋めのスイッチを開始番号の上へ。説明を「リネームリスト一覧の上から順に番号を振ります。」。
- 日時: 説明を「基準となる日時とフォーマットを選んでください。」(実装中に開発者が追加で指定。原文「日時の文言は、「基準となる日時とフォーマットを選んでください。」にしてください。」)。フォーマットのチップの最後に「**詳細に記述**」を足し、選んだときだけ入力欄を出す。入力欄は直前のフォーマットのまま(初期値)。プリセットを選び直すと入力欄は消える。プリセットに無いフォーマットの日時は「詳細に記述」を選んだ状態で開く。「詳細に記述」を選んでいる間はプリセットのチップを選ばれた扱いにしない。
- 高さ: ダイアログの本文を`AnimatedSize`(220ms、easeInOut、上端揃え)で包み、ゼロ埋めの切り替えと入力欄の出し入れで滑らかに変える。
- **土台から離れた点の更新**: 日時のフォーマットは土台と同じくチップが主で、自由入力は「詳細に記述」の中へ移った(003 の決定済み事項「プリセット＋自由入力」は満たす)。連番の説明・日時の説明は開発者の指定で、土台の文言ではない。
- testの追随: 日時の入力欄を使う既存test(`token_add_confirm_test.dart`の3件)は「詳細に記述」を押してから入力する形に、ゼロ埋めを切り替えた後の2件(`sequence_zero_pad_editor_test.dart`)はアニメーションの終わりを待つ形にした(途中のフレームでは確定ボタンが切り取られていて押せない。確かめる内容は変えていない)。新しいtest: スイッチが開始番号の上、日時の説明、「詳細に記述」の出し入れと初期値と確定、プリセットに無いフォーマットで開く、高さが途中の値を通って変わる(連番・日時)。
- 検証: `flutter test` 1062件PASS、`flutter analyze`・`dart format` PASS。
- mutation `M519`〜`M523`を足した。`command`を`flutter test test/spec_003_rule_builder`へ絞り、変更した箇所を守る既存の`M252`・`M503`・`M505`も回した8件の生出力(NOTEは省いた):

```text
M252 | KILLED | lib/ui/rule_builder/token_editors.dart | exit 1
M503 | KILLED | lib/ui/rule_builder/token_editors.dart | exit 1
M505 | KILLED | lib/ui/rule_builder/token_editors.dart | exit 1
M519 | KILLED | lib/ui/rule_builder/token_editors.dart | exit 1
M520 | KILLED | lib/ui/rule_builder/token_editors.dart | exit 1
M521 | KILLED | lib/ui/rule_builder/token_editors.dart | exit 1
M522 | KILLED | lib/ui/rule_builder/token_editors.dart | exit 1
M523 | KILLED | lib/ui/rule_builder/token_editors.dart | exit 1
8 mutations: 8 KILLED, 0 SURVIVED, 0 SKIPPED
```

- 手順書の1.〜3.を改善後の画面に合わせて書き直した(ゼロ埋めの位置、説明文、高さの滑らかさ、「詳細に記述」の出し入れと初期値、プリセットに無いフォーマットで開く)。

## manual 2回目の結果(2026-09-29、code `967a912`)

受領: 会話。開発者(原文): 「確認事項は全て確認できました。将来的にさらに改善する余地はありますが、ひとまず進めてください。」

- 手順書の1.〜5.(改善後の画面。ゼロ埋めの位置、説明文、高さの滑らかさ、「詳細に記述」、キーボードとスクロール)を**すべて確認。PASS**。対象はHEAD(`lib/`は`967a912`と同一。以後の差分は記録だけ)からのbuild。
- 「将来的にさらに改善する余地」は具体を受け取っていない。受け取ったらtaskとして登録する(このtaskの受け入れには含めない)。

## 独立review

既定のreviewerは`gpt-6-luna`(開発者指定)。UIの提示で、判定・contract・データ保護には触れない。

## 範囲の決定(2026-09-29)

開発者(原文): 「まず、参考デザインdocs/design/Bulk Renamer.htmlのデザインを適用したいです。ボトムシートも含めて修正したいですが、タスクを分けるべきでしょうか。」

参考デザインで整える画面は2つある。

| 画面 | 参考デザイン | 今の実装 |
|---|---|---|
| ① ルール構築シート(トークンを並べ、追加ボタンがある) | ボトムシート(プリセットの画面へ切り替える作りもある) | ボトムシート(`RuleBuilderWorkspace._openRuleSheet` → `RuleBuilderView`) |
| ② トークンの設定(連番の開始番号など) | ①の上に開く**中央のダイアログ**(変更後の名前の例も出す) | ①の上に重なるボトムシート(`showTokenEditor`) |

**決定: 2つに分ける**(開発者。Agentの推奨)。ほかの案: T44にまとめる。

- **このtask(T44)は②**: トークンの設定を参考デザインの中央のダイアログへ(形と中身)。すべての種別(テキスト / 区切り / 連番 / 日時)が対象。
- **①は`T45`**(新規)。T44 → T45 の順に進める(ダイアログは①の上に重なるので、後から①を整えてもダイアログは崩れない)。
- `T14`は実行前の確認ダイアログ(表の1)の文言と見せ方だけを持つ。`T14`が着手時に尋ねる予定だった「tokenのエディタをdialogへ揃えるか」は、**参考デザインを適用する(中央のダイアログにする)**でこの決定に含まれた。

参考デザインから**取り込まないもの**:

- プリセット(名前付きルール)。将来候補`009`。
- 追加ボタンを押した時点でトークンを列へ入れ、キャンセルで戻す動き。003 REQ-008(確定するまで`tokens`を変えない)と両立しない(003 spec の反証ログ「弱すぎ(008:T05)」)。確定したときだけ入れる今の手順を保つ。
- 連番の桁数の欄だけ(「桁数（ゼロ埋め）」)の形。`014:T04`で足したゼロ埋めのスイッチと下限(003 REQ-013/014)を保つ。

- attempt 1: `9806d96..403519c`(全範囲、implementation) — **PASS**(P2 1件)。reviewerのmodelは`gpt-6-luna`。確認された点: 003 REQ-008〜014の維持(確定前に`tokens`を変えない、キャンセル・戻る・外のタップ、空は確定不可、ゼロ埋めと下限)、`drag`を外した判断は妥当で他のtestの変更は追随だけ、「離れた点」の記述が土台と実装に一致、表示例と1件目の経路、`M242`・`M256`・`M247`の追随と`M248`を外した理由、`M512`〜`M518`、書式だけのcommitが`json.load`で同一、findingの16件の真偽。full test 1055件・format・analyze・`check specs` PASS。範囲付きmutation 10件KILLED。
  - **P2(成果物の欠陥)**: 手順書に、キーボードを出した状態でダイアログをスクロールして入力・確定できるかを見る手順が無い。→ 手順書の3.(日時)に足した。**SELF-CHECK**: 記録だけの差分でP2を閉じるだけなので、再reviewは起動しない(AGENTS.md)。

- attempt 2: `403519c..14a3065`(差分、implementation) — **PASS**(指摘なし)。reviewerのmodelは`gpt-6-luna`。改善点(1)〜(5)と手順書の一致、「詳細に記述」の振る舞いと003 REQ-012・決定済み事項、`AnimatedSize`とスクロール・確定の関係、testの追随がassertionの緩和でないこと、高さのtestが即時切替を検出すること、`M519`〜`M523`、触ったfileの既存mutationの`find`がちょうど1回一致することを確認された。full test 1062件・format・analyze・`check specs`・`git diff --check` PASS。範囲付きmutation 8件KILLED。
  - 連鎖: `9806d96..403519c` PASS(P2はSELF-CHECKで手順書へ)→ `403519c..14a3065` PASS。

- attempt 3: `14a3065..87b6482`(差分、final-evidence) — **PASS**(指摘なし)。reviewerのmodelは`gpt-6-luna`。`967a912..87b6482`に`lib/`・`hook/`・`src/`・依存・build設定の差分が無くmanual 2回目のidentityを保つこと、手順書の被覆、reviewの連鎖が`9806d96..HEAD`を切れ目なく覆うことを確認された。`check specs`・`git diff --check` PASS。
  - 連鎖: `9806d96..403519c` PASS → `403519c..14a3065` PASS → `14a3065..87b6482` PASS → 以後は記録だけ(SELF-CHECK)。

## Current state / handoff

- Last checkpoint: manual 2回目 PASS(code `967a912`)。
- Blocker category: none
- Evidence revision: code `967a912`
- Next Agent action: PR #199をreadyにし、CIとmerge条件を確かめてmergeする
