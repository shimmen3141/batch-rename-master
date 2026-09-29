# T43 更新日時ずらしをフッターから歯車の設定ボタンへ移す

## 目的

リネーム画面のフッターにある「**更新日時を一覧の並び順にずらす**」のチェックボックス(005 REQ-014)を、**ヘッダーなどに足す新しい歯車の設定ボタン**の中のオプションへ移す。フッターを命名ルールとリネームだけにする。

## 受領した要望(2026-09-29、原文)

> 「更新日時を一覧の並び順にずらす」のチェックボックスは設定ボタン内にオプションとして設置したいです。

> 「更新日時を一覧の並び順にずらす」は別タスクにします。なお、設定ボタンは既存のリネーム設定ボタンではなく、歯車マークの新しいボタンをヘッダーなどに追加するイメージでした。

観測の出所は`008:T42`のエミュレータ確認2回目・3回目のやりとり。

## 入力と既存taskとの境界

- 005 REQ-014(更新日時ずらしの入切。既定OFF)・REQ-015(設定できない端末では出さない)。**置き場所は縛っていない**。spec の代表例16(「Android で設定画面を開く → 更新日時ずらしの設定が出ない」)は、Androidでも切り替えが出ている今の実装(`005:T07`・`013`)と食い違って見える。着手時にspecの現在の文言と照らし、食い違うならspec側の整理を人間へ尋ねる。
- `008:T42`の選択モードのフッターは**通常のフッターの大きさに固定**し、説明が余った高さを埋める(足りなければ縮める、入る高さが無ければ出さない)。フッターから切り替えを外すと:
  - 狭幅(命名ルール+リネーム): 選択モードの説明カードとbuttonが命名ルールのカードとリネームにちょうど揃う(T42のtestの「命名ルール + リネーム」構成)。
  - ルールが空: 命名ルールの位置が低いbuttonなので、説明カードが今より縮む。
  - **広幅(desktopの2ペイン)**: 通常のフッターがリネームだけになり、**今の作りでは選択モードの説明が出なくなる**。このtaskで広幅の説明の置き方を決める。
- ヘッダー(`AppBar`)は`008:T42`で`#2E2B38`の固定色にした。歯車はこの上に置く想定。

## 決めること(着手時に開発者へ一問ずつ確かめる)

- 歯車の置き場: ヘッダー(`AppBar`の右端)か、別の場所か。広幅でも同じ場所か。
- 歯車を押したときの形: メニュー(ポップアップ)・下から出るシート・設定画面のどれか。更新日時ずらしのほかに入れるものがあるか。
- 切り替えが入っていることの見え方: フッターから消えると、ONのまま実行して更新日時が変わることに気づきにくい。フッターやリネームの確認に「更新日時もずらす」を示すか。
- 広幅での選択モードの説明の置き方(上の境界を参照)。

## 決定(2026-09-29)

| 論点 | 決定 | 決定者 |
|---|---|---|
| 歯車の置き場 | **ヘッダー(「一括リネーム」の帯)の右端**。狭幅・広幅とも同じ(ほかの案: フッターのリネームボタンの横) | 開発者 |
| 押したときの形 | **メニュー(ポップアップ)**。項目はチェック付きで、選ぶと入切する(ほかの案: 下から出るシート / 設定画面) | 開発者 |
| ONの見せ方 | **何も出さない**(メニューのチェックだけ)。ほかの案: 歯車に印 / 印+フッターに1行 | 開発者 |
| 有効な設定が無い端末 | **歯車そのものを出さない**(開発者の要望)。今の項目は更新日時ずらしだけなので、Androidでは歯車が出ない | 開発者 |
| **Androidで設定が出ていた食い違い** | **直す**。005 REQ-015・代表例16・`013:T04`の決定4は「Androidでは出さない」だが、`013:T07`以後Androidにも出ていた([finding](../../../../development-findings/2026-09-29-android-shows-desktop-only-setting.md))。仕様を変えるのではなく仕様へ戻す | Agent(仕様どおりへ戻す。開発者へ報告済み) |
| 広幅の選択モードの説明 | **操作の左に並べる1段**(小さな2行。フッターの大きさは固定のまま。入らなければ縮める)。ほかの案: 広幅だけ高さの固定をやめる / 広幅では説明を出さない | 開発者 |

## machine検証範囲と引き受け先

- **CIで閉じる**: widget test(歯車の有無・メニューでの入切・フッターに出ないこと・composition rootがヘッダーへ置くこと・Androidの写像が更新日時を書けないこと・フッターの大きさと説明の配置)とmutation。
- **このtaskのmanual(Androidエミュレータ)**: Androidで歯車も切り替えも出ないこと、フッターと選択モードのフッターの見た目(縦向き = 狭幅、横向き = 広幅の2ペイン)。
- **desktop(Windows)の歯車とメニューの見た目**: エミュレータでは出ない(Androidでは歯車を出さないため)。振る舞いはwidget testで閉じる(test環境はLinux = desktopで、composition rootの歯車まで通る)。見た目の確認は手順書の任意の節とし、行わなければ残余riskとして記録する。引き受け先のtaskは無い。

