# T50 各行の警告の出し方を再調整する

## 目的

各行の警告(重複・作成日時不明・連番の桁不足。`008:T16`/`T18` で行へ出すようにしたもの)の**出し方**を見直す。

## 出所

開発者の要望(2026-10-01、原文): 「変更前後の名前が横に並べても1行に収まるなら1行にまとめる・各行の警告の出し方を再調整するの二つも改めてタスクとして登録したいです。」(後半)

## 範囲(着手時に詰める)

- **何をどう変えたいかはまだ聞いていない。** 着手時に、開発者が気になっている点を聞き取ってから範囲を決める。
- 警告の**判定**(どの行に何が出るか。005 REQ-009 / REQ-021 など)は変えない。変えるなら仕様の変更として先に開発者の承認を得る。
- 参考designの行の警告(`warnText` を変更後名の下に赤字で置く)は土台であって正本ではない。

## 依存

- 当初は `T49`(変更前後の名前を1行にまとめる)の後に置いたが、**2026-10-01 に `T49` を止めた**ので依存は無い。`T48`(行のファイルサイズ)は merge 済み。

## 受け入れ証拠

- 聞き取った要望ごとの widget test。mutation。
- `flutter test`・`flutter analyze`・`dart format`。独立review。
- `manual-verification.md` で Android 実機と Windows desktop を確認する。

## 作業記録

- 2026-10-01 / 着手。開発者の要望(原文): 「気になっているのはわざわざ1行を警告に使ううえに、警告が見づらい部分です。今考えているのは、変更前の名前が書いてある行と同じ行の右端(ドラッグ用のつまみは含まない)に警告マークと「詳細」(太字・下線)を配置する案です。あるいは、詳細が無くても該当ファイルを見ればだいたい警告内容がわかるようにすることも考えました。…日時不明は各ファイルの詳細にある日時を赤字で強調する(並び順で日時不明の場合にやっているのと同じように)。連番の桁不足については、…自動で連番の桁を増やしつつトーストで通知すれば、…もう一つの案としては、命名ルール設定ボタンに警告を表示し、修正を促す導線にしつつ情報を一か所にまとめるというものです。」
- Agent が案を整理して推奨案1〜4を出し、開発者が採った(plan の 2026-10-01 の決定)。桁不足の自動の引き上げは仕様の変更なので `T51`(定義)/ `T52`(実装)へ分けた。命名ルール設定buttonの案(4)は、1〜3 を実機で見てから決める。
- **右端に書く種類**(開発者の確認「先ほどの表のとおりに進めてよいです」): 重複 →「重複」、名前が空 →「名前が空」、桁不足 →「桁不足」、作成日時不明 → 書かず補足情報の赤字。**書く種類が無い行(作成日時不明だけ)は「詳細」**。組み合わせは「・」でつなぐ(例「重複・桁不足」)。種類の呼び名は詳細と確認dialogも同じ短い語へそろえた(`008:T19` の同じ語彙の決まり)。
- **005 REQ-009 (1)(種別が一覧で分かる)との関係**: 作成日時不明は補足情報の赤字の `作成日時: 不明` で読める。名前が空の (ii)「改名の対象にならない」は変更後名の `（変更なし）` で読める(以前は右端の `名前が空・改名されません` が担っていた)。spec の文言は変えていない。
- branch `asdd/008-ui-alignment/T50-row-warning-retune`、worktree `/workspace/.worktrees/008-T50-row-warning-retune`、起点 `dev`@`ad61afe`。

### checkpoint 1: 行の警告の置き場所と見せ方(`1b5d119`)

- 専用の1行をやめ、現在名と同じ `Row` の右端(現在名は `Expanded` で残りの幅を取り、警告は削らない)へ。警告の形は枠と塗りの箱をやめ、**記号 + 太字・下線の文字**(押せることは下線で示す)。tap範囲は上下 4・左右 6 の余白を保つ。
- `rowWarningBadgeLabel`: 右端には他の場所から読めない種類だけ。`rowHasMissingCreatedAt`: 畳む前の警告に作成日時の基準日時不明があれば、補足情報の `作成日時: 不明` を赤で強調(並び順が作成日時でなくても)。
- 種類の呼び名: `duplicateKindLabel` = `重複`(以前 `名前の重複`)、`digitShortageKindLabel` = `桁不足`(以前 `連番の桁不足`)。
- 既存 test 27件の期待値を新しい決定へ追随させた(主張は弱めていない。右端の文字列の代わりに補足情報の赤字・`（変更なし）`・下線と太字を見る形へ置き換えた)。行の高さは「警告のある行も、増えるのは1行より少ない」を足した。
- mutation: M173・M179・M180・M213・M215・M218・M220〜M222・M227・M228・M261 の find を追随。**M224・M226・M605 を外した**(箱をやめて塗り・枠が無い / 行の警告は1行で行数の段階が無い。後継は M622・M623 と M180)。M622〜M626 を追加。範囲付き(`flutter test test/spec_005_rename_exec test/spec_002_file_list test/widget_test.dart`、対象 `1b5d119`、18件):

