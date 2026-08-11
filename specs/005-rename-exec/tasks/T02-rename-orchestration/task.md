# T02 RenameExecutor ポート + fake + 実行オーケストレーション(順序・ハンドル更新・部分失敗)

## 目的

- RenameExecutor ポート + fake + 実行オーケストレーション(順序・ハンドル更新・部分失敗)

## 入力と依存

- 依存: T01
- 同じworkspaceの`spec.md`、contract、decisions、仕様由来テスト。

## 変更範囲

- 旧planで定めた成果範囲。詳細は凍結履歴を参照する。

## 受け入れ証拠

- `test/spec_005_rename_exec/` のポート契約テストと実行順序テストが通る
  - fake で「改名のたびにハンドルが変わる」挙動を再現し、連続実行が壊れないことを検証している
  - **T8 で実機から得た実物の URI 断片**を使う検証が最低1本ある(改名で URI が変わる・戻り値の `name` が空、を fake が本物より親切にならない形で固定する)
  - `a→b, b→c` の入れ替えと、`a→b, b→a` の循環の双方で、既存ファイルを上書きしないことを検証している
  - 部分失敗時の状態が仕様どおりであることを検証している(成功分・失敗分の区別が観測できる)
- 参考: `lib/data/file_source/file_source.dart`(結果型 `Picked`/`Cancelled`/`Failed` の作り)、`lib/data/file_source/file_loading.dart`

## 作業記録

旧ASDD 0.xから、実際に記録されていたcheckpointだけを移行した。将来予定やlive状態には使わない。

- 2026-08-07 / 着手 / 担当: shimmen3141
  - 2026-08-07 / done / verifier PASS(試行1) / ミューテーション試験5種すべて検出。verifier 申し送り: notExecuted と stranded は同一要求を重複して含みうるので T4 の結果表示で二重に見せない
