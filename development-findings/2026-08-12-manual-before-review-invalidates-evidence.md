# Development finding: manualを独立reviewより先に依頼したため、reviewの修正で証拠が失効した

- 観測日: 2026-08-12
- 観測した作業: `005:T07`(desktopの更新日時ずらし)。manual実施後のreview指摘で`lib/`を修正し、manual証拠が失効して再実施になった
- 改善先: ASDD plugin(`run-plan`と`manual-verification.md`のstep順序)、および筆者の実行
- 関連artifact: `/home/dev/.claude/skills/asdd/skills/asdd-setup/references/manual-verification.md`、`/home/dev/.claude/skills/asdd/skills/run-plan/SKILL.md`、`/home/dev/.claude/skills/asdd/skills/review-task/SKILL.md`

## 観測した事実

`005:T07`で次の順に進めた。

1. 実装 + 仕様由来testを書く。
2. manual手順を具体化し、**人間へ実機確認を依頼**(2回実施。1回目は手順の不備で部分的、2回目で全項目PASS)。
3. **独立review**を起動 → FAIL。P1は「testがREQ-014の核心を判別できず、コメントが判別すると偽って主張していた」。
4. 修正の過程で`lib/data/rename_exec/desktop_rename_executor.dart`のcatch節も直した(例外の全捕捉化、分類を`errorOf`へ)。
5. 再reviewが**BLOCKED**。「manual証拠は対象commit以後にcode、dependency、build設定が変わったら再利用しない」(AGENTS.md)に触れ、**現headに対応する証拠が無い**。しかも変わったのは手順4が踏む例外経路そのものだった。
6. 人間が再取得範囲を判断し、手順4だけを現headで再実施した。

**人間の実機確認を、実質2.5回消費した。**

## 期待していた動きと実際の動き

- 期待: manualを1回依頼すれば、それが完了判定の証拠になる。
- 実際: reviewが後から`lib/`を変える指摘を出し、証拠が失効した。reviewはコードとtestを見る工程なので、**修正を要求する確率が高い**。その後ろにmanualを置いていれば失効しなかった。

## 根本原因

**manual verificationと独立reviewの順序が、どこにも定められていない。**

- `AGENTS.md`は完了条件として両方を挙げるが、順序は書いていない。
- `manual-verification.md`は「code、dependency、build設定を変更した後は、以前のmanual結果を再利用しない」と**失効の規則**だけを定め、失効しにくい順序については何も言わない。
- `review-task`は「manual証拠が同一commit/buildに対応するか」を確認項目に持つ。これは**manualが先に済んでいる前提**を示唆する。実際、筆者はこの記述からmanual→reviewの順が既定だと読んだ。

つまり資料はむしろ「manualが先」と読める形になっており、それが**証拠が最も失効しやすい順序**である。

筆者の側にも判断の誤りがある。実装が「できた」と見えた時点で人間の時間を使いに行った。reviewが何も指摘しない保証はないのだから、**人間の時間は最後に使うべき**だった。

## 影響とworkaround

- 影響: 人間の実機確認が余分に発生した。今回は手順4だけ(3分程度)で済んだが、変更箇所によっては全手順の再実施になる。人間の時間は最も高価な資源で、Agentのやり直しと違って取り返せない。
- 影響: 「証拠の再取得範囲」という、本来不要な人間判断が発生した(失敗経路限定の変更が成功経路の証拠を失効させるか)。
- 影響の限定: 実装・test・仕様の内容面には未解決のP0/P1が無く、成果物の品質は落ちていない。
- workaround: 変更が到達しない経路の証拠を再利用する範囲を人間が判断する。今回はそうした。

## 仮説と提案

- **実装を含むtaskでは、独立reviewを先に通してからmanualを依頼する。** 順序を次のようにする。
  1. 実装 + 仕様由来test + project-native検査。
  2. **独立review(コード・test・仕様)**。指摘を解消し、PASSまで回す。
  3. manualを依頼(このcommitが証拠のidentityになる)。
  4. **manual結果を対象にした最終review**(証拠の被覆とidentityを見る)。
- 4を分けるのは、`review-task`が「manual証拠が同一commit/buildに対応するか」を見る工程を残すためである。2と4は見る対象が違う。
- `004:T10`や`007:T06`のような**manual受け入れだけのtask**は、reviewの前にコードが無いので2が空になる。この場合は現行どおりmanual→reviewでよい。**実装を含むかどうかで分岐する。**
- `run-plan`へ一文足すと迷わない。例:「実装を含むtaskでは、独立reviewがPASSしてからmanualを依頼する。manualの前にreviewを通さないと、reviewの指摘でcodeが変わったときに証拠が失効する。」
- `manual-verification.md`の「依頼前のdry-run」へ「独立reviewがPASSしているか(実装を含むtaskの場合)」を1項目加えるのも同じ効果を持つ。
- 一般化: **人間の時間を使う工程は、Agentだけで回せる工程がすべて終わってから置く。** reviewはAgentだけで回せる。

## 改善結果

projectでは、人間の判断で手順4だけを現headで再実施し、証拠のidentityを回復した。ASDD plugin側の順序の明文化は未対応。

以後、筆者は実装を含むtaskで**独立reviewをmanualより先に**通す。
