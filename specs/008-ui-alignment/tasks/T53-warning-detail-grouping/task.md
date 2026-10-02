# T53 警告の詳細modalを、重複を変更後名ごとにまとめた見せ方へ改める

## 目的

警告の詳細modal(一覧の「⚠ N 件の問題 詳細」と、行の警告から開く)を、`008:T14` の実行前確認dialogと
同じ見せ方へ揃え、**どのファイル同士がぶつかっているか**が一目で読めるようにする。

## 受領した要望(2026-10-02、原文)

> 警告の詳細モーダルの見せ方も修正したいと考えています。現状でも悪くはないのですが、今回のダイアログの
> 修正のように、より分かりやすい表示の仕方があると思います。(重複するファイルを一つの枠に列挙するなど)

開発者へ現状と案を示し、行から開いたときの扱いを尋ねた。提示した選択肢は **相手も出す(推奨) / その行だけ**。
開発者は **「相手も出す (推奨)」** を選んだ。

## 現状(`dev`@`5c7b7a7`)

`lib/ui/file_list/rename_warning_view.dart` の `showWarningDetail`。標準の `AlertDialog` に、原因ごとの節
(`warningDetailSections`: 赤の見出し「重複 N 件」・説明1つ・`• 「a.jpg」 → 「same.jpg」` の箇条書き)を並べる。

- 重複は1つの節に全件が並び、**どれとどれが同じ名前になるのか**を読み手が名前を見比べて探すことになる。
  「same.jpg」になる組と「memo.txt」になる組が1つの箇条書きに混ざる。
- 行から開くと、その行の警告だけ(005 REQ-009 (4))。**重複の相手が読めない。**
- 見た目が `T14` の確認dialog(design 土台の枠)と揃っていない。

## 決めたこと / 変更範囲

1. **005 REQ-009 (4) を改訂する(revision 10.0)。** 行から開いた詳細で、**重複の相手(同じ folder で同じ変更後名に
   なる、読み込んだ他のファイル)**が読める。相手の他の警告は出さない。**読み込んでいない占有名との衝突は相手の名前を
   課さない**(001 の警告が相手が占有名かを持たないため)。改訂案は
   [`behavior-contract.json`](../../../005-rename-exec/contracts/behavior-contract.json) の `revision_history` 10.0 と、
   [`spec.md`](../../../005-rename-exec/spec.md) の代表例 20e″。**開発者が2026-10-02に承認した。**
2. **見せ方**(005 spec「自由とする点」):
   - `T14` の `_DesignDialog` と同じ枠(角丸18のcard、見出しと説明、区切り線の下の「閉じる」)。
   - 種類ごとに薄い赤の枠(`T14` の `_IssueCard` と同じ形)。見出しは種別名と件数、説明は原因ごとに1つ
     (REQ-009 (2))。トークンの名指しは今の説明文のまま。
   - **重複は変更後名ごとに小さな枠**へまとめ、その名前になるファイルを並べる。同じ folder・同じ変更後名の
     警告が1件だけなら、相手は「フォルダにある既存のファイル」と書く(読み込んでいない占有名との衝突)。
   - 行から開いたときは、その行が該当する警告だけ(重複は相手を含む)。全件の入口からは全件。
3. **判定は動かさない。** 何を警告するか(001)、REQ-021 のまとめ、行の警告の出し方(`T50`)はそのまま。

**design 土台**: 土台に警告の詳細modalは無い。**適用する画面範囲は「実行前の確認」dialogの枠と issues の形**
(`T14` が適用したもの)を、この modal へ流用する。

## 入力と依存

- `008:T14`(done、`dev` へ merge 済み): `lib/ui/file_list/rename_confirmation_view.dart` の枠と部品。共有部品へ切り出す。
- `008:T19`(done): 文言の正本(`warningKindLabel` など)。語彙は変えない。
- 005 contract REQ-009、spec 代表例 20d / 20e / 20e′。

## 受け入れ証拠

- 005 contract revision 10.0 が開発者に承認され、`status` が `approved`、`approved_date` が入る。
- widget test: 全件の入口で重複が変更後名ごとの枠に分かれる / 行から開くと相手が読め、相手の他の警告は出ない /
  占有名との衝突は「フォルダにある既存のファイル」/ 原因の説明は節に1つ(REQ-009 (2))/ 狭幅・文字拡大で読める。
- 既存の REQ-009 test(`warning_display_test.dart` など)が継続 PASS。assertion を緩めない。
- `flutter test` / `flutter analyze` / `dart format --output=none --set-exit-if-changed .` が PASS。
- mutation を `tool/mutations.json` へ足し、範囲付きで KILLED を確かめる。
- [manual-verification.md](manual-verification.md) で実機の見え方を確かめる。
- 独立review(gpt-6-luna)が PASS。**contract を変えるので、review は実装と同等以上の model を使う**(AGENTS.md)。

