# Development finding: Androidに、desktop専用の更新日時ずらしの設定が1か月出ていた

- 観測日: 2026-09-29
- 観測した作業: `008:T43`の着手時。開発者が「この設定自体がwindowsでしか有効ではなかったと思う」と尋ね、Agentが仕様と配線を照らした
- 改善先: `008:T43`(直した)
- 関連artifact: `lib/data/rename_exec/platform_rename_executor.dart`、005 REQ-015(代表例16)、`013:T04`の決定4

## 観測した事実

- 005 REQ-015は「更新日時を設定できないプラットフォームでは、更新日時ずらしの設定を提示しない」、代表例16は「Android で設定画面を開く → 更新日時ずらしの設定が出ない」。`013:T04`の決定4は「**Androidで出さないままにする**」(現状維持)。
- 画面が設定を出すかは`executor is ModifiedAtWriter`で決まる(`RenameExecutionController.canShiftModifiedAt`)。
- `013:T07`(`e3b43af`、2026-08-24)がAndroidの改名をdesktopと同じ`DesktopRenameExecutor`へ切り替えた。この実装は`ModifiedAtWriter`も実装しているので、**Androidでも設定が出るようになった**。
- 以後のエミュレータ確認(`008`の複数task)ではフッターに「更新日時を一覧の並び順にずらす」が出ていたが、仕様との食い違いとして誰も拾わなかった。`008:T42`のtestは「Androidと同じ」構成としてこの切り替えを前提にしていた。
- 代表例16のtest(`modified_time_test.dart`)は`FakeRenameExecutor`(書けない実装)で画面を組んでおり、**composition rootがAndroidへ何を渡すか**は見ていなかった。`platform_rename_executor_test.dart`は「Androidはdesktopと同じ実装を通る」を型で固定していたが、その型が設定の表示まで決めることは見ていなかった。

## 影響

- Androidで既定OFFの設定が見え、ONにすると実行後に更新日時が変わっていた(実装上は動く)。**仕様で決めた範囲の外の機能が、承認なしに製品に載っていた。**データ損失ではないが、`013:T04`が「将来やるなら別planでREQ-015の変更と再承認を伴う」とした判断を黙って越えていた。

## その場の対処

- `008:T43`: Androidには改名だけを見せる包み`RenameOnlyExecutor`で渡す。写像のtestに「Androidの実行手段は`ModifiedAtWriter`でない」を足した。mutation `M473`(包みを外す)がKILLED。

## 改善の入力

- **能力を型で表す設計(`is ModifiedAtWriter`)では、実装を共有すると能力も共有される。**配線を切り替えるtaskは、その型が決めている画面上の能力を列挙して照らす必要がある。
- 代表例のtestが部品(controller・view)だけを見ていると、composition rootの配線で仕様が破れても通る。platformごとの写像のtestで、仕様が要求する能力の有無まで固定する。
