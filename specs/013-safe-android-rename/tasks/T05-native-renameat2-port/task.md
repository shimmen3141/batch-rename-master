# T05 renameat2のnative portを実装する

## 目的

`T04`で承認された契約どおり、Androidの`RenameExecutor`を`renameat2(RENAME_NOREPLACE)`で実装する。

## 入力と依存

- `T04`で承認された005 contract revision 4。
- 検証済みの参照実装: [`../T01-decide-storage-boundary/spike/renameat2_spike.c`](../T01-decide-storage-boundary/spike/renameat2_spike.c)。**syscall番号のarch別fallbackとフラグ定義はここから写せる。**
- 現行のdesktop実装: `lib/data/rename_exec/native_exclusive_rename.dart`、`hook/build.dart`(`native_toolchain_c`)。**Androidも同じnative assets経路に載る見込み。**
- 現行の未対応adapter: `lib/data/rename_exec/saf_rename_executor.dart`。**削除しない**(ADR-002の退避経路)。

## 変更範囲

- Android向けnative renameの実装と、`platform_rename_executor.dart`の分岐。
- `errno`から`RenameErrorKind`への写像(`T04`の決定に従う)。
- 仕様由来testの追加。

**注意**: `renameat2`が**bionicのwrapperとして**公開されたのはAPI 30とされるが、これは検索結果の要約であり原文を読めていない(**[未到達]**)。**生の`syscall(SYS_renameat2, ...)`を使えばwrapperのlevelに依存しない**(`T01`のspike binaryは`android24`向けにビルドして動作した)。制約はlibcではなくkernelとfilesystemの側にある。

`T02`は**「`minSdk`は24のまま、対応可否を実行時に判定する」**と決めた(`spec.md`のD-1、2026-08-13 開発者承認)。生syscallで呼び、動かない端末は実行時に検出する。**API levelを対応可否の代理指標にしない。**

### このtaskの範囲ではないもの

**衝突時の再採番と結果の提示は005側(実行オーケストレーション)が持つ。** ここで作るのは「`renameat2(RENAME_NOREPLACE)`を1回呼んで結果を返す部品」と、`errno`を`RenameErrorKind`へ写す部分だけである。`EEXIST`→`nameConflict`を返せば、呼び出し側が005 contract REQ-023に従って再採番する。

**`renameat2`が使えない端末では、005 contract REQ-025の「実在確認してから改名する」経路へ落とす。** 「対応外」にはしない。

## 受け入れ証拠

- targetが既にある場合に`nameConflict`を返し、**targetの内容が変わらない**ことをtestで検査する。
- 権限が無い場合、対象が無い場合の分類をtestで検査する。
- `EEXIST`が`nameConflict`として返り、**005の再採番へ繋がる**ことをtestで検査する(005 contract REQ-023)。
- `EINVAL`/`ENOSYS`のとき、**実在確認による代替経路へ落ちる**ことをtestで検査する(005 contract REQ-025)。**未対応として利用者へ見せない。**
- 例外を投げないこと(REQ-017)をtestで検査する。
- 005の既存contract testが継続PASSする。
- `flutter test` / `flutter analyze` / `dart format --output=none --set-exit-if-changed .` がPASS。
- **Androidのbuildはcontainerで実行できない**(SDK・NDKが無い)。未実施と明記し、host側のbuildを`T08`で行う。
- exact rangeの独立reviewがPASSする。

## 検証結果

| 種別 | commandと結果 |
|---|---|
| full regression | `flutter test` = **PASS(476件)**。T05着手前は464件 |
| static analysis | `flutter analyze` = **PASS** |
| format | `dart format --output=none --set-exit-if-changed .` = **PASS** |
| ASDD構造 | `python3 <asdd-plugin>/scripts/workspace.py check specs` = **PASS** |
| 規範の書き写し | `python3 tool/check_normative_terms.py` = **PASS** |
| C(Linux分岐) | `gcc -fsyntax-only src/native_exclusive_rename.c` = **exit 0** |
| C(Android分岐) | `gcc -fsyntax-only -D__ANDROID__ src/native_exclusive_rename.c` = **exit 0**。**NDKが無いのでglibcのheaderで代用した syntax 検査であって、NDKでのコンパイルではない** |
| syscall番号 | arch表を**kernelのuapi headerと照合**した。`x86_64=316`(`asm/unistd_64.h`)、`asm-generic=276`(aarch64が使う)が一致。**`__arm__`(382)と`__i386__`(353)はこの環境にheaderが無く未照合**(出典は`T01`のspike) |
| mutation | `M44`〜`M47` = **4 KILLED, 0 SURVIVED, 0 SKIPPED**。表全体は`T08`の前に通す |
| **Android build** | **未実施。** AI containerにSDK・NDKが無い |
| **実機確認** | **未実施。** `T08`が行う |

