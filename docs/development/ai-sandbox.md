# このリポジトリの AI サンドボックス開発環境 — 使い方

このリポジトリは、Claude Code / Codex / Cursor などの AI エージェントが `.env` やサービスアカウント鍵などの**秘密情報に物理的に到達できない**ように隔離された開発環境(Dev Container)を備えています(ai-sandbox-setup 導入済み)。

基本の考え方はシンプルです:

- **AI はコンテナの中で作業する。** コンテナからは秘密はダミー値にしか見えず、任意の外部への通信も遮断され、push にはこのリポジトリ限定の PAT だけを持ちます(被害はこのリポジトリの contents / PR 操作に限定)。- **本物の秘密で動かすのは人間だけ。** ホスト側で人間が起動するときにだけ、本物の `secrets/` が使われます。

この2つを守っている限り、たとえ AI がプロンプトインジェクションで乗っ取られても、秘密の読み取り・持ち出しは「できない」構成になっています(push できる範囲もこのリポジトリの contents / PR に限定されます)。

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
2. `Ctrl+Shift+P` →「**Dev Containers: Reopen in Container**」。初回はイメージのビルドに数分かかります(ツールの導入など)。必要な拡張機能(AI エージェント・Dart/Flutter)は `devcontainer.json` の `customizations` に列挙してあり、自動でインストールされます。
3. 再び開いたら、**統合ターミナルはもうコンテナの中**です。初回だけ依存をインストール:

   ```bash
   flutter pub get
   ```

4. (任意の健全性チェック)隔離が効いていることを確認できます。値は表示されません:

   ```bash
   printenv AI_SANDBOX                      # → 1
   printenv SSH_AUTH_SOCK                    # → 空
   git config --list | grep -i credential    # → gh の helper だけが出れば正常(下記)
   ```

   方式Bでは3つ目のコマンドは**空になりません**。`gh auth setup-git` が次のような helper を設定するためで、これは正常です(空行は既存 helper をリセットするための定石):

   ```
   credential.https://github.com.helper=
   credential.https://github.com.helper=!/usr/bin/gh auth git-credential
   ```

   ここで確認したいのは「**ホスト由来の認証情報が紛れ込んでいないか**」です。`manager`・`manager-core`・`osxkeychain`・`store` といった**gh 以外の helper が出たら異常**で、ホストの gitconfig がコピーされています(§1 の `dev.containers.copyGitConfig: false` を設定してから Rebuild してください)。

5. **そのコンテナ内ターミナルで** AI エージェントを起動して作業します(下の「AI エージェントのログイン」参照)。

   > ⚠️ **ホスト側の VS Code で AI 拡張を使い続けると隔離になりません。** AI のツール実行はエディタ側で起きるため、必ずコンテナ内で AI を動かしてください。

6. AI は編集して commit まで行います(author は `ai-dev`)。commit はホストの `.git` にそのまま残ります。

### AI エージェントのログイン(初回のみ)

このコンテナには以下の AI エージェント CLI が入っています。ログイン状態は named volume に保存され、**Rebuild してもログインは保持されます**(初回だけログインが必要)。

- **Claude Code**: ターミナルで `claude` を起動。初回は `/login` → 表示された URL を**ホスト側のブラウザ**で開いて認証し、コードをターミナルに貼り戻します。
- **Codex CLI**: 初回は`codex login`を実行し、表示されたURLをホスト側のブラウザで開いて認証します(ChatGPTアカウント)。普段の作業は`codex-container`で起動します。Linux container内ではCodex自身のbubblewrap sandboxを重ねられないため、このwrapperが`AI_SANDBOX=1`とdummy secret shadowを検査してから内側sandboxだけを無効化します。wrapperをhost側で使ったり、同等の危険flagをhostの`codex`へ直接指定したりしないでください。APIキーで使う場合はキーをAIやチャットに貼らず、自分で入力してください。

### このコンテナでできること(Flutter)

コンテナには Android SDK / Xcode が**入っていません**。コンテナ内での作業はコード編集・`flutter analyze`・`flutter test`・`dart format` が主目的で、実機・エミュレータ向けのビルドと `flutter run` はホスト側で行います。

---

## 3. 実際にアプリを本物の秘密で動かす(人間だけ)

コンテナ内はダミー値しか見えないので、本物の秘密で動かすのは**人間がホスト側で**行います。

