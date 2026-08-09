# 手動検証: リネーム実行を完成させる

## 共通前提

- emulator・実機・desktop buildの起動、branch確認、hostとAI containerの違いは[`docs/development/emulator-verification.md`](../../docs/development/emulator-verification.md)を参照する。
- 消失してもよい専用fixtureだけを使い、元データでは確認しない。
- 対象commit、build、OS/device、操作結果、必要なscreenshotまたはcommand出力は、対応するwork-package IssueまたはPRへ記録する。このfileへ実施statusや結果を書き戻さない。

## warning-confirmation-and-results

- 環境: Androidまたはdesktopの代表build。
- fixture: 同じ拡張子のtest fileを2件以上読み込む。
- 操作と期待する観測:
  1. 重複しないruleで実行し、確認なしで開始して成功件数が表示される。
  2. 同名になるruleを設定し、対象名を識別できる警告と確認dialogが出る。
  3. cancelし、一覧と実fileが変化しない。
  4. 強制実行し、自動解決後の名前と成功・失敗・未実行・除外の件数が重複なく表示される。
- 記録する証拠: 対象build、確認dialogと結果表示、実fileがcancelで不変だった観測。

## rule-not-configured-ui

- 環境: Androidまたはdesktopの代表build。
- 操作と期待する観測:
  1. tokenが0件の状態でrenameを開始できず、rule設定の案内が表示される。
  2. tokenを1件追加すると通常のpreview、警告、rename操作へ戻る。
  3. tokenを再び0件にすると未設定状態へ戻る。
- 記録する証拠: 0件→1件→0件の各画面と操作可否。

## platform-rename-adapters

### Android SAF

- 環境: Android emulatorまたは実機。対象commit/buildをIssueへ記録する。
- fixture: `adb shell "mkdir -p /sdcard/Download/rename_test_a"`等で専用folderを作り、test fileを2件以上置く。
- 操作と期待する観測:
  1. 「ファイルを選ぶ」→「すべて」でfixtureを読み込み、重複しないruleで実行する。
  2. 一覧の現在名が目標名へ変わり、`adb shell ls /sdcard/Download/rename_test_a`でも旧名が消えて新名が存在する。
  3. **同じ一覧のまま**別のruleでもう一度実行し、2回目も成功する。1回目にSAFが返した新しいdocument URIを後続操作へ使えていることを観測する。
  4. SAFの戻り名が空でも、一覧には要求した目標名が表示される。
- 記録する証拠: 2回の実行前後の一覧、`adb shell ls`出力、対象device/build。

### desktop

- 環境: Windows、Linux、またはmacOSの対象desktop build。
- fixture: 専用の一時folderに内容を識別できるtest fileを2件以上作る。
- 操作と期待する観測:
  1. fixtureを読み込み、実行後に一覧とfile managerの両方で旧pathが消え、新pathに内容を保ったfileが存在する。
  2. 同じ一覧のまま2回目のrenameを行い、更新された絶対pathが使われる。
  3. 同名のfileが既に存在する目標では、既存fileの内容が上書きされず失敗理由が表示される。
- 記録する証拠: 2回の実行前後のpathと内容、衝突先の内容が不変だった観測、対象OS/build。

## session-undo

- 環境: Android SAFとdesktopの両方。
- 操作と期待する観測:
  1. rename成功直後の期限内に「元に戻す」を実行し、成功したfileだけが実行前名へ戻る。
  2. 期限後はundoできない。
  3. 部分失敗した実行では、成功した分だけを新しいhandleから逆順に戻せる。
- 記録する証拠: rename後・undo後の一覧と実file、期限前後の操作可否。

## desktop-modified-time

- 環境: desktop build。
- 操作と期待する観測:
  1. optionがdesktopだけに表示され、既定ではOFFである。
  2. OFFではmodified timeを変えず、ONではrename成功後に表示順の規則どおりずれる。
  3. modified time更新だけが失敗してもrename成功自体は維持され、副次処理の失敗として表示される。
- 記録する証拠: optionの表示・既定値、実fileのmodified time、失敗時のrename後実体。

## unit-integration

- Android SAFでは読み込み→警告確認→実rename→同じ一覧で再rename→undoまでを一連で確認する。
- desktopでは上記にmodified-time optionを加え、一覧、実path、内容、更新日時が各結果と一致することを確認する。
- work-packageごとの証拠と同じcommit/buildを対象に、unit全体の独立reviewで最終判定する。