```text
M173 M179 M180 M213 M215 M218 M220 M221 M222 M225 M227 M261 M622 M623 M624 M625 M626 KILLED / M228 SURVIVED
18 mutations: 17 KILLED, 1 SURVIVED, 0 SKIPPED
```
- **M228 の SURVIVED を全件で確かめ直した**(`flutter test --exclude-tags tooling`): `1 mutations: 0 KILLED, 1 SURVIVED`。警告は現在名と同じ `Row` の非 flex の子で横幅の上限が無く、`MainAxisSize.max` でも中身の幅にしかならない **等価な変異**。対照として表に残し、note に期待値を書いた(右寄せは M213 が見る)。
- 検証(`1b5d119`): `flutter test` +1152 PASS、`flutter analyze` No issues、`dart format` 0 changed、`check_mutation_finds.py` 571 PASS。

### 実機確認 1回目(2026-10-01)

- 対象: `lib/` が `bcc2c34` と同一の build。Android エミュレータと Windows desktop。手順 `manual-verification.md` の 0〜6(`T52` と共通)。
- 受領: 2026-10-01、会話で開発者から(原文)「動作は問題ありませんでしたが、各行の警告の下線が見えづらいです。ヘッダー付近の警告文の『詳細』の下線の引き方を参考にしてください。」→ **動作(0〜6)は期待どおり。下線の見え方だけ指摘。**

### checkpoint 2: 下線の引き方(`a1e173a`)

- 行の警告の下線を、文字の装飾(`TextDecoration.underline`。字形に接して細い)から、**件数表示の「詳細」と同じく文字の枠の下端に引いた線**へ変えた。太さは共有の定数 `warningLinkUnderlineWidth`(1.5)にし、件数表示も同じ定数を使う。
- test: 「警告は押せると分かる形」を、文字の装飾ではなく下の線(太さ = 共有の定数 ≥ 1.5、色 = 文字と同じ、文字の下にある)を見る形へ。行の高さの test は線の太さを足した値へ。
- mutation: M622・M623・M570 の find を追随、M633(線を細くする)を追加。範囲付き(`flutter test test/spec_005_rename_exec test/spec_002_file_list`、対象 `a1e173a`、7件):

```text
M220 M227 M261 M570 M622 M623 M633 すべて KILLED
7 mutations: 7 KILLED, 0 SURVIVED, 0 SKIPPED
```
- 検証(`a1e173a`): `flutter test` +1164 PASS、`flutter analyze` No issues、`dart format` 0 changed、`check_mutation_finds.py` 577 PASS。

### 独立review

reviewerは`gpt-6-luna`(開発者指定。AGENTS.md の既定「実装より一段軽い」に代えて従った)。`T50` と `T52` は同じ PR #208 なので、1回の review で両方を見た。

- **attempt 1**: `441acdf..950cb2c`(全範囲) — **PASS**。確認された点: T50 の右端の種類・補足情報の赤字・`（変更なし）` が 005 REQ-009 (1)・代表例20・20d・REQ-021 を保つ / `rowHasMissingCreatedAt` が畳む前の警告を見る / 語彙のそろい / 既存 test の書き換えに削除・skip・緩和が無い(4ファイルで 87 → 88 件)/ M224・M226・M605 の除外と M228 の等価の扱い / T52 が 003 REQ-015 を満たし、フレーム後1回でループしない / M631 を外した判断 / 既存 test 2件の意図 / mutation 表 576 件の一意 / manual 手順4が引き上げを起こす。reviewer 側: 範囲付き mutation 14 KILLED・M228 SURVIVED(全件でも SURVIVED)、`flutter test` 1164 PASS、analyze・format PASS。
  - **P2(成果物の欠陥)**: 両 task の `Current state / handoff` が「登録しただけ」のままで、実装・PR・merge の記録と食い違う → handoff を現状へ更新して閉じた(**SELF-CHECK**、記録だけの差分)。
- 連鎖: `441acdf..950cb2c` PASS → 以後の記録だけの差分は SELF-CHECK。

## Current state / handoff

- Last checkpoint: `T50`(行の警告)と `T52`(連番の桁の自動引き上げ)を同じ branch で実装(`bcc2c34`、T52 は merge で取り込み)。独立review attempt 1(`441acdf..950cb2c`)PASS、P2 は記録で閉じた
- Blocker category: human verification
- Waiting for: 開発者による実機確認1回目(`/workspace/.worktrees/008-T50-row-warning-retune/specs/008-ui-alignment/tasks/T50-row-warning-retune/manual-verification.md` の 0〜6。Android エミュレータと Windows desktop。`T50`・`T52` 共通)
- Requested action: worktree の HEAD から build し(`lib/` は `bcc2c34` と同一)、0〜6 を確かめて結果を会話で伝える
- Evidence revision: `bcc2c34`(`lib/`)
- Next Agent action: 結果を両 task の「実機確認 1回目」節へ記録する → 指摘があれば直して差分review(range は `950cb2c` 以降)→ 実機確認をやり直す。OK なら両方 done にし、PR #208 を ready → CI → merge commit で merge、`dev` で `workspace.py check specs`、T50・T52 の worktree と branch を片付ける。あわせて、命名ルール設定buttonに警告を出す案(推奨案4)を開発者に尋ねる
