# このリポジトリの AI サンドボックス開発環境 — 使い方

このリポジトリは、Claude Code / Cursor などの AI エージェントが `.env` やサービスアカウント鍵などの**秘密情報に物理的に到達できない**ように隔離された開発環境(Dev Container)を備えています(ai-sandbox-setup 導入済み)。

このプロジェクトは Flutter/Dart 製です。汎用の ai-sandbox-setup テンプレートは Node.js 向けに作られているため、このガイドおよび `.devcontainer/` 一式は Flutter 向けに手動で移植したものです(Flutter SDK 同梱の Docker イメージをベースに、firewall・secrets 隔離・push 権限分離を組み込んでいます)。

基本の考え方はシンプルです:

- **AI はコンテナの中で作業する。** コンテナからは秘密はダミー値にしか見えず、任意の外部への通信も pub.dev 等の許可リスト以外は遮断され、push にはこのリポジトリ限定の PAT だけを持ちます(被害はこのリポジトリの contents / PR 操作に限定)。
- **本物の秘密で動かすのは人間だけ。** ホスト側で人間が起動するときにだけ、本物の `secrets/` が使われます(現時点ではこのプロジェクトに秘密ファイルはありませんが、将来 Firebase 設定などを追加したときのための仕組みです)。

この2つを守っている限り、たとえ AI がプロンプトインジェクションで乗っ取られても、秘密の読み取り・持ち出し・勝手な push は「できない」構成になっています(push できる範囲もこのリポジトリの contents / PR に限定されます)。

---

## 1. 準備

**初回だけ:**

1. VS Code に **Dev Containers 拡張**(`ms-vscode-remote.remote-containers`)を入れる。
2. (推奨)VS Code の**ユーザー settings.json**(`Ctrl+Shift+P` →「Preferences: Open User Settings (JSON)」)に次を追加する。ホストの gitconfig や SSH agent がコンテナへコピー/転送されるのを止める設定です:

   ```json
   "dev.containers.copyGitConfig": false,
   "dev.containers.gitCredentialHelperConfigLocation": "none"
   ```

   これはプロジェクトの `.vscode/settings.json` ではなく**ユーザー設定**に置きます。これらはホスト側のふるまいを決める設定で、ワークスペース設定からは効かないためです。

**毎回(コンテナで開発するたび):**

- **Docker Desktop を起動しておく。** コンテナは Docker 上で動くので、開発セッションのたびに必要です(初回だけではありません)。

---

## 2. AI と一緒に開発する(日常)

1. VS Code でこのフォルダを開く。
2. `Ctrl+Shift+P` →「**Dev Containers: Reopen in Container**」。初回はイメージのビルドに数分かかります(Flutter SDK 同梱イメージ + firewall/gh ツールの導入)。
3. 再び開いたら、**統合ターミナルはもうコンテナの中**です。初回だけ依存を取得:

   ```bash
   flutter pub get
   ```

4. (任意の健全性チェック)隔離が効いていることを確認できます。値は表示されません:

   ```bash
   printenv AI_SANDBOX                      # → 1
   printenv SSH_AUTH_SOCK                    # → 空
   git config --list | grep -i credential    # → 空
   ```

5. **そのコンテナ内ターミナルで** Claude Code / Cursor の AI を起動して作業します。

   > ⚠️ **ホスト側の VS Code で AI 拡張を使い続けると隔離になりません。** AI のツール実行はエディタ側で起きるため、必ずコンテナ内で AI を動かしてください。

6. AI は編集・`flutter analyze` / `flutter test` の実行・commit までを行います(author は `ai-dev`)。commit はホストの `.git` にそのまま残ります。

> 補足: このコンテナは Android SDK / Xcode を含まないため、実機・エミュレータ向けの `flutter run` やネイティブビルド(`flutter build apk` 等)はコンテナ内ではできません。コード編集・静的解析・ユニットテストが主目的です。実機ビルドはホスト側(通常の Flutter 開発環境)で行ってください。

---

## 3. 本物の秘密を使う場面になったら(人間だけ)

現時点でこのプロジェクトには `.env` や Firebase 設定などの秘密ファイルはありません。将来 `google-services.json` や `GoogleService-Info.plist`、署名用の `key.properties` / `*.jks` などを追加する場合は、本物を `secrets/` に置き、コンテナには常にダミー値(`secrets.example/`)しか見えないようにします。具体的な追加手順は **§6** を参照してください。

---

## 4. push / PR

AI もコンテナ内から push / PR を作成できます(対象リポジトリ1つに限定した fine-grained PAT を使用)。ただし `.github/workflows/` を含む push は拒否されます(仕様。その場合は人間がホスト側から push してください)。

