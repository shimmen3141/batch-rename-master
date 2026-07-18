# AI エージェント用イメージ。Flutter/Dart プロジェクト向けに Flutter SDK 同梱イメージをベースにする。
# ベースは Cirrus Labs のコミュニティ Flutter イメージ(Ubuntu ベース、Flutter/Dart SDK 同梱)。
# .metadata の channel: stable に合わせて stable タグを使用する。
FROM ghcr.io/cirruslabs/flutter:stable

# pubspec.yaml の environment.sdk 制約(^3.12.2 / .metadata の revision)を満たすため、
# イメージ同梱の Flutter checkout をホスト開発環境と同じコミットへ合わせる
# (ビルド時点では firewall 未適用なので github.com への通信が必要)。
RUN cd /sdks/flutter \
  && git fetch --depth=1 origin ee80f08bbf97172ec030b8751ceab557177a34a6 \
  && git checkout ee80f08bbf97172ec030b8751ceab557177a34a6 \
  && flutter --version

# firewall(iptables/ipset)と検証に必要なツール
RUN apt-get update && apt-get install -y --no-install-recommends \
      iptables ipset iproute2 dnsutils jq curl ca-certificates \
  && rm -rf /var/lib/apt/lists/*

# gh CLI(方式B: fine-grained PAT で push / PR 作成するために使用)
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list \
  && apt-get update && apt-get install -y --no-install-recommends gh \
  && rm -rf /var/lib/apt/lists/*

# firewall スクリプトはイメージに焼き込む(workspace 上のコピーを書き換えても実行されるものは変わらない)。
# ベースイメージはコンテナ内 root で動作するため sudo 経由にはせず直接実行する。
COPY init-firewall.sh /usr/local/bin/init-firewall.sh
RUN chmod +x /usr/local/bin/init-firewall.sh

WORKDIR /workspace
