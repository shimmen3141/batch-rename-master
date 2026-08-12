# Development finding: native asset build hookがcontainerの`flutter test`を止めた

- 観測日: 2026-08-11
- 観測した作業: 005再開時のbaseline検証(`dev@63de09c`)
- 改善先: projectのAI container構成(`.devcontainer/Dockerfile`)、`hook/build.dart`、AGENTS.mdの検証手順
- 関連artifact: `hook/build.dart`、`src/native_exclusive_rename.c`、`specs/005-rename-exec/tasks/T05-platform-rename-adapters/task.md`

## 観測した事実

`dev@63de09c`のcontainerで`flutter analyze`(0件)と`dart format --set-exit-if-changed`(74 files / 0 changed)は成功するが、`flutter test`は1件もtestを開始せずに失敗する。

```
Unhandled exception:
System not configured correctly: No compiler configured on host 'linux_x64' with target 'linux_x64'.
  Running `which clang`.
  Running `which vswhere.exe`.
Building native assets failed.
```

原因はT05で追加したcode asset。`flutter test`はhost target(`linux_x64`)へ`hook/build.dart`を走らせ、`CLibrary`が`src/native_exclusive_rename.c`をcompileしようとする。containerにはclangもgccも無く、非rootのため`apt-get install clang`もできない。hookの`if (!input.config.buildCodeAssets) return;` guardはこの経路では効かない(`flutter test`はcode assetを要求する)。

T05の作業記録には「Dev ContainerのFlutter testは今回と別の既知制約（C compilerなし）で開始前に停止」と1行あるが、findingとしては記録されておらず、T05以降のtaskすべてがこの制約を引き継ぐことが正本から読めない。

## 影響とworkaround

- 影響: AGENTS.mdが完了条件に挙げるrelated testとfull regressionを、containerのAgentが一切実行できない。`flutter test <path>`も同じ地点で止まる。
- 影響: 検証がCIだけに依存するため、pushするまでtest結果が分からない。「完了はdiffと実際のproject-native検証から判定する」という規約と、AI containerの実行能力が食い違う。
- その場のworkaround: なし。analyze / formatまでをlocalで確認し、testはCI run IDで証拠とする。task.mdには`flutter test`をnot-runとその理由で明記する。

## 仮説と改善案

- 本命: `.devcontainer/Dockerfile`へclangを追加する(read-onlyなので人間へ依頼する)。Linux hostのcode asset buildが通れば制約が消える。
- 代案: `hook/build.dart`で、targetOSがWindows/macOS/Linuxでも該当compilerが解決できない場合はcode assetを出さずに終了し、Dart側は`unsupportedPlatform`へ落ちる。ただし「desktopでは必ずnative renameを使う」というT05の受け入れを緩めるため、仕様判断が要る。
- 代案: containerのfull regressionをflagで回避する方法は無い。`flutter config --no-enable-native-assets`を試すと、testは`Package(s) batch_rename_master require the dart assets feature to be enabled.`で拒否される(検証済み。設定は元へ戻した)。回避策を探すより、compilerを入れるかCI依存を正本へ明記するかを選ぶ。
- どの案でも、AGENTS.mdの「検証とreview」節へ「AI containerで実行不能な検証と、その代わりに使う証拠」を一度だけ書く。

## 改善結果

2026-08-12に「本命」を採用。人間が`.devcontainer/Dockerfile`の`apt-get install`へ`clang`と`build-essential`を追加し、imageをrebuildした。`clang`単体ではなくCbuild一式にしたのは、`debian:bookworm-slim`に標準headerとlinkerが無いためである。

Forward-test(rebuild後のcontainer、005 T09 branch):

- `clang --version` = `Debian clang version 14.0.6`、`which ld` = `/usr/bin/ld`、`which gcc` = `/usr/bin/gcc`。
- `flutter test` = PASS(346件)。code assetのbuildを含めて1件も止まらない。
- `sudo -l` = `(root) NOPASSWD: /usr/local/bin/init-firewall.sh`のみ。toolchainはimage build時の`USER dev`より前に入るため、Agentへrootや追加sudo権限は渡っていない。
- `printenv AI_SANDBOX` = `1`、`/workspace/secrets/.dummy-marker`は存在。secret shadowも変わっていない。

これでAGENTS.mdのrelated test / full regressionをcontainerのAgentが実行できるようになったため、「AI containerで実行不能な検証」としてのAGENTS.md追記は不要になった。`hook/build.dart`側の代案(compiler未解決時にcode assetを出さない)は、T05の受け入れを緩めるため採用しない。
