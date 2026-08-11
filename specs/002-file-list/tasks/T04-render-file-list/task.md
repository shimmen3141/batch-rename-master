# T04 ウィジェット: 2カラムリスト + チェックボックス + ソート切替

## 目的

- ウィジェット: 2カラムリスト + チェックボックス + ソート切替

## 入力と依存

- 依存: T03
- 同じworkspaceの`spec.md`、contract、decisions、仕様由来テスト。

## 変更範囲

- 旧planで定めた成果範囲。詳細は凍結履歴を参照する。

## 受け入れ証拠

- コントローラを描画する薄いウィジェット。各行に現在名/変更後名の2カラムとチェックボックス、上部にソート切替を表示。操作がコントローラに反映されプレビューが更新される。
  - 該当 REQ/VER を覆う widget test が `flutter test`(ヘッドレス)で通り、`flutter analyze`/`dart format` PASS。
- 参考: T1、PRD §3.1

## 作業記録

旧ASDD 0.xから、実際に記録されていたcheckpointだけを移行した。将来予定やlive状態には使わない。

- 2026-08-02 / 着手 / 担当: shimmen3141(Issue #18 を assign)。ブランチ asdd/002-file-list/T4。
  - 2026-08-02 / done / verifier PASS(試行1)+レビューパス(効率P2を1件修正: rows ゲッターの行ごと再計算を builder で1回に集約)。`FileListView`(ListenableBuilder で購読する薄い描画層)+ セマンティックカラー基盤 `AppColors`(ThemeExtension)/`appDarkTheme` を追加。ヘッダ(全選択トグル+件数)・ソートチップ4種・2カラム行(チェックボックス+現在名/変更後名)。VER-002 の file_list_view_test.dart 5件通過(spec_002 計32件)、`flutter analyze` 0 issue、`dart format` PASS。色は生値を app_colors.dart に集約し直書きなし(grep 確認)。REQ-002/004/006/007 を widget で被覆(REQ-003 ドラッグは T5)。
  - 2026-08-02 / スコープ観察(実装せず報告): 参考デザインの「⚠N件の問題」warn 表示(PRD §4.2 のリアルタイム警告 = 001 validate 由来)は approved の 002 spec の REQ に含まれないため T4 では出していない。002 spec への追加(→再承認)か後続機能で扱うかを要判断。
  - 2026-08-02 / PR #23 作成(asdd/002-file-list/T4 → dev, Closes #18)。マージ待ちで停止。最後の T5(ドラッグ並び替え)は T4 のマージ後に実行可。
  - 2026-08-02 / PR #23 マージ済み(dev)。#18 close。
