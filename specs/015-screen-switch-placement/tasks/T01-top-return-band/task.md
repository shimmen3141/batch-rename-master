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
- 2026-10-06 着手(branch `asdd/015-screen-switch-placement/T01-top-return-band`、base `7f14151`)。 実装 `f302e35`。

### 作ったもの

- [/workspace/lib/ui/file_source/return_band.dart](/workspace/lib/ui/file_source/return_band.dart): header の上に帯を重ねる `ReturnBandAppBar`。帯はアクセント色を薄く敷き下端にアクセント色の線を引いて header(`colors.bar`)と見分ける。左に矢印の無い「リネーム画面へ戻る」。status bar は帯が避ける(header は `primary: false`)。
- [/workspace/lib/ui/file_source/storage_browser_view.dart](/workspace/lib/ui/file_source/storage_browser_view.dart)・[/workspace/lib/ui/file_source/media_picker_view.dart](/workspace/lib/ui/file_source/media_picker_view.dart): 同じ部品で帯を足した。押すと footer と同じく `pop()`(決定していない)。header と footer は変えていない。

### 検証(`f302e35`)

- `flutter test`: PASS(+1383、exit 0)。related: `storage_browser_view_test`(帯の位置・矢印が無いこと・header の `←` が残ること・色・選択中に押して `null`・footer が残ること)、`media_picker_view_test`(同じ部品・位置・header と footer が残ること・選択中に押して `null`)。**既存の test を1件だけ直した**: 例61 の test で、帯の分だけ格子が下がり item c が footer の陰になったので、押す前に `ensureVisible` で見える所へ送った(期待値は変えていない)。`flutter analyze`: No issues。`dart format`: PASS。`check_mutation_finds.py`: PASS(726)。
- mutation(足した M785〜M789):

```text
command: flutter test test/spec_004_file_source/storage_browser_view_test.dart test/spec_004_file_source/media_picker_view_test.dart
M785 | KILLED
M786 | KILLED
M787 | KILLED
M788 | KILLED
M789 | KILLED
5 mutations: 5 KILLED, 0 SURVIVED, 0 SKIPPED
```

- **未実施**: Android の build(AI container に Android SDK が無い)。

### 独立review

- Review attempt 1: `7f14151..605dff2` — PASS — none(指摘なし)。全範囲。model: Sonnet(Agent tool の code-reviewer)。実装は Opus で、既定の「一段軽いもの」と開発者の指定(2026-10-02)のどちらとも一致する。plan の決定との一致(帯・矢印なし・header と footer の不変・同じ部品)、押すと `pop()`(決定していない)で選択中も同じこと、システムバックが変わらないこと、`ReturnBandAppBar` の高さ(Scaffold が appBar の領域へ足す status bar の分と、帯の `SafeArea` が足す分が一致する)、例61 の test の変更が assertion を緩めていないこと、手順書と見比べ用 worktree を確かめた。reviewer 自身が related(111)・`flutter test --exclude-tags tooling`(+1380。全件の +1383 との差は tooling タグの3件)・`flutter analyze`・`dart format`・`check_mutation_finds.py`(726)・M785〜M789(5 KILLED)を回し、文字倍率1.3・幅320dp で帯が溢れないことを一時 test で確かめた(表には入れていない)。

### 実機確認(見比べ)

- 対象: `lib/`・`android/` が `f302e35` と同一の build。見比べ用の今の配置は `.worktrees/015-T01-compare-dev`(`dev` の `7f14151`)。手順は [/workspace/specs/015-screen-switch-placement/tasks/T01-top-return-band/manual-verification.md](/workspace/specs/015-screen-switch-placement/tasks/T01-top-return-band/manual-verification.md)。
- attempt 1: 依頼中(2026-10-06)。

## Current state / handoff

- Last checkpoint: evidence。独立review attempt 1 PASS(`7f14151..605dff2`)
- Blocker category: manual-evidence
- Evidence revision: `f302e35`
- Waiting for: 開発者(Android エミュレータでの見比べと採否)
- Requested action: [manual-verification.md](manual-verification.md) の手順1〜4を行い、採るか・気になる点・footer の希望を会話で伝える
- Next Agent action: 結果を「実機確認(見比べ)」へ記録する。採るなら PR を ready にし merge 条件を確かめる。採らないなら PR を merge せずに閉じ、plan.md の「人間の決定」と product-map の行へ理由を残す。どちらでも見比べ用 worktree を消す
