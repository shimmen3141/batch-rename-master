# manual確認のfixtureがgit管理外にだけあり、初期化で消えた

## 観測したこと(2026-09-16)

`008:T07` の `manual-verification.md` は、fixture を `.worktrees/t07-fixtures/` に「用意してあります」と
書いていた。環境の初期化でこのfolderが消え、開発者の `adb push .worktrees\t07-fixtures /sdcard/DCIM/` が
`cannot stat ... No such file or directory` で止まった。生成に使った script も commit されておらず、
手順書だけが残っていた。

同じ fixture を前提にした `008:T20` の手順4は「選択を100件以上」と書いていたが、fixture は27件しかなく、
そのままでは実行できなかった(開発者は Agent が示した代替手順で確認した)。

## なぜ起きたか

- host から見える場所という制約で、git 管理外の `.worktrees/` を選んだ。置き場所の理由は書いたが、
  **作り直し方**を書かなかった。
- 後続taskが fixture を再利用するとき、fixture の件数を確かめずに手順を書いた。

## 変更先と検証

- `tool/make_t07_fixtures.py` を追加し、`T07` の手順から参照した。container で実行して27件が出ることを確認した。
- `T20` の手順4を27件で成立する形へ直した。
- 未適用: manual手順が fixture の件数・内容に依存するとき、その前提を手順に書く規律(他taskへの forward-test はまだ)。