## 実装の記録(2026-09-29)

実装は Claude Opus 5.5。起点は`dev`@`c42f131`、branch `asdd/008-ui-alignment/T43-settings-gear-shift-toggle`、code `683e4ce`。

- `lib/ui/rename_exec/rename_settings_button.dart`(新規): `RenameSettingsButton`。`canShiftModifiedAt`が偽なら何も出さない。`PopupMenuButton`に`CheckedPopupMenuItem`(「更新日時を一覧の並び順にずらす」)。`shiftModifiedAtKey`はここへ移した。
- `lib/main.dart`: `AppBar.actions`へ歯車を置く。app内browserのヘッダーには置かない(別の画面)。
- `lib/ui/file_list/file_list_view.dart`: フッターの`_ShiftModifiedAtToggle`を消した。選択モードのフッターは、狭幅(命名ルールがある)では説明のカードが操作の上(カードは命名ルールのカードと、操作はリネームとちょうど揃う)、広幅では**1段**(説明`_RemovalNoteCompact`を操作の左に)。`008:T42`で足した「説明の入る高さが無ければ出さない」判定は、その構成が無くなったので外した。
- `lib/data/rename_exec/platform_rename_executor.dart`: Androidは`RenameOnlyExecutor(DesktopRenameExecutor())`。改名は中身へそのまま渡し、`ModifiedAtWriter`は見せない。
- 005 spec・contractは変えていない(REQ-014/015は置き場所を縛らない。代表例16はこの修正で成り立つ。例の「設定画面を開く」は、歯車が出ないことで満たす)。

### 自動検証

- `removal_selection_mode_test.dart`: フッターの大きさの表を3構成へ(狭幅 = 命名ルール+リネーム / 広幅 = リネームだけ、一覧の最小幅480 / ルールが空)。どれも更新日時を書ける実行手段で組み、フッターに切り替えが出ないこと、通常のフッターに空きが無いこと、モードの出入りで大きさが変わらないこと、**説明がどの構成でも出る**こと(狭幅は操作の上、広幅は操作の左で縦の中央が揃う)を見る。狭幅で説明のカードと操作が命名ルールのカードとリネームにちょうど重なる(位置と高さ)testを足した。
- `modified_time_test.dart`(REQ-015): 書けない実装では歯車も項目も出ない(代表例16)。書ける実装ではヘッダーに歯車があり、フッターには出ず、メニューで入れる → 開き直すとチェックされている → もう一度で切れる。
- `platform_rename_executor_test.dart`: Androidは`RenameOnlyExecutor`で中身が`DesktopRenameExecutor`、**`ModifiedAtWriter`でない**。desktopは`ModifiedAtWriter`。包みは改名を中身へ渡す。
- `widget_test.dart`: composition root(`DemoApp`)のヘッダーに歯車があり、メニューに項目が出る。
- 広幅の説明の縮み(一時的な測定。testには残していない): 一覧の幅480で0.98倍、560以上で1.0倍。
- 検証: `flutter test` 1017件PASS、`flutter analyze`・`dart format` PASS。

### mutation

`M103`・`M457`・`M458`・`M460`の`find`を追随させ、`M462`(説明を出さない判定)は判定を外したので表から除いた。`M473`〜`M478`を足した。`command`を`flutter test test/spec_002_file_list/removal_selection_mode_test.dart test/spec_005_rename_exec/modified_time_test.dart test/spec_005_rename_exec/platform_rename_executor_test.dart test/widget_test.dart`へ絞った13件の生出力(NOTEは省いた):

```text
M103 | KILLED | exit 1
M457 | KILLED | exit 1
M458 | KILLED | exit 1
M460 | KILLED | exit 1
M461 | SURVIVED | exit 0: the tests passed with the mutation applied
M463 | KILLED | exit 1
M464 | KILLED | exit 1
M473 | KILLED | exit 1
M474 | KILLED | exit 1
M475 | KILLED | exit 1
M476 | KILLED | exit 1
M477 | KILLED | exit 1
M478 | KILLED | exit 1
13 mutations: 12 KILLED, 1 SURVIVED, 0 SKIPPED
M461 | KILLED | exit 1
1 mutations: 1 KILLED, 0 SURVIVED, 0 SKIPPED
```

(`M461`は全件のcommandで確かめ直した。殺すのは範囲外の`test/spec_004_file_source/load_affordance_test.dart`で、`008:T42`と同じ。)

## Current state / handoff

- Last checkpoint: 実装と自動検証(2026-09-29、code `683e4ce`)。
- Blocker category: なし(独立review → manual)。
- Waiting for: 独立review attempt 1(全範囲`c42f131..HEAD`)。その後manual 1回目(code `683e4ce`)。
- Requested action: なし(review後にmanualを依頼する)。
- Evidence revision: 起点は`dev`@`c42f131`。
- Next Agent action: Draft PRを作る → 独立review → manual依頼 → 結果を記録 → merge判断。
