#!/usr/bin/env bash
# S513: MIXFORGE's client-side mix recorder ("record button... save it to your IDUNA sso
# account") needs a same-origin /api/ proxy to IDUNA, same convention WOTAN/OKEMILY/CarePyre
# already use (their own ops/nginx-*.conf) -- so web/iduna.mjs's sso-exchange/recordings fetch()
# calls hit IDUNA without a cross-origin CORS question. The IDUNA side (mixforge.play permission,
# recordings endpoints, SSO_ALLOWED_REDIRECT_HOSTS) is already deployed and live-verified via curl.
#
# This is the one piece that needs root: mixforge.okemily.com's live nginx vhost predates this
# feature and has no /api/ location block yet -- confirmed live (curl -X POST .../api/v1/games/
# mixforge/guest-register returns nginx's own generic HTML 404, not IDUNA's JSON one, meaning the
# request never reaches IDUNA at all). MIXFORGE/ops/nginx/mixforge-okemily.conf already has the
# new block (right after the acme-challenge location, before /ws) -- this script just re-syncs the
# live file and reloads, the same two commands 93-mixforge-mjs-mime-fix.sh already established for
# this exact vhost.
set -euo pipefail

echo "[1/2] Sync the updated vhost (adds the /api/ same-origin proxy to IDUNA)"
sudo cp /home/fatbaby/MIXFORGE/ops/nginx/mixforge-okemily.conf /etc/nginx/sites-available/mixforge
sudo nginx -t

echo "[2/2] Reload nginx"
sudo systemctl reload nginx

echo "Verify:"
echo '  curl -s -X POST https://mixforge.okemily.com/api/v1/games/mixforge/guest-register -d "{\"display_name\":\"probe\"}"'
echo "  -- should return real IDUNA JSON (player_id/token/...), not nginx's generic HTML 404."
