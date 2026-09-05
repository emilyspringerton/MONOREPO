#!/usr/bin/env bash
# Regenerates the CarePyre SIP Phone's own extension 1000 PJSIP password (kanban follow-up to
# CAREPYRE-42143124, founder real-time: "you need to figure out how to regenerate it put it in
# EMILY/var"). Real, found-live root cause this script fixes: sudo-queue/52's own original
# secret generation was deliberately "never printed to this repo or any agent's terminal" (see
# that script's own [1/6] step) -- correct instinct at the time (don't leak a live secret into
# logs/history), but it meant NOBODY, including the founder, ever actually saw the value it
# generated. This script does the same real generation, but this time also writes the value to
# EMILY/var/carepyre-phone-secret.env (mode 600, owner-only) so it's actually retrievable --
# closing the real gap, not repeating it.
#
# RUN THIS AS YOURSELF (fatbaby) -- NOT with `sudo ./53-....sh`. Same real convention every other
# script in this queue follows: the individual `sudo` lines below elevate only the two real steps
# that actually need root (writing into /etc/asterisk, reloading Asterisk) -- running the whole
# script as root would repoint EMILY/var's own real path at /root instead of /home/fatbaby.
if [ "$(id -u)" -eq 0 ]; then
  echo "ERROR: run this script as yourself (fatbaby), not via sudo -- see the header comment" >&2
  echo "above for why. The individual sudo lines inside it will prompt for a password when" >&2
  echo "they actually need one." >&2
  exit 1
fi

set -euo pipefail

ASTERISK_CONF_DIR=/etc/asterisk
SECRET_FILE="/home/fatbaby/EMILY/var/carepyre-phone-secret.env"

echo "[1/4] Generate a real, fresh PJSIP password for extension 1000 (same real openssl rand -hex 16"
echo "      generation sudo-queue/52 originally used)"
PHONE_SECRET="$(openssl rand -hex 16)"

echo "[2/4] Write it to ${SECRET_FILE} (mode 600, owner-only) -- so it's actually retrievable this"
echo "      time, unlike sudo-queue/52's own original generation"
umask 077
cat > "${SECRET_FILE}" <<EOF
# CarePyre SIP Phone (extension 1000) PJSIP password -- generated $(date -u +%Y-%m-%dT%H:%M:%SZ)
# by sudo-queue/53-regenerate-carepyre-phone-password.sh. Use this to complete registration in
# any real SIP client (Linphone, Zoiper, or the CarePyre SIP Phone app itself once its own
# native signaling lands) after scanning the console's own QR code, which deliberately never
# encodes this value (see IDUNA_PRO's sip_accounts.go header comment for why).
CAREPYRE_PHONE_1000_PASSWORD=${PHONE_SECRET}
EOF
chmod 600 "${SECRET_FILE}"

echo "[3/4] Substitute it into the LIVE deployed config (not the repo template -- that keeps its"
echo "      own __CAREPYRE_PHONE_SECRET__ placeholder for future fresh deploys) and reload PJSIP"
sudo sed -i "s/^password=.*/password=${PHONE_SECRET}/" "${ASTERISK_CONF_DIR}/pjsip_carepyre_phone.conf"
sudo asterisk -rx "pjsip reload"

echo "[4/4] Verify"
sudo asterisk -rx "pjsip show endpoint 1000"

echo ""
echo "Done. New password saved to ${SECRET_FILE} -- read it with:"
echo "  cat ${SECRET_FILE}"
