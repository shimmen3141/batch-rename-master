# T09 preflightの実行制御と提示を実装する

## 目的

`T02`で承認された仕様のうち、**preflightを「いつ・どの単位で走らせ、駄目だったとき何を見せるか」**を実装する。

`T05`は`renameat2`を1回呼ぶ部品を作る。**その部品を安全に使い切る責務はここにある。** 後片付け、複数folderの停止単位、結果の失効、利用者への理由提示は、native portの範囲ではない。

## 入力と依存

- `T02`で承認された[`spec.md`](../../spec.md)のREQ-005、REQ-007、REQ-010〜013、INV-002、INV-004。
- `T05`のnative rename(観測の1回分を提供する)。
- `T04`で承認された005 contract revision 4(実行flowの正本)。
- 005の既存実行flow: `lib/`配下の`RenameExecutor`利用側。

## 変更範囲

- preflightの手続き本体(REQ-006の3観測を`T05`の部品で組み立て、判定を返す)。
- **専用subfolderとmarker fileの生成・検査・削除**(REQ-011)。
- **後片付け**(REQ-010、INV-004)。正常終了でも異常終了でも実体を残さない。
- **複数folderの停止単位**(REQ-012)。実行前に全folderをpreflightし、ひとつでも駄目なら実行しない。
- **結果の失効**(REQ-013)。実行をまたいで持ち回らない。
- **駄目だったfolderと理由の提示**(REQ-007)。

**subfolder名とmarker fileの具体はこのtaskで決める**(`spec.md`の「未解決」)。`spec.md`は規則を固定していないが、REQ-011の判定条件(名前の合致 **かつ** markerの存在)は満たさなければならない。

## 決めること

- subfolder名の規則。**利用者が見て正体が分かること**と衝突しにくさを両立する。
- markerの内容と検査方法。**名前だけで「自分のもの」と判定してはならない**(review attempt 2のP1-3)。
- 複数folderのpreflightをどこで走らせるか(実行直前の1箇所へ集約する)。

## 受け入れ証拠

- `spec.md`のVER-002、VER-005、VER-007、VER-008、VER-009に対応するtestがある。
- **markerを持つ残骸から開始すると片付けて続き、markerの無い同名実体があると削除せず中止する**ことをtestで検査する。**この2つは逆向きなので両方要る。**
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
- Waiting for: `T04`の契約承認と`T05`のnative port
- Requested action: なし
- Evidence revision: `dev@4fd6ab1` + `spec.md` re-approval 2026-08-14(修正A-1は確認待ち)
- Next Agent action: `T05`完了後に着手する。**subfolder + markerの規則を最初に決め、testを先に書く**
