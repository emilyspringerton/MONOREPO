#!/usr/bin/env bash
# camp-deploy.sh -- bring the camp's identity + stats services up on the LAN host, with no uplink and
# nothing pulled from a registry.
#
# Companion: sudo-queue/98-shankpit-camp-lan-pi.sh, which makes the Pi Zero the access point, the DHCP
# server and the DNS that resolves iduna.local / wotan.local to this host. Run that on the Pi first.
#
# The GAME is NOT started here. `shank_server` is a native binary with its own UDP loop (default port
# 6969, `--port N` to change it) and it is already running on this machine; a container would only add
# a hop. See docs/CAMP_LAN.md for the full picture and the honest gaps.
#
#   CAMP_HOST=192.168.43.10 ./camp-deploy.sh
#
# NOT VERIFIED end to end: there is no Docker daemon on the box this script was written on, so the
# image build and the deploy below have not been run. Every command is the repo's own and is checked
# for syntax, but the first real run is the first real run.
set -euo pipefail
cd "$(dirname "$0")"

CAMP_HOST="${CAMP_HOST:-192.168.43.10}"
STACK="${CAMP_STACK:-shankpit_camp}"

if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: docker is not installed on this host." >&2
  echo "       Install it, or run IDUNA natively (go run . in IDUNA/) and skip this script." >&2
  exit 1
fi

echo "[1/4] build iduna:camp locally -- a LOCAL tag, nothing is pushed and nothing is pulled"
docker build -t iduna:camp -f IDUNA/ops/docker/iduna.Dockerfile IDUNA

echo "[2/4] deploy the camp stack (CAMP_HOST=${CAMP_HOST})"
if [ "$(docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null || echo inactive)" = "active" ]; then
  MODE=stack
  docker stack deploy -c docker-compose.camp.yml "$STACK"
  VOLUME="${STACK}_iduna_data"
  echo "  mode: docker swarm stack '${STACK}'"
else
  MODE=compose
  docker compose -f docker-compose.camp.yml up -d
  VOLUME="$(docker volume ls -q | grep -m1 'iduna_data' || true)"
  echo "  mode: docker compose"
fi

echo "[3/4] schema bootstrap -- idempotent, and it runs against the SAME volume the service uses"
if [ -n "${VOLUME:-}" ]; then
  docker run --rm -v "${VOLUME}:/data" -e SQLITE_PATH=/data/iduna.db iduna:camp /app/iduna-bootstrap
else
  echo "  SKIPPED: could not identify the iduna_data volume." >&2
  echo "           Run: docker run --rm -v <volume>:/data iduna:camp /app/iduna-bootstrap" >&2
fi

echo "[4/4] verify"
echo "  curl -s http://${CAMP_HOST}:8080/ | head -3"
echo "  curl -s -X POST http://${CAMP_HOST}:8080/api/v1/games/shankpit/guest-register \\"
echo '       -H "Content-Type: application/json" -d '"'"'{"display_name":"probe"}'"'"' | head -5'
echo "  curl -s http://${CAMP_HOST}:8081/ | head -3"
echo
echo "READY (${MODE})."
echo "  IDUNA  http://${CAMP_HOST}:8080   (identity, guest register, JWKS)"
echo "  WOTAN  http://${CAMP_HOST}:8081   (static stats site)"
echo "  GAME   native, UDP 6969 by default -- not part of this stack"
echo "  Phones must be on the Pi's SSID, and the Pi must resolve iduna.local -> ${CAMP_HOST}."
