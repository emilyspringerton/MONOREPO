#!/usr/bin/env bash
# Deploys the /gfd-ws/<port> nginx WebSocket<->UDP proxy location (real TLS
# termination for the GFD Battlegrounds WASM web client — the client is
# served over HTTPS, so its WebSocket connections must be wss:// or every
# modern browser blocks them as mixed active content). Founder real-time,
# 2026-08-20: "ensure GFD web is live on okemily - link it from WOTAN" /
# "live demos that are more than just demos."
#
# Also folds in a real drift fix: /etc/nginx/sites-available/okemily had
# diverged from OKEMILY/ops/nginx-okemily.conf (the prompt-o-verse
# no-cache block from sudo-queue/16 was applied live but never synced back
# into this repo) — per OKEMILY/CLAUDE.md's own explicit warning ("always
# diff against the live file first... copy live into the repo, never the
# other way around"), this script's source file was built by copying the
# live file first, THEN adding the new location block on top, so this
# deploy is additive, not a silent regression of #16's fix.
set -euo pipefail
sudo cp /home/fatbaby/OKEMILY/ops/nginx-okemily.conf /etc/nginx/sites-available/okemily
sudo nginx -t
sudo systemctl reload nginx
