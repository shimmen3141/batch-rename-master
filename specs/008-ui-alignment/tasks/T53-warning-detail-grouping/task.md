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
   [`spec.md`](../../../005-rename-exec/spec.md) の代表例 20e″。**開発者の承認を得るまで実装しない。**
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

## Current state / handoff

- Last checkpoint: 起票と 005 revision 10.0 の改訂案(draft)
- Blocker category: human-decision
- Waiting for: 開発者(005 revision 10.0 の承認)
- Requested action: REQ-009 (4) の追記文と代表例 20e″ を読み、承認するか直す点を伝える
- Evidence revision: 未定(実装前)
- Next Agent action: 承認を受けたら contract の `status` を `approved`・`approved_date` を入れ、実装に入る
