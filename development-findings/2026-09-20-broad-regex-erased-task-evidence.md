# Development finding: 正本更新の広い正規表現が受け入れ証拠を消した

- 観測日: 2026-09-20
- 観測した作業: 008 / T34 の task.md 更新
- 改善先: agent-runtime
- 関連Issue・commit・artifact: [T34 task.md](../specs/008-ui-alignment/tasks/T34-hint-refinements/task.md)

## 観測した事実

T34 の検証結果を task.md へ反映する read-modify-write script で、複数行かつ DOTALL の正規表現を使った。review 節だけを置き換える意図だったが、開始条件が広すぎたため、気をつけること・受け入れ証拠・実装と機械検証の各節も削除された。

書き戻し後に全体を読み直したため削除を検出できた。直前のコミットから task.md を復元し、見出しで始点と終点を固定した置換へ変更した。

## 影響とworkaround

- 影響: 未commit の ASDD 正本が一時的に不完全になった。実装コード、test、commit は変更されなかった。
- その場のworkaround: HEAD の task.md を復元してから、各置換回数を 1 件に固定し、書き戻し後に必須見出しと検証記録の存在を assert した。

## 仮説と改善案

- 仮説: 正本の構造をまたぐ更新で、置換対象の始点を一般的な箇条書きにしたことが原因である。
- 改善案: 正本の自動更新では構造見出しを両端にした非貪欲な置換だけを使い、書き戻し後は変更箇所だけでなく必須見出し一覧も照合する。

## 改善結果

T34 では、復元後の task.md に受け入れ証拠・manual確認からの修正・機械検証・handoff がすべて存在することを確認した。
