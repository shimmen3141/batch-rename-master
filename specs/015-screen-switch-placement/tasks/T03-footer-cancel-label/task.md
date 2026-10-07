# T03 footer 左下の「← リネーム画面へ」を矢印なしの「キャンセル」にする

## 目的

Android の app 内 browser と写真・動画の選択画面で、footer 左下の「← リネーム画面へ」を**矢印の無い「キャンセル」**にする。置き場所・形(暗い地にシアンの枠と文字)・押したときの意味(選択を捨てて戻る = 決定していない)は変えない。右下の「確定」と対になり、「この選択をやめる」操作として読めるようにする。

2026-10-07 の開発者の決定(plan.md の「人間の決定」)。上部の帯(`T01`)を採らない代わりの task である。

## 入力と依存

- plan.md の「人間の決定」(2026-10-07 の方針の見直し)。
- `008:T38` の操作状態表(画面を閉じる導線は footer 左下に一本化)。**意味は変えず、文言だけを変える。**
- 004 REQ-001・REQ-008(閉じると「決定していない」)。
- 依存なし(`dev` の `7f14151` から始める)。

## 変更範囲

- `lib/ui/file_source/storage_browser_view.dart`・`lib/ui/file_source/media_picker_view.dart`(footer の button)、`lib/ui/file_list/file_list_view.dart`(コメントだけ)、`test/spec_004_file_source/`、`tool/mutations.json`。
- 触れない: header、footer の配置と「確定」、Android のシステムバック、戻ったときの意味。

## 受け入れ条件

- [x] 2つの画面の footer 左下が「キャンセル」で、矢印が付かない。形と位置は今のまま。
  - 証拠: widget test(browser の状態表の全行で文言、狭い幅・文字倍率1.3で切れず矢印が無いこと、選択画面の文言と矢印が無いこと)。mutation M794・M795。
- [x] 押すと選択を捨てて戻り、一覧は変わらない(今までと同じ)。
  - 証拠: 既存の widget test(閉じると `null`)が key を変えずに PASS。
- [ ] Android エミュレータで、2つの画面の footer が「キャンセル」「確定」に見え、押して戻れる。
  - 証拠: [manual-verification.md](manual-verification.md) の結果。
- [ ] 独立review が PASS。

## machine検証範囲と引き受け先

- machine: 文言・矢印が無いこと・文言が切れないこと・押したときの結果。
- 端末(この task の manual): 実際の見え方。

## 作業記録

- 2026-10-07 plan 015 の方針変更で足し、着手した(branch `asdd/015-screen-switch-placement/T03-footer-cancel-label`、base `7f14151`)。実装 `e1c56ab`。
- 文言は browser 側の定数 `browserCancelLabel` に置いた。選択画面は browser を import しないので同じ文言を直接書き、M795 で2つが食い違わないことを見ている。key(`browser-cancel`・`media-picker-back`)は変えていない。
- test の変更: footer の文言を見ていた3か所(状態表・semantics の操作名・狭い幅)を「キャンセル」に直し、狭い幅の test には文字倍率1.3と「矢印が無いこと」を足した(強めた)。選択画面に文言と矢印の test を1件足した。

### 検証(`e1c56ab`)

- `flutter test`: PASS(+1378、exit 0)。related `flutter test test/spec_004_file_source`: PASS(+370)。`flutter analyze`: No issues。`dart format --output=none --set-exit-if-changed .`: PASS。`check_mutation_finds.py`: PASS(723)。
- mutation(足した M794・M795 と、footer の幅を守る既存の M423):

```text
command: flutter test test/spec_004_file_source/storage_browser_view_test.dart test/spec_004_file_source/media_picker_view_test.dart
M423 | KILLED
M794 | KILLED
M795 | KILLED
3 mutations: 3 KILLED, 0 SURVIVED, 0 SKIPPED
```

- **未実施**: Android の build(AI container に Android SDK が無い)。

### 独立review

- Review attempt 1: `7f14151..31fa269` — **PASS** — none(指摘なし)。全範囲。model: Sonnet 5(Agent tool の code-reviewer)。実装は Opus 5.5 で、既定の「一段軽いもの」と開発者の指定(2026-10-02)のどちらとも一致する。決定との一致(矢印を外し文言だけ変え、key・形・`pop()` で決定していないこと・システムバックは不変)、test が緩んでいないこと、記録の相互整合を確かめた。reviewer 自身が related(+370)・`flutter test --exclude-tags tooling`(+1378)・`flutter analyze`・`dart format`・`check_mutation_finds.py`(723)・M423/M794/M795(3 KILLED)・`workspace.py check`(PASS)を回した。

### 実機確認

- Attempt 1(`e1c56ab`、2026-10-07): **動作は PASS**(手順2・3で戻り方は期待どおり)。**見た目に直しが要る**: 「キャンセル」と「確定」の間に不自然な隙間がある → 2つを横に伸ばす。あわせて開発者から、選択画面をモーダルらしく見せるため下から出て下へ戻るアニメーションの案が出た(採るかは開発者の判断待ち。決まるまでこの task の範囲に入れない)。
- 直し `01814c5`: 2つの button を `Expanded` にし、footer の余白12と間8を除いた幅を半分ずつ使う(browser・選択画面とも)。test: 2つの画面それぞれで「左右の端が余白だけ・間が8・同じ幅」を見る test を足した。M423 の `find` を新しい形へ追随させ、M796(browser の「確定」を伸ばさない)・M797(選択画面の「キャンセル」を伸ばさない)を足した。

### 検証(`01814c5`)

- `flutter test`: PASS(+1380)。related `flutter test test/spec_004_file_source`: PASS(+372)。`flutter analyze`: No issues。`dart format`: PASS。`check_mutation_finds.py`: PASS(725)。

```text
command: flutter test test/spec_004_file_source
M423 | KILLED
M794 | KILLED
M795 | KILLED
M796 | KILLED
M797 | KILLED
5 mutations: 5 KILLED, 0 SURVIVED, 0 SKIPPED
```

## Current state / handoff

- Last checkpoint: implementation(実機確認 attempt 1 の直し `01814c5`)。独立review attempt 1 PASS(`7f14151..31fa269`)、Draft PR #230
- Blocker category: manual-evidence / human-decision
- Evidence revision: `01814c5`
- Waiting for: 開発者(アニメーション案を採るかの判断と、Android エミュレータの再確認)
- Requested action: アニメーション案への回答。[manual-verification.md](manual-verification.md) の手順1〜4を `01814c5` で行い、結果を会話で伝える
- Review pending: `31fa269..` の差分review(`lib/`・`test/`・`tool/` に差分があるため。ready 化の前に行う)
- Next Agent action: 結果を「実機確認」へ記録する。PASS なら PR #230 を ready にし、CI と merge 条件を確かめて merge する。plan 015 の全 task が閉じるので、plan 完了の review へ進む。直しが要れば直して再確認を頼む
