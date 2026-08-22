# T07 app内file browserを実装する

## 目的

`T03`で承認された004 specどおり、Androidのfile選択をapp内のbrowserにする。SAFの選択導線を置き換える。

## 入力と依存

- `T03`で承認された004 spec。
- `T06`の権限状態(許可されていなければfilesystemを辿れない)。
- 現行実装: `lib/data/file_source/`、`lib/ui/file_source/file_source_bar.dart`、`lib/ui/file_source/file_kind.dart`。
- **008のUI整合**。008がfile_source_barの構成を触るので、着手時にどちらが先かを確認する。

## 変更範囲

- Android向け`FileSource`実装をSAFからpath baseへ差し替える。
- file browserの画面。
- `FileEntry`のhandleがAndroidで絶対pathになることに伴う周辺の調整。

**desktopは変えない。** OS pickerのままである(ADR-002 / `T03`)。

## 受け入れ証拠

- browserの操作(階層移動、選択、確定、cancel)が004 specどおりであることをwidget testで検査する。
- filesystemをportで抽象化し、testが実機に依存しないこと。
- 004の既存test(読み込み契約、置き換え、cancel、警告)が仕様変更後の形で継続PASSする。
- 選択したfileがどのfolderに属するかを保持する。**別の媒体(SDカード、USB)を跨いだ選択でfolderの区別が失われないこと**をtestで検査する。`T10`が対象folderの実在entry名をfolder単位で列挙し占有名を作るため、ここで潰すと衝突判定が正しい単位で行えない。
- **`listNames`(004 REQ-014)がAndroidで成功し、読み込んでいないfileとの衝突が実行前に警告として出ることを確認する**(005 REQ-026 / 例25)。**`T10`はこの受け入れをdesktopでしか満たしていない** — SAFは`pickFiles`で1fileずつの読み取り権限しか取らず親folderを列挙できないため、現在の`SafFileSource.listNames`は理由付きの失敗を返し、REQ-027により実行が止まる。app内browserが持つ列挙権限で`listNames`を実装し直すのはこのtaskである。`plan.md`の全体の受け入れ証拠「**Androidで**、同じことが成立する」はここが証拠元になる。
- `flutter test` / `flutter analyze` / `dart format --output=none --set-exit-if-changed .` がPASS。
- [`manual-verification.md`](manual-verification.md)で実機の選択導線を確認する。
- exact rangeの独立reviewがPASSする。

## 仕様被覆

`T03`が004 specへ定義し、開発者が承認したREQを実装する。**`task.json`の`covers`は空のままにする** — このworkspaceの構造検査は`covers`を**所有planのspec.mdのID**として引くので、他featureのIDを書くと未解決参照の警告になる(`013:T10`で観測。[finding](../../../../development-findings/2026-08-21-covers-cannot-express-cross-feature-coverage.md))。

| 正本 | 被覆するID |
|---|---|
| 004 spec | REQ-011(Android側)、REQ-015(app内browser)、REQ-016(選択は同一folder内)、REQ-017(そのまま見せる)、REQ-018(`/Android/data/`は改名できない旨)、REQ-019(権限が無い間は開かない)、REQ-014(`listNames`のAndroid実装)、VER-005 |
| 013 spec | REQ-001〜004(権限の導線。`T06`と分担する) |

**`listNames`(004 REQ-014)のAndroid実装はこのtaskが持つ。** `013:T10`はdesktopでしか占有名を供給できておらず、`plan.md`の全体の受け入れ証拠「**Androidで**、読み込んでいないfileとの衝突が実行前に警告として出る」の証拠元はここである。

## 作業記録

- 2026-08-13 / ADR-002の採用決定を受けて定義。

## Current state / handoff

- Last checkpoint: 定義しただけ。未着手
- Blocker category: dependency
- Waiting for: `T03`の仕様承認と`T06`の権限導線
- Requested action: なし
- Evidence revision: `dev@ec2e74f` + ADR-002
- Next Agent action: `T03`承認後に着手する。008との作業重複を先に確認する
