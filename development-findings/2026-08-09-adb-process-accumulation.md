# Development finding: オフラインAVDへの再試行でADBプロセスが異常残留した

- 観測日: 2026-08-09
- 観測した作業: `flutter devices` によるホスト側エミュレータ確認
- 改善先: project
- 関連Issue・commit・artifact: `docs/development/emulator-verification.md`

## 観測した事実

`flutter devices` はAndroid SDKの `adb.exe` を起動したが、`could not read ok from ADB Server`、`cannot connect to daemon` で失敗した。調査時には同一の `platform-tools/adb.exe` が2,137プロセス残留し、2026-08-05から起動中の `Pixel_8a` は `emulator-5554 offline` だった。期待値は、ローカルTCP 5037番をlistenするADBサーバー1つと、`device` 状態のエミュレータである。

対象パスを確認して残留ADBだけを停止すると1プロセスに戻った。ADBサーバーを再起動した時点ではAVDはまだ `offline` だったため、同じ `Pixel_8a` AVDも再起動した。約10秒後に `emulator-5554 device` となり、実ユーザーのホストセッションで `flutter devices` がAndroid、Windows、Chrome、Edgeの4デバイスを列挙して終了した。

## 影響とworkaround

- 影響: Android向けの手動受け入れ確認を開始できず、SDKや `ANDROID_HOME` の破損と誤認する可能性があった。多数の残留プロセスがホスト資源も消費した。
- その場のworkaround: 同一SDKパスのADBプロセスだけを停止し、ADBサーバーとオフラインAVDを再起動した。

## 仮説と改善案

- 仮説: 長期間オフラインだったAVDへFlutterまたはIDEが定期的に接続を再試行し、正常終了できないADBクライアントが蓄積した可能性が高い。残留プロセスの親は既に終了していたため、どのクライアントが生成元かは確定していない。
- 改善案: 共通のエミュレータ手順へ、ADB再起動、`offline` 時のAVD再起動、実体パスを確認したうえでの残留プロセス停止を順序付きで記載する。個人の絶対パスは書かない。

## 改善結果

`docs/development/emulator-verification.md` に汎用的な復旧手順を追加した。実機forward-testでは、ADBプロセス数1、`emulator-5554 device`、`flutter devices` exit 0を確認した。
