# T01 browser と写真・動画の選択画面の最上部に「リネーム画面へ戻る」の帯を足す

## 目的

Android の app 内 browser と写真・動画の選択画面の**いちばん上に、色で見分けられる帯**を足し、その左に**「リネーム画面へ戻る」**を置く。押すと footer の「← リネーム画面へ」と同じく、選択を捨ててリネーム画面へ戻る。**footer の button はこの task では残す**(外すかは `T02`)。

開発者がエミュレータで今の配置と見比べ、**採るかどうかを決める**。採らなければ merge しない。

## 入力と依存

- plan.md の「人間の決定」(2026-10-05 案A、2026-10-06 の2件)。
- `008:T38` の操作状態表(header・現在地の帯・footer)。**header は変えない。**
- 004 REQ-008(閉じると「決定していない」)、REQ-015〜020(browser)、REQ-022〜024(選択画面)。
- 今の実装: `lib/ui/file_source/storage_browser_view.dart`(footer の `browserBackKey` 相当)、`lib/ui/file_source/media_picker_view.dart`(`mediaPickerBackKey`)、リネーム画面の帯 `lib/ui/file_source/file_source_bar.dart`(高さ・色の参照)。

## 変更範囲

- `lib/ui/file_source/`(2つの画面と、帯の共通部品)、`lib/ui/theme/`(帯の色が要るなら)、`test/`。
- 触れない: header の記号と意味、`008:T38` の状態表、リネーム画面の帯、戻ったときの意味(REQ-008)。

## 受け入れ条件

- [ ] 2つの画面のいちばん上に帯があり、左に「リネーム画面へ戻る」がある。帯は header と色で見分けられる。
  - 証拠: widget test(帯と button の位置が header より上で左寄せ、2つの画面で同じ部品)。
- [ ] 押すと選択を捨ててリネーム画面へ戻り、一覧は変わらない(footer の button・Android のシステムバックと同じ)。選択中でも押せる。
  - 証拠: widget test(browser・選択画面のそれぞれで、選択があるときに押して `null` が返る)。
- [ ] header(`←`・`×`・題名・ⓘ・ケバブ)と footer は今のまま。
  - 証拠: 既存の widget test が変更なしで PASS。
- [ ] 開発者がエミュレータで今の配置と見比べ、採るかを決めている。
  - 証拠: [manual-verification.md](manual-verification.md) の結果と決定の記録。**採らないなら PR を merge せずに閉じ、plan.md の「人間の決定」と product-map の行へ理由を残す。**
- [ ] 独立review が PASS。

## machine検証範囲と引き受け先

- machine: 帯と button の有無・位置・押したときの結果、header と footer を変えていないこと。
- 端末(この task の manual): 見た目(色の見分けやすさ、押しやすさ、縦の余白)と、今の配置との見比べ。

## 作業記録

- 2026-10-06 plan 015 の作成で足した。
- 2026-10-06 着手(branch `asdd/015-screen-switch-placement/T01-top-return-band`、base `7f14151`)。

## Current state / handoff

- Last checkpoint: 着手(base `7f14151`)
- Blocker category: なし
- Evidence revision: なし
- Next Agent action: 着手時に `in_progress` へ変え、branch を作る。手順書には今の配置(`dev`)のスクリーンショットを撮る手順も入れる
