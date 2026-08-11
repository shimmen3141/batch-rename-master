# T01 振る舞い仕様の作成(Light)+ 001/002 仕様更新の洗い出し

## 目的

- 振る舞い仕様の作成(Light)+ 001/002 仕様更新の洗い出し

## 入力と依存

- 依存: なし
- 同じworkspaceの`spec.md`、contract、decisions、仕様由来テスト。

## 変更範囲

- 旧planで定めた成果範囲。詳細は凍結履歴を参照する。

## 受け入れ証拠

- `FileSource` の契約(pickFolder / pickFiles の入出力、キャンセル=空、エラー時の扱い)、`FileEntry` へのマッピング、**元場所ハンドル**の意味、**作業セットへの追加/除去/重複排除**(ハンドル同一で重複、既定選択)、002 への結線の REQ と VER が定義されている。
  - 時刻の扱い(`modifiedAt` 常時・`createdAt` は SAF で取得不能→暫定「更新日時」ラベル・撮影日時は後続機能)が REQ として明記されている。
  - **004 が触れる 001/002 の承認済み仕様の更新点**(002: 追加/除去 API と時系列ソートのラベル「作成日時」→「更新日時」、001: 日時トークンの「作成」表記、`FileEntry` への元場所ハンドル追加)を洗い出し、それぞれ**人間の再承認が要る**旨を明記する。
  - open_questions に「重複名・隠しファイルの扱い」「キャンセルとエラー(権限拒否)の区別」「返す順序(名前順/未定義)」「複数フォルダ混在時の表示(フォルダ名の副題等)」を挙げる。
  - 反証ログに反証観点と検出・対処が記録されている(0件ならその旨)。
  - 仕様が draft でインデックス登録され、完了報告にレビュー依頼が含まれる(approved 化は人間。**後続タスクは仕様が approved まで実行不可**)。
- 参考: create-verifiable-spec skill、PRD §2/§5、discovery.md(004)、001 の `file_entry.dart`、002 の `file_list_controller.dart`、007 の `rule_store`(ポート/fake の書き方)

## 作業記録

旧ASDD 0.xから、実際に記録されていたcheckpointだけを移行した。将来予定やlive状態には使わない。

- 2026-08-04 / PR #56 作成(Closes #51)。マージ待ちで停止。
  - 2026-08-04 / open_questions を開発者回答で解消(D-1〜D-4)。spec を更新: `PickResult`(Picked/Cancelled/Failed)+ Failed 通知(REQ-001/008)、場所のサブ情報表示(REQ-009)、隠しファイル非フィルタ(対象外)、追加順(REQ-007)。REQ-009 追加に伴い波及に「002 RowView 場所副題」「001 FileEntry 表示用の場所」を追記。PR #56 を更新。spec は引き続き draft(approved 化は人間)。
  - 2026-08-04 / PR #56 マージ。**spec.md を approved に(開発者承認: 「承認します」)。** open_questions ゼロ・全 REQ 確定。次ゲートは T2 前の 001/002 仕様更新→再承認。
  - 2026-08-04 / T1 着手 / shimmen3141。Issue #51 を assign(claim)、ブランチ asdd/004-file-source/T1。計画全体を in_progress に。create-verifiable-spec で Light 仕様を作成する。
  - 2026-08-04 / T1 完了 / spec.md(Light・draft)作成: REQ-001〜008 / VER-001〜003 / 「波及: 001・002 の再承認が要る更新点」/ 反証ログ5観点 / open_questions OQ-1〜4。verifier PASS(試行1回・6条件すべて充足)。**spec は draft。approved 化は人間。後続 T2 以降は spec approved まで実行不可。**