```bash
flutter run           # ホスト側で実行。秘密を注入する場合は --dart-define-from-file=secrets/<file>.json 等で secrets/ を指す
```

本物の秘密は `secrets/` に置きます。開発中にツールが新しい秘密ファイルを生成したときの寄せ方は **§6** を参照してください。

---

## 4. push / PR

AI もコンテナ内から push / PR を作成できます(対象リポジトリ1つに限定した fine-grained PAT を使用)。ただし `.github/workflows/` を含む push は拒否されます(仕様。その場合は人間がホスト側から push してください)。

トークンは `secrets/ai.env` に置きます。**ファイルとしては AI から見えません**(`secrets/` はダミーの影)が、compose が環境変数 `GH_TOKEN` として注入するため **AI プロセスの環境変数としては見えます**(これは意図した設計)。守りは「トークンを隠すこと」ではなく「**権限をこのリポジトリの contents / PR 操作だけに絞り、漏れても被害をそこに限定する**」ことです。だから PAT は必ず fine-grained・対象リポジトリ1つ・workflow なしにします。

**PAT の発行・更新(人間の作業。トークン値は AI に貼らない・見せない):**

1. GitHub → ユーザの Settings → Developer settings → **Fine-grained personal access tokens** → Generate new token
2. **Repository access: Only select repositories → このリポジトリ1つだけ**
3. Permissions(Add permissions で追加可能): `Contents: Read and write`、`Pull requests: Read and write`(issue も任せるなら `Issues: Read and write`)。**`Workflows` は付けない**(CI シークレット窃取の経路になる)
4. 有効期限は短め(〜90日)。`secrets/ai.env` を自分のエディタで開き、`GH_TOKEN=` にトークン値を記入する(チャットや AI への貼り付けは**しない**)。**Reopen in Container の前に記入**しておくと初回の gh 認証設定がそのまま通ります(未記入で Reopen しても失敗はせず「記入して Rebuild」と案内が出るだけ)
5. main はブランチ保護(PR 必須)にしておく
6. 失効したら 1〜4 をやり直す(手順4の記入だけで復帰)。トークンが漏れても被害はこのリポジトリの contents / PR 操作に限定される

---

## 5. 外部通信(egress)

このコンテナは許可した宛先以外への外向き通信を遮断します(egress allowlist)。開発中に必要な宛先が止まったら:

1. `.devcontainer/init-firewall.sh` の `ALLOWED_DOMAINS` にドメインを足す(**ホスト側で編集** — §7 参照)。
2. `Ctrl+Shift+P` →「**Dev Containers: Rebuild Container**」で反映(firewall はイメージに焼き込まれているので rebuild が必要)。

「迷ったら足さない」が原則です。エラーで宛先が分かってから足すと、その追加自体が人間のレビューを通ります。

---

## 6. ツールが新しい秘密ファイルを作ったら(ドリフト対応)

`prisma init` がルートに `.env` を作る、`vercel env pull` が `.env.local` を作る、`flutter build` の署名設定が `key.properties` を要求する、といった具合に、開発中にツールが秘密ファイルをツリー内へ生成することがあります。秘密は `secrets/` に集約する前提なので、ツリー内に実値が出た状態は AI から見える状態です。**コンテナ起動時やフォルダを開いた時に check-secrets.sh が「秘密の可能性があるファイルが AI から見えています」と警告するのは、この検出です。**

**まずホスト側でそのファイルの中身を確認します(AI に開かせない)。** 中身に応じて分けます:

- **ダミー/空のプレースホルダ**(`prisma init` が作る空 `.env` 等)→ 削除。本物は既に `secrets/` にあります
- **実値だが `secrets/` に同じものがある、または再取得できる** → 削除(再取得は出力先を `secrets/` に指定: 例 `vercel env pull secrets/.env`)
- **実値で、そのファイルにしか無い** → `secrets/` へ移す(削除するとデータ喪失)。手順は下記

### ダミー(`secrets.example/`)は手で作らない — 再生成コマンドがある

`secrets/` の内容を足したり変えたりしたら、**ホストのプロジェクトルートで次を実行**します。本物の値には触れず(スクリプト内でだけ変換)、`secrets.example/` のダミーが `secrets/` から作り直されます:

```bash
node scripts/refresh-secrets.mjs
```

`secrets.example/` のダミーを手で書く必要はありません(本物を開いてコンテキストや履歴に載せる事故を防ぐため、手作業は避けます)。更新されるのは `secrets.example/` だけで、`Dockerfile` / `compose.ai.yml` には触れません。既存ファイルの値変更・同じファイル内へのキー追加は、これだけで済みます。