**mutationで2件がSURVIVEDしてから直した。** `M46`(通常renameのnotFound分類)は
`expect([notFound, io], contains(result))`という曖昧なassertionで、どちらでも通って
いた。`M47`(**AndroidのRENAME_NOREPLACEを外す**)は`expect(source, contains('RENAME_NOREPLACE'))`
がfile全体を見ており、`#define`の行があるので**呼び出しからflagが消えても通っていた**。
**M47は置換renameになる = 005 INV-002が全面的に破れる**変更なので、これを見逃す
testは意味がない。呼び出し部分だけを切り出して検査する形へ直した。

## 決めたこと

| 論点 | 決着 | 理由 |
|---|---|---|
| wrapperか生syscallか | **生のsyscall** | bionicのwrapperはAPI 30とされるが、013 spec D-1は「minSdkは24のまま、対応可否を実行時に判定する」と決めている。**API levelを対応可否の代理指標にしない** |
| `EINVAL`の扱い | **Androidのときだけ`unsupported`へ写す** | `renameat2`はfilesystemがflagを解釈できないとき`EINVAL`を返す。Androidは共有storageがFUSEを経由するので現実的に起きる。**desktopの写像は変えない**(013 spec の範囲外に「desktopの振る舞い。何も変えない」とある) |
| 劣化をどこに置くか | **`androidRenameOperation`(port側)** | `DesktopRenameExecutor`へflagを足す案もあったが、**desktopの実装を1文字も変えない**方を採った。`tool/mutations.json`の17件がこのfileを対象にしており、触ると表ごと揺れる |
| composition rootの切り替え | **このtaskでは行わない** | Androidのハンドルはまだ**SAFのdocument URI**で、pathとして解釈できない。いま切り替えると、実体は壊れないが(対象が見つからず失敗する)revision 2以来の「理由付きの安全な未対応」より分かりにくい失敗になる。**`T07`が絶対pathを供給してから切り替える。** `platform_rename_executor.dart`のdoc commentとtestで固定した |

## この実装で残る限界

- **Androidで実際に動くかは未確認である。** container にSDK・NDKが無く、compileすら
  していない(`gcc -fsyntax-only`はglibcのheaderでの構文検査)。**`T08`が実機で見る。**
- **`__arm__`と`__i386__`のsyscall番号を照合できていない。** 出典は`T01`のspikeで、
  x86_64とaarch64はこの環境のkernel headerと一致した。32bit ABIの2つは未照合である。
- **劣化経路(`plainRenameFile`)は既存fileを置換しうる。** 呼び出し側が直前に実在確認を
  していることが前提で、`DesktopRenameExecutor`が005 REQ-025でそれを保証する。
  **単体で使うと黙って上書きする。** doc commentへ明記した。

## 作業記録

- 2026-08-13 / ADR-002の採用決定を受けて定義。
- 2026-08-22 / 着手。`T04`の契約承認(revision 4、さらに5 / 5.1)は済んでおり依存は解けていた。C へ Android 分岐(生syscall + arch表 + Android限定の`EINVAL`写像)、`hook/build.dart`からAndroidを未対応対象外へ、`android_rename_executor.dart`(劣化経路)を追加した。**composition rootは切り替えていない**(上表)。
- 2026-08-22 / mutation `M44`〜`M47`を追加し、**2件がSURVIVEDしたのでtestを直した**(上記)。

## Current state / handoff

- Last checkpoint: **実装とtestが揃い、`M44`〜`M47`が4 KILLED。** working treeはclean
- Blocker category: なし
- Waiting for: 独立review
- Requested action: なし
- Evidence revision: branch `asdd/013-safe-android-rename/T05-native-renameat2-port`、base は `dev@601ecbb`
- Next Agent action: **exact rangeの独立reviewを通してPRを作る。** mutation表全体(47件)はreview前に一度通す。
- **`T07`への申し送り**: `platform_rename_executor.dart`のAndroid分岐を`createAndroidRenameExecutor()`へ切り替えるのは`T07`である。同fileのdoc commentに理由を書いてある。切り替えたら`saf_rename_executor.dart`は**wiringから外れるが削除しない**(ADR-002の退避経路)。
- **`T08`への申し送り**: NDKでのcompileと実機での`renameat2`挙動の観測。`__arm__`/`__i386__`のsyscall番号の照合もここで取れる。
