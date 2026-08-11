# T03 警告表示(重複・桁不足・空名・基準日時不明)をプレビューに出す

## 目的

- 警告表示(重複・桁不足・空名・基準日時不明)をプレビューに出す

## 入力と依存

- 依存: T01
- 同じworkspaceの`spec.md`、contract、decisions、仕様由来テスト。

## 変更範囲

- 旧planで定めた成果範囲。詳細は凍結履歴を参照する。

## 受け入れ証拠

- 001 の `Warning` 4種それぞれについて、該当する行が識別できることをウィジェットテストで検証している
  - **基準日時が取れないとき**に、どのファイルのどのトークンが空になるかが分かる形で提示される
  - 警告が 0 件のときは何も表示しない
  - 色は `AppColors` のセマンティック色を用いる(直書きしない)
- 参考: `lib/core/rename_engine.dart` の `validate` と `Warning` 4種、`lib/ui/file_list/file_list_view.dart` の警告帯(004 T6 で作った `created-at-fallback-warning`)

## 作業記録

旧ASDD 0.xから、実際に記録されていたcheckpointだけを移行した。将来予定やlive状態には使わない。

- 2026-08-07 / 着手 / 担当: shimmen3141
  - 2026-08-07 / done / verifier PASS(試行1) / ミューテーション試験4種すべて検出。警告帯は既定で折りたたみ(件数と種別内訳は常時表示)。P2: warnings getter は build ごとに validate を再評価
