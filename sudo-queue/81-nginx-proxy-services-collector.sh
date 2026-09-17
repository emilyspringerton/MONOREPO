#!/usr/bin/env bash
# Adds nginx's own real reverse proxy for IDUNA's /services/ routes (currently only /api/,
# /admin/, /portal, /jewel/, /sarena/, /news/ are proxied on okemily.com) -- specifically needed
# right now for POST /services/collector, the real Splunk-HEC-shaped unified logging backend
# ingest endpoint (IDUNA/internal/http/handlers/logs.go), so the SHANKPIT RL training pipeline
# (which runs on an EXTERNAL Colab machine, not this box) can push per-generation heartbeat
# events (opponent chosen, match results, Elo before/after) somewhere durable instead of losing
# them to an ephemeral Colab session's own stdout the moment it disconnects -- founder real-time,
# after 60 generations of training showed no real Elo improvement: "can we have more debugging in
# the heartbeat? like when main chooses an opponent log it log the results log the elo".
# Confirmed directly first: the endpoint itself already works (curl against
# http://localhost:8080/services/collector returns a real 200 Success with a real HEC token,
# IDUNA/.config/iduna/env's own new IDUNA_HEC_TOKEN, generated and enabled this same session) --
# the ONLY real gap is that nginx never routes /services/ through to IDUNA at all, so the public
# https://okemily.com/services/collector path 404s before it ever reaches the backend.
#
# CRITICAL, per OKEMILY/CLAUDE.md's own real, hard-learned 2026-07-18 outage history: certbot's
# --nginx plugin rewrites the LIVE file in place (SSL/443 block, HTTP->HTTPS redirect, HSTS) --
# none of which exist in this repo's own OKEMILY/ops/nginx-okemily.conf copy, which is
# ALREADY KNOWN, confirmed directly, to have diverged from live (that repo copy lacks the real,
# already-deployed JEWEL/SARENA_NOTEBOOK location blocks added 2026-08-26/28 that must already be
# live). A blind `cp` of the repo copy over the live file, in EITHER direction, is exactly how
# HTTPS went down for real once already. This script never does that: it re-syncs the repo's own
# copy FROM live first (so the repo stops being stale), then makes one small, idempotent,
# search-based insertion into the LIVE file only -- never a wholesale overwrite.
#
# RUN THIS AS YOURSELF (fatbaby) -- NOT with `sudo ./81-....sh`.
if [ "$(id -u)" -eq 0 ]; then
  echo "ERROR: run this script as yourself (fatbaby), not via sudo." >&2
  exit 1
fi

set -euo pipefail

LIVE=/etc/nginx/sites-available/okemily
REPO_COPY=/home/fatbaby/OKEMILY/ops/nginx-okemily.conf

echo "[1/6] Real, live backup of the current file before touching it"
sudo cp "$LIVE" "$LIVE.bak-$(date +%Y%m%d-%H%M%S)"

echo "[2/6] Re-sync this repo's own copy FROM live first (OKEMILY/CLAUDE.md's own explicit"
echo "      remediation for a known-diverged file -- never edit-then-overwrite the other way)"
sudo cat "$LIVE" > "$REPO_COPY"
(cd /home/fatbaby/OKEMILY && git add ops/nginx-okemily.conf && git commit -m "$(cat <<'EOF'
ops: re-sync nginx-okemily.conf from live before adding /services/ proxy

Per this repo's own CLAUDE.md warning: the live file has diverged
(certbot's own SSL/redirect/HSTS rewrites, plus JEWEL/SARENA_NOTEBOOK
blocks added 2026-08-26/28) -- re-synced from the actual live file
before making any further edit, not the other way around.

session: sess-20260905-0720-ec33e7c5
Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Vs8sS28smp7C43Xxbt6JLr
EOF
)" && git push) || echo "      (no changes to commit, or push failed -- continuing, the live-file edit below is the real goal)"

echo "[3/6] Insert a /services/ location block right after each real /api/ block, if not already present"
if sudo grep -q "location /services/ {" "$LIVE"; then
  echo "      already present, skipping insertion"
else
  sudo python3 - "$LIVE" <<'PYEOF'
import re
import sys

path = sys.argv[1]
with open(path) as f:
    content = f.read()

block = '''
    # /services/ -- real reverse proxy for IDUNA's unified logging backend (sudo-queue/81,
    # founder real-time: "can we have more debugging in the heartbeat"). Same real proxy_pass
    # convention every other /api/ location block in this file already uses -- POST
    # /services/collector (Splunk HEC-shaped ingest) is the first real consumer, the SHANKPIT RL
    # training pipeline's own per-generation heartbeat events.
    location /services/ {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
'''

# Match a real "location /api/ { ... }" block at 4-space indent, ending at a lone "    }" line --
# matches this file's own consistent formatting (confirmed directly against the just-re-synced
# live copy, not assumed). Applied to EVERY occurrence (once per server stanza, matching how
# client_max_body_size was already added to every server_name line in sudo-queue/80).
pattern = re.compile(r'(    location /api/ \{.*?\n    \}\n)', re.DOTALL)
matches = pattern.findall(content)
if not matches:
    print("ERROR: no 'location /api/ { ... }' block found in the live file -- aborting without "
          "changing anything. The live file's own real structure must have changed; this needs "
          "a human look, not a blind insertion.", file=sys.stderr)
    sys.exit(1)

new_content = pattern.sub(lambda m: m.group(1) + block, content)
with open(path, "w") as f:
    f.write(new_content)
print(f"Inserted /services/ block after {len(matches)} real 'location /api/' block(s).")
PYEOF
fi

echo "[4/6] Real syntax check before reloading anything"
sudo nginx -t

echo "[5/6] Reload nginx (no downtime -- a real config reload, not a restart)"
sudo systemctl reload nginx

echo "[6/6] Re-sync the repo copy again, now that live has the real change (keeps it from"
echo "      going stale again immediately)"
sudo cat "$LIVE" > "$REPO_COPY"
(cd /home/fatbaby/OKEMILY && git add ops/nginx-okemily.conf && git commit -m "$(cat <<'EOF'
ops: add /services/ proxy for IDUNA's unified logging backend

session: sess-20260905-0720-ec33e7c5
Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Vs8sS28smp7C43Xxbt6JLr
EOF
)" && git push) || echo "      (no changes to commit, or push failed)"

echo ""
echo "Done. Verify from any machine (including the Colab training box):"
echo "  curl -s -X POST https://okemily.com/services/collector \\"
echo "    -H \"Authorization: Splunk \$IDUNA_HEC_TOKEN\" -H 'Content-Type: application/json' \\"
echo "    -d '{\"event\": {\"test\": true}, \"sourcetype\": \"test\", \"source\": \"test\"}'"
echo "  -> should return {\"code\":0,\"text\":\"Success\"}, not a 404."
