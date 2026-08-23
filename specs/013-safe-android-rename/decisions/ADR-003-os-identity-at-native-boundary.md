# ADR-003: OS identityをnative境界へ閉じ込め、Dart側のplatform分岐を持たない

- Status: **accepted**(2026-08-23 開発者承認)
- Date: 2026-08-23
- Related: [ADR-002](ADR-002-android-rename-storage-boundary.md)、005 `contracts/behavior-contract.json` revision 5.1、013 spec REQ-005 / REQ-006 / VER-005
- Related requirements: 013 REQ-005(flagが使えない端末でも対応外にしない)、REQ-006(`EEXIST`は再採番へ)、005 INV-002 / REQ-025
- Related tasks: `013:T05`(適用)、`013:T07`(composition rootの切り替えが簡単になる)、`013:T08`(残余riskの引き受け先)

## Context

`013:T05`で独立reviewが**3回連続FAIL**した。3回とも同じ型である。

> **production が実際に通る合成を、test が一度も通らない。**

場所だけが毎回違った。fakeの注入 → factoryの既定配線 → `?? 既定`の右辺 → 純関数の**呼び出し側**。
毎回その箇所へtestを足したが、**次のreviewでは1層外側で同じ型が再発**した。4回目は、3回目に
「分岐を純関数へ切り出した」ことで seam が関数の内側から外側へ**移動しただけ**だった。

AGENTS.mdの「同じtaskで独立reviewが合計3回FAILしたら`blocked`にして人間へ返す」に達し、
**この経緯を知らない外部のAI 2件へ一般的な解き方を尋ねた**(人間の作業として実施)。

## 外部から得た案と、前提の照合

2件の回答は独立に同じ結論へ収束した。**「Dart側のOS分岐を消し、OS identityをC/build境界へ
閉じ込める」**。片方はさらに「全platform共通UTF-8 ABI」と「結果値としての fallback 指示」を提案した。

そのままは採らず、前提がこのrepoと噛み合うかを実コードで確認した。

