# Specs Index

全機能の一覧と全体像。**タスク状態の正(source of truth)は各機能の plan.md**であり、この表はその要約。`run_plan_helper.py index`(create-plan / run-plan が実行)が全 plan.md から再生成する。手でタスク状態・進捗を書かない(概要だけは手で編集してよく、再生成でも保持される)。

| 機能 | 計画 | 仕様 | 進捗 | 依存する機能 | 概要 |
|------|------|------|------|--------------|------|
| [001-rename-core](001-rename-core/plan.md) | in_progress | approved (Strict) | 3/6 | - | 一括リネームアプリの中核となる**純粋 Dart の命名エンジン**を、UI・ファイルIO・プラットフォーム固有処理から |
<!-- 例: | [001-auth](001-auth/plan.md) | in_progress | approved (Strict) | 2/5 | - | 認証基盤 | -->
<!-- 計画: draft / approved / in_progress / done。進捗: doneタスク数/全タスク数
     仕様: `-`(作らない) / `予定(Light)` / `予定(Strict)`(計画にT1がある未着手状態) / `draft (レベル)` / `approved (レベル)` / `deprecated` -->

## 機能間のタスク依存


<!-- 機能をまたぐタスク依存はここに列挙する(依存する側の plan.md のタスク表にも `<機能ディレクトリ名>.Tn` 形式で書く。例: 001-auth.T3)
例: 002-billing.T2 → 001-auth.T3(認証APIの完成が前提) -->
