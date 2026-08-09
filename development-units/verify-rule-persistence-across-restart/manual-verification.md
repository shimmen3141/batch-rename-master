# 手動検証: 再起動をまたぐルール復元を受け入れ確認する

## 共通前提

- 起動、device接続、branch/commit確認は`docs/development/emulator-verification.md`に従う。
- 元名、自由text、連番、日時のうち複数種類を、順序と既定値以外の設定が識別できるruleとして作る。
- commit、build、OS/device、保存前、再起動後のruleをlive IssueまたはPRへ記録する。このfileへstatusを書かない。

## Android

1. ruleを作成し、previewへ反映されたtoken順と設定値を記録する。
2. `R`によるhot restartで同じruleが復元されることを確認する。
3. `flutter run`を終了するかappを強制停止し、processを完全終了する。
4. appをcold startし、token種別・順序・設定値が同じであることを確認する。
5. tokenを変更し、もう一度cold startして新しい値へ更新されることを確認する。

## desktop

1. Androidと同じ識別可能なruleを作る。
2. desktop appのprocessを完全終了して再起動する。
3. token種別・順序・設定値が同じであることを確認する。
4. tokenを変更し、次のprocess起動で新しい値へ更新されることを確認する。

## 記録する証拠

- 対象commit/build/OSまたはdevice。
- 保存前、hot restart後、cold start後のrule。
- 変更後の2回目cold start結果。
