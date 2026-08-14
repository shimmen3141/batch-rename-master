# T10 対象folderの占有名を衝突判定へ入れる

## 目的

001の衝突判定が見ている「既存の名前」を、**アプリへ読み込まれたfileの名前**から**占有名**へ広げる。

**占有名 = 対象folderの実在entry名 − この実行で改名される選択fileの現在名。** REQ-022で除外されたfileの現在名は改名されないので**含める**(005 contract revision 4の用語)。

## なぜ必要か

001の重複判定は、最終名集合を「未選択の現在名 ∪ 選択の生成後名」で作る(001 spec)。**これはアプリへ読み込まれたfileだけである。** 対象folderには、利用者が読み込んでいないfileもある。

現状では、**読み込んでいないfileと同じ名前になる改名を、実行前に検出できない**。005 contract revision 4はこれをREQ-004・REQ-026で塞ぐと定めたので、占有名を供給する経路が要る。

**これは005 ADR-002の中心にある変更である。** 事前検出が効かなければ、衝突は実行時の`nameConflict`まで持ち越され、原子的no-replaceが無い環境では取りこぼす。

## 入力と依存

- `T04`で承認された005 contract revision 4(REQ-004、REQ-011、REQ-023〜026)。
- 001の`validate` / `autoResolve`と`contracts/behavior-contract.json`(001が正本)。
- 004のfile source(実在entry名を供給する側)。

## 変更範囲

- **001**: 最終名集合の定義へ**占有名**を加える。**実在名をそのまま加えてはならない** — 選択file自身の現在名が入り、`IMG_0001..0100`を1つずらす改名でほぼ全件に` (n)`が付く(005:T04のreview attempt 1のP0)。**001は純粋Dartでfilesystemを触らない**ので、占有名は入力として受け取る。001 specとcontractの改訂・再承認を伴う。
- **`validate`だけでなく`autoResolve`も占有名を避ける**(005 contract REQ-026)。警告だけを占有名で出して解決を占有名抜きで行うと、確認した目標名が占有名と衝突したまま実行へ渡る。
- **004**: 対象folderのentry名を列挙して供給する。004 specの改訂を伴う(`T03`と範囲が重なるので着手時に調整する)。
- **005**: 004から受け取った実在名から**占有名を作って**001の検証へ渡す(005 contract `scope.in`)。

## 決めること

- **占有名をいつ取るか。** 読み込み時か、実行の確認直前か、両方か。古い一覧で判定すると、事前検出をすり抜ける。
- **複数folderに跨る選択でどう扱うか。** 衝突はfolderごとにしか起きないので、folder単位で持つ必要がある。
- **列挙できないfolderがあったときの扱い**(権限、I/Oエラー)。**「列挙できなかった」を「衝突が無い」と読まない。**

## 受け入れ証拠

- 読み込んでいないfileと同じ名前になる改名が、**実行前に警告として出る**ことをtestで検査する(005 spec 例25)。
- **`a→b`, `b→c`のような入れ替えで警告が出ない**ことをtestで検査する(005 spec 例25b)。**この検査が無いと、P0の再発を検出できない。**
- **他に警告が無くても、占有名との衝突だけで確認を経る**ことをtestで検査する(005 contract REQ-026、SM-001の直行経路)。
- **REQ-022で除外されたfileの現在名との衝突は警告として出る**ことをtestで検査する(005 spec 例25c)。
- `autoResolve`が返す名前が占有名と衝突しないことをtestで検査する。
- 001が占有名を**入力として**受け取り、filesystemに依存しないままであることをtestで検査する(INV-004 副作用なし)。
- 列挙できなかったfolderで、衝突が無いと誤判定しないことをtestで検査する。
- 001の既存contract testが継続PASSする。
- `flutter test` / `flutter analyze` / `dart format --output=none --set-exit-if-changed .` がPASS。
- exact rangeの独立reviewがPASSする。

## 作業記録

- 2026-08-14 / 005 ADR-002(衝突は採番で回避する)を受けて定義。preflightを削除した`T09`の代わりに置く**わけではない** — `T09`はpreflightの実行制御で、こちらは事前検出の入力を正すtaskである。

## Current state / handoff

- Last checkpoint: 定義しただけ。未着手
- Blocker category: dependency
- Waiting for: `T04`(005 contract revision 4)の承認
- Requested action: なし
- Evidence revision: `dev@4fd6ab1` + 005 ADR-002(proposed)
- Next Agent action: `T04`承認後に着手する。**001と004の仕様改訂を伴うので、`T03`との範囲重複を先に調整する**