## 作業記録

- 2026-10-02 / 開発者の要望を受けて起票し、005 revision 10.0 の改訂案を書いた。
- 2026-10-02 / 開発者が 005 revision 10.0 を承認した(「詳細modalの変更案は承認します」)。contract の `status` を `approved`、10.0 の `approved_date` を 2026-10-02 にし、task を `in_progress` にした。
- 2026-10-02 / 同時に尋ねた「元に戻す」付きの失敗通知を閉じるまで残すかは、開発者が **B(現状維持: 5秒で通知ごと消える)** を選んだ。この task の範囲に含めない。
- 2026-10-02 / 実装(`0652b32`)。
  - **共有部品**: `T14` の確認dialogの枠を `lib/ui/common/design_dialog.dart`(`DesignDialog` / `DialogButton` / `IssueCard`)
    へ切り出した。確認dialog・再採番の結果の詳細・警告の詳細が同じ枠を使う。`DesignDialog` の説明は省略可にした。
  - **詳細modal**(`lib/ui/file_list/rename_warning_view.dart`): `showWarningDetail` を `DesignDialog` で作り直した。節は
    `IssueCard`(見出し・説明1つ・対象)。**重複は (folder, 変更後名) ごとの組**(`WarningDetailGroup`)で小さな枠に並べ、
    見出しは `→ 「変更後名」`。同じ変更後名の組が別の folder にもあれば見出しへ場所を添える。組が1件だけなら
    「フォルダにある既存のファイル」(`existingFileLabel`)を添える。既存の key(`warningDetailSectionKey` /
    `warningDetailExplanationKey` / `warningDetailTargetsKey` / `warning-detail-close`)は保った。
  - **行から開くと相手も**: `rowDetailWarnings(rowWarnings, allWarnings)` が、その行の重複と同じ (folder, 変更後名) の
    **重複の警告だけ**を足す(相手の他の警告は足さない)。`file_list_view.dart` の行の入口は、行と全件を同じ
    `controller.preview` から取って渡す(行の `warnings` と全件の警告が同じ instance なので、自分の重複を identity で除ける)。
  - **test**: `warning_display_test.dart` の2件と `warning_detail_scope_test.dart` の2件は、**revision 10.0 で期待が変わった**
    ので書き換えた — 行から開くと相手(bravo / b.txt)が**読める**ことへ、変更後名は組の見出しに1回だけ書くことへ。
    「他の行のファイルが混ざらない」(`nodate.jpg` の行)と「その行の空名の節に相手が出ない」は残した。追加: 代表例 20e″
    (相手の作成日時不明は出ない)、`rowDetailWarnings` の unit test(別 folder・別の名前・他の警告を足さない)、
    占有名との衝突(行・全件の両方で「フォルダにある既存のファイル」)、別 folder の同名は別の組、幅320・文字1.6・30組で
    見出しと「閉じる」が画面に残る。
  - 検証(`0652b32`): `flutter analyze` No issues、`dart format` 0 changed、`flutter test` **1181 PASS**、
    `check_mutation_finds.py` PASS(597件)。
  - mutation: `find` を追随させた M191 / M194 / M195 / M257 / M264 / M641(file を共有部品へ)、追加 M646〜M653。
    範囲付き(`flutter test test/spec_005_rename_exec test/spec_002_file_list`、変更箇所を守る既存の M175 を含む15件):

