# Batch Rename Master — specifications and plans

このREADMEは、人間と新しく参加したAgentがプロダクト構造から正本へ到達するためのリンク集である。詳細status、依存、証拠は複製しない。

## 現在の開発

- [008 UIと主要操作の整合](008-ui-alignment/plan.md)
- [013 Androidの安全なrename境界](013-safe-android-rename/plan.md)

## 既存能力

- [001 コア命名エンジン](001-rename-core/plan.md)
- [002 ファイル一覧・選択・プレビュー](002-file-list/plan.md)
- [003 ルール構築UI](003-rule-builder/plan.md)
- [004 対象ファイルの選択と読み込み](004-file-source/plan.md)
- [005 安全なリネーム実行](005-rename-exec/plan.md)
- [007 前回ルールの保存と復元](007-rule-persistence/plan.md)

## 全体像と移行

- [プロダクトマップ](product-map.md) — 能力、未完了、将来候補、対象外、機能間依存。
- [移行カバレッジ](migration-coverage.md) — 旧ASDD成果物から新しい正本への一対一対応。
- [凍結した旧ディスカバリ](history/asdd-0.x-discovery.md) — 判断の由来のみ。次作業の正本にはしない。
- 開発中の不具合・手戻り・ASDD改善点は[`development-findings/`](../development-findings/)に一件一ファイルで記録する。

## 将来候補

Windows Explorer D&D、UIと主要操作の整合、写真・動画source、名前付きルールpreset、保存schema移行、隠しfile filter、元名のcase変換は[プロダクトマップ](product-map.md#将来候補)を入口にする。候補のままIssueを一括作成せず、着手判断後にplanへ定義する。

再開時はASDD pluginの`resume`で作業中・block中・着手可能なtaskだけを確認する。全taskの状態と依存が必要な場合だけ`summary`を使う。

```console
python <asdd-plugin>/scripts/workspace.py resume specs
python <asdd-plugin>/scripts/workspace.py summary specs
```
