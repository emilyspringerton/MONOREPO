#!/usr/bin/env bash
# Deploys the CarePyre Console (kanban CPP-124433/CPP-2144333): a real, separate, live IDUNA_PRO
# instance as CarePyre's own auth+backend, plus the real CarePyre-branded static console page
# fronting it. Real, checked-not-assumed: :8081 is free on this box (`ss -tulnp` this session
# found :8080=IDUNA, :8088=gpt2-alpine-c model server, nothing on :8081).
#
# Architecture (full writeup: CarePyre/docs/CAREPYRE_CONSOLE_NORTHSTAR.md): IDUNA_PRO's own
# source is UNTOUCHED -- this just runs its existing binary as its own real, separate service
# (its own port, own SQLite DB, own JWT signing key -- a genuinely separate trust domain from
# IDUNA proper, not a shared session). CarePyre's own console.html (already live-pushed to
# /var/www/carepyre/ by 13-carepyre-domain-setup.sh's own convention) talks to it via nginx's
# new /console-api/ same-origin proxy -- no CORS code needed anywhere.
#
# EINHORN_INDUSTRIAL's own internal ops keep running on the ORIGINAL IDUNA (:8080) exactly as
# before -- this script does not touch that service at all.
#
# RUN THIS AS YOURSELF (fatbaby) -- NOT with `sudo ./51-....sh`. Same real convention every
# other script in this queue follows (see run-all.sh's own header: "each one prompts for sudo
# itself when it needs to") -- the individual `sudo` lines below (nginx config, reload) elevate
# only the two steps that actually need root. Real, found-live reason this one bites harder than
# most: `systemctl --user ...` needs a real per-user D-Bus session, which a `sudo`-wrapped shell
# doesn't have ("Failed to connect to bus: No medium found") -- and running the whole script as
# root also silently repoints every `~`/`$HOME` path (the built binary, the JWT secret file) at
# /root instead of /home/fatbaby, which the systemd --user unit and its `%h`-based paths then
# can't find either way.
if [ "$(id -u)" -eq 0 ]; then
  echo "ERROR: run this script as yourself (fatbaby), not via sudo -- see the header comment" >&2
  echo "above for why. The individual sudo lines inside it will prompt for a password when" >&2
  echo "they actually need one." >&2
  exit 1
fi

set -euo pipefail

echo "[1/6] Build the idunapro binary"
cd /home/fatbaby/IDUNA_PRO
GOWORK=off go build -o ~/.local/bin/idunapro .

echo "[2/6] Real, freshly-generated JWT secret -- IDUNA_PRO is its own trust domain, this must"
echo "      NEVER be the same secret IDUNA's own env file uses."
mkdir -p ~/.config/idunapro
if [ ! -f ~/.config/idunapro/env ]; then
  JWT_SECRET="$(openssl rand -hex 32)"
  cat > ~/.config/idunapro/env <<EOF
JWT_SECRET=${JWT_SECRET}
JWT_ISSUER=https://carepyre-console.internal
ADDR=:8081
EOF
  chmod 600 ~/.config/idunapro/env
  echo "      wrote a new ~/.config/idunapro/env (real secret generated, not printed here)"
else
  echo "      ~/.config/idunapro/env already exists -- leaving it as-is (not overwriting a real,"
  echo "      already-deployed secret)"
fi

echo "[3/6] Install + start the systemd user unit"
mkdir -p ~/.config/systemd/user
cp /home/fatbaby/IDUNA_PRO/scripts/idunapro.service ~/.config/systemd/user/idunapro.service
systemctl --user daemon-reload
systemctl --user enable --now idunapro.service
systemctl --user status idunapro.service --no-pager | head -8

echo "[4/6] Push the CarePyre Console static page"
cp /home/fatbaby/CarePyre/console.html /var/www/carepyre/console.html

echo "[5/6] Install the updated nginx config (adds location /console-api/ -> idunapro :8081)"
sudo cp /home/fatbaby/CarePyre/ops/nginx-carepyre.conf /etc/nginx/sites-available/carepyre
sudo nginx -t
sudo systemctl reload nginx

echo "[6/6] Verify"
curl -sf http://localhost:8081/health && echo " <- idunapro health, direct"
curl -s -o /dev/null -w "https://carepyre.org/console.html: %{http_code}\n" https://carepyre.org/console.html
curl -s -o /dev/null -w "https://carepyre.org/console-api/health: %{http_code}\n" https://carepyre.org/console-api/health

echo ""
echo "Done. Visit https://carepyre.org/console.html to create the first real account."
echo "Reminder (matches 13-carepyre-domain-setup.sh's own note): after any future certbot"
echo "re-run, diff the live /etc/nginx/sites-available/carepyre against"
echo "CarePyre/ops/nginx-carepyre.conf and copy the live version back if they've diverged."
