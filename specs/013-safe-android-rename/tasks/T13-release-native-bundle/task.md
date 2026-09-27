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

## manual確認の結果

### 1回目(2026-09-27、Androidエミュレータ、**release build**、code `a13877b`) — **PASS**

開発者の報告(会話)。

| 項目 | 結果 |
|---|---|
| 1 release buildが通る | **確認できた**(`does not have a link hook`が出ずに起動した) |
| 2 release版で改名が動く | **実行は正常に完了し、fileの内容等も想定どおりだった**(`x_one.txt`、`x_two (1).txt`が作られ、既存の`x_two.txt`は上書きされなかった) |

- 開発者の補足:「`two.txt`の変更後名が`x_two.txt`と衝突する旨の警告は、実際にリネームbuttonを押すまで出なかった。警告modalが出てからはfile行に警告が出続けた」。**これは仕様どおり**である — 005 代表例25が求めるのは「**実行前に**重複警告として提示される」ことで、読み込んでいないfileの実在名は実行の時点で読む(`013:T07`の確認と同じ形)。**手順書の期待(一覧に先に出る)が不正確だった**ので、手順書を直した(記録のみ)。
- **このmanual証拠はcode `a13877b`に対応する。** その後の差分は`specs/`と`tool/mutations.json`(対照の追加)だけで、code・dependency・build設定は変えていない。

## 独立review

**reviewerのmodelは`gpt-6-luna`**(開発者指定。実装はClaude Opus 5.5)。

- attempt 1: `15a15f0..250ac5c`(全範囲、implementation) — **PASS**(P2が1件)。packageのsourceで、変更前の`CLibrary`がreleaseで静的ライブラリをlink hookへ送り、変更後は両経路で動的ライブラリをbundleへ出すこと、名前・asset id・sources・includes・definesが保たれること、link hookを採らない理由の妥当性、仕様・contract・権限・データ保護の判定を変えていないことを確認された。**修正前のhookへ戻すとtestが落ちる**ことも実行で確かめられた。full test 991件PASS。
  - **P2(成果物の欠陥)**: manualの`flutter run --release -d <emulator>`はPowerShellで`<`が演算子になり、そのまま実行できない。→ `flutter run --release`(端末が1台なら`-d`不要)へ直し、IDを書く場合の注意を足した。
  - **SELF-CHECK**(AGENTS.mdの差分review): P2を閉じる差分は`specs/`だけで、ほかは`tool/mutations.json`へ対照を足しただけ(`lib/`・`hook/`・`src/`・`test/`・依存・build設定は変えていない)ことを`git diff --stat 250ac5c..HEAD`で確かめた。再reviewは起動しない。
  - reviewerの対照`R-CONTROL-1`(hostから渡るlink mode preferenceを使う)を`M437`として取り込んだ。**等価mutantでSURVIVEDする**(testもFlutterもdynamicを渡す)。dynamicの明示は防御として残す。
  - reviewerの補足: `M436`のKILLEDはこのcontainerではarchiver不足による。archiverのある環境では、static linkの成果物(`StaticLinking`)が`DynamicLoadingBundled`の検査で落ちる設計である(未実証として記録する)。

## Current state / handoff

- Last checkpoint: **完了**(2026-09-27)。PR #191をAgentがmergeした(auto-merge条件1〜7: review連鎖 = attempt 1 PASS + SELF-CHECK、CI SUCCESS、未解決threadなし、`dev`と競合なし、最新headでfull test 991件PASS、manual証拠はcode `a13877b`でその後code差分なし)。統合後の`dev`@`4aa46e0`で`flutter analyze` PASS、`flutter test` 991件PASS。
- Blocker category: なし。
- Evidence revision: code `a13877b`、merge commit `4aa46e0`。
- Waiting for: なし。
- Requested action: なし。
- Next Agent action: なし。`008:T13`のrelease確認がこの修正を使う。
