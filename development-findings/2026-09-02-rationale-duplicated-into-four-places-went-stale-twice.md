# 変更の根拠を4か所へ複製し、2回続けて古くなった

- 観測日: 2026-09-02
- 場所: `008:T17`(005 contract revision 9.0 の作成)
- 種別: 手戻り / 検証漏れ

## 何が起きたか

005 contract を revision 9.0 へ改訂するとき、**「何をなぜ変えたか」を4か所へ散文で書いた** —
契約の `revision_history`、`task.md`、`plan.md` の決定表、PR 本文である。

独立review attempt 1 が「REQ-009 も変える必要がある」と指摘し、**REQ-009 を変えた**。
このとき4か所のうち直したのは一部で、契約の `revision_history` は**見出しの1文だけを
「REQ-009 も変えた」へ差し替え、以降の本文(「(1)は免除している」「契約で動かしたのは
実行可否だけである」)を1文字も直さなかった。** PR 本文にいたっては一度も更新していない。

attempt 2 がこれを P1-A / P1-B として挙げた。**同じ根本原因(部分編集して写しが追随しない)が
2回続いた**ことになる。あわせて 005 `spec.md` の Status 行も、1本の長い太字へ追記し続ける形の
ため、追記のたびに強調の対の位置が壊れ、attempt 1 の P2-4 と attempt 2 の P2-a で2回指摘された。

## なぜ prose の注意で止まらなかったか

- 「直す」対象が**自分の書いた散文**なので、`workspace.py check specs` も `flutter test` も
  `flutter analyze` も通る。**構造検査は「壊していない」を見るだけで、「意図した変更が入った」を
  見ない**(`AGENTS.md`)。
- このprojectは同じ型に対して既に `tool/check_normative_terms.py` を持っていた。だが
  **走査対象が `specs/**/*.md` だけ**で、`revision_history` を持つ**契約 JSON が範囲の外**だった。
  今回のP1はちょうどその外側で起きた。

## どう変えたか

1. **根拠の正本を1か所に絞った。** 契約の `revision_history` の revision 9.0 が正本で、
   `task.md` と `plan.md` と PR 本文は**指すだけ**にした。`task.md` にはこのtaskに固有の事実
   (指摘で足した経緯、承認を2回取ったこと)だけを残した。
2. **`check_normative_terms.py` の走査を `specs/**/contracts/*.json` へ広げた。**
   差し替えた言い回し3件(「契約で動かしたのは実行可否だけである」「REQ-009 は変えていない」
   「8.0 までは実行へ入って全件が除外されていた」)を `forbidden` へ登録した。
3. **005 `spec.md` の Status 行を、追記で伸びる1本の太字から、契約を指す短い記述へ作り替えた。**
   revision ごとの意味をここへ複製しないことを本文に明記した。

## forward-test

走査を広げ、差し替えた言い回しを`forbidden`へ登録した直後に検査を走らせたところ、**手作業では見落としていた3か所を即座に検出した**。

```console
$ python3 tool/check_normative_terms.py
FAIL: specs/008-ui-alignment/plan.md:101: 差し替え済みの言い回し `REQ-009 は変えていない` が残っています。
FAIL: specs/008-ui-alignment/tasks/T17-define-file-scoped-warnings/task.md:159: ...
FAIL: specs/008-ui-alignment/tasks/T17-define-file-scoped-warnings/task.md:168: ...
3 violation(s). scanned 126 file(s), 3 owned term(s), 4 forbidden phrase(s).
```

**`plan.md:101` は独立reviewerも挙げていなかった。** 3か所を直したあと PASS。

**この3件はすべて `specs/**/*.md` で、拡張前から走査対象だった。** 検出の実体は`forbidden`への
登録であり、**契約JSONへの走査拡張がこのforward-testで寄与した検出は0件である**(独立review
attempt 3 の指摘。**当初この記述は拡張の効果を実際より大きく読ませていた**)。拡張そのものの
実効性は、reviewerが契約JSONへ言い回しを注入するprobeで別に確認している。

## 残っている限界

**PR 本文は依然として走査の外にある。** CIから到達できないので、この検査では閉じられない。
`AGENTS.md` は「受け入れ条件と証拠、review試行、manual対象commitと結果を PR 本文へ複製せず
`task.md` を正本とする」と既に定めており、**PR 本文へ書くのは「観測可能になった成果」と
「対象外」「integration条件」に絞る**のが現実的な防ぎ方である。今回の P1-B は、その規律を
守っていれば起きなかった — PR 本文に契約の変更理由を書き写していたのが原因である。
