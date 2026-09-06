#!/usr/bin/env bash
# Restores the /ws WebSocket proxy block that sudo-queue/63 added directly to the LIVE nginx
# config but never checked into this repo's own CarePyre/ops/nginx-carepyre.conf -- so the next
# time sudo-queue/51 (console deploy) blindly `cp`'d that file over the live one (as it did
# earlier today, redeploying the mail encryption feature), it silently erased the webphone's only
# public entry point. Founder: "ok i made joe ext 1 and then i logged out on penelope and then
# back in still shows me a login form" -> after confirming she WAS actually logged in and the Web
# Phone panel just hung on "Connecting..." forever -- root-caused via a direct wss:// probe
# returning a plain 404 instead of a 101 Switching Protocols.
#
# This repo's own nginx-carepyre.conf now has the /ws block permanently, so this can't regress
# again on a future sudo-queue/51 run. This script just applies that fix to the live file right
# now, narrowly (nginx config + reload only) -- it does NOT rebuild or restart idunapro, since
# nothing about the backend changed.
#
# RUN THIS AS YOURSELF (fatbaby) -- NOT with `sudo ./73-....sh`.
if [ "$(id -u)" -eq 0 ]; then
  echo "ERROR: run this script as yourself (fatbaby), not via sudo." >&2
  exit 1
fi

set -euo pipefail

echo "[1/3] Install the corrected nginx config (now includes the /ws block for real)"
sudo cp /home/fatbaby/CarePyre/ops/nginx-carepyre.conf /etc/nginx/sites-available/carepyre
sudo nginx -t
sudo systemctl reload nginx

echo ""
echo "[2/3] Verify the WebSocket upgrade now succeeds (should be 101, not 404)"
curl -s -o /dev/null -w "wss upgrade probe: %{http_code}\n" \
  -H "Connection: Upgrade" -H "Upgrade: websocket" -H "Sec-WebSocket-Version: 13" \
  -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" https://carepyre.org/ws

echo ""
echo "[3/3] Done. Refresh the console and try the Web Phone again -- it should move past"
echo "      'Connecting...' to 'Registered.' now."
