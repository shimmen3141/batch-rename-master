# T06 期限付き単一step undoを統合する

## 目的

成功したdesktop renameを最新handleから逆順に戻し、5秒の期限、部分成功、undo失敗を仕様どおり提示する。

## 入力と依存

- `T05`の実adapter contractと更新後handle。
- 005 REQ-006〜008、INV-004、OP-003、SM-001。
- Issue #97。実装はPR #116へ同一build検証の依存成果として含まれる。

## 変更範囲

- session内一件のundo snapshot、5秒timer、逆順実行、途中失敗停止、結果表示。
- 永続的・複数世代のundo履歴は対象外。

## 受け入れ証拠

- PR #116 product code baseline `b866e35`の仕様由来testと、ASDD 2.0合流後latest headのCI。
- [`manual-verification.md`](manual-verification.md)で、画面の「元に戻す」を5秒以内に押した場合の実file復元と、6秒待った場合のボタン消失・改名後file維持を同じdesktop buildで確認する。
- T05のmanual証拠を含むexact range最終reviewがPASSする。

## 作業記録

- 2026-08-09 / PR #116で成功済みrenameを最新handleから逆順に戻す単一step undo、5秒期限、途中失敗停止を実装。

## Current state / handoff

- Last checkpoint: product code baseline b866e35で自動testと独立reviewのP0/P1なし。ASDD 2.0合流後も同じ実装を維持
- Blocker category: manual evidence
- Waiting for: T05と同じdesktop buildの期限内・期限後undo結果
- Requested action: T05のdesktop checklistと連続してundo checklistを実施する
- Evidence revision: product code `b866e35`; ASDD合流後のhead・CI runはPR #116とIssue #96に記録する
- Next Agent action: T05と同じlatest headのmanual buildへ含め、移行後のexact rangeで最終独立reviewする