> **新しい種類のファイルを初めて足した場合**(例: これまで無かった `.env.local` を新規作成)だけは、コンテナへダミーを渡すために `compose.ai.yml` の `env_file` にも登録が要ります。この一度きりの反映は、このプロジェクトを作ったときの `ai-sandbox-setup` の scaffold を `--force` 付きで再実行し、`compose.ai.yml` の diff をレビューしてから Rebuild します(compose は隔離設定なので必ず目視)。以後の値変更は上の `refresh-secrets.mjs` に戻ってよいです。

実値を `secrets/` へ移す手順(アダプタ方式):

```bash
mv <file> secrets/                          # 本物を secrets/ へ
```

そのうえで、そのファイルを使うツールに `secrets/` を指させます(Node なら `dotenv -e secrets/<file> -- ...`、Flutter なら `--dart-define-from-file=secrets/<file>`、または compose の `env_file`)。ツールが**固定パスでしか読めない**ファイル(`google-services.json` 等)は、`compose.ai.yml` に個別ダミーマウント `- ./secrets.example/<file>:/workspace/<file>:ro` を足してコンテナから隠します。**compose の変更は隔離設定の変更なので、レビューしてから rebuild** してください。ダミー自体は **`node scripts/refresh-secrets.mjs`** が作るので、手では書きません。

> コンテナの中では `vercel env pull` のような「実値を取得する」コマンドは認証が無く失敗します。これは仕様です。pull はホスト側で行ってください。

---

## 7. コンテナ内から設定ファイルを保存できないとき(仕様です)

コンテナ内の VS Code で `.devcontainer/` 配下や `compose.ai.yml` を編集して保存しようとすると、右下に

```
Failed to save 'devcontainer.json': Unable to write file ...
```

というエラーが出ます。**これは故障や権限設定のミスではなく、このサンドボックスの中核仕様です。** これらのファイルは read-only でマウントされており、AI が隔離設定そのものを書き換えて次回の Rebuild で隔離を解除する、という攻撃経路を塞いでいます。コンテナ内から `chown` / `chmod` しても直りません(read-only file system)。

**編集したいときの正しい手順(人間の作業):**

1. `Ctrl+Shift+P` →「**Dev Containers: Reopen Folder Locally**」でホスト側に戻る(または別ウィンドウでこのフォルダをローカルで開く)。
2. ホスト側で `.devcontainer/devcontainer.json` 等を編集して保存する。**変更内容は隔離設定のレビュー対象**です(特に volumes / cap_add / postStartCommand)。
3. 「**Dev Containers: Reopen in Container**」(構成変更時は「Rebuild Container」)で反映する。

**あわせて知っておくと良い IDE の挙動:**

- **拡張機能**: `devcontainer.json` の `customizations.vscode.extensions` に列挙されたものが自動で入ります。コンテナ内で手動インストールした拡張は Rebuild で消えるので、常用する拡張は上の手順で `customizations` に追記してください。
- **画面レイアウト**: コンテナはホストと別ワークスペース扱いのため、パネル配置などのレイアウトは初回は既定に戻ります(VS Code の仕様で、devcontainer 側からは制御できません)。コンテナ内で整えたレイアウトは、同じコンテナを開き直す限り保持されます。

---

## 8. 覚えておくと良いこと

- **AI の diff は実行前に人間がレビューする。** 特に次の変更は、rebuild やローカルで開く前に必ず確認してください:
  - `compose*.yml` / `.devcontainer/`(隔離の設定そのもの)
  - `package.json` の scripts・postinstall / lockfile(インストール時・実行時にコードが走る)
  - `.vscode/tasks.json`(特に `runOn: folderOpen`)・`.vscode/launch.json`(**ホスト上**で実行される)
- **未 push の作業は AI が消しうる。** こまめに push してください(リモートが実質のバックアップ)。
- **本物の env で動くのは人間が実行するときだけ。** `NEXT_PUBLIC_*` のようなクライアント公開前提の変数には、本当の秘密を入れないこと。
- クラウド認証(gcloud / aws)や広権限トークンをこの環境に持ち込まない。インフラ・デプロイ設定の作業はホスト側の人間監督下セッションで行う。
- コンテナから抜けてホストに戻るには `Ctrl+Shift+P` →「Reopen Folder Locally」。
