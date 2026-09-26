# Development finding: release buildが一度も作られず、native build hookの欠陥が1か月残った

- 観測日: 2026-09-25
- 観測した作業: `008:T13`の手動確認で、scrollの滑らかさをdebugではなくreleaseで見るため、開発者がhostで`flutter run --release`を実行した
- 改善先: `013:T13`(直した)、manual確認の既定(`docs/development/emulator-verification.md`)、build hookのtest
- 関連artifact: `hook/build.dart`、`test/hook/build_hook_test.dart`

## 観測した事実

`flutter run --release -d emulator-5554` が次で失敗した。

```text
Hook.build hook of package:batch_rename_master has invalid output
Asset "...libbatch_rename_native.a..." is sent to package "batch_rename_master" for linking,
but that package does not have a link hook.
```

- `hook/build.dart`(`013:T05`、2026-08-22)は`CLibrary.build()`を使っていた。`CLibrary`はrelease(`linkingEnabled == true`)で**静的ライブラリを同じpackageのlink hookへ送る**が、`hook/link.dart`は無い。
- `013:T05`〜`T08`、`008`の手動確認は**すべてdebug build**だった(`docs/development/emulator-verification.md`の手順が`flutter run`だけを書いている)。**release buildは一度も作られていなかった。**
- 既存のhook testは`buildCodeAssets == false`の経路だけを見ていた。`hooks`の`testBuildHook`は`linkingEnabled`を既定で`false`にするので、release経路は明示しないと走らない。

## 影響

- **releaseのappを作れない。** 配布(Play提出)の直前まで気づかない種類の欠陥だった。
- scrollの滑らかさなど、**debugでは判断できない観測**をreleaseで確かめる手段が無かった。

## その場の対処

- `013:T13`: `CBuilder.library`で動的ライブラリを直接app bundleへ送る(debugと同じ形)。build hookを`linkingEnabled: false / true`の両方で**実際にCをbuildして**検査するtestを足し、修正前の実装で`true`側が落ちることを確かめた。mutation `M435`/`M436`。

## 改善の候補

- 手動確認の共通手順に「release buildが通ること」を、native・build設定に触れたtaskの完了条件として足す。
- 速度・滑らかさを観測するmanualは、最初から`--release`で行う。
