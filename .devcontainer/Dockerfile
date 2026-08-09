FROM debian:bookworm-slim

# 基本ツール(firewall 用 iptables 類を含む)
RUN apt-get update && apt-get install -y --no-install-recommends \
      git curl ca-certificates unzip xz-utils zip iptables ipset iproute2 dnsutils jq sudo nodejs npm \
  && rm -rf /var/lib/apt/lists/*

# 非 root ユーザー。root で動かすと AI 自身が iptables を書き換えて firewall を解除できてしまう
RUN useradd -m -s /bin/bash dev

# gh CLI(方式B: fine-grained PAT で push / PR 作成)
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates \
  && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list \
  && apt-get update && apt-get install -y --no-install-recommends gh \
  && rm -rf /var/lib/apt/lists/*

# firewall スクリプトはイメージに焼き込む(workspace 上のコピーを書き換えても実行されるものは変わらない)。
# sudo は dev ユーザーにこのスクリプト1つだけ許可する
COPY init-firewall.sh /usr/local/bin/init-firewall.sh
RUN chmod +x /usr/local/bin/init-firewall.sh \
  && echo "dev ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.sh" > /etc/sudoers.d/dev-firewall \
  && chmod 0440 /etc/sudoers.d/dev-firewall

# AI エージェント CLI(バージョンは pin せず、Rebuild のたびに最新を入れる)。
# 先に npm の latest メタデータを取り込むことでキャッシュを制御する: 新バージョンが公開された
# ときだけこのファイルの内容が変わり、下の RUN のキャッシュが無効化される(変化が無ければ
# キャッシュが効くので、毎回 --no-cache でフルリビルドする必要がない)。
# CLI はコンテナ内(非 root)からは更新できない設計なので、更新はこの Rebuild で行う
ADD https://registry.npmjs.org/@anthropic-ai/claude-code/latest /tmp/claude-code-latest.json
ADD https://registry.npmjs.org/@openai/codex/latest /tmp/codex-latest.json
RUN npm install -g @anthropic-ai/claude-code @openai/codex

# Windows hostからbind mountしたrepositoryはcontainer内のdev userと所有者が異なる。
# 対象をworkspace rootだけに限定し、compose runでもGitの所有者保護を満たす。
# devcontainer.jsonのpostCreateCommandはVS Code経由でしか実行されないため、imageにも設定する。
RUN git config --system --add safe.directory /workspace

# named volume の初期所有者(volume は初回マウント時にイメージ側の内容と所有者を引き継ぐ)
RUN mkdir -p /workspace/.dart_tool /workspace/build /workspace/.pub-cache /home/dev/.claude /home/dev/.codex && chown -R dev:dev /workspace /home/dev

USER dev
# Flutter SDK をホストと同じリリースタグに pin する。
# 可変タグ(cirruslabs の :stable 等)は pull タイミングでプロジェクトの SDK 制約(pubspec の
# sdk: ^x.y.z)とズレるため、ホストの `flutter --version` のバージョンを使う。
# sha 直接の shallow fetch はタグが無く flutter が 0.0.0-unknown を名乗り pub が解決不能になるため、タグで fetch する
RUN mkdir /home/dev/flutter && cd /home/dev/flutter && git init -q \
  && git remote add origin https://github.com/flutter/flutter.git \
  && git fetch --depth=1 origin refs/tags/3.44.6:refs/tags/3.44.6 \
  && git checkout -q tags/3.44.6 \
  && git rev-parse HEAD | grep -qi "^ee80f08bbf97172ec030b8751ceab557177a34a6" # タグがホストの revision と一致することの検証
ENV PATH="/home/dev/flutter/bin:/home/dev/.local/bin:$PATH"
ENV PUB_CACHE=/workspace/.pub-cache
# ログインシェル(bash -l)では Debian の /etc/profile が PATH を上書きするため、~/.profile でも追加する
RUN echo 'export PATH="$HOME/flutter/bin:$HOME/.local/bin:$PATH"' >> /home/dev/.profile
# 初回実行で Dart SDK・ツールをダウンロードしてイメージに焼き込む
RUN flutter --version
# artifacts(Material Fonts / Gradle Wrapper / engine 等)も焼き込む。
# これが無いと VS Code の Flutter 拡張が daemon 起動時に毎回ダウンロードを始め、
# タイムアウトして「The Flutter Daemon failed to start」になる(実機で確認)
RUN flutter precache

# container自体をsecurity boundaryにしたCodex起動wrapper。
# 最後のlayerに置き、wrapperだけの変更でFlutter SDKを再取得しない。
COPY --chmod=0755 codex-container /usr/local/bin/codex-container
