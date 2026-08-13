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

## 受け入れ証拠

- 未許可・許可・設定画面から戻った直後の各状態で、表示と操作可否が仕様どおりであることをwidget testで検査する。
- 権限判定をportで抽象化し、testで両状態を再現できるようにする(実機に依存しないこと)。
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
