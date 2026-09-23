# Development finding: `.worktrees/`でhostとcontainerが`.dart_tool`と生成registrantを書き換え合う

- 観測日: 2026-09-23
- 観測した作業: `008:T39` のエミュレータ確認(hostが`.worktrees/008-T39-browser-selection-navigation`で`flutter run`)と、同じworktreeでのcontainer内`flutter test`
- 改善先: AI container構成(`compose.ai.yml`の`.dart_tool`専用volumeはrepository直下だけ)、worktree運用の手順、commit手順
- 関連artifact: `.dart_tool/package_config.json`、`.dart_tool/hooks_runner/`、`linux/` `macos/` `windows/`の`generated_plugin*`

## 観測した事実

1. hostの`flutter pub get` / `flutter run`の後、containerの`flutter test`が`hook/build.dart`のcompileで失敗した。
   `.dart_tool/package_config.json`が`/C:/Users/.../Pub/Cache/...`を指していた。**repository直下の`.dart_tool`は
   container専用volumeだが、`.worktrees/`配下は共有されている。** containerで`flutter pub get`し、
   `.dart_tool/hooks_runner/`を消すと直る。逆にcontainerで`pub get`すると、hostは次の`flutter run`前に`pub get`が要る。
   T39の中でこれが3回起きた。
2. container内で`flutter test`を動かした後、working treeの`linux/` `macos/` `windows/`のplugin registrantから
   `file_selector`(macOSは`shared_preferences`も)の登録が消えていた。**それを`git add -A`でcommit(`3d5a3ae`)に含め、
   独立review attempt 3 がP1として検出した。** package_configがhostのpathを指していた時点のcontainer実行が
   pluginを解決できずに作り直したと推定する(未確定)。hostの`flutter run`が正しい内容へ戻し、それを
   「hostの変更」と誤読して一度は「消すかどうかは人間の判断」と報告していた。

## 影響

- 検証の手戻り(依存の取り直し)が、manual確認を依頼するたびに起きる。
- **生成物の意図しない差分が、機能と無関係なcommitに紛れ込む。** desktopのOS pickerを壊しうる差分だった。

## その場の対処

- `e2d4717`で生成registrantを`dev`の内容へ戻した(`git diff 0fd66d1 -- linux macos windows`が空)。
- task側のcommitでは`git add -A`を使わず、変更したpathを明示してstageする。

## 改善の候補

- `compose.ai.yml`で`.worktrees/*/.dart_tool`もcontainer専用にする(host側の変更。人間の作業)。
- commit前に`git diff --cached --stat`で、task外のpath(生成registrant等)が入っていないかを確かめる手順を明記する。
