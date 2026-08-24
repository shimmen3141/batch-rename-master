# T06 権限取得導線を実装する

## 目的

`T02`で承認された方針どおり、`MANAGE_EXTERNAL_STORAGE`を要求し、許可・不許可の状態を画面へ反映する。

## 入力と依存

- `T02`で承認された仕様。
- `Environment.isExternalStorageManager()`(付与の確認)、`Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION`(設定画面への誘導)。

## 変更範囲

- `AndroidManifest.xml`への`MANAGE_EXTERNAL_STORAGE`宣言。**AI sandboxの境界に触れないことを確認する**(`.github/workflows`や`.devcontainer/`ではないので通常のpushでよい)。
- 権限状態を持つcontrollerと、未許可時の表示。
- 設定画面への誘導と、そこから戻ったときの再確認。

**「なぜこの権限が要るか」を利用者へ説明する文言を必ず置く。** 「すべてのファイルへのアクセス」は強い権限で、説明なく求めるappは信用されない。文言は`T02`で承認された仕様に従う。

## machine検証する範囲と引き受け先(AGENTS.md の宣言)

このtaskは**CIで実行できない領域**(Androidの実行時権限、設定画面への遷移、
`AndroidManifest.xml`の効き方)を含む。**どこまでをこの環境で機械検証するか**と
**その外側を誰が引き受けるか**を先に宣言する。**宣言の外側の指摘は安全網の穴として扱う。**

| 対象 | この環境での検証 | 引き受け先 |
| --- | --- | --- |
| 権限状態に応じたUIの表示・操作可否(REQ-001 / REQ-003) | **widget testで閉じる。** portをfakeにして未許可・許可・拒否後を再現する | — |
| 要求のタイミング(REQ-002: 起動時に飛ばさない、読み込み操作で初めて確認する) | **widget testで閉じる。** portへの呼び出し順を観測する | — |
| 直前確認(REQ-004: 読み込み直前と実行直前に毎回確認する) | **widget test / unit testで閉じる。** 状態を途中で変えて再確認されることを観測する | — |
| **INV-002 / VER-003**(未許可でfilesystemへ書き込まない) | **testで閉じる。** 権限portを未許可に固定し、**書き込み側のportへの呼び出しが1件も無い**ことを観測する | — |
| `MANAGE_EXTERNAL_STORAGE`の実際の付与・取り消し | **できない**(実機が要る) | `013:T08` / [`manual-verification.md`](manual-verification.md) |
| 設定画面(`ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION`)への遷移と復帰 | **できない**(実機が要る) | `013:T08` / [`manual-verification.md`](manual-verification.md) |
| `AndroidManifest.xml`の宣言が効くこと、Android build | **できない**(SDK/NDKが無い) | `013:T08`(host側のbuild) |
| platform channel の Kotlin 側実装 | **できない**(compileできない)。Dart側は port の fake で閉じる | `013:T08` |
| Playの審査に通るか | **できない** | 人間(`spec.md`の未解決。通らなければADR-002の退避経路へ) |

## 受け入れ証拠

- 未許可・許可・設定画面から戻った直後の各状態で、表示と操作可否が仕様どおりであることをwidget testで検査する。
- 権限判定をportで抽象化し、testで両状態を再現できるようにする(実機に依存しないこと)。
- **INV-002 / VER-003**(013 spec): 権限portを未許可に固定した状態で読み込みと実行を起動し、**filesystem portへの書き込み呼び出しが1件も発生しない**ことをtestで検査する。
- `flutter test` / `flutter analyze` / `dart format --output=none --set-exit-if-changed .` がPASS。
- [`manual-verification.md`](manual-verification.md)で、実機の許可・拒否・設定画面往復を確認する。
- exact rangeの独立reviewがPASSする。

## 作業記録

- 2026-08-13 / ADR-002の採用決定を受けて定義。

## Current state / handoff

- Last checkpoint: 定義しただけ。未着手
- Blocker category: dependency
- Waiting for: `T02`の仕様承認
- Requested action: なし
- Evidence revision: `dev@ec2e74f` + ADR-002
- Next Agent action: `T02`承認後に着手する。権限判定をportにしてからUIを書く
