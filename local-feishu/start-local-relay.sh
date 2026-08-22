#!/bin/bash
set -euo pipefail

if ! command -v cloudflared >/dev/null 2>&1; then
  echo "cloudflared is not installed. Install it first, then run this file again."
  exit 1
fi

read -r -p "Paste the temporary HTTPS tunnel address (for example https://...trycloudflare.com): " PUBLIC_BASE_URL
read -r -s -p "Enter the Feishu App Secret (it will not be saved): " FEISHU_APP_SECRET
echo
export PUBLIC_BASE_URL FEISHU_APP_SECRET
export FEISHU_APP_ID="cli_aaf6d50ac2f95be2"
node "$(dirname "$0")/server.mjs"
