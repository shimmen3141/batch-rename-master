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

## 013 REQ-005 / REQ-006 を製品として観測可能にする(`T05`から引き継ぐ)

**`T05`は改名portを作ったが、composition rootは切り替えていない。** したがって
**Androidは今も`SafRenameExecutor`(安全な未対応)のまま**で、`renameat2`は製品の
経路に載っていない。`T05`が切り替えなかった理由は2つある。

1. Androidのハンドルがまだ**SAFのdocument URI**で、pathとして解釈できない。切り替えても
   `p.dirname()`がURIを分解して`notFound`になるだけである。**このtaskが絶対pathを
   供給して初めて成立する。**
2. **005 contract revision 5.1が今なおAndroid SAFを未対応と規定している**
   (REQ-017、OP-004の`errors`、用語「ハンドル」)。いま切り替えると**承認済み契約に
   反する。**

**したがって013 REQ-005 / REQ-006 を製品として観測可能にするのはこのtaskである。**

## 変更範囲(`T05`から引き継いだ分)

- **`platform_rename_executor.dart`から`if (Platform.isAndroid) return const SafRenameExecutor();`の
  行を消す。** これだけでAndroidも`DesktopRenameExecutor`を通る。Android専用のexecutorは
  存在しない — 劣化は native が返す`fallbackRequired`が駆動する([ADR-003](../../decisions/ADR-003-os-identity-at-native-boundary.md))。
  同fileのdoc commentに理由と切り替え条件が書いてある。
- **005 contractの再承認を取る。** REQ-017とOP-004の`errors`から「Android SAF経路は
  revision 2の未対応を維持する」を、用語「ハンドル」の「Androidは SAF の document URI」を、
  実態へ合わせる。**REQ-025も対象へ含める** — 劣化経路の通常renameは既存fileを置換しうる
  ので、「一度も上書きrenameを使わない」がAndroidでは文字どおりには成立しない
  (INV-002の環境依存条項と013 REQ-005が実質を認めているが、**製品経路に載せるのはこのtask
  なので、ここで明文化する**)。**規範を触るので人間の再承認が要る。**
- **`saf_rename_executor.dart`はwiringから外れるが削除しない**(ADR-002の退避経路。
  Playの宣言が却下されたらAndroid未対応へ戻す)。negative testも維持する。

## 受け入れ証拠

- browserの操作(階層移動、選択、確定、cancel)が004 specどおりであることをwidget testで検査する。
- filesystemをportで抽象化し、testが実機に依存しないこと。
- 004の既存test(読み込み契約、置き換え、cancel、警告)が仕様変更後の形で継続PASSする。
- 選択したfileがどのfolderに属するかを保持する。**別の媒体(SDカード、USB)を跨いだ選択でfolderの区別が失われないこと**をtestで検査する。`T10`が対象folderの実在entry名をfolder単位で列挙し占有名を作るため、ここで潰すと衝突判定が正しい単位で行えない。
- **`listNames`(004 REQ-014)がAndroidで成功し、読み込んでいないfileとの衝突が実行前に警告として出ることを確認する**(005 REQ-026 / 例25)。**`T10`はこの受け入れをdesktopでしか満たしていない** — SAFは`pickFiles`で1fileずつの読み取り権限しか取らず親folderを列挙できないため、現在の`SafFileSource.listNames`は理由付きの失敗を返し、REQ-027により実行が止まる。app内browserが持つ列挙権限で`listNames`を実装し直すのはこのtaskである。`plan.md`の全体の受け入れ証拠「**Androidで**、同じことが成立する」はここが証拠元になる。
- `flutter test` / `flutter analyze` / `dart format --output=none --set-exit-if-changed .` がPASS。
- **Androidで`createPlatformRenameExecutor()`が`DesktopRenameExecutor`を返す**ことをtestで検査する(013 REQ-005 / REQ-006 が製品の経路に載る)。- **`T05`が受容した残余riskのうち2件を再判定する。** `T05`の「受容した残余risk」表の1行目(CのAndroid分岐の実挙動)と4行目(劣化経路)は、**このtaskが切り替えた時点で条件1(製品経路に載っている)が成立する**。AGENTS.mdの3条件で判定し直し、満たすものはここで閉じる(満たさないものは`T08`へ渡す)。`platform_rename_executor_test.dart`の「composition rootはまだAndroidを切り替えていない」testは**消さずにこの検査へ置き換える**。
- **`saf_rename_executor.dart`のnegative testが継続PASSする**(退避経路の維持)。
- **005 contractの再承認を得ている**(REQ-017 / OP-004 / REQ-025 / 用語「ハンドル」)。
- [`manual-verification.md`](manual-verification.md)で実機の選択導線を確認する。
- exact rangeの独立reviewがPASSする。