| 外部案の前提 | このrepoの実際 | 採否 |
| --- | --- | --- |
| Dart側のOS許可リストを消すと、未知OSで**symbol解決に失敗する**のが唯一の代償 | `hook/build.dart`はiOSにだけ`BRM_UNSUPPORTED_PLATFORM`を付け、**全targetOSで同じsymbolをbuildする**。native assetがbundleされるOSでは必ずexportされる | **採る。**懸念は実質消える |
| 全platform共通UTF-8 ABI(WindowsもUTF-8で渡しC内でUTF-16へ変換) | Dart側のWindows分岐には`_extendedWindowsPath`(`\\?\` prefix)が同居しており、**これは純関数として既にtestされている**。ABIを統一するとこれもCへ移る = **testできるDartコードを、この環境では`gcc -fsyntax-only`すら通せないC(`windows.h`不在)へ移す** | **採らない。**目的と逆方向 |
| 同上。unpaired surrogateの往復欠損に注意が要る | Windows実機が無く**検証手段が無い**。005のWindows manual証拠も再取得が必要になる | **採らない。**未検証のまま交換できない |
| `unsupported`を「機能が無い」と「fallbackしてよい」に割り、OS identityを結果値へ変える | Cの`EINVAL`写像は既に`#if defined(__ANDROID__)`限定 = **OS判定は最初からC側にある**。desktopは`unsupported → RenameError`のまま維持できる | **採る** |
| 「この行が存在する」source assertではなく「禁止された依存が存在しない」検査にする | `platform_rename_executor_test.dart`に、**まさにその避けるべき形のassertが18件**ある(`T05`のreview対応で自分が足したもの) | **採る** |
| `testCodeBuildHook(targetOS: ...)`でbuild wiringを検査する | `code_assets 1.2.1`(pin済み)に**実在を確認**。ただしhook本体がCコンパイラを呼ぶため、**android / ios / windowsではtoolchain不在で失敗する**。Linuxでしか動かない | **今は採らない。**費用対効果が低い |
| target OS別のbuild CIを足す | `.github/workflows`はAGENTS.mdにより**人間のみ**が変更できる | **今は採らない。**残余riskとして受容(2026-08-23 開発者決定) |

## Decision

**OS identityをDartから消し、native境界(C + `hook/build.dart`)へ閉じ込める。**

1. **Dart側のOS許可リストを持たない。** `usesUtf8NativePath`を削除し、
   `Platform.isWindows`ならUTF-16 symbol、**それ以外は常にUTF-8 symbol**を呼ぶ。
2. **`fallbackRequired`を結果値として導入する。** Cは**Androidのときだけ**
   `EINVAL` / `ENOSYS` / `ENOTSUP`をこれへ写す。desktopは従来どおり`unsupported`である。
   Dartは「Androidか」ではなく「**nativeがfallbackを要求したか**」で分岐する。
3. **劣化はDartの単一地点で行う。** `DesktopRenameExecutor`が`_rename`の結果を受けて
   `fallbackRequired`なら通常renameへ落とす。**optionalな既定引数による合成を作らない。**
4. **source assertは「禁止された依存が無い」検査へ置き換える。**
   `Platform.`と`@Native`は指定fileの外に書けない、を`tool/check_platform_boundary.py`が検査する。

## Consequences

**得るもの。**

- `013:T05`で4回SURVIVEDした変異のうち**3つはmutation pointごと消滅する**
  (Dart側Android分岐、factoryの既定配線、`?? 既定`の右辺)。潰すのではなく、書けなくなる。
- **Androidの劣化経路がLinux上で完全にtestできるようになる。** 引き金がplatformではなく
  **結果値**になるため、fakeが`fallbackRequired`を返せば実際の`plainRenameFile`が動く。
- `013:T07`のcomposition root切り替えが「`isAndroid`の行を消す」だけになる。
  Android専用のexecutor factoryが存在しなくなるため。
- desktopの**利用者から見た振る舞いは変わらない**。`fallbackRequired`はdesktopのCが返さない。

**失うもの・残るrisk。**

- **CのAndroid分岐は依然としてLinux CIで検証できない。** これは設計で消せる種類ではなく、
  `013:T08`(実機確認)が引き受ける。target OS別build CIは**今回入れない**(上表)。
- `NativeRenameResult`に値が1つ増える。既存の値のindexは変えない(末尾へ追加する)ため、
  C側のenumとDart側の`values[value]`写像は互換のままである。
- 「未知のOS」でUTF-8 symbolを呼ぶことになる。`hook/build.dart`が全targetOSで同じsymbolを
  出す限り安全だが、**この不変条件はbuild hook側の責務になった**。破ると実行時失敗になる。
- 005 contractは変更しない。`NativeRenameResult`はcontractの語彙ではなく実装型である
  (contractが持つ`unsupportedPlatform`は`RenameError`の理由であって、この列挙ではない)。

## Why not

- **見つかった箇所ごとにtestを足す(現路線)。** 4回とも次の層で再発した。DI / test seamは
  「到達できない分岐を到達可能にする」手法であって、「分岐を消す」手法ではない。
  本番entry pointから最初のtestable seamまでの区間は、どこまで行っても残る。
- **`Platform`を抽象化して注入する。** 有効な一般手法だが、今回は第一候補にしない。
  **production composition rootが最後に残る**という同じ構造が再現するためである。
- **conditional import。** Dartのconditional keyは`dart.library.*`であり、
  native OS間(Linux / Windows / Android)を分ける仕組みではない。
- **sealed / exhaustive switch。** 今回問題になった変異(`'android' => true`を
  `'linux' || 'macos' => true`にする)は**どちらもexhaustiveで合法**なので検出できない。
  variant追加漏れには効くが、補助策である。
