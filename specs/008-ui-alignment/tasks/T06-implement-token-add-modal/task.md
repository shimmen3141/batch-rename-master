# T06 token追加をmodal確定へ変える

## 目的

`T05`で承認された仕様どおり、tokenは設定を終えてから列に入るようにする。既定値のままのtokenが紛れない。

## 入力と依存

- `T05`で承認された003 spec。
- `docs/design/Bulk Renamer.html`。**適用する画面範囲はルール構築のtoken追加に限る**。

## 変更範囲

- token追加の導線(modal)と、cancel時に追加されないこと。
- 003の仕様由来testの更新と追加。

## 受け入れ証拠

- modalをcancelするとtokenが追加されないことをwidget testで検査する。
- 設定を終えて確定すると、その設定値でtokenが列に入ることをtestで検査する。
- 007の永続化(ruleの保存・復元)が壊れていないことを既存testの継続PASSで確認する。
- `flutter test` / `flutter analyze` / `dart format --output=none --set-exit-if-changed .` がPASS。
- [`manual-verification.md`](manual-verification.md)で実機の操作感を確認する。
- exact rangeの独立reviewがPASSする。

## 着手時の宣言(2026-09-17)

### machine検証する範囲

CIで閉じるのは次である(003 REQ-008〜REQ-012。例6〜12)。

- 設定項目を持つ4種の追加ボタンで**エディタが開くだけで `tokens` が変わらず、変更通知も起きない**こと。
  確定したときだけ**確定した値で1件**入り、通知が1回であること(値が一度入って戻る実装を排除する)。
- 確定以外の閉じ方 — **キャンセル、戻る操作、シート外のtap、下方向のdrag** — のそれぞれで何も変わらないこと。
  **エディタの中で値を変えてから閉じる**(既定値のまま閉じるだけだと、入力値を捨てる経路を通らない)。
- 元の名前は**エディタを開かずに**1件入ること。
- 既存tokenの編集: 確定以外で閉じると `tokens` も通知も変わらないこと。`LiteralToken` は区切りとして
  入れたものでも**文字列入力と区切りプリセットの両方を持つ共通エディタ**が開くこと。
- 確定できない入力(自由テキスト・区切りの空、日時フォーマットの空)を**追加と編集の両方**で。
- **狭幅(ルール設定シートの上にエディタが重なる)と広幅(右ペイン)の両方**で、エディタが開いているあいだ
  一覧のプレビュー(`FileListController.rule`)が変わらないこと。狭幅ではエディタを閉じてもルール設定シートは
  残ること。
- 007 の保存: `PersistentRuleController` は変更通知ごとに保存するので、**通知が起きないこと**で押さえる
  (保存の実体は 007 の既存testの継続PASS)。

### machineで閉じられない範囲と引き受け先

- **実機での操作感**(シートが2枚重なったときの分かりやすさ、キーボードとシートの重なり、戻る操作・
  swipeの誤爆)。manual確認で見る。見た目・余白の詰めは **`008:T10`**。
- **確定ボタンの文言**: 追加は「追加」、編集は「確定」にする(003 spec は自由とする)。分かりやすさはmanualで見る。

### 参考designから離れる点

- 参考designは**押した瞬間に既定値のtokenを列へ入れてからdialogを開く**。003 REQ-008 が禁じているので採らない
  (理由は [`T05` の task.md](../T05-define-token-add-modal/task.md) の「参考designから離れた点」)。
- 参考designは「元のファイル名」でもdialogを開く。003 REQ-010(2026-09-14 開発者決定)により即追加する。
- **エディタの形はbottom sheetのまま**にする(参考designは中央のdialog)。003 spec は形を自由としており、
  既存の編集エディタと同じ部品を追加でも使う。形の変更は `T10` / `T14` の範囲。

## 作業記録

- 2026-08-12 / plan作成時に定義。

## 実装の記録(2026-09-17)

- `rule_builder_view.dart` の `_AddBar._add`: 設定項目を持つ4種は `showTokenEditor(confirmLabel: '追加')` を開き、
  **null でないときだけ** `addToken`。元の名前はエディタを開かずに `addToken`。
- `token_presets.dart`: `defaultTokenFor` を `initialTokenFor`(エディタの初期値)へ改名し、自由テキストを `LiteralToken('')` にした
  (改修前は `'テキスト'` を即挿入しており、003 spec の約束と食い違っていた)。
- `token_editors.dart`: 確定ボタンの文言を引数にした(追加「追加」/編集「確定」)。エディタに `tokenEditorKey` を付けた。
- **置き換えたtest**: `rule_builder_view_test.dart` の「追加ボタンで既定トークンが追加され Chip が表示される(REQ-002)」は
  **改修前の振る舞い(押すと即追加)そのものを主張していた**ので、エディタで「追加」を押す形へ書き換えた。
  「開いただけでは入らない」の assertion を足しており、緩めていない。
