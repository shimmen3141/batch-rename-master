# T34 吹き出しの位置・文言・配色・時間を詰める

## 目的

`T30` で入れた「外すアイコンへ重ねる補足」を、2回目の実機確認で受領した5点で詰める。
**`T30` の欠陥ではない** — 手順1〜5の確認事項はすべて成立した上での調整である。

## 受領した要望(2026-09-19、原文)

> 吹き出しは、ツノがアイコンの中央からすこしだけ右にずれているので、やや左にずらしたい。吹き出し自体ももう少し下にずらせる。また、文言を「押すとファイルをリネームリストから外します。削除はされません。」(改行なし)にしたほうがわかりやすそうです。また、フェードまでの時間を5秒に延長し、色の主張が強すぎるので枠だけシアンで中は黒にしたいです(ツノと長方形の境界線が見えないように)。

## 変更範囲

すべて [`lib/ui/file_list/removal_hint.dart`](../../../../lib/ui/file_list/removal_hint.dart) の中で閉じる。

1. **ツノを少し左へ。** いまは `removalHintTailInsetFromRight`(= `headerMenuExtent` +
   `headerIconExtent` / 2)で**アイコンの中心に一致させている**(widget test が実測で固定)。
   実機では少し右に見えるとのことなので、**見た目の中心とアイコンの中心がずれている**
   ことになる。原因を確かめてから動かす(`Icons.playlist_remove` の字面が枠の中で
   左寄りである可能性が高い)。**test の期待値も一緒に動かす**(いまは「ツノの中心 ==
   アイコンの中心」を厳密に見ているので、ずらすなら意図した差として書く)。
2. **吹き出し全体をもう少し下へ。** `_build` の `offset` の `dy`(いまは `-2`)。
3. **文言を明示改行なしへ。** 「押すとファイルをリネームリストから外します。削除はされません。」とし、**「削除はされません」は落とさない**(005 / 013 の境界。対照 M353)。後続のmanual確認で「改行なし」は自然な折り返しを禁止しない意味だと明確になったため、約16文字幅で通常倍率では自然に2行へ収める。removalHintMaxWidthと「画面に収まるか」の判定(_showIfItFits)への影響を測り直す。
4. **表示開始から完全に消えるまでを7秒へ。**
5. **配色を「枠だけシアン・中は黒」へ。** いまは面も枠もツノも `primary` 一色。
   **ツノと箱の継ぎ目に線を出さない**という要求は変わらない(対照 `M367`)ので、
   ツノにも同じ塗り(`background` 相当)と**外側の2辺だけに枠線**が要る。
   箱の下辺のうちツノが接する部分は枠線を描かない、という描き方になる
   (`CustomPainter` で箱ごと描くのが素直かもしれない)。

## 気をつけること

- **`T30` が閉じた保証を戻さない。** 収まらないときは出さない / 出ているときは画面の中に
  ある / 閉じる操作が押せる / 飾りは pointer を取らない / 読み上げから文言が消えない。
  **文言を約16文字幅で自然に折り返すと箱の形が変わる**ので、`test/spec_002_file_list/removal_hint_test.dart`
  の格子を回し直す。
- **画面サイズを変える test は `tester.view.physicalSize` を使う**
  (`tester.binding.setSurfaceSize` は `MediaQuery.size` を動かさない。
  [finding](../../../../development-findings/2026-09-19-set-surface-size-does-not-move-media-query.md))。
- 対照 `M352`(ツノの位置)・`M353`(文言)・`M367`(枠線)・`M363`(幅)は**動かす対象なので
  再アンカーが要る**。

## 受け入れ証拠

- ツノの位置・文言・白文字・自然な2行表示・7秒の時間・配色が要望どおりであることを widget test で固定する。
- `T30` の格子(幅 × 文字倍率)を回し直して、**出る/出ないの境目**を記録し直す。
- `flutter test` / `flutter analyze` / `dart format` / `mutation_check.py` が PASS。
- Android実機での manual 確認(`manual-verification.md` を作る)。**`T32` の確認は要らない**
  (触らないため)。

## manual確認からの修正(2026-09-20)

- 黒地の上で文字が読めなかった。原因は、`CustomPainter`を前面に置いたため塗りが文字を
  覆っていたことである。painterを背面へ移し、文字を白へ固定する。
- 「改行なし」は文と文の間へ明示的な改行を入れない意味であり、自然な折り返しは許容する。
  約16文字幅へ収め、通常倍率では2行にする。
- 表示開始から完全に消えるまでを7秒にする。フェード自体は400msなので、6.6秒表示してから
  フェードを始める。

## 実装と機械検証(2026-09-20)

