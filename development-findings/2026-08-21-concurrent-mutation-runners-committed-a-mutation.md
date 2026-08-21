# mutation runnerを並走させ、適用中のmutationをそのままcommitした

- 日付: 2026-08-21
- 観測: `013:T10` の verification checkpoint
- 種類: 不具合 / 検証漏れ

## 何が起きたか

`mutation_check.py` を**2つ同時に走らせてしまい**、片方が mutation を適用している最中に `git add -A && git commit` した。その結果、**M14 の mutation(`if (result != NativeRenameResult.nameConflict)` → `if (false)`)が実装として commit へ入った**(`a2e8b1e`)。

入っていたのは `013:T11` が REQ-023 / OQ-008 のために置いた保護である。「目標名に実体があることを観測したあと、一時名への退避が別の理由で失敗しても `nameConflict` を返す」という分岐で、**これが消えると既知の衝突で実行全体が止まる**。

並走した理由は、1回目の実行を `timeout 3000 python3 ...` で起動し、**その外側のシェル呼び出しが2分で切れたのに `timeout 3000` のプロセス自身は生き残っていた**ことである。生き残りに気づかないまま2回目を起動した。

## なぜ気づかなかったか

**3つの見落としが重なった。**

1. **commit の直前に `git status` を見たが、そのとき片方の runner はちょうど復元済みの窓にいた。** mutation runner は「適用 → test → 復元」を繰り返すので、**working tree が clean に見える瞬間が周期的にある**。一点観測では並走を検出できない。
2. **`flutter test` が PASS した記憶を根拠にしてしまった。** その PASS は commit より前の、mutation が入っていない状態のものだった。**「直前に通した」と「いま通る」は別である。**
3. **mutation の結果表が 4 件 SKIPPED を出していたのに、原因を「T10 で行を書き換えたから」だけで説明した。** M14 は T10 が触っていない file なので、その説明は成り立たなかった。**SKIPPED を1件ずつ突き合わせていれば、ここで気づけた。**

## 何が救ったか

**mutation 表そのものである。** M14 が `SKIPPED — matched 0 time(s)` として出たので、「find 文字列が現在の source に存在しない」ことが記録に残った。tool が「対象が見つからなかった」と「test が落ちなかった」を分けているおかげで、**PASS の山に埋もれずに済んだ**。

逆に言えば、**`flutter test` だけを見ていたら見つからなかった**。M14 を潰した状態でも 460 件は全部 PASS する — その分岐を検査する test は「退避が非 `nameConflict` で失敗する」経路を通るもので、その1件だけが落ちる。**しかしこの commit の時点では、その test は走らせていなかった。**

## 得られた知見

- **mutation runner が動いている間は git を触らない。** working tree を書き換えて戻す tool と、working tree を読む操作は排他にする。
- **runner の生存確認を、起動シェルの終了で代用しない。** `timeout` や `&` を挟むと、呼び出し側が切れてもプロセスは残る。**プロセスを直接見る。**
- **commit の直前に `git diff --cached` を読む。** `git status` の一点観測ではなく、**これから記録される内容そのもの**を見る。file 数が想定と違えば止まる。
- **SKIPPED は1件ずつ理由を確かめる。** 「変更したから」で束ねると、変更していない file の SKIPPED が紛れ込む。
- **baseline が汚れた mutation 実行の結果は採用しない。** 1回目は 38 KILLED / 0 SURVIVED だったが、**M14 が適用済みの source を baseline にしていた**ので、他の 38 件も「壊れた実装の上で壊した」結果である。作り直して 42 KILLED / 0 SURVIVED / 0 SKIPPED を取り直した。

## ASDD側で緩和できること

- `AGENTS.md` の mutation の節へ、**「runner の実行中は commit しない」**と**「SKIPPED は1件ずつ理由を確かめ、変更していない file の SKIPPED を見逃さない」**を加える。現在の記述は「生の出力を報告へ貼る」「対象が見つからなかったと test が落ちなかったを区別するのが要点である」までで、**区別したあと何をするかが無い**。
- 長時間 tool を起動するときの**生存確認の手順**(プロセスを直接見る)を書く。「起動したシェルが終わった」を完了の代用にしない。

## 改善結果

- 2026-08-21 / `ebeb92d` で M14 の混入を戻し、T10 の変更で古くなっていた M18 / M23 / M24 の find 文字列を現在の source へ合わせた。
- 2026-08-21 / **clean な baseline で再実行し、42 mutations: 42 KILLED, 0 SURVIVED, 0 SKIPPED。** 混入していた M14 も KILLED になった(= 保護が戻り、それを検査する test が実在する)。
- forward-test: **未実施。** 次に mutation を回す task で、上の「runner 実行中は commit しない」が守られるかを見る。
