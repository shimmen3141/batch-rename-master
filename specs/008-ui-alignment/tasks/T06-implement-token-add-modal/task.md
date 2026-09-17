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

## Current state / handoff

- Last checkpoint: claimし、machine検証する範囲を宣言した(2026-09-17)
- Blocker category: なし
- Waiting for: なし
- Requested action: なし
- Evidence revision: branch `asdd/008-ui-alignment/T06-implement-token-add-modal`(`dev@85f29b7` から作成)
- Next Agent action: 003 REQ-008〜REQ-012 のtestを先に書いて赤を確かめ、実装する