- ツノは、40dpのアイコン枠の幾何学的中心から字面に合わせて3dp左へ補正した。吹き出しは4dp下へ寄せ、文言を明示改行なしの「押すとファイルをリネームリストから外します。削除はされません。」へ替えた。幅を180dp(約16文字)にし、通常倍率で自然に2行になることをtestで確認する。
- 文字は白で、黒地とシアンの連続外枠は子widgetの背面で一つのCustomPainterが描く。表示開始から6.6秒後に400msのフェードを開始し、開始から完全に消えるまでを7秒にした。
- flutter test test/spec_002_file_list/removal_hint_test.dart — PASS (13 tests)
- flutter test test/spec_002_file_list test/spec_004_file_source — PASS (333 tests)
- dart format --output=none --set-exit-if-changed . — PASS (131 files)
- flutter analyze — PASS (No issues found)
- flutter test — PASS (938 tests)
- Android SDKが無いため、buildと実機確認はmachineでは未実施。

### mutation の生出力

mutation_check.pyを、対応するtest名だけへ絞った作業用表で実行した。

    command: flutter test test/spec_002_file_list/removal_hint_test.dart
    M363 | KILLED | lib/ui/file_list/removal_hint.dart | 008:T34 吹き出しの幅を2倍にする — 16文字前後の自然な2行折り返しと画面内への収まりを崩す | exit 1
    M365 | KILLED | lib/ui/file_list/removal_hint.dart | 008:T34 表示開始から7秒で消えない — 補足が画面に残り続ける | exit 1
    M367 | KILLED | lib/ui/file_list/removal_hint.dart | 008:T34 シアンの一体枠を消す — 黒い面とツノの外形が読めず、継ぎ目なしの吹き出しにならない | exit 1
    M389 | KILLED | lib/ui/file_list/removal_hint.dart | 008:T34 黒地の文字を黒へ替える — 背景と同化して説明が読めなくなる | exit 1
    4 mutations: 4 KILLED, 0 SURVIVED, 0 SKIPPED

### review

- SELF-REVIEW ONLY: 8b0279f..b902dc0 の実装・test・mutation・task正本を照合した。成果物の欠陥は見つからなかった。実機の色、相対位置、7秒の体感は手動確認で判定する。

## Final-evidence independent review(2026-09-20)

- Scope: 008 / T34、final-evidence、f19b1651e12efa076f1b8ba65716a18d29b9ea41..4f0cb00a67b457300b5480a7babecd4ac57da975。
- Review attempt: unknown(過去の独立final-evidence attemptをtask記録から確定できない)。
- 判定: PASS。成果物の欠陥なし、安全網の穴なし、未解決P0/P1なし。T34はdoneへ進められる。
- Manual後の差分はtask記録とdevelopment findingだけで、code、dependency、build設定の変更はない。
- Reviewer model: gpt-5。実装時のmodel指定との相対既定より、実際に利用可能だったreview model名を記録する。

## Manual evidence and branch remediation(2026-09-20)

- Manual evidence: PASS — revision 70837562e6409571cd230c671db92626edaa584a、準備済みのAndroid実機またはemulator環境、2026-09-20に会話で「確認事項はすべて問題ありませんでした」と受領。manual-verification.mdの手順1〜3をすべて充足した。
- Branch deviation: T34の実装・証拠commitをintegration branchのdev上で作成していた。origin/devはf19b165のまま未変更・未pushであることを確認し、同じHEADに規定branch asdd/008-ui-alignment/T34-hint-refinementsを作成した後、local devをorigin/devへ戻した。T34のcommit rangeはf19b165..7083756として規定branchに保持している。
- 人間確認後にcode、dependency、build設定の変更はない。

## Current state / handoff

- Last checkpoint: f19b165..4f0cb00のfinal-evidence独立reviewがPASSし、manualを含む全受け入れ証拠が揃った(2026-09-20)
- Blocker category: none
- Waiting for: none
- Requested action: none
- Pull request: #178 (https://github.com/shimmen3141/batch-rename-master/pull/178)
- Touches: `lib/ui/file_list/removal_hint.dart`(必要なら `header_metrics.dart`)、
  `test/spec_002_file_list/removal_hint_test.dart`、`tool/mutations.json`(M363/M365/M367/M389 の再アンカー)
- 並行: **`T31` とは別file**(あちらは `file_list_view.dart`)なので同時に進められる。
  `header_metrics.dart` だけは `file_list_view.dart` と共有している定数なので、
  **そこを動かすなら `T31` と順番を決める**
- Evidence revision: 4f0cb00a67b457300b5480a7babecd4ac57da975
- Machine verification scope: widget testでツノの意図した視覚補正、明示改行のない文言、白文字と自然な2行表示、開始から完全消失まで7秒、黒地とシアン枠、画面内への収まり、閉じる操作、pointer透過を検証する。Android実機の見た目と操作感はmachineで閉じられないため、このtaskのmanual確認で受ける。
- Next Agent action: PR #178のrequired CI、未解決thread、devとの競合を確認し、integration gateを満たせばmergeする。
