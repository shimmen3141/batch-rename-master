# ADR-001: Android SAF renameを安全な未対応として扱う

- Status: accepted
- Date: 2026-08-09
- Related contract: `contracts/behavior-contract.json` revision 2
- Related requirements: REQ-017, OP-004, INV-001, INV-002, INV-003
- Related development units: `complete-rename-execution`, `design-safe-android-rename-boundary`

## Context

revision 1は、Androidで`saf_util.rename`が改名後URIを返す実機観測を根拠にproduction adapterを計画した。しかし独立reviewで、そのfakeとtestがproviderの競合意味論を再現していないことが判明した。

Androidの`DocumentsContract.renameDocument`は、providerが要求名と異なるdisplay nameを選ぶことを許す。AOSPの`FileSystemProvider`は候補名を選ぶ処理とfilesystem renameを別に行い、基盤の通常renameには「その瞬間に既存targetを置換しない」という共通契約がない。`saf_util 3.1.0`もfile rename内の例外を握りつぶしてgenericなplugin errorへ変えるため、Dart側でpermission、notFound、conflictを安定分類できない。

参照:

- Android `DocumentsContract.renameDocument`: https://developer.android.com/reference/android/provider/DocumentsContract#renameDocument(android.content.ContentResolver,%20android.net.Uri,%20java.lang.String)
- AOSP `FileSystemProvider`: https://android.googlesource.com/platform/frameworks/base/+/master/core/java/com/android/internal/content/FileSystemProvider.java
- `saf_util 3.1.0` rename実装: `/workspace/.pub-cache/hosted/pub.dev/saf_util-3.1.0/android/src/main/kotlin/com/fluttercavalry/saf_util/SafUtilPlugin.kt`

## Decision

1. INV-002のno-replace保証にplatform例外を設けない。
2. Android SAFのproduction `RenameExecutor`は、providerのrename APIを呼ぶ前に理由付き`unsupportedPlatform`を返す。
3. 失敗時は名前、内容、個数、URIが指す実体を一切変更しない。
4. desktopはOS固有の排他的renameを使い、成功、競合、権限、消失をstableな結果へ分類する。
5. Androidで成功可能なrenameは別development unitでstorage境界を再設計し、安全性を証明した新revisionでだけ採用する。

## Considered alternatives

### SAF rename前のtarget存在確認

採用しない。確認とrenameの間に外部processまたはproviderがtargetを作れるため、TOCTOU raceを残す。

### providerが返した実名を採用する

採用しない。要求名と異なる成功を許すとREQ-018とINV-003を変え、既存targetを置換するraceも解消しない。

### rename後に実名を検査し、異なれば巻き戻す

採用しない。失敗として返す前に実体を変更しており、巻き戻し自体も失敗・競合しうるためOP-004の失敗時不変を保証できない。

### copy後に元fileをdeleteする

採用しない。rename-onlyのINV-001を破り、途中失敗で個数・内容・所在の中間状態を作る。

### SAF URIからraw pathを推測する、または広域storage権限を要求する

採用しない。SAF URIはprovider固有の不透明handleであり一般にfilesystem pathへ変換できない。`MANAGE_EXTERNAL_STORAGE`等は権限・配布審査・利用者信頼の境界を変えるため、Issue #96内で導入しない。

## Consequences

- Android利用者には実renameを行わず、未対応理由を表示する。選択済みfileは不変である。
- Issue #96の完了は「Android実rename成功」を意味しない。desktopの安全な実renameとAndroidの安全な未対応処理を意味する。
- Android成功経路の設計判断は`development-units/design-safe-android-rename-boundary/`が所有する。
- #116はこのrevisionとscopeが独立reviewされ、desktopとAndroid未対応の同一commit/build手動証拠が揃うまでDraftを維持する。