```text
M175 | KILLED | lib/ui/file_list/rename_warning_view.dart | 008:T16 原因の説明を該当ファイルの件数ぶん繰り返す(005 REQ-00 ... | exit 1
M191 | KILLED | lib/ui/file_list/rename_warning_view.dart | 008:T16 詳細dialogから原因ごとの説明を落とす ... | exit 1
M194 | KILLED | lib/ui/file_list/rename_warning_view.dart | 008:T16 詳細dialogの説明を該当fileの件数ぶん繰り返す ... | exit 1
M195 | KILLED | lib/ui/file_list/rename_warning_view.dart | 008:T16 詳細dialogの対象の列挙を節あたり1件へ間引く ... | exit 1
M257 | KILLED | lib/ui/file_list/file_list_view.dart | 008:T19 行から開く詳細を改修前の全件へ戻す ... | exit 1
M264 | KILLED | lib/ui/file_list/file_list_view.dart | 008:T19 行の詳細へ行の畳み込みを掛ける ... | exit 1
M641 | KILLED | lib/ui/common/design_dialog.dart | 008:T14 本文だけをscrollさせるのをやめる ... | exit 1
M646 | KILLED | lib/ui/file_list/rename_warning_view.dart | 008:T53 行から開いた詳細に重複の相手を足さない ... | exit 1
M647 | KILLED | lib/ui/file_list/rename_warning_view.dart | 008:T53 相手の重複だけでなく、相手の他の警告(日時不明など)も足す ... | exit 1
M648 | KILLED | lib/ui/file_list/rename_warning_view.dart | 008:T53 重複の組を folder で分けない ... | exit 1
M649 | KILLED | lib/ui/file_list/rename_warning_view.dart | 008:T53 重複を変更後名ごとの組に分けない(1つの組に全件) ... | exit 1
M650 | KILLED | lib/ui/file_list/rename_warning_view.dart | 008:T53 読み込んでいない同名とぶつかる組に「フォルダにある既存のファイル」を書かない ... | exit 1
M651 | KILLED | lib/ui/file_list/rename_warning_view.dart | 008:T53 読み込んだ相手がいる組にも「フォルダにある既存のファイル」を書く ... | exit 1
M652 | KILLED | lib/ui/file_list/rename_warning_view.dart | 008:T53 同じ変更後名の組が別の folder にもあるとき、見出しに場所を添えない ... | exit 1
M653 | KILLED | lib/ui/file_list/rename_warning_view.dart | 008:T53 重複の組にファイルを並べない ... | exit 1
15 mutations: 15 KILLED, 0 SURVIVED, 0 SKIPPED
```


- 2026-10-02 / **実機確認1回目(build: `lib/` が `0652b32`)**。開発者「確認事項について、動作に問題はなかったが、見せ方はもっと工夫できると思いました」。指摘は次の3点(原文の要旨):
  1. 各枠の1行目にある赤の矢印と変更後名は、枠の**最後の行**へ(「1行目に矢印があるのは不自然」)。
  2. ファイル名は縦に並べず「、」で区切って横にも並べてよい。入りきらなければ**ファイル名の途中では改行せず、次の行から始める**。
  3. 「フォルダにある既存のファイル」は矢印の行の**次の行**(一番下)、**赤**、文言は「(フォルダにある既存のファイルと重複)」。
  - 同時に「実行buttonを押す前に読み込んでいない同名を調べられるか」を尋ねられた。回答は会話で返し、この task の範囲には含めない。
- 2026-10-02 / 指摘の修正(`a2ab21b`)。組の中を `Wrap`(1ファイル1子、区切り「、」は名前の後ろ)→ 赤の `→ 「変更後名」`
  (`warningDetailGroupResultKey`)→ 赤の `existingFileLabel`(`warningDetailGroupExistingKey`)の順にした。test を追随
  (組の Text の順)し、並び・色・文言の test と、入りきらない名前が次の行の先頭から1行で始まる test を足した。
  - 検証(`a2ab21b`): `flutter analyze` No issues、`dart format` 0 changed、`flutter test` **1183 PASS**、`check_mutation_finds.py` PASS(601件)。
  - mutation: M653 の `find` を追随、追加 M654〜M657。範囲付き(`flutter test test/spec_005_rename_exec`、M650 / M651 を含む7件):

```text
M650 | KILLED | lib/ui/file_list/rename_warning_view.dart | 008:T53 読み込んでいない同名とぶつかる組に「フォルダにある既存のファイル」を書かない ... | exit 1
M651 | KILLED | lib/ui/file_list/rename_warning_view.dart | 008:T53 読み込んだ相手がいる組にも「フォルダにある既存のファイル」を書く ... | exit 1
M653 | KILLED | lib/ui/file_list/rename_warning_view.dart | 008:T53 重複の組にファイルを並べない ... | exit 1
M654 | KILLED | lib/ui/file_list/rename_warning_view.dart | 008:T53 変更後名をファイルより前(組の1行目)に戻す ... | exit 1
M655 | KILLED | lib/ui/file_list/rename_warning_view.dart | 008:T53 ファイルを1行に1つ縦に並べる ... | exit 1
M656 | KILLED | lib/ui/file_list/rename_warning_view.dart | 008:T53 「(フォルダにある既存のファイルと重複)」を赤にしない ... | exit 1
M657 | KILLED | lib/ui/file_list/rename_warning_view.dart | 008:T53 区切りを名前の前に付ける ... | exit 1
7 mutations: 7 KILLED, 0 SURVIVED, 0 SKIPPED
```

  - manual の期待を新しい並びへ直し、対象 build を `a2ab21b` にした。**1回目の結果は再利用しない**(code が変わった)。

### 独立review

reviewer は開発者の指定どおり `gpt-6-luna`(`codex-container exec -m gpt-6-luna`)。実装は Claude Opus 5.5。
contract を変える task なので、実装と同等以上の model を使う(AGENTS.md)。

