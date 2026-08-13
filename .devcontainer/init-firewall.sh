#!/bin/bash
# egress allowlist: 許可した宛先以外への外向き通信を遮断する。
# Anthropic の Claude Code リファレンス devcontainer の init-firewall.sh を基にした簡略版。
# 最新版: https://github.com/anthropics/claude-code/tree/main/.devcontainer
#
# 注意:
# - このスクリプトはイメージに COPY され、sudo で実行される(devcontainer.json の postStartCommand)。
#   変更したら compose build のやり直しが必要。
# - allowlist は「ドメイン→IP 解決」を起動時に一度行う方式。CDN の IP ローテーションで
#   到達できなくなった場合は `sudo /usr/local/bin/init-firewall.sh` を再実行する。
set -euo pipefail
IFS=$'\n\t'

# 過去の成功markerを初期化開始前に無効化する。途中失敗時にstale markerを残さない。
rm -f /run/ai-firewall-ready

# ============================================================
# 許可ドメイン(scaffold.mjs が言語・エージェント選択に応じてこの配列を書き換える。
# 手動配置の場合は使うものだけ残して編集する。プロジェクト固有ドメインは随時追記)
# ============================================================
ALLOWED_DOMAINS=(
  "pub.dev"                # dart pub / flutter pub
  "pub.dartlang.org"       # pub の旧ホスト(リダイレクトで残る)
  "storage.googleapis.com" # Flutter エンジン成果物・Dart SDK(注: GCS 全バケットに開く。references/flutter.md)
  "registry.npmjs.org"     # AI エージェント CLI の更新
  "api.anthropic.com"       # Claude Code (API)
  "statsig.anthropic.com"   # Claude Code (テレメトリ)
  "sentry.io"               # Claude Code (エラーレポート)
  "claude.ai"               # Claude Code (OAuth ログイン)
  "console.anthropic.com"   # Claude Code (OAuth ログイン)
  "api.openai.com"          # Codex CLI (API)
  "auth.openai.com"         # Codex CLI (ログイン)
  "chatgpt.com"             # Codex CLI (ChatGPT プラン利用時)
  # Android storage・permission境界の一次資料調査(ASDD 013:T01)
  "developer.android.com"   # Android SDK・storage・permission公式資料
  "source.android.com"      # AOSP platform・storage公式資料
  "android.googlesource.com" # AOSP source repository
  "support.google.com"      # Google Play policy公式資料
  "api.flutter.dev"         # Flutter API公式資料
  # --- プロジェクト固有の例(必要なものだけ有効化) ---
  # "<project-ref>.supabase.co"
)

# 既存ルールをクリア
iptables -F
iptables -X
iptables -P INPUT ACCEPT
iptables -P OUTPUT ACCEPT
iptables -P FORWARD ACCEPT
ipset destroy allowed-domains 2>/dev/null || true

# localhost を許可し、DNS は resolv.conf のリゾルバ宛だけ許可する(以降のドメイン解決に必要)。
# 任意宛先の 53 番を開けると DNS クエリ自体が持ち出しチャネルになるため宛先を絞る。
# Docker 内では通常 127.0.0.11(内蔵 DNS)= loopback 経由。リゾルバの再帰解決を使う
# DNS トンネリングは残る(references/firewall.md の「限界」参照)
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT
while read -r ns; do
  iptables -A OUTPUT -p udp -d "$ns" --dport 53 -j ACCEPT
  iptables -A OUTPUT -p tcp -d "$ns" --dport 53 -j ACCEPT
done < <(awk '/^nameserver/ {print $2}' /etc/resolv.conf | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$')

ipset create allowed-domains hash:net

# GitHub は IP レンジが公開されているので meta API から登録(git clone/push, gh CLI)。
# scaffold は git-method に応じて種類を絞る(方式A: .git+.web / 方式B: +.api。.packages は使うときだけ手で足す)。
# 手動配置の場合も必要な種類だけ残すこと
echo "Fetching GitHub IP ranges..."
gh_ranges=$(curl -fsS --connect-timeout 10 https://api.github.com/meta)
for range in $(echo "$gh_ranges" | jq -r '(.git + .api + .web)[]' | grep -v ':' | sort -u); do
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
# 到達確認は github.com(.web レンジ)で行う — api.github.com(.api)は方式Aでは allowlist に入れない
if ! curl --connect-timeout 10 -fsS -o /dev/null https://github.com; then
  echo "NG: github.com に到達できない(allowlist が効いていない)" >&2
  exit 1
fi
marker_tmp=$(mktemp /run/.ai-firewall-ready.XXXXXX)
printf '%s\n' 'AI_FIREWALL_READY v1' > "$marker_tmp"
chown root:root "$marker_tmp"
chmod 0444 "$marker_tmp"
mv -f "$marker_tmp" /run/ai-firewall-ready
echo "OK: egress firewall configured"
