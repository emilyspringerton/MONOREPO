#!/usr/bin/env bash
# Stands up carepyre.org the same way okemily.com was stood up: a static
# site served from /var/www/carepyre by nginx, then a Let's Encrypt cert
# via certbot's --nginx plugin. DNS is already live (carepyre.org and
# okemily.com both resolve to this box's real IP, confirmed 2026-08-10).
#
# This is a NEW server block for a NEW domain in a NEW sites-available
# file -- it does not touch okemily's own config at all. The founder
# raised a concern about needing to take okemily.com down first to get
# this cert; that concern isn't obviously necessary for a brand-new
# domain (certbot's --nginx plugin only needs *this* domain's HTTP-01
# challenge to resolve, which doesn't require any other site to be down),
# but this box has a documented "learned the hard way" certbot/nginx
# outage before (OKEMILY/CLAUDE.md, 2026-07-18) that this script has no
# visibility into the specifics of. Read through this whole script before
# running it, and if in doubt, take okemily.com's own site down first as
# a precaution -- that's a judgment call for whoever runs this with real
# credentials, not something to assume away here.
set -euo pipefail

echo "[1/5] Create the serving directory"
sudo mkdir -p /var/www/carepyre
sudo chown fatbaby:fatbaby /var/www/carepyre

echo "[2/5] Copy site files from the repo"
cp -r /home/fatbaby/CarePyre/index.html /var/www/carepyre/

echo "[3/5] Install the nginx server block (HTTP only, pre-cert)"
sudo cp /home/fatbaby/CarePyre/ops/nginx-carepyre.conf /etc/nginx/sites-available/carepyre
sudo ln -sf /etc/nginx/sites-available/carepyre /etc/nginx/sites-enabled/carepyre
sudo nginx -t

echo "[4/5] Reload nginx so the HTTP-01 challenge has somewhere to answer"
sudo systemctl reload nginx

echo "[5/5] Issue the cert -- certbot's --nginx plugin rewrites"
echo "      /etc/nginx/sites-available/carepyre to add the SSL server"
echo "      block automatically, same as it did for okemily.com."
sudo certbot --nginx -d carepyre.org -d www.carepyre.org

echo ""
echo "Done. Verify:"
echo "  curl -sI https://carepyre.org/"
echo ""
echo "Reminder: after any future certbot re-run, diff the live"
echo "  /etc/nginx/sites-available/carepyre against this repo's"
echo "  ops/nginx-carepyre.conf and copy the live version back into the"
echo "  repo if they've diverged -- same lesson OKEMILY/CLAUDE.md already"
echo "  documents for okemily.com's own config."
