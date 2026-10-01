# T52 件数が増えたとき連番の桁数を自動で引き上げて通知する

## 目的

`T51` で定義した振る舞い(ゼロ埋めありの連番の桁数が下限を下回ったら、ルールを下限まで引き上げてトーストで知らせる)を実装する。

## 範囲(`T51` の承認後に詰める)

- composition root(一覧の件数を知る側)で件数とルールを見て、下限を下回る連番の桁数を引き上げる。`RuleController` 経由で変えるので、前回ルールとして保存される(007)。
- 引き上げたことをトースト(`008:T25` の閉じられる通知)で知らせる。
- 件数が減っても下げない。

## 受け入れ証拠

- widget test(003 の代表例15〜15d: 件数が増えて引き上がる・通知が出る・減っても下がらない・ゼロ埋めなしは触らない・復元して起動しても引き上がる・**連番が複数なら下限を下回るものだけ引き上がる**・保存される(007 REQ-008 の経路))。mutation。
- `flutter test`・`flutter analyze`・`dart format`。独立review。
- `manual-verification.md` で Android 実機と Windows desktop を確認する。

## 作業記録

- 2026-10-01 / 着手(`T51` の承認と merge の後)。branch `asdd/008-ui-alignment/T52-implement-digit-auto-raise`、worktree `/workspace/.worktrees/008-T52-implement-digit-auto-raise`、起点 `dev`@`441acdf`。

### checkpoint 1: 自動の引き上げと通知(`51f7870`)

- `RuleController.raiseSequenceDigits(itemCount)`(003 層): ゼロ埋めありの連番の桁数が下限([sequenceMinDigits]。エディタと同じ式)を下回れば引き上げ、引き上げた内容を返す。下げない・ゼロ埋めなしは触らない・桁数以外は変えない・何本あっても通知は1回。保存は 007 の既存の経路(`PersistentRuleController` が変更の通知で保存)に乗る。
- `sequenceMinDigits` を `lib/ui/rule_builder/sequence_digits.dart` へ移した(`token_editors.dart` は export で互換を保つ)。
- `RuleBuilderWorkspace`(composition): 一覧とルールの通知・起動時に、**フレーム後に1回**引き上げを試み、変えたら `showAppToast`(info)で「ファイルの数に合わせて、連番の桁数を2桁から3桁へ増やしました」と知らせる。件数は連番のエディタと同じ `selectedCount`(一覧 = rename 対象)。通知の最中に同期でルールを変えないのは、一覧とルールが互いの通知の中で書き換わるのを避けるため。
- test: `test/spec_003_rule_builder/sequence_digit_auto_raise_test.dart`(003 代表例15・15a・15b・15c・15d、下限の式に開始・増分が入る、保存される、知らせの文言)。
- **既存 test 2件を、意図を保つ形へ直した**(自動の引き上げで前提が崩れたため):
  - `sequence_zero_pad_editor_test.dart`「件数がエディタへ届く」: 既存の [連番(2桁)] を150件で置くと開く前に3桁になり、エディタが件数を受け取らなくても3と出て空振りする → **追加の経路**(初期値2桁)で見る形へ。
  - `warning_display_test.dart`「狭幅と広幅のどちらでもルール単位の警告表示が無い」: 警告の元を桁不足(自動で消える)から**作成日時不明**へ替えた。
- mutation: M627〜M632 を追加。`sequenceMinDigits` の移動に合わせ M506・M510・M511 の file を追随。範囲付き(`flutter test test/spec_003_rule_builder test/spec_005_rename_exec/warning_display_test.dart`、対象 `51f7870`、9件):

```text
M506 KILLED / M510 KILLED / M511 SURVIVED(期待どおり。note に「SURVIVEDが期待値」) / M627 KILLED / M628 KILLED / M629 KILLED / M630 KILLED / M631 SURVIVED / M632 KILLED
9 mutations: 7 KILLED, 2 SURVIVED, 0 SKIPPED
```
- **M631 の SURVIVED を全件で確かめ直した**(`flutter test --exclude-tags tooling`): `1 mutations: 0 KILLED, 1 SURVIVED`。起動時の `_scheduleRaiseDigits()` は、初期の `_syncRule` → `setRule` が一覧を通知して一覧の購読が引き上げを起こすので**等価**だった。重複した呼び出しを外し、M631 を表から削除した(代表例15c は M630 の経路が担う。test「例15c」は残っている)。
- 検証(`51f7870`): `flutter test` +1163 PASS、`flutter analyze` No issues、`dart format` 0 changed、`check_mutation_finds.py` 575 PASS。

