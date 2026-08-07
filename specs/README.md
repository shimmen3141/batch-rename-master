# Specs Index

全機能の一覧と全体像。**タスク状態の正(source of truth)は各機能の plan.md**であり、この表はその要約。`run_plan_helper.py index`(create-plan / run-plan が実行)が全 plan.md から再生成する。手でタスク状態・進捗を書かない(概要だけは手で編集してよく、再生成でも保持される)。

| 機能 | 計画 | 仕様 | 進捗 | 依存する機能 | 概要 |
|------|------|------|------|--------------|------|
| [001-rename-core](001-rename-core/plan.md) | approved | approved (Strict) | 0/6 | - | 一括リネームアプリの中核となる**純粋 Dart の命名エンジン**を、UI・ファイルIO・プラットフォーム固有処理から |
| [002-file-list](002-file-list/plan.md) | approved | approved (Light) | 0/5 | 001-rename-core | メインのワークスペース画面。読み込んだファイルを一覧表示し、左に現在名・右に変更後名(001 のプレビュー)を並べる。チ |
| [003-rule-builder](003-rule-builder/plan.md) | approved | approved (Light) | 0/6 | 002-file-list | 命名ルールを組み立てる UI。トークン(元のファイル名 / 自由テキスト / 区切り / 連番 / 日時)を Chip  |
| [004-file-source](004-file-source/plan.md) | approved | approved (Light) | 0/9 | 002-file-list | 実ファイルの読み込みを担う。抽象ポート `FileSource` を定義し、利用者はまず**リネームしたいファイルの種類 |
| [005-rename-exec](005-rename-exec/plan.md) | approved | approved (Strict) | 0/9 | - | 001〜004 で「何に変えるか」は決まり、画面にも出る。しかし**実ファイルは一度も書き換えていない**。005 がそ |
| [007-rule-persistence](007-rule-persistence/plan.md) | approved | approved (Light) | 0/5 | 003-rule-builder | 直近に組み立てた「現在のルール」1件を永続化し、次回アプリ起動時にそのルールから始められるようにする。中核は 001 の |
<!-- 例: | [001-auth](001-auth/plan.md) | in_progress | approved (Strict) | 2/5 | - | 認証基盤 | -->
<!-- 計画: draft / approved / in_progress / done。進捗: doneタスク数/全タスク数
     仕様: `-`(作らない) / `予定(Light)` / `予定(Strict)`(計画にT1がある未着手状態) / `draft (レベル)` / `approved (レベル)` / `deprecated` -->

## 機能間のタスク依存

- 002-file-list.T3 → 001-rename-core.T4
- 003-rule-builder.T5 → 002-file-list.T3
- 004-file-source.T3 → 002-file-list.T2
- 007-rule-persistence.T4 → 003-rule-builder.T2

<!-- 機能をまたぐタスク依存はここに列挙する(依存する側の plan.md のタスク表にも `<機能ディレクトリ名>.Tn` 形式で書く。例: 001-auth.T3)
例: 002-billing.T2 → 001-auth.T3(認証APIの完成が前提) -->
