#!/usr/bin/env bash
# S583: real, found-live bug in the NOCK video editor's phone-upload QR flow, reported by the
# founder as "nock tools video uploader qr... doesnt work". Root cause confirmed directly (not
# assumed): the admin side that GENERATES the QR (/admin/nock/api/video-upload-links/{id}/qr)
# already worked fine -- it's under /admin/, already proxied to IDUNA. But the URL that QR image
# actually ENCODES is /nock/upload/{token}, the public no-login page a phone's camera navigates
# to -- and okemily.com's live nginx vhost has NO location block for bare /nock/ at all. Every real
# phone scan hit this file's own default `location / { try_files ... =404; }` static-site fallback
# instead of IDUNA's NockPhoneUploadHandler, a plain 404 before the request ever reached IDUNA.
#
# OKEMILY/ops/nginx-okemily.conf already has the new /nock/ location block (same same-origin-proxy
# shape as /admin/, /portal/, /api/ in this same file) -- this script just re-syncs the live file
# and reloads, the same two commands 93/96's own precedent already established for other vhosts.
set -euo pipefail

echo "[1/2] Sync the updated okemily.com vhost (adds the /nock/ same-origin proxy to IDUNA)"
sudo cp /home/fatbaby/OKEMILY/ops/nginx-okemily.conf /etc/nginx/sites-available/okemily
sudo nginx -t

echo "[2/2] Reload nginx"
sudo systemctl reload nginx

echo "Verify:"
echo '  curl -s -o /dev/null -w "%{http_code}\n" https://okemily.com/nock/upload/does-not-exist'
echo '  -- should be a real IDUNA response (410/404 JSON from NockPhoneUploadHandler, or the real'
echo '  "expired/invalid link" HTML page), never nginx'"'"'s generic static-site 404 for an unknown route.'
