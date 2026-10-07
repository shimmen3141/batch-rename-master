# T04 browser と写真・動画の選択画面を下からせり上げて開き、閉じると下へ下げる

## 目的

リネーム画面から開く選択画面(Android の app 内 browser・写真・動画の選択画面)を、**下からせり上がって開き、閉じると下へ下がる**動きにする。別の画面へ移るのではなく、リネーム画面の上に一時的に重なり「確定」か「キャンセル」で元へ戻る画面だと、動きで分かるようにする。`T03` の「キャンセル」と対になる。

2026-10-07 の開発者の決定(plan.md の「人間の決定」、案A)。

## 入力と依存

- plan.md の「人間の決定」(2026-10-07 の案A)。
- `T03`(footer の「キャンセル」。同じ PR #230 に入れ、エミュレータの確認を1回にまとめる)。
- 004 REQ-008(閉じると「決定していない」)。**閉じたときの意味は変えない。**

## 変更範囲

- `lib/ui/file_source/modal_screen_route.dart`(新設)、`lib/main.dart`(選択画面を開く3か所: browser・開き直し・写真・動画)、`test/spec_004_file_source/modal_screen_route_test.dart`、`tool/mutations.json`。
- 触れない: 2つの画面の中身(header・footer・一覧)、browser の中で folder を移る動き(route ではない)、写真・動画の選択画面のアルバムのボトムシート、閉じたときの結果。

## 形(案A)

- 画面は**全画面のまま**。一部だけを覆うボトムシートや、下へ払って閉じる操作は入れない(一覧のスクロール・なぞって選ぶ操作と重なり、選んだものを誤って捨てうる。アルバムのシートと重なる。一覧が狭くなる)。
- 開く: 下からせり上がる(300ms、`Curves.easeOutCubic`)。閉じる: 同じ curve を逆に辿って下へ下がる(250ms)。「キャンセル」「確定」・Android のシステムバックのどれで閉じても同じ。
- 下のリネーム画面は動かさない(`fullscreenDialog: true` で、下の `MaterialPageRoute` の退場の動きを止める。2つの画面とも `automaticallyImplyLeading: false` なので header に × は出ない)。
- 端末で「アニメーションを削除」が有効なら、動かさずに出し入れする。
- 退けた案(plan.md): 上の端にリネーム画面を少し見せて角を丸める(案B)。

## 受け入れ条件

- [x] 選択画面は下からせり上がって開き、閉じると下へ下がる。途中も全画面の大きさで、横には動かない。リネーム画面は動かない。閉じたときの結果はそのまま返る。
  - 証拠: widget test(`modal_screen_route_test.dart`)。mutation M798・M799・M801。
- [x] 「アニメーションを削除」が有効なら動かさない。
  - 証拠: widget test。mutation M800。
- [x] browser・開き直し・写真・動画の3か所すべてがこの開き方を使う。
  - 証拠: `lib/main.dart` の source を見る test(main.dart の結線は実際の platform を使うので widget test で開けない)。mutation M802。
- [x] Android エミュレータで、開く・「キャンセル」・「確定」・システムバックの動きが自然に見える。
  - 証拠: [`T03` の manual-verification.md](../T03-footer-cancel-label/manual-verification.md)(同じ build で1回にまとめる)。
- [ ] 独立review が PASS。

## machine検証範囲と引き受け先

- machine: 動きの向き・長さ・下の画面が動かないこと・アニメーションを削除したとき・3か所の結線。
- 端末(この task の manual): 実際の動きの自然さ。Android 14 以降の「予測型戻る」の動きは、manifest で `android:enableOnBackInvokedCallback` を有効にしていないので対象外(システムバックは通常の閉じる動きになる)。

## 作業記録

- 2026-10-07 開発者が案Aを選び(`T03` の実機確認 attempt 1 の後)、足して着手した(branch は `T03` と同じ `asdd/015-screen-switch-placement/T03-footer-cancel-label`、PR #230)。実装 `22ee3d6`。

### 検証(`22ee3d6`)

- `flutter test`: PASS(+1385)。related `flutter test test/spec_004_file_source/modal_screen_route_test.dart`: PASS(+5)。`flutter analyze`: No issues。`dart format --output=none --set-exit-if-changed .`: PASS。`check_mutation_finds.py`: PASS(730)。

```text
command: flutter test test/spec_004_file_source
M798 | KILLED
M799 | KILLED
M800 | KILLED
M801 | KILLED
M802 | KILLED
5 mutations: 5 KILLED, 0 SURVIVED, 0 SKIPPED
```

- **未実施**: Android の build(AI container に Android SDK が無い)。

### 独立review

- 未実施(`T03` の差分と合わせ、`31fa269..` を ready 化の前に行う)。

### 実機確認

- Attempt 1(`T03` の attempt 2 と同じ確認。build: branch HEAD `5618d53`。`lib/` は `22ee3d6` と同一、2026-10-07): **PASS**。開発者が [manual-verification.md](../T03-footer-cancel-label/manual-verification.md) の確認事項(下からせり上がって開く・後ろが動かない、footer の2つが同じ幅で隙間が無い、フォルダ移動は今までどおり、キャンセル・確定・システムバックで下へ下がって戻る、写真・動画も同じ)を行い「問題ありませんでした」。

## Current state / handoff

- Last checkpoint: evidence(実機確認 attempt 1 PASS。`5618d53`)
- Blocker category: なし
- Evidence revision: `22ee3d6`
- Next Agent action: `31fa269..head` の差分review(`T03` と合わせて1回)。PASS なら PR #230 を ready にし、merge して plan 015 の完了 review へ進む