### 実機確認 1回目(2026-10-01)

- 対象: `lib/` が `bcc2c34` と同一の build(`T50` と共通の手順 4)。受領: 開発者「動作は問題ありませんでしたが、各行の警告の下線が見えづらいです。…」→ **手順4(起動し直して1桁から2桁へ引き上がり、通知が出る)は期待どおり。** 指摘は `T50` の下線だけ。`T50` の修正(`a1e173a`)で code が変わったので、2回目で同じ build をもう一度確かめる。

### 独立review

reviewerは`gpt-6-luna`(開発者指定。AGENTS.md の既定「実装より一段軽い」に代えて従った)。`T50` と `T52` は同じ PR #208 なので、1回の review で両方を見た。

- **attempt 1**: `441acdf..950cb2c`(全範囲) — **PASS**。確認された点: T50 の右端の種類・補足情報の赤字・`（変更なし）` が 005 REQ-009 (1)・代表例20・20d・REQ-021 を保つ / `rowHasMissingCreatedAt` が畳む前の警告を見る / 語彙のそろい / 既存 test の書き換えに削除・skip・緩和が無い(4ファイルで 87 → 88 件)/ M224・M226・M605 の除外と M228 の等価の扱い / T52 が 003 REQ-015 を満たし、フレーム後1回でループしない / M631 を外した判断 / 既存 test 2件の意図 / mutation 表 576 件の一意 / manual 手順4が引き上げを起こす。reviewer 側: 範囲付き mutation 14 KILLED・M228 SURVIVED(全件でも SURVIVED)、`flutter test` 1164 PASS、analyze・format PASS。
  - **P2(成果物の欠陥)**: 両 task の `Current state / handoff` が「登録しただけ」のままで、実装・PR・merge の記録と食い違う → handoff を現状へ更新して閉じた(**SELF-CHECK**、記録だけの差分)。
- `950cb2c..bcb5b58` は記録だけ(attempt 1 の P2 を閉じた。SELF-CHECK)。
- **attempt 2**: `bcb5b58..47d0b40`(差分review。実機確認1回目の下線の指摘の修正) — **PASS**(指摘なし)。reviewerは`gpt-6-luna`。確認された点: 行の警告と件数表示の「詳細」が同じ引き方・太さ・色、行の高さ・文字倍率・baseline への影響が test に入っている、M622・M623・M633 KILLED(M570 は範囲付きで SURVIVED、全件で KILLED)、manual 2回目の build の見分け方が一致。`flutter test` 1164 PASS、analyze・format PASS。
- 連鎖: `441acdf..950cb2c` PASS → `950cb2c..bcb5b58` SELF-CHECK → `bcb5b58..47d0b40` PASS → 以後の記録だけの差分は SELF-CHECK。

## Current state / handoff

- Last checkpoint: 実機確認1回目(動作OK・下線の指摘)を受けて下線の引き方を直した(`a1e173a`)。差分review attempt 2(`bcb5b58..47d0b40`)PASS
- Blocker category: human verification
- Waiting for: 開発者による実機確認2回目(`/workspace/.worktrees/008-T50-row-warning-retune/specs/008-ui-alignment/tasks/T50-row-warning-retune/manual-verification.md` の 0〜6。Android エミュレータと Windows desktop。`T50`・`T52` 共通)
- Requested action: worktree の HEAD から build し(`lib/` は `a1e173a` と同一)、0〜6 を確かめて結果を会話で伝える
- Evidence revision: `a1e173a`(`lib/`)
- Next Agent action: 結果を両 task の「実機確認 2回目」節へ記録する → 指摘があれば直して差分review(range は `47d0b40` 以降)→ 確認をやり直す。OK なら両方 done にし、PR #208 を ready → CI → merge commit で merge、`dev` で `workspace.py check specs`、T50・T52 の worktree と branch を片付ける。あわせて、命名ルール設定buttonに警告を出す案(推奨案4)を開発者に尋ねる
