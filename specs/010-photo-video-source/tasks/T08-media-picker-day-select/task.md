# T08 「写真・動画」の選択画面で見出しを押してその日をまとめて選ぶ

## 目的

撮影日の見出しを押すと、その日の item(今の絞り込みで並んでいるもの)をまとめて選び、すべて選択済みならまとめて解除する(開発者の要望。2026-10-05)。

## 入力と依存

- 004 REQ-023 の見出しの部分。代表例 58・59。
- plan.md の決定「日のまとめ選択の task」: `T07` と分けた。小さければ `T07` と同じ PR にまとめてよい。
- **`T11` の後に行う**(2026-10-05 の決定)。「その日」は見出しの日付で、`T11` が見出しの日付の決め方を変える(`DATE_TAKEN` が無い item は中身の日時)。

## 変更範囲

- `lib/ui/file_source/`(選択画面)、`test/`。

## 受け入れ条件

- [x] 見出しを押すと、その日の今の絞り込みで並んでいる item をまとめて選ぶ。すべて選択済みならまとめて解除する(代表例 58・59)。
  - 証拠: widget test、端末の manual。
- [x] 見出しが、その日が選ばれているかを示す。
- [x] 独立review が PASS(attempt 1)。
- [x] 端末の manual が PASS(attempt 1、2026-10-06)。

## machine検証範囲と引き受け先

- machine: まとめて選ぶ・外すの規則、絞り込みとの関係。
- 端末(この task の manual): 押しやすさと示し方。

## 作業記録

- 2026-10-05 `T05` が spec(004 REQ-011・012・016・021〜024)の承認を受けて足した。
- 端末の manual が要る。`manual-verification.md` は実装のときに書き、`task.json` の `manualVerification` に入れる。

- 2026-10-05 着手(branch `asdd/010-photo-video-source/T08-media-picker-day-select`、base `0976eb5`)。実装 `ea8be91`。

### 作ったもの

- [/workspace/lib/ui/file_source/media_picker_view.dart](/workspace/lib/ui/file_source/media_picker_view.dart): 日付の見出しを押せるようにした(`_dayHeader`・`_toggleDay`)。その日の item(今の絞り込みで並んでいるもの)が**すべて選ばれていれば外し、そうでなければ選ぶ**。**見えていない同じ日の選択には触れない**(見出しの1押しで見えないものを外すと、何が外れたか分からない)。
- 見出しの右端に、その日がすべて選ばれているかを示す丸い印(item と同じ `SelectionCheckbox`。押下は見出し全体で受ける)。一部だけ選ばれている日は印を付けない(3つ目の状態は作らない)。支援技術には button と、押すと何が起きるかの hint を渡す。
- 同じ PR で、`specs/product-map.md` の将来候補に「画面を切り替えるbuttonの位置を揃える」を足した(`T11` の実機確認での開発者の指摘と決定: 案A、010 の残りの後)。

### 検証(`ea8be91`)

- `flutter test`: PASS(+1348、exit 0)。related: `media_picker_view_test` PASS(+26。代表例 58・59、絞り込みとの関係、「日付不明」の見出しの4件を追加)。`flutter analyze`: No issues。`dart format`: PASS。`check_mutation_finds.py`: PASS(702)。
- mutation(範囲 `flutter test test/spec_004_file_source/media_picker_view_test.dart`。M761〜M764 を足した。**M757 は `T11` で等価として外した番号なので使い回さない**):

```text
M761 | KILLED | 010:T08 一部だけ選んだ日の見出しで、まとめて外す
M762 | KILLED | 010:T08 見出しで外すと、見えていない選択も外す
M763 | KILLED | 010:T08 一部だけ選んだ日にも見出しの印を付ける
M764 | KILLED | 010:T08 見出しで、その日ではなく並んでいる全件を選ぶ
4 mutations: 4 KILLED, 0 SURVIVED, 0 SKIPPED
```

- **未実施**: Android の build(AI container に Android SDK が無い)。

### 独立review

- attempt 1: range `0976eb5..329a8ec`(全範囲。product-map の1行を含む)。model: Sonnet(Agent tool の code-reviewer)。実装は Opus で、既定の「一段軽いもの」と開発者の指定(2026-10-02)のどちらとも一致する。**判定 PASS、指摘なし。** REQ-023・代表例 58・59 への適合(対象は今の絞り込みで並ぶその日の item だけ、見えていない選択に触れない)、印の判定、drag との干渉が無いこと(`_dragSelection.finish()`)、「日付不明」、支援技術への見せ方、記録と手順書と product-map の行の整合を確かめた。reviewer 自身が related test(+26)・`flutter analyze`・`dart format`・`check_mutation_finds.py`(702)・M761〜M764(4 KILLED)を回した。

### 実機確認

- 対象: `lib/`・`android/` が `ea8be91` と同一の build。手順は [/workspace/specs/010-photo-video-source/tasks/T08-media-picker-day-select/manual-verification.md](/workspace/specs/010-photo-video-source/tasks/T08-media-picker-day-select/manual-verification.md)。
- attempt 1(2026-10-06、build は `ea8be91` と同じ `lib/`・`android/`): **PASS。** 開発者の報告「確認事項について、問題ありませんでした」。手順1〜4(見出しでまとめて選ぶ・外す、一部だけ選んだ日はすべて選ぶ、絞り込み中は見えていない動画を外さず印も付かない、2008年5月30日(金)の見出し、範囲選択・ⓘ・確定)がすべて期待どおり。押しやすさ・印の見え方への指摘なし。

## Current state / handoff

- Last checkpoint: handoff。独立review attempt 1 PASS(`0976eb5..329a8ec`)、以後は記録だけ(SELF-CHECK)、実機確認 attempt 1 PASS。done
- Blocker category: なし
- Evidence revision: `ea8be91`
- Next Agent action: なし(PR を作り、CI の PASS と merge 条件を確かめて merge する)
