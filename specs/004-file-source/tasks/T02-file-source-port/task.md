# T02 FileSource ポート + 元場所ハンドル + 作業セット + fake + 002 結線

## 目的

- FileSource ポート + 元場所ハンドル + 作業セット + fake + 002 結線

## 入力と依存

- 依存: T01
- 同じworkspaceの`spec.md`、contract、decisions、仕様由来テスト。

## 変更範囲

- 旧planで定めた成果範囲。詳細は凍結履歴を参照する。

## 受け入れ証拠

- `FileSource` ポートと in-memory fake(与えた `FileEntry` 群を返す)を定義。各 `FileEntry` が元場所ハンドルを持つ。
  - 作業セットのロジック(追加・除去・ハンドルによる重複排除・既定選択)と、fake の pickFolder/pickFiles 結果を 002 の作業セットへ**追加**する結線が T1 の REQ どおり動く(キャンセル=空は無変化)。
  - 002 コントローラに追加/除去 API を足し、既存の 002 テストが緑のまま(退行なし)。
  - 該当 REQ/VER を覆う unit test が fake で通り、`flutter analyze`/`dart format` PASS。実 IO 不要。
  - 001/002 の該当仕様が**先に更新・再承認**されていること(未承認ならブロック報告)。
- 参考: T1、001 `FileEntry`、002 `FileListController`、007 の `rule_persistence`(結線の書き方)

## 作業記録

旧ASDD 0.xから、実際に記録されていたcheckpointだけを移行した。将来予定やlive状態には使わない。

- 2026-08-04 / スコープ外の申し送り(未実施・plan の判断待ち): (1) **002 REQ-002 の時系列ソート `createdAt`→`modifiedAt` が未実装**(`lib/ui/file_list/file_sort.dart` は `FileSortMode.createdAt` のまま)。T2 の変更対象外のため触らず。T3 に含めるか別タスク化するか要判断。(2) T4 の実 `FileSource` は全エントリに `sourceHandle` を必ず設定すること(null はハンドル重複排除の対象外のため)。
  - 2026-08-04 / PR #61 作成(Closes #52)。マージ待ちで停止。
  - 2026-08-04 / PR #61 マージ。
  - 2026-08-04 / 波及 / ハンドル・場所の置き場を **core `FileEntry` の任意フィールド**に決定(開発者選択)。001(Strict): `sourceHandle`/`sourceLocation` + INV-005 を追加、`spec_lint --strict` PASS(errors=0, warnings=0)。002(Light): `addFiles`/`removeFile`/`clearFiles`(REQ-008/009)・時系列ソート `createdAt`→`modifiedAt`(REQ-002)・場所サブ情報(REQ-010)。PR #58 で **開発者再承認**(「#58は承認します」)→ 両仕様を approved に復帰し index 再生成。**T2 のゲート解除。**
  - 2026-08-04 / T2 着手 / shimmen3141。Issue #52 を assign(claim)、ブランチ asdd/004-file-source/T2。
  - 2026-08-04 / T2 完了 / `FileSource` ポート + `PickResult`(Picked/Cancelled/Failed)+ `FakeFileSource`(lib/data/file_source/file_source.dart)、結線 `applyPick`/`loadFolderInto`/`loadFilesInto`(file_loading.dart、data→ui 依存を避けるため受け口は `AddFiles` コールバック)、`FileEntry` に `sourceHandle`/`sourceLocation` を追加、002 に `addFiles`/`removeFile`/`clearFiles`。テスト28件(VER-001/002/003)。verifier PASS(試行1回・5条件充足)。レビューパスの指摘で **INV-005 の回帰検出を determinism_test.dart に追加**(P1: VER-005 が宣言していたが実体が無かった)。全 187 tests PASS / analyze 0 issue / format PASS。
