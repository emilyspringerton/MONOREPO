#!/bin/bash
# One-time setup for wotan.okemily.com (kanban WOTAN-DNS-001). DNS is already live -- the
# wotan.okemily.com A record already exists in Cloudflare, pointing at this box's own IP
# (198.58.107.85), same as okemily.com/console.okemily.com/mc.okemily.com/news.okemily.com --
# checked directly via the real Cloudflare API before writing this script, not assumed. What's
# actually missing is the server side: a real /var/www/wotan directory this user can deploy to
# without sudo (matching OKEMILY's own precedent -- see OKEMILY/CLAUDE.md's own "Deploy" section,
# "/var/www/okemily/ is now fatbaby:www-data mode 2775... deploying no longer needs sudo at
# all"), the real nginx server block, and a real Let's Encrypt cert.
set -e

echo "Creating /var/www/wotan..."
mkdir -p /var/www/wotan
chown fatbaby:www-data /var/www/wotan
chmod 2775 /var/www/wotan

echo "Installing nginx site config..."
cp /home/fatbaby/WOTAN/ops/nginx-wotan.conf /etc/nginx/sites-available/wotan
ln -sf /etc/nginx/sites-available/wotan /etc/nginx/sites-enabled/wotan
nginx -t
systemctl reload nginx

echo "Deploying initial content (plain HTTP first, so certbot's HTTP-01 challenge has something to serve)..."
sudo -u fatbaby /home/fatbaby/wotan-deploy.sh

echo "Requesting Let's Encrypt cert for wotan.okemily.com..."
certbot --nginx \
  -d wotan.okemily.com \
  --non-interactive --agree-tos -m emilyspringerton@gmail.com \
  --redirect --hsts

echo "Done. Verifying..."
curl -sI https://wotan.okemily.com/ | head -5
echo "If that shows HTTP/2 200 (or HTTP/1.1 200), HTTPS is live."
