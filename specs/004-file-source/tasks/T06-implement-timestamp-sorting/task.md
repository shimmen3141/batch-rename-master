# T06 時系列ソート2種+警告の実装(取得可否・ソート・警告表示)

## 目的

- 時系列ソート2種+警告の実装(取得可否・ソート・警告表示)

## 入力と依存

- 依存: T05
- 同じworkspaceの`spec.md`、contract、decisions、仕様由来テスト。

## 変更範囲

- 旧planで定めた成果範囲。詳細は凍結履歴を参照する。

## 受け入れ証拠

- T5 の仕様が **approved**(未承認なら着手せずブロック報告)。
  - `FileEntry` の作成日時が**「不明」を表現できる**形になり(001 用語 FileEntry)、既存の呼び出し・テストが退行なく追随している。
  - 作成日時・更新日時の**両ソート**が動き、作成日時ソートでは**不明な item を当該 item の更新日時をキーに代替**して並ぶ(002 REQ-002)。
  - 作成日時ソート選択時に、**不明の件数と「更新日時で代替して並べている」旨の警告**が表示される(取得可否での判定。ファイル種別では判定しない。0 件なら出さない・作成日時以外では出さない。002 REQ-011)。
  - **各行が作成日時(不明ならその旨)と更新日時の双方 + 作成日時が不明かを供給**し、行 UI がそれを識別表示する(002 REQ-013。色は `AppColors` のセマンティック色で、直書きしない)。
  - **`validate` が基準日時不明を警告する**(001 REQ-014)。基準日時が取得不能な日時トークンは**空文字列**を出力し(001 REQ-004)、更新日時・now で代替しない(001 INV-006)。
  - 取得不可を捏造しない(データと命名で `modifiedAt` の暗黙代入をしない)ことがテストで示される。代替はソートキーと表示に閉じる。
  - 該当 REQ/VER を覆うテストが通り、既存の 001/002/003/004/007 テストが緑のまま(退行なし)。`flutter analyze`/`dart format` PASS。色は `AppColors`。
- 参考: T5、002 `file_sort.dart`/`FileListView`/`RowView`、001 の日時トークンと `validate`、`AppColors`

## 作業記録

旧ASDD 0.xから、実際に記録されていたcheckpointだけを移行した。将来予定やlive状態には使わない。

- 2026-08-04 / 申し送り(いずれも T6 の変更対象外・人間の判断待ち): (1) **002 spec の VER 表の成果物パスが実体と食い違う** — REQ-011/012/013 の実テストは新規の `test/spec_002_file_list/created_at_sort_test.dart` / `created_at_sort_view_test.dart` にあるが、VER-001/002 は `controller_test.dart` / `file_list_view_test.dart` を指したまま(approved 済みのため更新には再承認が必要)。(2) `lib/main.dart` のデモデータは全件 `createdAt` を持つため、デモでは警告バナー・「作成日時: 不明」行が出ない(T3/T4 で実データが入る際に手動確認)。(3) **002 REQ-010(場所サブ情報)は未実装のまま**で VER-002 の宣言と食い違う — T3 で回収されるか計画側の確認が要る。
  - 2026-08-04 / PR #67 作成(Closes #64)。マージ待ちで停止。
  - 2026-08-04 / 計画変更 / **T6 の受け入れ条件に4項目を追記**(開発者指示「T6の受け入れ条件に追記してください」): 作成日時の「不明」表現への追随 / 作成日時ソートの代替キー(002 REQ-002) / 警告に代替した旨を含める(002 REQ-011) / 各行の両日時+不明フラグの供給と識別表示(002 REQ-013) / validate の基準日時不明警告(001 REQ-014)。あわせて参考欄に RowView・validate を追加。非規範の `specs/discovery.md` に残っていた旧方針(「004 は暫定『更新日時』まで」)も承認済み仕様に合わせて更新。
  - 2026-08-04 / T6 着手 / shimmen3141。Issue #64 を assign(claim)、ブランチ asdd/004-file-source/T6。
  - 2026-08-04 / T6 完了 / **core**: `FileEntry.createdAt` を `DateTime?`(不明を表現)、`DateTimeToken.baseDateOf` を追加し基準日時が取得不能なら空文字列(001 REQ-004 / INV-006)、`MissingSourceDateWarning` を追加し `validate` が選択ファイル×トークンごとに発行(001 REQ-014)。**002**: `FileSortMode.modifiedAt` 追加、`createdAtSortKey`(判明→その値 / 不明→当該 item の更新日時)で作成日時ソートを代替、`unknownCreatedAtCount` と `createdAtSortWarning`(0件・他ソートでは供給しない)、UI に「更新日時順」チップ・警告バナー・行の日時サブ情報(不明は `AppColors.danger` + 警告アイコン)。テスト +34(合計 221)。**221 tests PASS / analyze 0 issue / format PASS / spec_lint --strict PASS**。verifier PASS(試行1回・8条件充足)。検証ループ中の修正2件: 狭幅で行サブ情報が overflow → `Text.rich` 1行化、widget test の RichText 特定が別テキストを拾う → プレーンテキストで絞り込み。
  - 2026-08-04 / 仕様更新 / **002 の VER 表を実体に合わせ、ディレクトリ+種別の指定に変更**(開発者指示「2については早めにやりたい」)。単一ファイル固定だったため T6 で分割した `created_at_sort_test.dart` / `created_at_sort_view_test.dart` と食い違っていた(FINDINGS 記録済み)。**規範要件(REQ)の変更は無く、検証の成果物指定のみ**。002 spec を draft にし再承認を依頼する。
  - 2026-08-04 / 申し送りの回収 / 003 の潜在バグは **003 計画に T6 を追加**して回収(開発者指示)。