## 仕様被覆

`T03`が004 specへ定義し、開発者が承認したREQを実装する。**表はID だけを持つ。** 何を要求しているかは正本を読むこと — **説明を書き写すと、正本を直したときにここが古くなる**(`013:T03`で3回続いた。[finding](../../../../development-findings/2026-08-22-restating-a-requirement-outside-its-row-went-stale-twice.md))。`tool/check_normative_terms.py`が書き写しを機械的に検出する。

**`013`の権限のREQ-001〜004は`T06`と分担する。** 分担の内容は`T06`の`task.md`を見ること。

**このtaskが持つのはAndroid側だけである。** 004 REQ-011はdesktopの種類選択も、REQ-014はdesktopの`listNames`も規定しており、そちらは既に`004:T09`と`013:T10`が実装済みである。**どこがAndroid側かは004 specのVER-005が示す。**

**この表と機械検査は書き写しの一部しか止めない。** 検査(`tool/check_normative_terms.py`)が見るのは登録した literal の一致だけで、要求の**強さ**やliteralを持たない要求の範囲は検出できない。**実装前に正本を読むこと。****`task.json`の`covers`は空のままにする** — このworkspaceの構造検査は`covers`を**所有planのspec.mdのID**として引くので、他featureのIDを書くと未解決参照の警告になる(`013:T10`で観測。[finding](../../../../development-findings/2026-08-21-covers-cannot-express-cross-feature-coverage.md))。

| 正本 | 被覆するID |
|---|---|
| 004 spec | REQ-011、REQ-014、REQ-015、REQ-016、REQ-017、REQ-018、REQ-019、VER-005 |
| 013 spec | REQ-001、REQ-002、REQ-003、REQ-004、REQ-005、REQ-006 |

**`listNames`(004 REQ-014)のAndroid実装はこのtaskが持つ。** `013:T10`はdesktopでしか占有名を供給できておらず、`plan.md`の全体の受け入れ証拠「**Androidで**、読み込んでいないfileとの衝突が実行前に警告として出る」の証拠元はここである。

## 他の正本への申し送り

- **004 spec の SAF 由来の理由文が2箇所 stale になる。** REQ-003 の「SAF には作成日時の列が無いため」と検証節の「SAF は常に不明を返すため」は、Android が直接 path access へ移ると前提が変わる(`stat` にも作成時刻は無いので**結論は変わらない**が、理由が違う)。**要求そのものは有効**なので `T03` では触っていない。このtaskで Android の実装を入れる時点で理由文を直すこと。
- **005 contract の用語「ハンドル」が stale になる。** 現在の定義は「004 が供給する不透明な識別子(**Android は SAF の document URI**、デスクトップは絶対 path)」だが、`013:T03` の 004 REQ-002 で **Android も絶対 path へ変わる**。**規範部分ではない**(用語の例示)ので `T03` では触っていない。**このtaskが Android の実装を入れる時点で、005 contract の用語を更新して再承認を取ること。** 実装と用語が食い違ったまま残すと、契約を読んで実装する次のAgentが誤る(`013:T10` の OQ-007/008 と同じ型)。

## 作業記録

- 2026-08-13 / ADR-002の採用決定を受けて定義。

## Current state / handoff

- Last checkpoint: 定義しただけ。未着手
- Blocker category: dependency
- Waiting for: `T03`の仕様承認と`T06`の権限導線
- Requested action: なし
- Evidence revision: `dev@ec2e74f` + ADR-002
- Next Agent action: `T03`承認後に着手する。008との作業重複を先に確認する