- Review attempt 1: `5c7b7a7..ec9ab32` — **PASS** — 未解決 P0/P1 なし、P2/P3 なし
  - 確認できた点: revision 10.0 と `rowDetailWarnings` / 組の分け方が一致(相手の他の警告・別 folder・別の変更後名は
    混ざらない。行と全件は同じ `preview`)。「フォルダにある既存のファイル」は読み込んだ1件だけの組に限られ、
    選んでいない行・占有名との衝突と矛盾しない。REQ-009 (2)/(3)、REQ-021 規則1/2 を維持。共有部品への切り出しで
    T14 の振る舞いは変わらない。test の書き換えは revision 10.0 による期待の変更で緩和ではない。manual 手順3は
    `prepare()` の占有名の反映と一致。
  - reviewer の検証: `flutter test` 1181 PASS、`flutter analyze` No issues、`dart format` 0 changed、
    mutation M646〜M653 の8件 KILLED。足した mutation なし。

- Review attempt 2(差分): `ec9ab32..c568f09` — **FAIL** — P1 1件(T53-R1)。reviewer は `gpt-6-luna`
  - **T53-R1(P1・成果物の欠陥)**: 「名前の途中で折らない」の保証が、1件ずつなら幅に収まる名前でしか確かめられて
    いない。**1行の幅より長い名前**が名前の中で折れる経路がある。
  - 確認できた点(次回の前提): 指定の3点(順序・横並び・既存ファイルの行の位置/色/文言)は実装と test で満たす。
    スコープ(`rowDetailWarnings`)と REQ-009 (3)/(4) は前回から変わらない。manual は `a2ab21b` と一致。test の
    書き換えは緩和でない。M650 / M651 / M653〜M657 は KILLED。`flutter test` 1183 PASS、analyze No issues。
  - **対応(`53ec95d`)**: 1行より長い名前は、折り返すか切り詰めるかしか無い。**切り詰めると名前が読めず REQ-009 (3)
    「識別できる形」に反する**ので、**次の行の先頭から始めて名前の中で折り返す**と決め、code のコメント・test
    (`maxLines`・`overflow` を持たない、行頭から始まる、2行以上に折れて全体が読める)・manual へ明記した。
    開発者の指定「ファイル名の途中では改行せず、次の行から始める」は、1行に収まる名前について満たす。
  - 検証(`53ec95d`): `flutter analyze` No issues、`dart format` 0 changed、`flutter test` **1184 PASS**、
    `check_mutation_finds.py` PASS(601件)。
  - **以後の review は Sonnet**(Agent tool、`model: sonnet`)。2026-10-02、開発者「レビューはいったんsonnetにやらせるようにしてください」。
    contract を変える task には実装(Opus 5.5)と同等以上を使う既定(AGENTS.md)と食い違うが、開発者の指定に従う。

- Review attempt 3(差分): `c568f09..5ac87f4` — **PASS** — 未解決 P0/P1 なし。reviewer は Sonnet 5(Agent tool、開発者の指定)
  - T53-R1 が閉じた: 新しい test は、`_DuplicateGroupBox` の `Text` へ `maxLines: 1, overflow: TextOverflow.ellipsis` を
    足すと FAIL する(reviewer が一時的に当てて確かめ、復元済み)。「折り返す・切り詰めない」は REQ-009 (3) から導かれる。
    他の振る舞い・manual の対象 commit(`53ec95d`)は current code と一致。
  - reviewer の検証: `flutter test` 1184 PASS、`flutter analyze` No issues、`dart format` 0 changed、`check_mutation_finds.py` PASS(601)。
  - **T53-R3(P3)**: 切り詰めへ戻す対照 mutation が表に無い。**足さない** — 上のとおり test が検出することを reviewer が
    確かめており、`tool/` への追加は新たな差分reviewを要する。受容(引き受け先: 次に T53 の詳細modalへ触れる task)。
- 連鎖: `5c7b7a7..ec9ab32` PASS → `ec9ab32..c568f09` FAIL(T53-R1)→ `c568f09..5ac87f4` PASS(T53-R1 閉鎖)→ 以後の記録だけの差分は SELF-CHECK。

## Current state / handoff

- Last checkpoint: 差分review attempt 3 PASS(`c568f09..5ac87f4`)。code を `53ec95d` で凍結し、実機確認2回目を待つ
- Blocker category: manual-evidence
- Waiting for: 開発者(Android エミュレータでの実機確認2回目)
- Requested action: [manual-verification.md](manual-verification.md) の手順0〜3(4は任意)を行い、結果を会話で伝える
- Evidence revision: `lib/` が `53ec95d` と同一の build
- Next Agent action: 結果を作業記録へ書き、問題が無ければ `done` にして PR を ready にし、merge する
