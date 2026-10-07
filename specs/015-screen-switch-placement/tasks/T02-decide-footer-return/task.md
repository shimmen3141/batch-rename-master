# T02 footer の「← リネーム画面へ」を残すか外すかを決めて反映する

## 目的

`T01` で上部に「リネーム画面へ戻る」を足した後、**footer 左下の「← リネーム画面へ」を残すか外すか**を開発者が決め、その形にする。外すなら footer は「確定」だけになる。

## 入力と依存

- `T01`(帯が `dev` に入っていること。**`T01` を採らなかったら、この task は削除せず「不要」と記録して閉じる**)。
- `008:T38` の決定「画面を閉じる導線は footer 左下に一本化」(外すなら、閉じる導線は上部の帯になる。その記録を `008:T38` の状態表へ注記する — 表は書き換えない)。

## 変更範囲

- `lib/ui/file_source/storage_browser_view.dart`、`lib/ui/file_source/media_picker_view.dart`、`test/`。外さないと決めたら code は変えない。

## 受け入れ条件

- [ ] 開発者が残すか外すかを決めている(`T01` の見比べのときに尋ねてよい)。
  - 証拠: この task.md と plan.md の「人間の決定」の記録。
- [ ] 外すなら: footer に「確定」だけがあり、画面を閉じるのは上部の「リネーム画面へ戻る」と Android のシステムバックになる。
  - 証拠: widget test、Android エミュレータの確認(`manual-verification.md` は外すと決まったときに書き、`task.json` に入れる)。
- [ ] 独立review が PASS(code を変えたとき)。

## machine検証範囲と引き受け先

- machine: footer の構成と、閉じる導線が残っていること。
- 端末(この task の manual): 外した後の footer の見え方。

## 作業記録

- 2026-10-06 plan 015 の作成で足した。`manual-verification.md` は外すと決まったときに書く。

- 2026-10-07 **不要として閉じた。** `T01` を採らないため(この task の「入力と依存」の取り決め)。一度は外すと決め、PR #229 の branch で `1676715` として外したが、帯ごと採らないことになり merge しない。footer 左下の button は**残し、文言を「キャンセル」にする**(`T03`)。

## Current state / handoff

- Last checkpoint: 完了(不要。2026-10-07)
- Blocker category: なし
- Evidence revision: なし
- Next Agent action: なし(不要として閉じた)
