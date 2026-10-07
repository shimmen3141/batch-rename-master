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
- 2026-10-07 開発者が `T01` の見比べ attempt 1 で**外す**と決めた(「上部へ移すのが目的なので、footer は確定ボタンのみに」。plan.md の「人間の決定」)。**`T01` の採否が決まる前に、同じ branch・PR #229 で着手した** — 帯と footer を一緒に見て採否を決めたいという開発者の求めによる。依存(`T01` が `dev` に入っていること)を満たす前の着手であり、`T01` を採らないなら、この task の commit も同じ PR ごと merge しない。
- 実装 `1676715`。

### 作ったもの

- [/workspace/lib/ui/file_source/storage_browser_view.dart](/workspace/lib/ui/file_source/storage_browser_view.dart)・[/workspace/lib/ui/file_source/media_picker_view.dart](/workspace/lib/ui/file_source/media_picker_view.dart): footer から「← リネーム画面へ」を外し、「確定」を右寄せにした。`browserBackToRenameKey`・`mediaPickerBackKey` は消した。閉じるのは帯の「リネーム画面へ戻る」と Android のシステムバック(システムバックの test はそのまま PASS)。
- test: footer の button が「確定」だけであること(2画面)。footer の button を使っていた test(閉じると決定していない・semantics の操作名・空の folder の文言の中央・狭い幅で文言が切れない)は、帯の button を使うよう直した。期待値は緩めていない — 狭い幅の test は文字倍率 1.3 を足して強めた。
- `008:T38` の状態表へ注記した(表は書き換えない)。

### mutation

- 足した: M792・M793(footer に戻る button を戻すと落ちる)。結果は `T01` の task.md の「検証(`1676715`)」(9件 KILLED)。
- **外した: M423**(「footer で『確定』との間に `Spacer` を戻す — 『リネーム画面へ』が半分の幅になり文言が切れる」)。守る対象の footer の button が無くなり、`find` が一致しなくなった。帯の button の文言が切れないことは、狭い幅の test が見ている。

### 検証(`1676715`)

- `T01` の task.md の「検証(`1676715`)」と同じ(同じ head)。`flutter test` PASS(+1385)、`flutter analyze` No issues、`dart format` PASS、`check_mutation_finds.py` PASS(729)。
- **未実施**: Android の build(AI container に Android SDK が無い)。独立review は `T01` と同じ範囲で、見比べ attempt 2 の後に行う。

## Current state / handoff

- Last checkpoint: implementation(`1676715`)
- Blocker category: manual-evidence
- Evidence revision: `1676715`
- Waiting for: 開発者(`T01` と一緒のエミュレータ確認。[manual-verification.md](manual-verification.md))
- Requested action: `T01` の [manual-verification.md](../T01-top-return-band/manual-verification.md) の attempt 2 の手順で、footer が「確定」だけであることと、帯・システムバックで戻れることを確かめ、採否を会話で伝える
- Next Agent action: 結果を記録する。`T01` と同じ扱い(採るなら差分 review → PR ready、採らないなら merge しない)
