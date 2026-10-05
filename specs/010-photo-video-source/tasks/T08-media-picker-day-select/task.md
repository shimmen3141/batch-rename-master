# T08 「写真・動画」の選択画面で見出しを押してその日をまとめて選ぶ

## 目的

撮影日の見出しを押すと、その日の item(今の絞り込みで並んでいるもの)をまとめて選び、すべて選択済みならまとめて解除する(開発者の要望。2026-10-05)。

## 入力と依存

- 004 REQ-023 の見出しの部分。代表例 58・59。
- plan.md の決定「日のまとめ選択の task」: `T07` と分けた。小さければ `T07` と同じ PR にまとめてよい。

## 変更範囲

- `lib/ui/file_source/`(選択画面)、`test/`。

## 受け入れ条件

- [ ] 見出しを押すと、その日の今の絞り込みで並んでいる item をまとめて選ぶ。すべて選択済みならまとめて解除する(代表例 58・59)。
  - 証拠: widget test、端末の manual。
- [ ] 見出しが、その日が選ばれているかを示す。
- [ ] 独立review が PASS。

## machine検証範囲と引き受け先

- machine: まとめて選ぶ・外すの規則、絞り込みとの関係。
- 端末(この task の manual): 押しやすさと示し方。

## 作業記録

- 2026-10-05 `T05` が spec(004 REQ-011・012・016・021〜024)の承認を受けて足した。
- 端末の manual が要る。`manual-verification.md` は実装のときに書き、`task.json` の `manualVerification` に入れる。

## Current state / handoff

- Last checkpoint: 未着手
- Blocker category: なし
- Evidence revision: なし
- Next Agent action: 着手時に `in_progress` へ変え、branch を作る
