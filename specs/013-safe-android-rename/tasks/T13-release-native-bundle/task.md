# T13 release buildでもnative改名ライブラリを同梱する

## 目的

`flutter run --release`(Android)が build hook の検証で失敗し、**release build を作れない**。`T05`が作った build hook(`hook/build.dart`)の欠陥で、debug では露見していなかった。**release でも debug と同じく、改名の native ライブラリ(`batch_rename_native`)を動的ライブラリとして app に同梱する**。

## 観測(2026-09-25)

`008:T13`のrelease buildでの手動確認で、開発者がhostで次を観測した(会話で受領)。

```text
flutter run --release -d emulator-5554
Hook.build hook of package:batch_rename_master has invalid output
Asset "...libbatch_rename_native.a..." is sent to package "batch_rename_master" for linking,
but that package does not have a link hook.
```

- `CLibrary.build()`は、release(`BuildInput.config.linkingEnabled == true`)では**静的ライブラリ**を作り、**同じpackageのlink hookへ送る**(`native_toolchain_c 0.19.2`の`clibrary.dart`)。このpackageには`hook/link.dart`が無い。
- debug(`linkingEnabled == false`)では動的ライブラリを app に同梱するので、`T05`〜`T08`の確認はすべてこちらを通っていた。**release buildは一度も作られていなかった。**
- 既存の hook test は `buildCodeAssets == false` の経路しか見ておらず、検出できなかった。

## 決定(2026-09-25、Agent。開発者の依頼で2案から選んだ)

| 案 | 採否 | 理由 |
|---|---|---|
| **`CBuilder.library`で動的ライブラリを直接build・同梱する**(routing `ToAppBundle`、link mode `dynamic`) | **採る** | **debug と同じ形**になる — `T08`が実機(emulator API 37)で`renameat2`を確かめたのはこの形である。C は1本で、LTO で得るものが無い |
| `CLibrary`の定義を共有し、`hook/link.dart`から`CLibrary.link()`を呼ぶ | 採らない | debug と release で経路が分かれる。link で FFI が呼ぶ symbol を明示しないとリンカが落としうり(`CLinker`は`--gc-sections`等を持つ)、**release だけ改名が実行時に失敗する**という、データ保護の経路で最も見つけにくい壊れ方を持ち込む |

仕様(005 contract、013 spec)は変えない。改名の意味は変わらず、ライブラリの作り方だけが変わる。

## machine検証範囲と引き受け先

- **CIで閉じる**: build hook を `linkingEnabled: false / true` の両方で**実際に C を build して**走らせ、link hook へ何も送らず、動的ライブラリ(`DynamicLoadingBundled`)を1つ app へ同梱することを検査する(`test/hook/build_hook_test.dart`)。host の Linux 向け build で見る — routing と link mode の決定は target OS に依らない。
- **CIで閉じられないもの(このtaskのmanual)**: Android の release build が実際に通ること、**release の app で改名が実際に動くこと**(FFI が library を読めること)。AI container には Android SDK が無い。
- Android 固有の`renameat2`の効き方は`T08`が確かめ済みで、このtaskでは変えない。

## 受け入れ証拠

- 再発検出 test: 修正前の hook で `linkingEnabled: true` が失敗し、修正後に PASS する。
- `flutter test` / `flutter analyze` / `dart format` PASS。関係する mutation が KILLED。
- **manual**: host で `flutter run --release` が成功し、release の app で1件の改名と衝突回避(既存名があれば`(1)`)が動く。
- 独立 review PASS。

## 実装の記録(2026-09-25)

実装は Claude Opus 5.5。起点は`dev`@`15a15f0`、branch `asdd/013-safe-android-rename/T13-release-native-bundle`、code `a13877b`。

- `hook/build.dart`: `CLibrary(...).build()`を`CBuilder.library(...).run(routing: [ToAppBundle()], linkModePreference: dynamic)`へ替えた。名前・asset名・sources・includes・definesは同じ(`M76`・`M81`がそのまま効く)。
- `test/hook/build_hook_test.dart`: `testBuildHook`を`linkingEnabled: false / true`の両方で、**hostのclangで実際にCをbuildして**走らせる。link hookへ何も送らないこと、asset id、`DynamicLoadingBundled`であることを見る。
  - **修正前の実装では`linkingEnabled: true`が落ちた**(このcontainerでは静的ライブラリを作ろうとして`No archiver configured`。archiverのある環境では`encodedAssetsForLinking`が空でないことで落ちる)。修正後は3件PASS。

### 自動検証

- `flutter test`: 991件PASS。`flutter analyze`: No issues。`dart format`: 0 changed。

### mutation

`command`を`flutter test test/hook test/spec_005_rename_exec/platform_rename_executor_test.dart`へ絞り、`hook/build.dart`のmutation全4件を回した:

```text
M76 | KILLED | hook/build.dart | headerの依存宣言を取り除く | exit 1
M81 | KILLED | hook/build.dart | literalを使わずAndroidを未対応へ戻す | exit 1
M435 | KILLED | hook/build.dart | release(linkingEnabled)で改名ライブラリをlink hookへ送る | exit 1
M436 | KILLED | hook/build.dart | 静的ライブラリにする | exit 1
4 mutations: 4 KILLED, 0 SURVIVED, 0 SKIPPED
```

(NOTEは要約。`M436`はこのcontainerではarchiverが無いことで落ちる。archiverのある環境では`DynamicLoadingBundled`の検査で落ちる。)

経緯は[development finding](../../../../development-findings/2026-09-25-release-build-never-built-native-hook.md)。

## 独立review

**reviewerのmodelは`gpt-6-luna`**(開発者指定。実装はClaude Opus 5.5)。

## Current state / handoff

- Last checkpoint: 実装とmachine検証が済んだ(2026-09-25、code `a13877b`)。
- Blocker category: なし。
- Evidence revision: 起点は`dev`@`15a15f0`。
- Waiting for: 独立review attempt 1(全範囲)。その後、host のrelease buildのmanual。
- Requested action: なし。
- Next Agent action: mutation → 独立review → manual依頼。**`008:T13`のrelease確認はこのtaskのmerge後**(そのbranchへ`dev`を取り込んでから)。
