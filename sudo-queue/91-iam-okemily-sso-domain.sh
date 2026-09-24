#!/usr/bin/env bash
# Stands up iam.okemily.com -- the real, dedicated IDUNA SSO login domain (founder real-time,
# 2026-09-24: "instead of putting your password into page on wotan iduna needs to become the
# SSO" -> "iam.okemily.com make that the actual sso page"). See
# /home/fatbaby/IDUNA/internal/http/handlers/sso_login.go and
# /home/fatbaby/IDUNA/ops/nginx/iam-okemily.conf for the app-level side of this (already built,
# tested, committed -- this script is only the missing infra half).
#
# PRECONDITION, not handled by this script: iam.okemily.com must already resolve to this box's
# public IP (198.58.107.85, same as wotan.okemily.com/okemily.com) before certbot's HTTP-01
# challenge below can succeed. DNS is now managed via Terraform (founder real-time: "use
# cloudflare to do the dns - use terraform"), not a raw API call -- see
# IDUNA/ops/terraform/main.tf. Run that first:
#   export TF_VAR_cloudflare_api_token="$(grep -oP '^cfat_[A-Za-z0-9]+' /home/fatbaby/EMILY/var/cloudflare.md | head -1)"
#   cd /home/fatbaby/IDUNA/ops/terraform && terraform init && terraform plan && terraform apply
# then wait for it to propagate (`dig iam.okemily.com` should return 198.58.107.85) before
# running this script.
set -euo pipefail

echo "[0/4] Sanity check: does iam.okemily.com resolve yet?"
if ! dig +short iam.okemily.com | grep -q .; then
  echo "iam.okemily.com does not resolve yet -- create the DNS record first (see header comment)." >&2
  exit 1
fi

echo "[1/4] Install the nginx server block (HTTP only, pre-cert)"
sudo cp /home/fatbaby/IDUNA/ops/nginx/iam-okemily.conf /etc/nginx/sites-available/iam
sudo ln -sf /etc/nginx/sites-available/iam /etc/nginx/sites-enabled/iam
sudo nginx -t

echo "[2/4] Reload nginx so the HTTP-01 challenge has somewhere to answer"
sudo systemctl reload nginx

echo "[3/4] Issue the cert -- certbot's --nginx plugin rewrites"
echo "      /etc/nginx/sites-available/iam to add the SSL server block"
echo "      automatically, same as every other *.okemily.com vhost."
sudo certbot --nginx -d iam.okemily.com

echo "[4/4] Done. Verify:"
echo "  curl -sI https://iam.okemily.com/"
echo "  curl -s 'https://iam.okemily.com/?redirect_uri=https://wotan.okemily.com/store.html' | head -20"
echo ""
echo "Reminder: after any future certbot re-run, diff the live"
echo "  /etc/nginx/sites-available/iam against IDUNA/ops/nginx/iam-okemily.conf"
echo "  and copy the live version back into the repo if they've diverged --"
echo "  same lesson OKEMILY/CLAUDE.md documents for okemily.com's own config."
