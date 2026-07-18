## AI sandbox 前提(ai-sandbox-setup 導入済み)

このリポジトリの AI エージェント作業は Dev Container(compose.ai.yml)内で行う。サンドボックス内かは `printenv AI_SANDBOX`(=1)で判定できる。Flutter/Dart プロジェクト向け構成(ai-sandbox-setup の `--lang flutter` で生成): ベースは `debian:bookworm-slim` に Flutter SDK をホストと同じ revision で pin して導入したもので、非 root ユーザー `dev` で動作する。Claude Code / Codex の CLI はイメージに導入済みで、ログインは volume に永続化される。

- コンテナ内の `secrets/` はダミー実体(secrets.example の read-only マウント)。環境変数も、`.env` 等の慣習パスの中身もすべてダミー値になる。本物が見えないのは故障ではなく仕様。本物の env で動かすのは人間の実行時のみ
- `compose.ai.yml` と `.devcontainer/` は read-only。変更が必要なら人間に依頼する
- push / PR: gh で可。ただし `.github/workflows` を含む push は拒否される(仕様。ユーザーが push する)
- クラウド認証(gcloud / aws)や広権限トークンをこの環境に持ち込まない。インフラ・デプロイ設定の作業(infra-setup / cd-setup 相当)はホスト側の人間監督下セッションで行う
- 新しい秘密(Firebase 設定・署名鍵・実値 tfvars 等)は `secrets/` に置く。ツールがルート等に生成した場合、逃がし方の調査と手順の提案までは自分で行ってよい(ファイルの中身は開かない)が、**移動の実行と compose の変更は人間に依頼する** — コンテナ内の `secrets/` は read-only のダミーで、ホストの `secrets/` へは書き込めないため(起動時の check-secrets.sh も警告する)
- このコンテナには Android SDK / Xcode が無い。実機・エミュレータ向けビルド(`flutter run`, `flutter build apk` 等)はできない。コード編集・`flutter analyze` / `flutter test` が主目的