- **test-first**: `token_add_confirm_test.dart`(39件)を先に書き、エディタの key だけを足した状態で **32件 FAIL / 7件 PASS** を確認した。
  PASS の7件は改修前から成立していた振る舞い(元の名前の即追加、編集を確定せず閉じる4通り、編集の確定、日時フォーマット空の編集)。
- **他taskの手順の追随**: `005:T05` の manual 手順2(「テキスト」を押して編集していた)と
  `docs/development/emulator-verification.md` の説明を新しい手順へ直した。

## mutation の記録

```console
$ python3 <asdd-plugin>/scripts/mutation_check.py tool/mutations.json --root . --list
242 mutations, 0 with an unexpected match count
```

このtaskが足した M242〜M251 を `flutter test test/spec_003_rule_builder test/spec_007_rule_persistence` で回した。

```console
M242 | KILLED | lib/ui/rule_builder/rule_builder_view.dart | 008:T06 参考designの形(押した瞬間に既定値で入れ、キャンセルで取り除く)… | exit 1
M243 | KILLED | … 設定項目を持つ種別を改修前のように既定値で即追加する(日時以外) | exit 1
M244 | KILLED | … 確定せずに閉じても既定値で追加する | exit 1
M245 | KILLED | … 元の名前をエディタ経由にする | exit 1
M246 | KILLED | … 自由テキストの初期値を改修前のプレースホルダへ戻す | exit 1
M247 | KILLED | … シート外のtapで閉じられなくする(対照) | exit 1
M248 | KILLED | … 下方向のswipeで閉じられなくする(対照) | exit 1
M249 | KILLED | … 文字列が空でも確定できる | exit 1
M250 | KILLED | … 編集を確定せずに閉じても同じ値で差し替える | exit 1
M251 | KILLED | … 編集の確定ボタンを「追加」にする | exit 1
10 mutations: 10 KILLED, 0 SURVIVED, 0 SKIPPED
```

## 独立review

### attempt 1(2026-09-17、range `85f29b7...28e6f74`)— **PASS**

P0/P1 なし。reviewer が M242〜M251 と独自の probe 6件を回した(14 KILLED、2 SURVIVED。SURVIVED の1件は等価候補の
`useRootNavigator: true` で表に入れていない)。

| # | 重大度 | 分類 | 指摘 | 扱い |
|---|---|---|---|---|
| 1 | P2 | 成果物の欠陥 | manual 手順1 確認A「後ろのシートにトークンが増えていない」が実機で見えない(エディタがルール設定シートを覆う。412x915 で測定) | **直した。** 確認Aを「追加」の文言と押した感覚へ、確認Bを「閉じるとシートに戻り入っている」へ変え、見えない理由を手順に書いた。fixture の参照を `008 / T07` の手順へのlinkにした |
| 2 | P2 | 安全網の穴 | 狭幅で「追加」を確定したあとにルール設定シートまで閉じても検出されない(probe P4 SURVIVED)。3条件: (1) 該当 (2) データ損失等に**該当しない**(UXの退行) (3) 該当 | **閉じた**(受容でなく)。狭幅testの確定後にシートが残る assertion を足し、`M255` として表へ入れて KILLED |
| 3 | P2 | 安全網の穴 | 狭幅で戻る操作・スワイプの経路がtestに無い(シート外tapだけ)。3条件は 2 と同じ | **閉じた。** 狭幅testを4つの閉じ方すべてで回す形にした |

reviewer が足した mutation M252〜M256 を表へ取り込んだ。

```console
$ python3 <asdd-plugin>/scripts/mutation_check.py tool/mutations.json --root . --list
247 mutations, 0 with an unexpected match count

(M242〜M256 を flutter test test/spec_003_rule_builder test/spec_007_rule_persistence で)
15 mutations: 15 KILLED, 0 SURVIVED, 0 SKIPPED
```

attempt 1 の後に動いたのは **test・mutation表・記録だけ**で、`lib/` は `31427b2` のまま。

## 検証の記録

**この表は commit ごとに置き換える。**

| 検査 | 結果 |
|---|---|
| `flutter test` | PASS(833) |
| `flutter analyze` | PASS(No issues found) |
| `dart format --output=none --set-exit-if-changed .` | PASS(0 changed) |
| `mutation_check.py --list`(全表) | `247 mutations, 0 with an unexpected match count` |
| `workspace.py check specs` | PASS |

## Current state / handoff

- Last checkpoint: 独立review attempt 1 PASS、指摘を閉じた(2026-09-17)。**`lib/` の最終commitは `31427b2`**
- Blocker category: なし
- Waiting for: なし
- Evidence revision: branch `asdd/008-ui-alignment/T06-implement-token-add-modal`(`dev@85f29b7` から作成)
- Next Agent action: manual確認の結果を待つ。並行して attempt 1 後の差分(test・記録のみ)の独立reviewを受ける
