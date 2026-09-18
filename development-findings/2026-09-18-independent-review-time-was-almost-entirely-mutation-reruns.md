# 独立reviewの所要時間のほぼ全てが、mutationの流し直しだった

## 観測したこと(2026-09-18)

`008:T19` の独立review attempt 1 が **16分半**かかった。開発者が「20分以上かかるのですが、原因は
分かりますか」と尋ねたので、containerで各操作を実測した。

| 操作 | 時間 |
|---|---|
| `flutter test`(全件851件) | 42秒 |
| `flutter test <1 file>`(暖まった状態) | 10秒 |
| 同上(worktree作成直後の初回) | 16秒 |
| `flutter analyze` | 10秒 |
| `flutter pub get` | 2秒 |

`tool/mutations.json` の `command` は全件の `flutter test` である。mutationは1件ずつ「書き換える →
testを回す → 戻す」を繰り返すので、**1件あたり約45秒**かかる。attempt 1 の内訳はおおよそ次のとおりで、
**9割がmutationの実行**だった。modelの速さはほとんど効いていない。

- mutation 14件 × 45秒 ≒ 10分
- reviewer独自のprobe 5件 ≒ 4分
- 通常の検査(全件test・analyze・format・構造検査)≒ 1分
- 差分と仕様を読む、報告を書く ≒ 1〜2分

reviewerが流し直した14件は、**所有task側が同じ表で回して生出力をtaskへ残していたもの**である。
`AGENTS.md`は「独立reviewが足したmutationは`tool/mutations.json`へ取り込む」とだけ書いており、
**reviewerが既存の表をどこまで流し直すか**を決めていなかった。そのため「全部流し直す」が既定になっていた。

## なぜ起きたか

- 表は `command` を一つしか持てず、001のコア判定やdataのmutationも同じ表にあるため、`command` は
  全件の `flutter test` でなければ安全でない。**表の既定値を、reviewerの実行範囲としても使っていた。**
- 「何を流すか」(件の選び方)と「どこまで流すか」(testの範囲)を、規約が区別していなかった。

## 変更先と検証

- `AGENTS.md`の「検証とreview」へ次を追記した。
  - reviewerは表を全件流し直さず、**疑わしいものとreviewer自身が設計した対照だけ**を回す。
  - 回すときは変更に対応するtestへ**範囲を絞ってよい**。**`SURVIVED`が出たものだけ全件で確かめ直す**
    (`KILLED`は範囲を狭めても結論が変わらない)。
  - `tool/mutations.json` の `command` は**全件のまま置く**。
  - 独立reviewのmodelは既定でSonnet。判定・contract・権限・データ保護に触れるtaskと、2回FAIL後はOpus。
- forward-test: `008:T19` の attempt 2 でこの指示を適用した。mutation **16件**を範囲を絞って回して
  16 KILLED / 0 SURVIVED、review全体は **約14分**。所要時間は下がったが、**attempt 1 で見つかった
  P1 2件の再発検出(`M262` / `M263`)は同じく効いていた。**
- 未確認: 実装量の多いtaskでどこまで縮むか(attempt 2 はreviewerのprobeが多く、縮み幅は
  mutation側だけで測れていない)。Sonnetが attempt 1 相当の欠陥(同名判定の数え方)を
  見つけられるかも未確認 — あの2件はOpusのreviewが見つけている。
