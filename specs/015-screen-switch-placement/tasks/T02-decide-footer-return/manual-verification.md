# 手動確認: footer を「確定」だけにする(Androidエミュレータ)

`015:T02` で、browser(「すべて」)と写真・動画の選択画面の footer から「← リネーム画面へ」を外し、「確定」だけにした。画面を閉じるのは、いちばん上の帯の「リネーム画面へ戻る」(`T01`)と Android のシステムバックである。

**`T01` と同じ build で一緒に確かめる。** 手順は [/workspace/specs/015-screen-switch-placement/tasks/T01-top-return-band/manual-verification.md](/workspace/specs/015-screen-switch-placement/tasks/T01-top-return-band/manual-verification.md) の attempt 2 の手順2〜4(footer の確認とシステムバック)に含めた。対象buildは、`lib/`・`android/` が task.md の「Evidence revision」と同一のもの。**code・dependency・build設定が変わったら、この結果は再利用しない。**

期待結果:

- 2つの画面とも footer は右に「確定」だけ。左は空いている。
- 「確定」は今までどおり、選んだときだけ押せる。
- 帯の「リネーム画面へ戻る」と Android のシステムバック(画面端からのスワイプ)で、どちらも選んだものを捨ててリネーム画面へ戻る。一覧は開く前のまま。
