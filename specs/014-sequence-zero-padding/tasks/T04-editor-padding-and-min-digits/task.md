# T04 連番のエディタでゼロ埋めを切り替え、ゼロ埋めでは下限未満の桁数を選べなくする

## 目的

連番のエディタ(追加・編集)でゼロ埋めの有無を選べ、ゼロ埋めでは開始・増分・一覧の件数から決まる下限未満の桁数を確定できない。件数が後から増えて下限を超えたときは、今の桁不足の警告が出て、連番を開くと直せる。

## 入力と依存

- T01で承認された003のspec(と連動する002・005の文言)。T02の`SequenceToken`。
- エディタは今は件数を知らない(003は002と独立)。件数を渡す経路はcomposition root(`lib/main.dart`)から。
- 見た目の土台は`docs/design/Bulk Renamer.html`(正本ではない)。適用範囲と離れる点は着手時にこのtask.mdへ書く。

## 変更範囲

- `lib/ui/rule_builder/`(連番のエディタ、ルールの字面)、`lib/main.dart`の配線、連番を文字で見せる所(下部バーのルールの字面など)と、そのwidget test。
- 001・007は変えない。
- **連番を文字で見せる所の追随**(`014:T02`の独立review attempt 1の観察): `token_presets.dart`の「連番(N桁)」と`rename_warning_view.dart`の連番の説明は`digits`を無条件に出す。ゼロ埋めなしでは桁数を見せない形にする。

## 受け入れ条件

- [ ] ゼロ埋めを切り替えられ、ゼロ埋めなしでは名前が数字そのまま・警告なし。ゼロ埋めでは下限未満を確定できず、下限は開始・増分・件数の変更に追随する。件数が後から増えると警告が出る。
  - 証拠: widget test(composition rootから件数が届くことを含む)、full test・analyze・format、mutation。
- [ ] Androidエミュレータで見た目と操作を確認する。
  - 証拠: [`manual-verification.md`](manual-verification.md)(実装後にcurrent revisionの文言で完成させる)。
- [ ] 独立reviewがPASS。

## 土台(`docs/design/Bulk Renamer.html`)との関係

- 適用範囲: 連番のエディタ(開始番号・桁数・増分のステッパー)。
- **離れた点**: 土台には「桁数（ゼロ埋め）」のステッパーしか無い。003 REQ-013(ゼロ埋めの切り替え)のため、開始番号と桁数のあいだに**ゼロ埋めのスイッチ**を足し、桁数の欄の名前を「桁数」にした(ゼロ埋めなしでは欄ごと出さない)。スイッチの色は`008:T43`の設定メニューに揃えた(ONは緑、OFFはグレー。開発者の要望)。下限を上回るときだけ、桁数の下に理由(「N件・開始S(・増分I)なのでM桁以上」)を出す。

## machine検証範囲と引き受け先

- **CIで閉じる**: widget test(下限の式、例13〜17、切り替え、表示の文言、`RuleBuilderWorkspace`の狭幅・広幅から件数が届くこと)とmutation。
- **このtaskのmanual(Androidエミュレータ)**: 見た目と操作、保存と復元。引き受け先のtaskは無い。

## 作業記録

実装は Claude Opus 5.5(2026-09-29)。branch `asdd/014-sequence-zero-padding/T04-editor-padding-and-min-digits`、起点`dev`@`f5e8518`。

- 件数の経路: `RuleBuilderWorkspace`(composition rootの`lib/main.dart`が`fileList`とともに組む)→ `RuleBuilderView.itemCount`(getter。エディタを開くときに読む)→ `showTokenEditor(itemCount:)`。件数は`FileListController.selectedCount`で、001 が連番の最大値に使う件数と同じ(`008:T03`以後は一覧の件数と一致)。`lib/main.dart`は変えていない。
- `lib/ui/rule_builder/token_editors.dart`: `sequenceMinDigits`(下限の式)、`_SequenceEditor`にゼロ埋めのスイッチ、下限つきの桁数、引き上げ(開いたとき・開始/増分を変えたとき・ゼロ埋めへ戻したとき。ゼロ埋めなしのあいだは触らない。下げない)。
- 連番を文字で見せる所: `token_presets.dart`「連番(ゼロ埋めなし)」、`rename_warning_view.dart`の説明「連番 ゼロ埋めなし」と下部バーのchip `[1…]`。
- test: `test/spec_003_rule_builder/sequence_zero_pad_editor_test.dart`(14件)。**実装と同じ回で書いた**(先に失敗させていない)ので、testが効いていることはmutationで確かめた(下)。
- 手順書を書く途中で、3件で3桁の下限を見るには開始番号を97回押す必要があると分かった。増分で見る形(3件・開始1・増分5 → 最大11 → 2桁)へ変え、**下限の理由の文に増分を足した**(増分が1以外のとき「N件・開始S・増分IなのでM桁以上」)。
- 検証(code `0c6f86e`): `flutter test` 1046件PASS、`flutter analyze`・`dart format` PASS。

### mutation

