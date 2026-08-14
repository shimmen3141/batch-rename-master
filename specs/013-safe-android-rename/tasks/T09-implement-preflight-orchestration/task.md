# T09 preflightの実行制御と提示を実装する

## 目的

`T02`で承認された仕様のうち、**preflightを「いつ・どの単位で走らせ、駄目だったとき何を見せるか」**を実装する。

`T05`は`renameat2`を1回呼ぶ部品を作る。**その部品を安全に使い切る責務はここにある。** 後片付け、複数folderの停止単位、結果の失効、利用者への理由提示は、native portの範囲ではない。

## 入力と依存

- `T02`で承認された[`spec.md`](../../spec.md)のREQ-005〜007、REQ-010〜013、INV-002、INV-004。
- `T05`のnative rename(観測の1回分を提供する)。
- `T06`の権限port。**INV-003によりpreflightは権限を確認してからでなければ開始できない**ので、port無しには書けない。
- `T07`のfile browser。REQ-007の「どのfolderがなぜ駄目か」を提示する先の画面がここにある。
- `T04`で承認された005 contract revision 4(実行flowの正本)。
- 005の既存実行flow: `lib/`配下の`RenameExecutor`利用側。

## 変更範囲

- preflightの手続き本体(REQ-006の3観測を`T05`の部品で組み立て、判定を返す)。
- **専用subfolderとmarker fileの生成・検査・削除**(REQ-011)。**subfolder名は実行ごとに一意**とし、衝突したら別の名前を取る。**対象folderに何があっても中止しない。** 残骸の削除はbest-effortで、失敗しても続行する。
- **後片付け**(REQ-010、INV-004)。正常終了でも異常終了でも実体を残さない。
- **複数folderの停止単位**(REQ-012)。実行前に全folderをpreflightし、ひとつでも駄目なら実行しない。
- **結果の失効**(REQ-013)。実行をまたいで持ち回らない。
- **駄目だったfolderと理由の提示**(REQ-007の4分類)。
- **全域性**(REQ-005)。どの入力でも必ず結果を返し、例外を外へ出さない。**「確認できなかった」が受け皿である。**

**subfolder名とmarker fileの具体はこのtaskで決める**(`spec.md`の「未解決」)。`spec.md`は規則を固定していないが、REQ-011の判定条件(名前の合致 **かつ** markerの存在)は満たさなければならない。

## 決めること

- subfolder名の規則。固定成分(preflightのものと分かる)と**実行ごとに一意な成分**の作り方。**同じ名前を再利用しない。**
- **名前取得の試行上限**(REQ-011)。上限に達したらREQ-007の「確認できなかった」を返す。**無限に試さない。**
- **subfolderを隠すかどうか。** 先頭`.`や`.nomedia`はgallery・同期appへの露出を減らすが、「見て正体が分かる」と衝突する。`spec.md`の「未解決」がこのtaskへ委ねている。
- markerの内容と検査方法。**削除には名前とmarkerの両方を要求する**(名前だけで「自分のもの」と判定しない)。ただし**判定に失敗しても実行を止めない**(REQ-011)。
- 複数folderのpreflightをどこで走らせるか(実行直前の1箇所へ集約する)。

## 受け入れ証拠

- `spec.md`のVER-002、VER-005、VER-007、VER-008、VER-009に対応するtestがある。
- `spec.md`のVER-007が挙げる5項目をtestで検査する。**中でも(3)が要である** — markerが無い残骸、削除に失敗する残骸、名前が衝突する利用者の実体のいずれがあっても、**中止せず別の名前で続行し、その実体に触れない**こと。ここが3回のreview FAILの中心だった。
- 中断(例外注入、権限失効)のあと実体が残らないことをtestで検査する。
- 複数folderで一部が「効かない」とき、**どのfolderも改名されない**ことをtestで検査する。
- filesystemをportで抽象化し、testが実機に依存しないこと。
- 005の既存contract testが継続PASSする。
- `flutter test` / `flutter analyze` / `dart format --output=none --set-exit-if-changed .` がPASS。
- exact rangeの独立reviewがPASSする。

## 作業記録

- 2026-08-14 / `T02`のreview attempt 2のP1-2を受けて定義。**REQ-010〜013はpreflightのorchestrationとUIの要求であり、`T05`(native port)の範囲ではなかった。** `covers`だけをT05へ載せた状態は、被覆の記録としては埋まっていても実装の約束になっていなかった。

## Current state / handoff

- Last checkpoint: 定義しただけ。未着手
- Blocker category: dependency
- Waiting for: `T04`の契約承認、`T05`のnative port、`T06`の権限port、`T07`の画面
- Requested action: なし
- Evidence revision: `dev@4fd6ab1` + `spec.md`(2026-08-14の残骸方針変更。**再承認待ち**)
- Next Agent action: `T05`完了後に着手する。**subfolder + markerの規則を最初に決め、testを先に書く**
