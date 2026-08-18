#!/usr/bin/env bash
# Adds Cache-Control: no-cache to the /prompt-o-verse/ HTML pages on
# okemily.com. Founder, real-time: "live reload still seems broken" /
# "auto reload seems broken", reported AFTER the actual server-side bug
# (a stale iduna.service binary re-stamping old JS, see EMILY/BACKLOG.md
# S176-32) was already fixed and live-verified via curl (fresh
# Last-Modified, correct incremental-patch JS served, live nodes API
# up to date).
#
# Root cause of the REMAINING gap: /var/www/okemily/prompt-o-verse/ is
# served as plain static files with NO Cache-Control/Expires header at
# all (verified: `curl -D -` shows none). Per RFC 7234's heuristic
# freshness rule, a browser can cache a response like that for a while
# based on how old Last-Modified was AT THE TIME IT WAS FETCHED -- so
# anyone who loaded the gallery page even once before today's fixes
# landed can keep looking at that same stale snapshot indefinitely,
# with no visible sign anything is wrong (no error, just old content
# forever, "live reload" appearing permanently broken from their side).
#
# This does not disable caching outright -- it forces revalidation
# (If-Modified-Since / If-None-Match) on every load, which nginx answers
# with a cheap 304 when nothing changed and a fresh body when it did.
# Only the /prompt-o-verse/ HTML documents get this; the images
# underneath keep normal static-file caching (unaffected, not the part
# that needs to stay fresh moment-to-moment).
#
# Apply:
#   sudo bash /home/fatbaby/sudo-queue/16-prompt-o-verse-nocache.sh
#   sudo nginx -t && sudo systemctl reload nginx
#
# This script backs up the config itself (timestamped .bak- copy) before
# editing, and inserts the same location block into every `location / {
# try_files $uri $uri/ =404; }` occurrence in the file -- this config has
# two near-identical `server { ... }` blocks (HTTP + HTTPS), both need it.

set -euo pipefail

CONF=/etc/nginx/sites-available/okemily

if [ "$(id -u)" -ne 0 ]; then
  echo "must run as root (sudo)" >&2
  exit 1
fi

if grep -q "location /prompt-o-verse/ {" "$CONF"; then
  echo "already applied -- location /prompt-o-verse/ block already present in $CONF"
  exit 0
fi

cp "$CONF" "$CONF.bak-$(date +%Y%m%d-%H%M%S)"

python3 - "$CONF" <<'PYEOF'
import re, sys

path = sys.argv[1]
with open(path) as f:
    content = f.read()

block = '''
    # Prompt-o-verse gallery: force revalidation on every load (added by
    # sudo-queue/16-prompt-o-verse-nocache.sh) -- the page polls
    # /api/v1/promptoverse/nodes and patches itself live, but with no
    # Cache-Control at all a browser could otherwise keep serving an old
    # cached snapshot of the page indefinitely (RFC 7234 heuristic
    # freshness), silently defeating the live-reload feature for anyone
    # who loaded it before this location block existed.
    location /prompt-o-verse/ {
        add_header Cache-Control "no-cache";
        try_files $uri $uri/ =404;
    }
'''

marker = '    location / {\n        try_files $uri $uri/ =404;\n    }\n'
count = content.count(marker)
if count == 0:
    print("ERROR: expected marker not found -- aborting, no changes made", file=sys.stderr)
    sys.exit(1)

content = content.replace(marker, marker + block)
with open(path, 'w') as f:
    f.write(content)

print(f"inserted /prompt-o-verse/ no-cache block after {count} occurrence(s) of the generic location / block")
PYEOF

echo "done -- now run: nginx -t && systemctl reload nginx"
