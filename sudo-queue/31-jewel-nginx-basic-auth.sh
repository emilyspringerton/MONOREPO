#!/usr/bin/env bash
# Deploys the /jewel/ nginx location block (both okemily.com server stanzas -- 443 and the
# port-80 one), proxying to the fatbaby-broker (127.0.0.1:8679).
#
# Founder real-time chain: "work on our parena JUPYTER backend just use basic auth to protect it
# for now until we get google oauthg to work" -> "call it JEWEL" -> ... -> "set up a single nginx
# proxy" -> "use fatbaby proxy broker to manage proxies instead of always asking for a new
# feature". This nginx block is now a dumb pass-through -- no auth_basic, no htpasswd file. Real
# HTTP Basic Auth (bcrypt) and real WebSocket proxying both now live in the broker itself
# (PRRJECT_FATBABY/broker/middleware.go, broker/proxy.go), config-driven via
# gpt2-alpine-c/config/broker-routes.json's "jewel-jupyter" route. The broker is a user systemd
# unit (fatbaby-broker.service) -- redeploying it, or adding the NEXT broker-routed service,
# needs no sudo at all. This script (nginx + sudo) should be the LAST sudo ask for this whole
# class of "expose a new internal service" problem, not a per-service recurring one.
#
# 2026-08-26 REVISION: an earlier version of this script wrote /etc/nginx/.htpasswd-jewel and
# pointed nginx straight at JupyterLab (127.0.0.1:8890) with its own auth_basic block. That
# version also had a real bug -- its own diff-check compared the live file against THIS repo's
# already-edited copy (which of course differ, that's the whole point of the deploy) instead of
# against a pre-edit snapshot, so it refused to apply, every time, by construction. Both are fixed
# here: no more htpasswd (the broker owns auth now), and the check below diffs against the actual
# git history instead of the working tree.
set -euo pipefail

cd /home/fatbaby/OKEMILY
# Walk this file's own commit history looking for a match against the live file -- confirms the
# live file corresponds to some real point in this file's own history, not just today's tip. A
# live file matching ANY commit in this file's history is safe to overwrite (nothing has
# hand-edited it out of band); matching NONE of them means real drift (e.g. a certbot renewal
# run) that needs reconciling first, not blindly overwriting.
MATCHED=0
for rev in $(git log --format=%H -- ops/nginx-okemily.conf); do
    if diff -q <(git show "$rev:ops/nginx-okemily.conf") /etc/nginx/sites-available/okemily >/dev/null 2>&1; then
        MATCHED=1
        break
    fi
done
if [ "$MATCHED" -ne 1 ]; then
    echo "REFUSING: live /etc/nginx/sites-available/okemily doesn't match any commit of"
    echo "ops/nginx-okemily.conf's own history (likely a certbot renewal run, or a manual edit)."
    echo "Re-sync the repo copy from the live file first, re-apply the /jewel/ location blocks"
    echo "on top of that, then re-run."
    diff /home/fatbaby/OKEMILY/ops/nginx-okemily.conf /etc/nginx/sites-available/okemily || true
    exit 1
fi

# Clean up the stale htpasswd file from the earlier (now-superseded) direct-to-nginx-auth_basic
# approach, if it's still there -- broker/middleware.go is the real gate now.
if [ -f /etc/nginx/.htpasswd-jewel ]; then
    sudo rm -f /etc/nginx/.htpasswd-jewel
fi

sudo cp /home/fatbaby/OKEMILY/ops/nginx-okemily.conf /etc/nginx/sites-available/okemily
sudo nginx -t
sudo systemctl reload nginx

echo "applied. verify with:"
echo "  curl -sI https://okemily.com/jewel/ | head -1                                    # expect 401 (broker's own Basic Auth challenge)"
echo "  curl -su jewel:'<password>' -sI https://okemily.com/jewel/lab | head -1          # expect 200"
