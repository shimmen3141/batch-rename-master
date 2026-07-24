#!/bin/bash
# ドリフト検出: 秘密らしきファイルが AI コンテナから見える場所に無いかを起動のたびに検査する。
# コンテナ内で実行することに意味がある — ここで見つかるもの = 実際に AI から見えているもの。
# 値は出力しない。ファイル名のみ警告する。
#
# 検査は2段:
#   1) /workspace/secrets がダミー差し替え(secrets.example の ro マウント)になっているか(マーカー照合)。
#      不一致 = 本物の secrets/ が見えている可能性 → 即エラー(fail-open の検出)
#   2) secrets/ の外に秘密パターンのファイルが見えていないか(ドリフト検出)。
#      symlink は -type f にマッチしないので、リンク方式の慣習パス(.env 等)は警告されない
#
# 秘密は導入時に一度 secrets/ へ集約しても、日常開発で再発する:
#   npx prisma init → ルートに .env / vercel env pull → .env.local / terraform → 実値 tfvars・ローカル state
#
# ホスト側でも実行できる: bash .devcontainer/check-secrets.sh .
#   (ホストではマーカー検査をスキップし、ドリフト検出のみ行う。secrets/ は実体の置き場なので除外)
set -uo pipefail

ROOT="${1:-/workspace}"
MARKER="AI_SANDBOX_DUMMY_MARKER v1"

# ---- 1) ダミー差し替えマウントの健全性(コンテナ内のみ) ----
# grep で照合する: マーカーは Windows ホストで作成されることがあり CRLF を含みうるため、
# 完全一致比較($(cat) との =)では改行差で偽陽性の「隔離破綻」になる
if [ "$ROOT" = "/workspace" ]; then
  if ! grep -q "$MARKER" "$ROOT/secrets/.dummy-marker" 2>/dev/null; then
    echo "NG: /workspace/secrets がダミー(secrets.example)になっていません。隔離が破綻している可能性があります。" >&2
    echo "    compose.ai.yml の「./secrets.example:/workspace/secrets:ro」マウント行と、" >&2
    echo "    secrets.example/.dummy-marker の存在を確認してください。" >&2
    exit 2
  fi
fi

# ---- 2) ドリフト検出 ----
PATTERNS=(
  ".env"
  ".env.*"
  ".dev.vars"
  "*.pem"
  "*.key"
  "*.p12"
  "service-account*.json"
  "firebase-adminsdk*.json"
  "*.tfvars"
  "*.tfstate"
  "*.tfstate.*"
  # Flutter / モバイルの署名鍵・設定(Node プロジェクトではマッチしないだけなので常に入れておく)
  "*.jks"
  "*.keystore"
  "key.properties"
  "google-services.json"
  "GoogleService-Info.plist"
)

found=0
for p in "${PATTERNS[@]}"; do
  while IFS= read -r f; do
    case "$f" in
      "$ROOT/secrets/"*) continue ;;     # コンテナではダミー(マーカー確認済み)、ホストでは実体の正しい置き場
      */secrets.example/*) continue ;;   # ダミーは対象外
      */node_modules/*) continue ;;
      */.dart_tool/*) continue ;;        # Flutter のツールキャッシュ
      */.pub-cache/*) continue ;;        # pub のパッケージキャッシュ(volume)
      "$ROOT/build/"*) continue ;;       # Flutter のビルド成果物(ルート直下のみ除外。実体の秘密は元ファイル側で検出される)
      */.git/*) continue ;;
      *.example | *.sample) continue ;;  # .env.example / dev.tfvars.example 等
    esac
    [ -s "$f" ] || continue              # 空ファイルは対象外(.gitkeep 等)
    echo "WARN: 秘密の可能性があるファイルが AI から見えています: $f" >&2
    found=1
  done < <(find "$ROOT" -name "$p" -type f 2>/dev/null)
done

if [ "$found" -eq 1 ]; then
  echo "" >&2
  echo "対処: 実値なら secrets/ へ移す。ダミー/重複/再取得可能なら削除。対応はホスト側で行う。" >&2
  echo "手順は docs/development/ai-sandbox.md の「ツールが新しい秘密ファイルを作ったら」節を参照。対応後にコンテナを再起動する。" >&2
  exit 1 # postStartCommand を失敗させ、ユーザーに通知を出す(コンテナ自体は動く)
fi
echo "OK: no secret-like files visible"
