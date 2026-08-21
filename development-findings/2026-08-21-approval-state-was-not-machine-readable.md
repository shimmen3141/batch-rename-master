# 契約の承認状態が機械可読でなく、spec.mdと契約が互いを正本と指し合っていた

- 日付: 2026-08-21
- 観測: `013:T10` の独立review attempt 2(P2-4)
- 種類: 仕組みの不足 / 曖昧な記述

## 何が起きたか

`013:T10` は 001 contract(Strict)を改訂し、人間の再承認を待つ状態に入った。ところが **その「待っている」ことが契約側から読めなかった。**

- `specs/001-rename-core/contracts/behavior-contract.json` は `status: "approved"` のまま。`revision` も `revision_history` も**欄そのものが無い**。
- `specs/001-rename-core/spec.md` の Status 行に「再承認待ち」と書いた。しかし同じ行は「**正本は `contracts/behavior-contract.json` の `status`**」と宣言している。
- つまり **spec.md は「契約を見ろ」と言い、契約は `approved` と言う。** 再承認待ちであることは、spec.md の注記を**正本ではない情報として**読むしかなかった。

reviewer が P2 として挙げるまで、この循環に気づかなかった。**契約を機械的に読む次のAgentは、改訂済みの条文を「承認済み」として扱う。**

005 は同じ問題を持っていない。`revision` と `revision_history` があり、`approved_date: null` で「この revision は未承認」を表せる。**001 に同じ欄が無かったのは、001 が revision を刻む必要のある改訂を一度も経ていなかったから**である(2026-08-04 の 004 由来の更新は spec.md の節として記録された)。

## なぜ起きたか

**`AGENTS.md` は「`spec.md`、contracts: 利用者から観測できる正しさ」としか書いておらず、contract の必須欄を定めていない。** `revision` / `revision_history` は 005 が自分で持ち込んだ形で、規約ではない。したがって feature ごとに有無が揺れる。

加えて、**Light の feature(004)は spec.md の Status 行だけで承認状態を持つ**ので、Strict でも同じで足りると錯覚しやすい。Strict は「正誤判定は契約が行う」と宣言している以上、**承認状態も契約が持たなければ宣言と食い違う。**

## 得られた知見

- **「正本はあちら」と書くファイルに、正本が持っていない情報を書かない。** 書いた瞬間、その情報は正本の外にある。
- **承認は状態であって注記ではない。** 状態は、それを正本と宣言した場所が機械可読な形で持つ。
- **`status: approved` の一語では、複数回改訂される契約の状態を表せない。** 「何が承認されたのか」を revision で指せないと、改訂中と承認済みが同じ値になる。

## ASDD側で緩和できること

- **Strict contract に `revision` と `revision_history` を必須とする**を `AGENTS.md` へ加える。`revision_history` の各要素は `revision` / `approved_date`(未承認は `null`)/ `meaning` を持ち、**`status` の `approved` は「`approved_date` が入っている最新 revision に対するもの」と読む**規則も併記する。
- **構造検査へ足せる検査**: `status == "approved"` かつ最新 revision の `approved_date == null` のとき、**その契約は改訂中である**ことを出力する(FAIL ではなく情報)。今回のような「改訂したのに承認済みに見える」状態を、人間とAgentの両方が一目で拾える。
- Light の feature については、spec.md の Status 行が正本であることが明示されているので、現在の形で足りる。**問題は「正本を別ファイルへ委ねている側」だけに起きる。**

## 改善結果

- 2026-08-21 / `001` contract へ `revision: "2"` と `revision_history` を追加した。revision 1(2026-08-04 承認)と revision 2(`013:T10` 由来)を刻み、承認前は `approved_date: null` とした。`spec.md` の Status 行も「`revision_history` の revision 2 の `approved_date` を参照」と書き換え、**注記ではなく正本を指す**形にした。
- 2026-08-21 / 開発者が 001 revision 2 / 004 spec / 005 revision 5 を承認したので、両契約の `approved_date` を `2026-08-21` にした。
- **未解決**: `specs/004-file-source/spec.md` の「### T7 由来の波及(2026-08-05・再承認待ち)」は、同ファイルの Status 行が同日に再承認済みと書いているのに**節見出しだけ「再承認待ち」のまま残っている**。`013:T10` の range 外なので今回は触っていないが、同じ型の食い違いである。
- forward-test: **未実施。** 次に Strict contract を改訂する task で、`revision_history` に `approved_date: null` を刻む形が守られるかを見る。