`M497`〜`M509`を足した。`command`を`flutter test test/spec_003_rule_builder test/spec_005_rename_exec/bottom_bar_presentation_test.dart test/spec_005_rename_exec/warning_display_test.dart`へ絞った13件の生出力(NOTEは省いた):

```text
M497 | KILLED | lib/ui/rule_builder/token_editors.dart | exit 1
M498 | KILLED | lib/ui/rule_builder/token_editors.dart | exit 1
M499 | KILLED | lib/ui/rule_builder/token_editors.dart | exit 1
M500 | KILLED | lib/ui/rule_builder/rule_builder_workspace.dart | exit 1
M501 | KILLED | lib/ui/rule_builder/rule_builder_workspace.dart | exit 1
M502 | KILLED | lib/ui/rule_builder/token_editors.dart | exit 1
M503 | KILLED | lib/ui/rule_builder/token_editors.dart | exit 1
M504 | KILLED | lib/ui/rule_builder/token_editors.dart | exit 1
M505 | KILLED | lib/ui/rule_builder/token_editors.dart | exit 1
M506 | KILLED | lib/ui/rule_builder/token_editors.dart | exit 1
M507 | KILLED | lib/ui/rule_builder/token_editors.dart | exit 1
M508 | KILLED | lib/ui/rule_builder/token_presets.dart | exit 1
M509 | KILLED | lib/ui/file_list/rename_warning_view.dart | exit 1
13 mutations: 13 KILLED, 0 SURVIVED, 0 SKIPPED
```

## manual 1回目の結果(2026-09-29、code `0c6f86e`)

受領: 会話。開発者がAndroidエミュレータで手順書の1.〜4.を実行し「確認事項はすべて問題ありませんでした」。対象はHEAD(`lib/`は`0c6f86e`と同一。以後の差分は`tool/`と記録だけ)からのbuild。**PASS**。

- あわせて受領(原文): 「なお、連番の設定シートのUIなど、かなり改善点がありますが、これは別タスクとして設定されていますよね？」 → 専用のtaskは無かった(`008:T14`はtokenのエディタの**形**(sheetかdialogか)だけを扱い、中身は`T05`/`T06`(done)へ送ると書いている。`008:T10`は画面全体の余白・typography)。**`008:T44`として登録した**。このtaskの受け入れ(003 REQ-013/014)とは別の、見た目と操作の改善である。

## 独立review

既定のreviewerは`gpt-6-luna`(開発者指定)。UIの入力範囲で、判定・contract・データ保護には触れないが、開発者の指定に従う。

- attempt 1: `f5e8518..f6cde93`(全範囲、implementation) — **PASS**(指摘なし)。reviewerのmodelは`gpt-6-luna`。確認された点: 下限の式と引き上げの契機・下げないこと・ゼロ埋めなしでは触らないこと、確定まで`tokens`を変えないこと、追加でも同じ下限、`main.dart` → `RuleBuilderWorkspace`の狭幅・広幅の両方で`selectedCount`が届くこと(`RuleBuilderView`を直接組むのはtestだけ)、`selectedCount`が003の「一覧の件数」と001の数え方に食い違わないこと、ゼロ埋めなしの表示、`lib/`に未追随の`digits`表示が無いこと、手順書の数値と文言。full test 1046件・format・analyze・`check specs`・`git diff --check` PASS。範囲付きmutation `M497`・`M500`・`M501`・`M504` KILLED。reviewerの対照`RV-T04-1`は、最初の案が等価(SURVIVED)で、差し替えた案がKILLED。両方を`M510`(KILLED)・`M511`(等価の対照。SURVIVEDが期待値)として取り込んだ。
  - 以後はmutation表への取り込みと記録だけ(SELF-CHECK)。

- attempt 2: `f6cde93..8f21a23`(差分、final-evidence) — **PASS**(指摘なし)。reviewerのmodelは`gpt-6-luna`。`0c6f86e..8f21a23`に`lib/`・`hook/`・`src/`・依存・build設定の差分が無くmanual証拠のidentityを保つこと、manualの記録と手順書の被覆、`M510`・`M511`の定義と期待値、`008:T44`の登録と境界の記述を確認された。full test 1046件・format・analyze・`check specs`(102 tasks)・`git diff --check` PASS。
  - 連鎖: `f5e8518..f6cde93` PASS → `f6cde93..8f21a23` PASS → 以後は記録だけ(SELF-CHECK)。

## Current state / handoff

- Last checkpoint: PR #198をmerge commitで`dev`へmerge(2026-09-29、`deeb85a`)。merge条件1〜7を確認した: Draftでない・一意 / 独立reviewの連鎖(`f5e8518..f6cde93` PASS → `f6cde93..8f21a23` PASS → 以後は記録だけのSELF-CHECK) / CI `check` PASS・未解決threadなし / `dev`を取り込み済みで最新・競合なし、full test 1046件PASS / manual 1回目が`0c6f86e`に対応し、以後code・依存・build設定の差分なし / 未解決P0/P1なし / `.github/workflows`・AGENTS.md・sandbox境界の変更なし。
- Blocker category: none
- Evidence revision: code `0c6f86e`、merge `deeb85a`。
- Next Agent action: なし(done)。エディタの見た目と操作は`008:T44`。
