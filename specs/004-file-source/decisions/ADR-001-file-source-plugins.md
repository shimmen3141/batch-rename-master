# ADR-001: 実 `FileSource` のプラットフォーム実装とプラグイン選定

- Status: accepted
- Date: 2026-08-04
- Related requirements: REQ-001, REQ-002, REQ-003, REQ-008, REQ-009, REQ-010
- Related tasks: 004 T4

## Context

004 は抽象ポート `FileSource` の実装を、Android(主目標)と Windows に用意する必要がある。
前提と制約:

- Android は `MANAGE_EXTERNAL_STORAGE` を要求せず、**SAF のフォルダ単位 URI 権限**で読む(PRD §5・計画の決定事項)。
- 004 が返す `sourceHandle` は、**005 が実ファイル名を書き換える先**を一意に指す(REQ-002)。したがって
  「あとでリネームできるハンドルか」が実装選定の合否を分ける。
- 作成日時は SAF の列に存在せず、取得できないなら「不明」として返す(REQ-003)。取得経路の実装範囲は自由(REQ-010)。
- サンドボックスに Android SDK が無く、実権限・実ピッカーの確認はホスト側になる。

## Decision

プラットフォームごとに別実装を用意し、`createPlatformFileSource()` で選ぶ。

1. **Android = `saf_util`**(`SafFileSource`)。`pickDirectory`(永続化可能な書き込み権限付き)/ `pickFiles`(複数)/
   `list` / `stat` に加えて **`rename` を公開している**。`sourceHandle` は **SAF の document URI**。
2. **Windows(および Linux/macOS)= `file_selector`**(`DesktopFileSource`)。`openFiles`(複数)/ `getDirectoryPath` を使い、
   メタデータは `dart:io` の `FileStat` から読む。`sourceHandle` は**絶対パス**で、005 は `File.rename` で書き戻せる。
3. 未対応プラットフォームは `UnsupportedFileSource` が **`Failed` を返す**(例外を投げない。REQ-001/008)。
4. **作成日時は両実装とも常に `null`(不明)**とし、更新日時などで代替しない(REQ-003 / 001 INV-006)。

## Why

- **`saf_util` を選んだ決め手は `rename` の有無**。最も人気のある `saf`(v2.1.0)は pick / list / read/write / copy / move / delete を
  備えるが、リネームに相当する API が見当たらない。移動+コピーでの代替は、同一フォルダ内の改名としては
  意味論が違い(一時ファイル生成・URI 変化・失敗時の中間状態)、005 の安全性を損なう。004 の時点で
  「リネームできないハンドル」を配ってしまうと 005 で行き詰まるため、ここで選び切る。
- **`file_picker` を採らなかった理由**: 全プラットフォームを1パッケージで賄えるが、Android では選択結果を
  アプリのキャッシュへコピーしたパスとして返す挙動が知られ、**元ファイルを指すハンドルにならない**恐れがある。
  Android は SAF 専用実装があるため、このリスクを負う理由がない。
- **`file_selector` を選んだ理由**: flutter.dev の公式パッケージで、Windows の `openFiles` / `getDirectoryPath` を
  サポートする。デスクトップでは実パスが得られるため、ハンドル=絶対パスという単純で確実な設計にできる。
- **ポートで隔離しているため選定はやり直せる**。`FileSource` の契約(`PickResult` の3値・ハンドル・不明な作成日時)を
  満たす限り、プラグインの差し替えは仕様に影響しない。

## Why not

- **単一プラグインで統一(`file_picker` のみ)**: 依存は減るが、上記のとおり Android のハンドル信頼性が担保できない。
  T4 の実機検証で問題が出てから差し替えるより、選定時点で回避するほうが安い。
- **`saf` + 別途リネーム手段**: リネームのためだけに追加のネイティブ実装/プラグインが必要になり、
  `saf_util` 1つで足りる構成より複雑になる。
- **作成日時の取得(EXIF / MediaStore / NTFS)を T4 で実装**: 取得経路は仕様上「自由」であり、EXIF を読むには
  ファイル内容の読み取り(`saf_stream` 等)、NTFS の作成時刻には FFI が要る。**T4 のスコープ(読み込み入口の実装)を
  越える**ため、不明のままとし、写真機能・後続タスクで経路を足す。判定を「取得可否」に置いた設計により、
  経路を後から追加しても仕様は変わらない(不明の件数が減るだけ)。

## Consequences

- Android は追加のマニフェスト権限を必要としない(SAF の権限は URI 単位で付与される)。
  **`saf_util` の要件は minSdk 24**(`saf_util-3.1.0/android/build.gradle.kts`)。本アプリは
  `android/app/build.gradle.kts` で `flutter.minSdkVersion` を使っており、Flutter 3.44 系の既定は 24 なので一致する。
  **minSdk を 24 未満へ下げるとビルドが壊れる**点に注意。
- 実権限・実ピッカー・複数フォルダ蓄積の確認は**ホスト側**(`docs/development/emulator-verification.md`)。
  サンドボックスでは、ピッカーを伴わない部分(SAF ドキュメント→`FileEntry` のマッピング、実フォルダの列挙、
  失敗の分類、プラットフォーム選択)を `test/spec_004_file_source/platform_source_test.dart` で検証する。
- 005 のリネーム実装は、Android では `saf_util.rename`、デスクトップでは `File.rename` を使う前提になる。
