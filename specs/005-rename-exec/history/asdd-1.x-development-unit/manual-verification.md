# 手動検証: platform rename adapterとdesktop undo

## 共通前提

- emulator・実機・desktop buildの起動、branch確認、hostとAI containerの違いは[`docs/development/emulator-verification.md`](../../docs/development/emulator-verification.md)を参照する。
- 消失してもよい専用fixtureだけを使い、元データでは確認しない。
- Androidとdesktopで**同じcommitから作ったbuild**を使う。対象commit、build識別、OS/device、操作結果、必要なscreenshotまたはcommand出力はIssue #96またはPR #116へ記録する。
- このfileへ実施statusや結果を書き戻さない。

## platform-rename-adapters

### Android SAF: 安全な未対応

- 環境: Android emulatorまたは実機。
- fixture: 専用folderに内容を識別できるtest fileを2件以上置き、操作前の名前・個数・内容を記録する。
- 操作と期待する観測:
  1. 「ファイルを選ぶ」からfixtureを読み込み、重複しないruleで実行する。
  2. 結果にAndroid SAFの安全なrenameが未対応である理由が表示され、成功件数は0件になる。
  3. 一覧の現在名、SAF URIが指すfileの名前・個数・内容がすべて操作前と一致する。
  4. 同じ操作を再度行っても結果と実体が変わらない。
- 記録する証拠: 対象commit/build/device、表示された未対応理由、操作前後の一覧、file名・個数・内容が不変であるcommand出力または画面。

### desktop: 排他的rename・失敗理由・undo

- 環境: Windows、Linux、またはmacOSの対象desktop build。
- fixture: 専用の一時folderに、内容を識別できるsource、同名競合用target、権限拒否を再現できるfolderを用意する。
- 操作と期待する観測:
  1. sourceを読み込み、実行後に一覧とfile managerの両方で旧pathが消え、新pathに同じ内容のfileが存在する。
  2. 同じ一覧のまま2回目のrenameを行い、更新された絶対pathが使われる。
  3. 同名targetが存在する名前へrenameし、`nameConflict`に対応する理由が表示される。sourceとtargetの名前・個数・内容は変化しない。
  4. folder write permissionを外したfixtureでrenameし、`permissionDenied`に対応する理由が表示される。sourceの名前・内容は変化せず、targetは作られない。確認後にpermissionを戻す。
  5. 正常rename直後の5秒以内に「元に戻す」を実行し、一覧と実fileが元の名前・内容へ戻る。
  6. 別の正常rename後に5秒を過ぎるとundoできず、実fileはrename後のままになる。
- 記録する証拠: 対象commit/build/OS、2回のrename前後の絶対pathと内容、競合・権限拒否の表示と不変な実体、期限内undo後と期限後の一覧・実file。
