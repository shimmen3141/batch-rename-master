# T10 対象folderの実在名を衝突判定へ入れる

## 目的

001の衝突判定が見ている「既存の名前」を、**アプリへ読み込まれたfileの名前**から**対象folderに実際にあるentryの名前**へ広げる。

## なぜ必要か

001の重複判定は、最終名集合を「未選択の現在名 ∪ 選択の生成後名」で作る(001 spec)。**これはアプリへ読み込まれたfileだけである。** 対象folderには、利用者が読み込んでいないfileもある。

現状では、**読み込んでいないfileと同じ名前になる改名を、実行前に検出できない**。005 contract revision 4はこれをREQ-004・REQ-011で塞ぐと定めたので、実在名を供給する経路が要る。

**これは005 ADR-002の中心にある変更である。** 事前検出が効かなければ、衝突は実行時の`nameConflict`まで持ち越され、原子的no-replaceが無い環境では取りこぼす。

## 入力と依存

- `T04`で承認された005 contract revision 4(REQ-004、REQ-011、REQ-023〜025)。
- 001の`validate` / `autoResolve`と`contracts/behavior-contract.json`(001が正本)。
- 004のfile source(実在名を供給する側)。

## 変更範囲

- **001**: 最終名集合の定義へ実在名を加える。**001は純粋Dartでfilesystemを触らない**ので、実在名は入力として受け取る。001 specとcontractの改訂・再承認を伴う。
- **004**: 対象folderのentry名を列挙して供給する。004 specの改訂を伴う(`T03`と範囲が重なるので着手時に調整する)。
- **005**: 供給された実在名を001の検証へ渡す。

## 決めること

- **実在名をいつ取るか。** 読み込み時か、実行の確認直前か、両方か。古い一覧で判定すると、事前検出をすり抜ける。
- **複数folderに跨る選択でどう扱うか。** 衝突はfolderごとにしか起きないので、folder単位で持つ必要がある。
- **列挙できないfolderがあったときの扱い**(権限、I/Oエラー)。**「列挙できなかった」を「衝突が無い」と読まない。**

## 受け入れ証拠

- 読み込んでいないfileと同じ名前になる改名が、**実行前に警告として出る**ことをtestで検査する。
- 001が実在名を**入力として**受け取り、filesystemに依存しないままであることをtestで検査する(INV-004 副作用なし)。
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
