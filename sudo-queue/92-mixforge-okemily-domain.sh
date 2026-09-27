#!/usr/bin/env bash
# Stands up mixforge.okemily.com -- MIXFORGE's own dedicated domain (founder real-time,
# 2026-09-27: "lets get MIXFORGE live mixforge.okemily.com"). See
# /home/fatbaby/MIXFORGE/ops/nginx/mixforge-okemily.conf and
# /home/fatbaby/MIXFORGE/ops/systemd/mixforge-room-server.service for the app-level side of this
# (already built, tested, committed, and running as a user systemd service -- this script is only
# the missing sudo-gated infra half: nginx vhost + cert).
#
# PRECONDITION, not handled by this script: mixforge.okemily.com must already resolve to this
# box's public IP (198.58.107.85, same as iam.okemily.com/wotan.okemily.com/okemily.com) before
# certbot's HTTP-01 challenge below can succeed. DNS is managed via Terraform, same as every
# other *.okemily.com record now -- see IDUNA/ops/terraform/main.tf. Run that first:
#   export TF_VAR_cloudflare_api_token="$(grep -oP '^cfat_[A-Za-z0-9]+' /home/fatbaby/EMILY/var/cloudflare.md | head -1)"
#   cd /home/fatbaby/IDUNA/ops/terraform && terraform init && terraform plan && terraform apply
# then wait for it to propagate (`dig +short mixforge.okemily.com` should return 198.58.107.85)
# before running this script.
set -euo pipefail

echo "[0/4] Sanity check: does mixforge.okemily.com resolve yet?"
if ! dig +short mixforge.okemily.com | grep -q .; then
  echo "mixforge.okemily.com does not resolve yet -- create the DNS record first (see header comment)." >&2
  exit 1
fi

echo "[1/4] Install the nginx server block (HTTP only, pre-cert)"
sudo cp /home/fatbaby/MIXFORGE/ops/nginx/mixforge-okemily.conf /etc/nginx/sites-available/mixforge
sudo ln -sf /etc/nginx/sites-available/mixforge /etc/nginx/sites-enabled/mixforge
sudo nginx -t

echo "[2/4] Reload nginx so the HTTP-01 challenge has somewhere to answer"
sudo systemctl reload nginx

echo "[3/4] Issue the cert -- certbot's --nginx plugin rewrites"
echo "      /etc/nginx/sites-available/mixforge to add the SSL server block"
echo "      automatically, same as every other *.okemily.com vhost."
sudo certbot --nginx -d mixforge.okemily.com

echo "[4/4] Done. Verify:"
echo "  curl -sI https://mixforge.okemily.com/"
echo "  open https://mixforge.okemily.com/ in two browser tabs -- each should join its own seat"
echo ""
echo "Reminder: after any future certbot re-run, diff the live"
echo "  /etc/nginx/sites-available/mixforge against MIXFORGE/ops/nginx/mixforge-okemily.conf"
echo "  and copy the live version back into the repo if they've diverged --"
echo "  same lesson OKEMILY/CLAUDE.md documents for okemily.com's own config."
