# エミュレータ / 実機での確認手順（ホスト側）

このリポジトリの AI エージェント作業は Dev Container（サンドボックス）内で行うが、**サンドボックスには Android SDK が無く `flutter run` / `flutter build apk` はできない**（コード編集・`flutter analyze` / `flutter test` / `dart format` が主目的）。UI の目視確認・実機/エミュレータ向けビルドは、**ホスト側の人間が別ターミナル（またはAndroid Studio）で**行う。

## 前提

- ホストに Flutter SDK（このリポジトリに pin した revision。CI は 3.44.6 系）と Android Studio + AVD（エミュレータ）が入っていること。
- ここでいう「ターミナル」は**ホストのターミナル**で、AI サンドボックス（Dev Container）とは別。エージェントはここを操作できない。

## エミュレータで起動する

> ⚠️ **起動前に「どのブランチをチェックアウトしているか」を必ず確認する。**
> コンテナ(AI)とホストは同じ作業ツリーを共有しており、**エージェントが別作業でブランチを切り替えると、
> 検証したいタスクを含まないコードが動く**。症状は「実装したはずの機能が無い / 古い挙動のまま」で、
> アプリの不具合と誤認しやすい(2026-08-05 に実際に発生: T4 の実 SAF を検証しようとして、
> T3 のデモ用フェイクが動いた)。
>
> ```bash
> git branch --show-current   # 検証したいタスクのブランチ、または dev(マージ済みなら)
> git log --oneline -1        # 対象のコミットが入っているか
> ```
>
> 検証中はエージェントに「ブランチを動かさないで」と伝えるか、エージェントが停止しているタイミングで行う。

```bash
# ホスト側・リポジトリのルートで
flutter --version                          # pin した revision と一致するか
flutter emulators                          # 使えるエミュレータ一覧
flutter emulators --launch <emulator_id>   # 起動（または Android Studio の Device Manager で ▶）
flutter devices                            # エミュレータが認識されているか
flutter pub get                            # 依存が増えた直後は必須(コンテナと .pub-cache が別のため)
flutter run -d <device_id>                 # 実行。r=ホットリロード / R=ホットリスタート / q=終了
```

### `flutter devices` がADBサーバーへ接続できない場合

`could not read ok from ADB Server` や `cannot connect to daemon` が出たら、SDKの再インストールより先にADBサーバーを再起動する。

```powershell
$adbPath = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
& $adbPath kill-server
& $adbPath start-server
& $adbPath devices -l
```

- 端末が `device` なら、もう一度 `flutter devices` を実行する。
- `offline` のままなら、Device Managerで対象AVDを停止して起動し直し、上の3コマンドを再実行する。長期間起動したままのAVDでは、ADBサーバーだけの再起動では戻らないことがある。
- `adb.exe` が異常に多数残っている場合は、Android Studio・Flutter・ADBを使うターミナルをいったん閉じ、タスクマネージャーで **`%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe` と確認できるプロセスだけ**を終了してから再実行する。名前だけで無関係なプロセスを一括終了しない。

ADBはローカルTCP 5037番のサーバー1つを複数クライアントで共有する。したがって、このエラーは通常 `ANDROID_HOME` の値そのものではなく、残留サーバー・競合・オフラインのエミュレータを先に疑う。

## エージェント（AI）の変更を反映する

`compose.ai.yml` は `- ./:/workspace` でホストのリポジトリを**バインドマウント**している。つまりコンテナ（AI サンドボックス）とホストは**同じ作業ツリー（1つの git チェックアウト）を共有**する。エージェントの編集はホストのファイルにも即現れる（ファイル自体は git pull 不要）。ただし「自動で画面に反映」にはならない:

1. **`flutter run`（CLI）は変更を自動ホットリロードしない。** ファイルが変わっても、`r`（ホットリロード）/ `R`（ホットリスタート）を押して初めて反映される（IDE の保存時オートリロードは別）。`main()`・初期状態・依存が変わるときは `R` が確実。
2. **作業ツリーを共有している = ブランチもチェックアウトも共有。** エージェントはブランチを切り替えながら作業するので、**作業途中はブランチ/ファイルが動いて不安定**。安定して見たいときは、エージェントが**停止したチェックポイント**（特定ブランチ、または dev マージ後の状態）で `R` を押す。
3. **`.dart_tool` / `build` / `.pub-cache` はコンテナ専用 volume でホストと非共有**（性能・バイナリ互換のため）。ビルドキャッシュは各自独立。`pubspec.yaml` を変えたらホストで `flutter pub get` を実行する。

> 別クローン（バインド元と異なるディレクトリ）でエミュレータを動かす場合のみ、`git pull` で変更を取り込む必要がある。

## 画面別の見どころ（現状のデモ入口）

`lib/main.dart` は002〜004と005の警告確認・結果表示を束ねる。起動直後のsampleはUI確認用で実fileではなく、実fileを選ぶと一覧が置き換わる。005のplatform adapterは所有taskとPRのrevisionを確認してから検証する。

- **モバイル幅（スマホ）**: ファイルリスト全面 + 下部「ルールを編集」→ ボトムシートでトークン編集。
- **デスクトップ幅（≥840dp・タブレット/横向き）**: 左にリスト、右にルールビルダーの 2 ペイン。
- チェックボックス選択・ソート切替（名前/作成日時/サイズ/カスタム）・行のドラッグ並び替え・トークンの追加/タップ編集/削除が、その場でプレビュー（変更後名）へ反映される。

## 機能別の実機確認（実装後）

この文書には複数taskで共通するhost起動・接続手順だけを置く。機能固有のfixture、操作、期待結果、記録する証拠は所有taskを正本とする。

- **004 ファイル読み込み**: [`specs/004-file-source/tasks/T10-verify-target-platforms/manual-verification.md`](../../specs/004-file-source/tasks/T10-verify-target-platforms/manual-verification.md)
- **005 platform rename**: [`specs/005-rename-exec/tasks/T05-platform-rename-adapters/manual-verification.md`](../../specs/005-rename-exec/tasks/T05-platform-rename-adapters/manual-verification.md)
- **005 session undo**: [`specs/005-rename-exec/tasks/T06-session-undo/manual-verification.md`](../../specs/005-rename-exec/tasks/T06-session-undo/manual-verification.md)
- **005 empty rule UI**: [`specs/005-rename-exec/tasks/T09-empty-rule-ui/manual-verification.md`](../../specs/005-rename-exec/tasks/T09-empty-rule-ui/manual-verification.md)
- **007 ルール永続化**: [`specs/007-rule-persistence/tasks/T06-verify-restart-persistence/manual-verification.md`](../../specs/007-rule-persistence/tasks/T06-verify-restart-persistence/manual-verification.md)

- **APK ビルド**: `flutter build apk --debug`（成果物 `build/app/outputs/flutter-apk/`）。署名済みリリースは `--release`（署名鍵の扱いは別途）。

## 注意

- **エージェントは実行結果を代われない。** 実機/エミュレータでの見え方・権限挙動・実ファイル変化の確認は人間が行い、必要ならスクリーンショットや `adb` 出力を共有する。
- `.github/workflows` を含む push はサンドボックスから拒否される（仕様）。CI 変更が要るときは人間が push する。
