# Development finding: 詰まっていないtaskでもhandoffの待ち欄を埋めないとcheckが落ちる

- 観測日: 2026-08-12
- 観測した作業: 005 T09のhandoff更新(branch `asdd/005-rename-exec/T09-empty-rule-ui`)
- 改善先: ASDD plugin(`scripts/workspace.py`)
- 関連artifact: `/home/dev/.claude/skills/asdd/scripts/workspace.py` の`HANDOFF_FIELDS`と`require_markdown_field_values`

## 観測した事実

toolchainのblockerが解消したので、T09の`Current state / handoff`から`Waiting for:`と`Requested action:`を削り、`Blocker category: なし`だけを残した。`workspace.py check specs`は次で落ちた。

```
ERROR: missing handoff field Waiting for: in /workspace/specs/005-rename-exec/tasks/T09-empty-rule-ui/task.md
ERROR: missing handoff field Requested action: in /workspace/specs/005-rename-exec/tasks/T09-empty-rule-ui/task.md
```

`HANDOFF_FIELDS`の6項目は、statusにもBlocker categoryにも関係なく全taskへ無条件に要求される。値が空でもFAILする(`empty handoff field`)ため、「今は誰も待っていない」を表現する方法が無い。

今回はmanual verification待ちが実在したので実質的な文を書けたが、待ちが本当に無い`in_progress` taskでは`なし`のような埋め草を書くしか通す手が無い。

## 期待していた動きと実際の動き

- 期待: 待ちが無いtaskは`Blocker category: なし`で完結し、`Waiting for` / `Requested action`は不要になる。
- 実際: 6項目すべてが必須で、待ちの有無を問わず文字列を要求される。

## 影響とworkaround

- 影響: `Waiting for`が常に埋まっているため、grepやsummaryで「本当に人間待ちのtask」を見分けられない。埋め草と実際の待ちが同じ形で並ぶ。
- 影響: 0.xの「厳密すぎる検査を避ける」方針と食い違う。構造checkが内容の正しさではなく記入の有無を強制している。
- workaround: 待ちが無いときも`Blocker category: なし`と、`Waiting for: なし` / `Requested action: なし`を書いて通す。

## 仮説と提案

- `Blocker category`が`なし`(または`none`)のときは`Waiting for` / `Requested action`を任意にする。逆に`environment` / `manual` / `review`等のときだけ必須にすると、必須性が意味と一致する。
- あるいは6項目必須は維持しつつ、`なし`を正規の値として認め、summary側で「待ちあり」から除外する。前者のほうが記入量が減る。
- どちらも`status`とは独立に判定できるので、statusの意味論には触れない。

## 改善結果

未対応。ASDD plugin側の判断待ち。projectのT09は`Waiting for` / `Requested action`へmanual verification待ちを書いて通している。
