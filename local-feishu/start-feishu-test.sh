#!/bin/bash
# One-command personal Feishu OAuth test: opens a temporary Cloudflare tunnel,
# then starts the local callback service with the tunnel URL.
set -euo pipefail

RELAY_DIR="$(cd "$(dirname "$0")" && pwd)"
TUNNEL_LOG="$(mktemp -t motion-note-cloudflared.XXXXXX)"
CLOUDFLARED_BIN="$(command -v cloudflared || true)"
if [ -z "$CLOUDFLARED_BIN" ] && [ -x "$HOME/Downloads/cloudflared" ]; then
  CLOUDFLARED_BIN="$HOME/Downloads/cloudflared"
fi
if [ -z "$CLOUDFLARED_BIN" ]; then
  echo "找不到 cloudflared。请先在“下载”文件夹双击 cloudflared-darwin-arm64.tgz 解压。"
  exit 1
fi

cleanup() {
  [ -n "${TUNNEL_PID:-}" ] && kill "$TUNNEL_PID" 2>/dev/null || true
  rm -f "$TUNNEL_LOG"
}
trap cleanup EXIT INT TERM

"$CLOUDFLARED_BIN" tunnel --url http://127.0.0.1:8787 >"$TUNNEL_LOG" 2>&1 &
TUNNEL_PID=$!
for _ in $(seq 1 30); do
  PUBLIC_BASE_URL=$(grep -Eo 'https://[-a-z0-9]+\.trycloudflare\.com' "$TUNNEL_LOG" | head -1 || true)
  [ -n "$PUBLIC_BASE_URL" ] && break
  sleep 1
done
if [ -z "${PUBLIC_BASE_URL:-}" ]; then
  cat "$TUNNEL_LOG"
  echo "没有取得临时 HTTPS 地址，请检查网络后重试。"
  exit 1
fi

echo
echo "临时回调地址：${PUBLIC_BASE_URL}/feishu/callback"
echo "请现在到飞书开放平台的安全设置中，把这个完整地址加入“重定向 URL”。"
echo "然后回到这里按回车键继续。"
read -r
read -r -s -p "输入飞书 App Secret（不会保存，也不会显示）: " FEISHU_APP_SECRET
echo
export PUBLIC_BASE_URL FEISHU_APP_SECRET
export FEISHU_APP_ID="cli_aaf6d50ac2f95be2"
node "$RELAY_DIR/server.mjs"
