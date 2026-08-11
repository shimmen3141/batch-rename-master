# T06 不具合修正: 初期ルール同期がビルド中に notifyListeners を呼ぶ

## 目的

- 不具合修正: 初期ルール同期がビルド中に notifyListeners を呼ぶ

## 入力と依存

- 依存: T05
- 同じworkspaceの`spec.md`、contract、decisions、仕様由来テスト。

## 変更範囲

- 旧planで定めた成果範囲。詳細は凍結履歴を参照する。

## 受け入れ証拠

- `RuleBuilderWorkspace` の**初期同期がビルド中に通知しない**(フレーム後へ回す等)。ユーザー操作由来の同期は従来どおり。
  - **同じ `FileListController` を購読する兄弟ウィジェットを同一フレームで並べても例外が出ない**ことを widget test で示す(再発検出。004 の `FileSourceBar` を並べる形でよい)。
  - 003 の既存の振る舞い(初期ルールがプレビューに反映される・変更が反映される)が保たれる。反映が1フレーム遅れる場合はテストを適切に待たせる(**アサーションの緩和・削除は不可**)。
  - 既存テストが緑のまま(退行なし)。`flutter analyze`/`dart format` PASS。
- 参考: 004 T3 の作業ログと `specs/FINDINGS.md`、`lib/ui/file_source/file_source_bar.dart`(購読しない回避策のコメント)

## 作業記録

旧ASDD 0.xから、実際に記録されていたcheckpointだけを移行した。将来予定やlive状態には使わない。

- 2026-08-04 / 申し送り(T6 の変更対象外): `lib/ui/file_source/file_source_bar.dart` のコメント「購読すると 003 のワークスペースが『ビルド中の setState』を誘発する」が、原因解消により**事実と異なる説明**になった。同ファイルは 004 の担当なので触らず報告する。あわせて、バーが再びコントローラを購読できるようになったため「作業セットが空なら『すべて外す』を無効化」の UX も復活可能(004 側の任意改善)。
  - 2026-08-04 / PR #75 作成(Closes #73)。マージ待ちで停止。
  - 2026-08-04 / 計画変更 / **T6(不具合修正)を追加**(開発者指示「1については修正タスクを立ててください」)。004 T3 で発見した「`RuleBuilderWorkspace` の初期同期がビルド中に `FileListController` へ通知する」問題の回収。計画状態を done → in_progress に戻した。再発検出のため、同一フレームで同コントローラを購読する兄弟ウィジェットを並べる widget test を受け入れ条件に含めた。
  - 2026-08-04 / T6 着手 / shimmen3141。Issue #73 を assign(claim)、ブランチ asdd/003-rule-builder/T6。
  - 2026-08-04 / T6 完了 / `RuleBuilderWorkspace` の初期同期(initState / didUpdateWidget)を `addPostFrameCallback` + `mounted` ガードでフレーム後へ回した。ユーザー操作由来の `_syncRule` は同期実行のまま。再発検出として、**同じ `FileListController` を購読する兄弟ウィジェットをワークスペースより前に置く** widget test を2件追加(`tester.takeException()` が null であることを検証)。既存テストには初期反映を待つ `await tester.pump()` を1行足しただけで、**アサーションの削除・弱化なし**。修正を戻すと新規2件が「setState() called during build」で落ち、初期同期を削除すると既存テストが落ちることを実行して確認(回帰検出として有効)。**239 tests PASS / analyze 0 issue / format PASS**。verifier PASS(試行1回・4条件充足)。
  - 2026-08-04 / 計画完了 / T6 done により 6/6。計画状態を in_progress → done に戻した。
