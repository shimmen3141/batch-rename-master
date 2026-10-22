# Development finding: Node.js 配布元の変更で Python の間接依存を失った

- 観測日: 2026-10-22
- 観測した作業: 開発コンテナの Node.js セキュリティ更新と再作成
- 改善先: project / agent-runtime
- 関連Issue・commit・artifact: [Node.js 更新 PR](https://github.com/shimmen3141/ai-sandbox-setup/pull/3)、[Python 維持の修正 PR](https://github.com/shimmen3141/ai-sandbox-setup/pull/4)、`.devcontainer/Dockerfile`、`test/tooling/repo_checks_test.dart`

## 観測した事実

Debian の Node.js / npm を公式 Node.js イメージ由来のバイナリへ置き換えたところ、従来 npm の間接依存として存在した Python 3 がコンテナから失われた。Node.js と npm の動作確認、`flutter analyze` は成功したが、最初の全テストでは Python を呼ぶ repository 検査 3 件が失敗した。

`test/tooling/repo_checks_test.dart` は `tool/check_normative_terms.py`、`tool/check_platform_boundary.py`、`tool/check_mutation_finds.py` を実行する。これらの既存検査が使えることが期待されていたが、ランタイム単体の動作確認では依存不足を検出できなかった。

## 影響とworkaround

- 影響: 開発コンテナで既存の検査を完走できず、再ビルドと再作成が必要になった。
- その場のworkaround: Dockerfile に `python3` の明示的な導入を追加した。更新前のイメージと既存の永続ボリュームを保持した。

## 仮説と改善案

- 仮説: パッケージの置き換えを主要コマンドの互換性だけで評価し、既存検査が利用する間接依存を見落とした。
- 改善案: 配布元やインストール方式を変更するときは、既存の project 検査が必要とするコマンドを確認し、候補イメージで関連検査と全テストを実施してから切り替える。必要な開発ツールは間接依存に頼らず明示する。

## 改善結果

project の Dockerfile と Flutter sandbox の生成スクリプト・テンプレートに Python 3 を明示した。インストール済み skill にも同じ修正を適用し、生成 4 シナリオと独立レビューが成功した。

修正後の実コンテナで Node.js 22.23.4、npm 10.9.9、Python 3.11.2 を確認した。`flutter analyze` と全テストが成功した（1,538 件完了、失敗 0、skip 0）。再作成処理も終了コード 0 で完了した。既存 6 ボリュームの維持、保護対象の読み取り専用マウント、非 root 実行、通信先の制限も確認した。
