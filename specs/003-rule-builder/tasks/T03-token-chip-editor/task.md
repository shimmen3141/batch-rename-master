# T03 ウィジェット: トークン Chip 列 + 追加ボタン + 削除 + D&D 並び替え

## 目的

- ウィジェット: トークン Chip 列 + 追加ボタン + 削除 + D&D 並び替え

## 入力と依存

- 依存: T02
- 同じworkspaceの`spec.md`、contract、decisions、仕様由来テスト。

## 変更範囲

- 旧planで定めた成果範囲。詳細は凍結履歴を参照する。

## 受け入れ証拠

- トークンを Chip として横並び表示し、5種の追加ボタン・各 Chip の削除・D&D 並び替えが `RuleController` に反映される。色は `AppColors` を使用。
  - 該当 REQ/VER を覆う widget test が通り、`flutter analyze`/`dart format` PASS。
- 参考: T1、T2、002 の `file_list_view.dart`(ReorderableList/ドラッグの実装)、`AppColors`

## 作業記録

旧ASDD 0.xから、実際に記録されていたcheckpointだけを移行した。将来予定やlive状態には使わない。

- 2026-08-02 / 着手 / 担当: shimmen3141(Issue #28 を assign)。ブランチ asdd/003-rule-builder/T3。
  - 2026-08-02 / done / verifier PASS(試行1)+レビューパス(P0/P1 なし)。`RuleBuilderView`(薄い描画層)+ `token_presets.dart`(既定トークン・区切り/日時プリセット・ラベルを集約)を追加。トークン Chip の横並び(横 ReorderableListView)・5種の追加ボタン・各 Chip 削除・D&D 並び替え(onReorderItem)を controller へ委譲。色は AppColors。REQ-002/003/004 を widget で被覆(rule_builder_view_test.dart 5件、spec_003 計17件)、`flutter analyze` 0 issue、`dart format` PASS。自由テキストの追加は暫定プレースホルダ(T4 でエディタ確定フローへ)。Chip タップ→編集(onEditToken)配線は T4。
  - 2026-08-02 / PR #33 作成(asdd/003-rule-builder/T3 → dev, Closes #28)。マージ待ちで停止。次は T4(詳細エディタ。依存 T2。T3 とは独立だが同一ファイル rule_builder_view.dart に onEditToken 配線を足すため T3 マージ後が無難)。
  - 2026-08-02 / PR #33 マージ済み(dev)。#28 close。
