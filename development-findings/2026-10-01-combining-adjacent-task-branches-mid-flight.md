# 隣接taskを途中から1つのPRへまとめ、mutationの表の衝突をidで解いた

## 観測(2026-10-01、`008:T50` と `008:T52`)

- `T50`(行の警告の見せ方)と `T52`(連番の桁の自動引き上げ)は別の branch・worktree で並行して実装した。どちらも一覧の見え方を変えるので、**実機確認を1回で済ませるため**、`T52` の branch を `T50` の branch へ merge し、1つの PR(#208)・1つの build・1つの `manual-verification.md` にした。AGENTS.md の「同じreview・rollback境界の小さな隣接taskはまとめてよい」に当たる。
- merge では `tool/mutations.json` が衝突した。両方の branch が表の末尾へ mutation を足し、既存の mutation の `find` も追随させていたためである。**行単位の手での解消は、追加・追随・削除を取りこぼしやすい。**
- 解き方: `git show :1: / :2: / :3:` で base・ours・theirs の表を読み、**id をキーに**合わせた(ours を基に、theirs が base から変えたものは theirs を採り、theirs が消したものは消し、theirs だけが足したものを足す。両方が同じ id を変えていたら止める)。その後 `tool/check_mutation_finds.py` で全件の `find` の一致を確かめた。
- `T52` の task.json の `manualVerification` は `../T50-row-warning-retune/manual-verification.md` を指した(`workspace.py check specs` は PASS)。証拠は両 task の task.md の「実機確認」節へ同じ内容で記録した。

## 次に同じことをするとき

- まとめるなら、**両方の実機確認の前**に決める。まとめた後の build が両 task の証拠の対象になる。
- `tool/mutations.json` の衝突は id で解く。解いた後に件数(ours + theirs で新しく足した数 − theirs が消した数)と `check_mutation_finds.py` を確かめる。

## 改善先

なし(手順として AGENTS.md に足すほどの頻度ではない。2回目が起きたら、表の merge を script にするか検討する)。
