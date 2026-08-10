#!/usr/bin/env bash
# Adds the /api/ reverse-proxy to carepyre.org's nginx config and pushes the
# updated static site + contact-form-enabled index.html live. Same pattern
# okemily.com already uses for its own /api/ -> IDUNA (:8080) proxy.
#
# Founder real-time, 2026-08-10: "can we make the contact us a form that
# dumps to iduna?" -> "remove hello@carepyre.org and use the real contact
# form" -> "so a backend in iduna backoffice" -> "make the contact form send
# to a page in iduna back office" -> "not real email to keep scope small".
#
# IDUNA-side work (already deployed, no sudo needed for that half):
#   - new public endpoint POST /api/v1/carepyre/contact (CORS+rate-limited,
#     no auth -- IDUNA/internal/http/handlers/carepyre_contact.go)
#   - new table carepyre_contact_submissions (migration
#     202608100001_carepyre_contact_submissions.sql, applied automatically)
#   - new Back Office page /admin/carepyre listing submissions, linked from
#     the dashboard's Quick Actions card
#   - IDUNA binary already rebuilt + redeployed + systemd-restarted
#
# This script is the other half: it needs root to touch
# /etc/nginx/sites-available/carepyre and /var/www/carepyre.
set -euo pipefail

echo "[1/3] Install the updated nginx config (adds location /api/ -> IDUNA :8080)"
echo "      (/var/www/carepyre/index.html already pushed directly -- fatbaby-owned dir, no sudo needed)"
sudo cp /home/fatbaby/CarePyre/ops/nginx-carepyre.conf /etc/nginx/sites-available/carepyre
sudo nginx -t

echo "[2/3] Reload nginx"
sudo systemctl reload nginx

echo "[3/3] Verify"
curl -sI https://carepyre.org/ | head -1
curl -s -o /dev/null -w "contact endpoint via carepyre.org: %{http_code}\n" \
  -X OPTIONS -H "Origin: https://carepyre.org" https://carepyre.org/api/v1/carepyre/contact

echo ""
echo "Done. Test a real submission:"
echo '  curl -s -X POST https://carepyre.org/api/v1/carepyre/contact \'
echo '    -H "Content-Type: application/json" \'
echo '    -d '"'"'{"name":"Test","email":"test@example.com","message":"hello"}'"'"''
