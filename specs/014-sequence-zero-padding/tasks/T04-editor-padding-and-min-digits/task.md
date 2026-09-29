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

## 受け入れ条件

- [ ] ゼロ埋めを切り替えられ、ゼロ埋めなしでは名前が数字そのまま・警告なし。ゼロ埋めでは下限未満を確定できず、下限は開始・増分・件数の変更に追随する。件数が後から増えると警告が出る。
  - 証拠: widget test(composition rootから件数が届くことを含む)、full test・analyze・format、mutation。
- [ ] Androidエミュレータで見た目と操作を確認する。
  - 証拠: [`manual-verification.md`](manual-verification.md)(実装後にcurrent revisionの文言で完成させる)。
- [ ] 独立reviewがPASS。

## Current state / handoff

- Last checkpoint: 未着手
- Blocker category: none
- Evidence revision: none
- Next Agent action: T02のmerge後、エディタへ件数を渡す経路を決め、失敗するwidget testから書く