トークンは `secrets/ai.env` に置きます。**ファイルとしては AI から見えません**(`secrets/` はダミーの影)が、compose が環境変数 `GH_TOKEN` として注入するため **AI プロセスの環境変数としては見えます**(これは意図した設計)。守りは「トークンを隠すこと」ではなく「**権限をこのリポジトリの contents / PR 操作だけに絞り、漏れても被害をそこに限定する**」ことです。だから PAT は必ず fine-grained・対象リポジトリ1つ・workflow なしにします。

**PAT の発行・更新(人間の作業。トークン値は AI に貼らない・見せない):**

1. GitHub → Settings → Developer settings → **Fine-grained personal access tokens** → Generate new token
2. **Repository access: Only select repositories → `shimmen3141/batch-rename-master` 1つだけ**
3. Permissions: `Contents: Read and write`、`Pull requests: Read and write`(issue も任せるなら `Issues: Read and write`)。**`Workflows` は付けない**(CI シークレット窃取の経路になる)
4. 有効期限は短め(〜90日)。`secrets/ai.env` を自分のエディタで開き、`GH_TOKEN=` にトークン値を記入する(チャットや AI への貼り付けは**しない**)。**Reopen in Container の前に記入**しておくと初回の gh 認証設定がそのまま通ります(未記入で Reopen しても失敗はせず「記入して Rebuild」と案内が出るだけ)
5. main はブランチ保護(PR 必須)にしておく
6. 失効したら 1〜4 をやり直す(手順4の記入だけで復帰)。トークンが漏れても被害はこのリポジトリの contents / PR 操作に限定される

---

## 5. 外部通信(egress)

このコンテナは許可した宛先以外への外向き通信を遮断します(egress allowlist)。既定で許可しているのは `pub.dev` / `pub.dartlang.org` / `storage.googleapis.com`(pub パッケージ取得)、GitHub 全般(git/gh CLI)、`api.anthropic.com` 等(Claude Code)です。開発中に必要な宛先が止まったら:

1. `.devcontainer/init-firewall.sh` の `ALLOWED_DOMAINS` にドメインを足す。
2. `Ctrl+Shift+P` →「**Dev Containers: Rebuild Container**」で反映(firewall はイメージに焼き込まれているので rebuild が必要)。

「迷ったら足さない」が原則です。エラーで宛先が分かってから足すと、その追加自体が人間のレビューを通ります。

---

## 6. ツールが新しい秘密ファイルを作ったら(ドリフト対応)

Firebase 導入(`google-services.json` 生成)や署名設定(`key.properties` 作成)などで、開発中にツールが秘密ファイルをツリー内へ生成することがあります。秘密は `secrets/` に集約する前提なので、ツリー内に実値が出た状態は AI から見える状態です。**コンテナ起動時に check-secrets.sh が「秘密の可能性があるファイルが AI から見えています」と警告するのは、この検出です。**

**まずホスト側でそのファイルの中身を確認します(AI に開かせない)。** 中身に応じて分けます:

- **ダミー/空のプレースホルダ** → 削除。本物は既に `secrets/` にあります
- **実値だが `secrets/` に同じものがある、または再取得できる** → 削除
- **実値で、そのファイルにしか無い** → `secrets/` へ移す(削除するとデータ喪失)

実値を `secrets/` へ移す手順:

```bash
mv <file> secrets/                          # 本物を secrets/ へ
```

そのうえで、そのファイルを使うツール(Gradle・Xcode 等)に `secrets/` 配下を指させるか、読み込み専用の固定パスが必要なら `compose.ai.yml` に個別ダミーマウントを足します(例: `- ./secrets.example/google-services.json:/workspace/android/app/google-services.json:ro`)。**compose の変更は隔離設定の変更なので、レビューしてから rebuild** してください。あわせて、そのファイルのダミー版(キーは保ち値だけ形状保持ダミーに置換したもの)を `secrets.example/` にも足します。

> コンテナの中では「実値を取得する」操作(Firebase CLI のログイン等)は認証が無く失敗します。これは仕様です。取得はホスト側で行ってください。

---

## 7. 覚えておくと良いこと

- **AI の diff は実行前に人間がレビューする。** 特に次の変更は、rebuild やローカルで開く前に必ず確認してください:
  - `compose*.yml` / `.devcontainer/`(隔離の設定そのもの)
  - `pubspec.yaml` の依存関係・`.vscode/tasks.json`(特に `runOn: folderOpen`)・`.vscode/launch.json`(**ホスト上**で実行される)
- **未 push の作業は AI が消しうる。** こまめに push してください(リモートが実質のバックアップ)。
- **本物の env で動くのは人間が実行するときだけ。**
- クラウド認証(gcloud / aws)や広権限トークンをこの環境に持ち込まない。インフラ・デプロイ設定の作業はホスト側の人間監督下セッションで行う。
- コンテナから抜けてホストに戻るには `Ctrl+Shift+P` →「Reopen Folder Locally」。
