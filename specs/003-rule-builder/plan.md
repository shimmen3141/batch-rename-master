# 003 ルール構築UI

## 目的

命名ルールを組み立てる UI。トークン(元のファイル名 / 自由テキスト / 区切り / 連番 / 日時)を Chip として追加・削除・並び替え(D&D)し、タップで各トークンの詳細設定を編集する。編集結果は 001 の `RenameRule`(`List<Token>`)として組み上がり、002 の `FileListController.setRule` に渡してリアルタイムプレビューへ反映する。002 と同じく、ウィジェットから分離した状態層 `RuleController` を先に作り unit test で固定し、その上に薄いウィジェット層(ビルダー・詳細エディタ・レスポンシブ外殻)を載せて widget test で検証する。

## 境界

### 対象

- `spec.md`、contract、既存テストが定めるこの機能の成果。
- 各タスクに移行した実装・検証・未完了受け入れ。

### 対象外

- 命名ロジック本体(トークンの評価・プレビュー生成・検証)は 001(done)。003 は 001 の `Token`/`RenameRule` を**組み立てるだけ**。
- ファイル一覧・選択・ソート・プレビュー表示は 002(done)。003 は組み上げた `RenameRule` を `setRule` で渡すのみ。
- **ルールのプリセット保存・読み込み**(参考デザインにあるが永続化を伴う)は 003 の対象外。必要なら別機能として discover-requirements → 計画(永続化の正しさは別途仕様)。
- **元のファイル名トークンの大文字/小文字変換**(参考デザインの keep/upper/lower)は 001 が未対応のため対象外。実装するなら先に 001 仕様の拡張(→再承認)が必要(discovery.md 001 の将来拡張)。
- 実ファイルのリネーム実行は 005。

## 方針

- 配置: `lib/ui/rule_builder/`。状態層 = `RuleController`(編集中の `List<Token>` を保持し、追加・削除・並び替え・トークン差し替えを提供、`RenameRule get rule` を公開して変更を通知)。001 の `Token` は不変値なので、詳細編集は「新しい `Token` インスタンスへの差し替え」で表現する。
- トークン種別: 元のファイル名(`OriginalNameToken`)/ 自由テキスト(`LiteralToken`)/ 区切り(`LiteralToken` のプリセット `-` `_` 空白)/ 連番(`SequenceToken`)/ 日時(`DateTimeToken`)。区切りは自由テキストと同一実体で、UI 上プリセットとして提供(001 期の決定を踏襲)。
- ウィジェット層は `RuleController` を描画する薄い層。色は 002 で作った `AppColors`(セマンティックカラー)を再利用し、視覚は参考デザインに準拠。レイアウトは振る舞い非依存。
- レスポンシブ: 画面幅で表示方式を切替(モバイル=ModalBottomSheet / デスクトップ=右側2ペイン。PRD §3.2)。ブレークポイントは仕様の open_question で確定する。
- 詳細エディタの入力範囲・既定値・日時フォーマットのプリセット集合は**仕様(T1)の open_questions** で確定する。

旧ASDD 0.xの状態欄とログは`history/asdd-0.x-plan.md`へ凍結した。現在の状態・依存・Issue/PRは`plan.json`と各`task.json`を正本とする。

## 全体の受け入れ証拠

- `spec.md` の Status が approved(Light)。
- T1 で定義される REQ/VER を覆う `test/spec_003_rule_builder/` が `flutter test` で通る(unit 12 + widget 14 = 26件)。
- `flutter analyze` 0 issue、`dart format --output=none --set-exit-if-changed .` PASS。
- `RuleController` はウィジェット(`Widget` の構築)に依存せず、ロジックが unit test 単体で検証できる(`foundation.dart` のみ)。
- 組み上げた `RenameRule` が 002 の `FileListController.setRule` 経由でプレビューへ反映される(rule_builder_workspace_test.dart で結合を確認)。

## 人間の決定

| 日付 | 論点(要旨) | 決定 | 決定者 |
|------|------------|------|--------|
| 2026-08-02 | 仕様レベル | Light(ルールモデルの編集UI。お金・権限・データ整合性・並行性なし。永続化は対象外) | Claude(判定) |
| 2026-08-02 | 区切りトークン | 自由テキスト(`LiteralToken`)と同一実体。UI でプリセット記号を提供 | 開発者(001 期決定の踏襲) |
| 2026-08-02 | プリセット保存/読込(名前付きルール) | 003 対象外。**別機能として実装**(開発者確定) | 開発者 |
| 2026-08-02 | 元名の大小変換 | 003 対象外(001 未対応。先に 001 拡張→再承認が必要)。**開発者確定** | 開発者 |
| 2026-08-02 | 前回ルールの復元(次回起動時) | **新規要求**(開発者)。永続化を伴うため**別機能として計画**(003 対象外)。RenameRule/Token のシリアライズは将来のプリセット機能と共有。discovery.md に記録 | 開発者 |
| 2026-08-02 | 仕様 open_questions の確定(T1 レビュー) | 連番 digits=2 / 区切りに全角スペース追加 / 自由テキスト空不可(エディタ確定無効) / 連番は正のみ(負・降順除外) / 日時はプリセット+自由入力(UIはT4検討) / 境界840dp / 空ルール許容。正本は spec.md | 開発者 |

## タスク

タスクのID・依存・状態は`plan.json`と各`tasks/*/task.json`が正本。番号は安定した識別子であり、実行順ではない。

| ID | 詳細 |
|---|---|
| T01 | [task.md](tasks/T01-define-behavior/task.md) |
| T02 | [task.md](tasks/T02-rule-controller/task.md) |
| T03 | [task.md](tasks/T03-token-chip-editor/task.md) |
| T04 | [task.md](tasks/T04-token-detail-editor/task.md) |
| T05 | [task.md](tasks/T05-responsive-rule-workspace/task.md) |
| T06 | [task.md](tasks/T06-defer-initial-rule-sync/task.md) |
