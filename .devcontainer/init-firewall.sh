#!/bin/bash
# egress allowlist: 許可した宛先以外への外向き通信を遮断する。
# Anthropic の Claude Code リファレンス devcontainer の init-firewall.sh を基にした簡略版。
#
# 注意:
# - このスクリプトはイメージに COPY され、コンテナ起動時(postStartCommand)に実行される。
#   変更したら compose build のやり直しが必要。
# - allowlist は「ドメイン→IP 解決」を起動時に一度行う方式。CDN の IP ローテーションで
#   到達できなくなった場合は /usr/local/bin/init-firewall.sh を再実行する。
set -euo pipefail
IFS=$'\n\t'

# ============================================================
# 許可ドメイン(Flutter/Dart プロジェクト向け)
# ============================================================
ALLOWED_DOMAINS=(
  "pub.dev"                  # flutter pub get
  "pub.dartlang.org"         # pub の旧ホスト名(一部ツールが参照)
  "storage.googleapis.com"   # pub パッケージ本体・Flutter SDK アーティファクトの実配信元
  "api.anthropic.com"        # Claude Code
  "statsig.anthropic.com"
  "sentry.io"
)

# 既存ルールをクリア
iptables -F
iptables -X
iptables -P INPUT ACCEPT
iptables -P OUTPUT ACCEPT
iptables -P FORWARD ACCEPT
ipset destroy allowed-domains 2>/dev/null || true

# DNS と localhost は先に許可(以降のドメイン解決に必要)
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT

ipset create allowed-domains hash:net

# GitHub は IP レンジが公開されているので meta API から登録(git clone/push, gh CLI)
echo "Fetching GitHub IP ranges..."
gh_ranges=$(curl -fsS --connect-timeout 10 https://api.github.com/meta)
for range in $(echo "$gh_ranges" | jq -r '(.git + .api + .web + .packages)[]' | grep -v ':' | sort -u); do
  ipset add allowed-domains "$range" 2>/dev/null || true
done

# 許可ドメインを解決して登録
for domain in "${ALLOWED_DOMAINS[@]}"; do
  echo "Resolving $domain..."
  ips=$(dig +short A "$domain" | grep -E '^[0-9]+\.' || true)
  if [ -z "$ips" ]; then
    echo "WARN: $domain を解決できない(スペルミス or DNS 不調)" >&2
    continue
  fi
  for ip in $ips; do
    ipset add allowed-domains "$ip" 2>/dev/null || true
  done
done

# ホスト側ネットワーク(Docker ゲートウェイ)との通信を許可
HOST_IP=$(ip route | grep default | awk '{print $3}')
HOST_NETWORK=$(echo "$HOST_IP" | sed 's/\.[0-9]*$/.0\/24/')
iptables -A INPUT -s "$HOST_NETWORK" -j ACCEPT
iptables -A OUTPUT -d "$HOST_NETWORK" -j ACCEPT

# 確立済み接続と allowlist 宛のみ許可し、既定を DROP に
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m set --match-set allowed-domains dst -j ACCEPT
iptables -P INPUT DROP
iptables -P OUTPUT DROP
iptables -P FORWARD DROP

# ============================================================
# 自己検証: 遮断と許可の両方を確認して初めて成功とする
# ============================================================
if curl --connect-timeout 5 -fsS https://example.com >/dev/null 2>&1; then
  echo "NG: example.com に到達できてしまう(firewall が効いていない)" >&2
  exit 1
fi
if ! curl --connect-timeout 10 -fsS https://api.github.com/zen >/dev/null 2>&1; then
  echo "NG: api.github.com に到達できない(allowlist が効いていない)" >&2
  exit 1
fi
echo "OK: egress firewall configured"
