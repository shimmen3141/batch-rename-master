# T03 UI 入口: フォルダを開く / ファイルを選ぶ(追加・除去、fake で結線・widget test)

## 目的

- UI 入口: フォルダを開く / ファイルを選ぶ(追加・除去、fake で結線・widget test)

## 入力と依存

- 依存: T02, 002:T02
- 同じworkspaceの`spec.md`、contract、decisions、仕様由来テスト。

## 変更範囲

- 旧planで定めた成果範囲。詳細は凍結履歴を参照する。

## 受け入れ証拠

- 「フォルダを開く」「ファイルを選ぶ」の導線から `FileSource` を呼び、結果が 002 の作業セットに**追加**される(複数回で別フォルダ分も蓄積)。選択の除去・全消去導線がある。空(キャンセル)時は無変化(fake を注入した widget test で検証)。
  - `Failed` のとき作業セットを変えずに**エラー(理由)をユーザーへ通知**する(004 REQ-008。`Cancelled` では通知しない)。
  - **各行に場所(元フォルダ)がサブ情報として表示される**(002 REQ-010。T6 で作った行サブ情報に並べる。同名・非同名に関わらず常時表示。色は `AppColors`)。REQ-010 は T2 でデータ供給まで実装済みで**表示が未実装**のため、ここで回収する。
  - 該当 REQ/VER を覆う widget test が通り、既存テストが緑のまま(退行なし)。`flutter analyze`/`dart format` PASS。色は `AppColors`。
- 参考: T1、T2、002 の `FileListView` と T6 の `_DateSubInfo`、`AppColors`

## 作業記録

旧ASDD 0.xから、実際に記録されていたcheckpointだけを移行した。将来予定やlive状態には使わない。

- 2026-08-04 / 設計判断 / バーは `FileListController` を**購読しない**設計にした。購読すると、003 の `RuleBuilderWorkspace` が `initState` でビルド中に `setRule`(= `notifyListeners`)を呼ぶため「ビルド中の setState」エラーになる。**003 は T3 の変更対象外**のため触らず、表示が作業セットに依存しないバー側で依存を持たない形に。機能欠落なし(空での「すべて外す」は無変化・無通知)。**003 の潜在バグは未解消**(同コントローラを購読する兄弟ウィジェットを近傍に置くと再発)。FINDINGS に記録。
  - 2026-08-04 / 申し送り(T3 の変更対象外・人間の判断待ち): (1) **004 VER-003 の成果物パスが実体と食い違う** — T3 の widget テストは `test/spec_004_file_source/ui_entry_test.dart` だが VER-003 は `wiring_test.dart` を指したまま。002 で実施した「ディレクトリ + 種別」指定への変更を 004 spec にも適用すると再発を防げる(approved 済みのため再承認が必要)。002 VER-002 の「現在:」列挙にも `location_view_test.dart` が未記載。(2) 003 の潜在バグ(上記)の回収。(3) 行の × は `sourceHandle` を持つ行にのみ出る — T4 で全エントリにハンドルを付ける前提(T2 申し送り)が守られることの確認が必要。
  - 2026-08-04 / PR #71 作成(Closes #53)。マージ待ちで停止。
  - 2026-08-04 / PR #71 マージ。
  - 2026-08-04 / 計画変更 / **T3 の受け入れ条件に2項目を追記**(開発者指示「1についてはT3の受け入れ状態に含めてください」): (a) **002 REQ-010 の場所サブ情報表示**(T2 でデータ供給まで実装済み・表示が未実装だった分の回収。T6 の `_DateSubInfo` に並べる)、(b) 004 REQ-008 の `Failed` 時のエラー通知(spec にはあったが T3 の条件に明示されていなかったため詳細化)。変更対象に `test/spec_002_file_list/` を追加。
  - 2026-08-04 / T3 着手 / shimmen3141。Issue #53 を assign(claim)、ブランチ asdd/004-file-source/T3。
  - 2026-08-04 / T3 完了 / `FileSourceBar`(lib/ui/file_source/)を追加: 「フォルダを開く」「ファイルを選ぶ」で `loadFolderInto`/`loadFilesInto` を呼び作業セットへ追加、「すべて外す」で全消去、`Failed` は SnackBar で理由通知(`Cancelled`・成功は通知なし)。`FileListView` の各行に **× で個別除去**(元場所ハンドルを持つ行のみ)と、サブ情報の先頭に**場所(元フォルダ)を常時表示**(002 REQ-010 の回収)。`lib/main.dart` にバーを配線(デモ用 `FakeFileSource`。**T4 で実 `FileSource` に差し替える**)。テスト +16(合計 237: ui_entry_test 12 / location_view_test 4)。**237 tests PASS / analyze 0 issue / format PASS**。verifier PASS(試行1回・4条件充足)。
  - 2026-08-04 / 仕様更新 / **004 spec の VER 表を「ディレクトリ + 種別」指定へ変更**(開発者指示「2についてもあなたの推奨通りに」)。T3 の `ui_entry_test.dart` と VER-003 のパスが食い違っていた分の解消で、002 spec と同じ形に揃えた。**規範要件(REQ)の変更は無し**。004 spec を draft にし再承認を依頼する。あわせて 002 spec の VER-002 の内訳(非規範)に `location_view_test.dart` を追記(内訳は非規範のため 002 の Status は approved のまま)。
  - 2026-08-04 / デモデータ / `lib/main.dart` のサンプルに **`createdAt` が不明な1件(`Screenshot_20260304.png`)を追加**(開発者指示)。作成日時順ソートで警告帯と「作成日時: 不明」行をエミュレータで目視確認できるようにするため。221 tests PASS のまま(退行なし)。
