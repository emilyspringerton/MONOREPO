#!/usr/bin/env bash
# Fixes a real, live-verified Asterisk config bug (founder, 2026-09-05, after trying to register
# the CarePyre SIP Phone via the new provisioning-URL flow: "Registering.. for a long time then
# failed"). Root cause, confirmed via a full SIP digest-auth REGISTER probe run from an external
# box against this server's real Asterisk instance: the request correctly gets challenged (401)
# and the password is accepted, but the actual registration then fails with "404 Not Found"
# because /var/log/asterisk/messages.log shows:
#
#   WARNING[...] res_pjsip_registrar.c: AOR '' not found for endpoint '1000' (...)
#   WARNING[...] res_pjsip_registrar.c: AOR '' not found for endpoint '1000web' (...)
#
# i.e. the LIVE deployed /etc/asterisk/pjsip_carepyre_phone.conf and
# pjsip_carepyre_webphone.conf have an EMPTY aors= value for both endpoints, even though this
# repo's own checked-in templates (PARENA/ops/asterisk/pjsip_carepyre_phone.conf and
# pjsip_carepyre_webphone.conf) correctly say aors=carepyre-phone-aor / aors=carepyre-webphone-aor
# -- the live files have drifted from the repo at some point after an earlier deploy. This script
# does not touch the templates (already correct) or regenerate any secret -- it only fixes the
# one broken line in each live deployed file and reloads PJSIP.
#
# RUN THIS AS YOURSELF (fatbaby) -- NOT with `sudo ./70-....sh` -- same convention every other
# script in this queue follows; the individual `sudo` lines below elevate only the steps that
# actually need root (this box's own OS user can't read/write /etc/asterisk or reload asterisk).
if [ "$(id -u)" -eq 0 ]; then
  echo "ERROR: run this script as yourself (fatbaby), not via sudo -- see the header comment" >&2
  echo "above for why. The individual sudo lines inside it will prompt for a password when" >&2
  echo "they actually need one." >&2
  exit 1
fi

set -euo pipefail

echo "[1/4] Show the current, live, broken aors= lines (for your own visibility before this"
echo "      script changes anything)"
sudo grep -n "^aors=" /etc/asterisk/pjsip_carepyre_phone.conf /etc/asterisk/pjsip_carepyre_webphone.conf || true

echo ""
echo "[2/4] Back up both live files before editing"
sudo cp /etc/asterisk/pjsip_carepyre_phone.conf "/etc/asterisk/pjsip_carepyre_phone.conf.bak-$(date -u +%Y%m%dT%H%M%SZ)"
sudo cp /etc/asterisk/pjsip_carepyre_webphone.conf "/etc/asterisk/pjsip_carepyre_webphone.conf.bak-$(date -u +%Y%m%dT%H%M%SZ)"

echo ""
echo "[3/4] Fix the empty aors= value on each live endpoint section (leaves every other line --"
echo "      including the real, already-deployed passwords -- untouched)"
sudo sed -i 's/^aors=\s*$/aors=carepyre-phone-aor/' /etc/asterisk/pjsip_carepyre_phone.conf
sudo sed -i 's/^aors=\s*$/aors=carepyre-webphone-aor/' /etc/asterisk/pjsip_carepyre_webphone.conf
sudo asterisk -rx "pjsip reload"

echo ""
echo "[4/4] Verify -- both endpoints should now show a real AOR, not '(none)' or blank"
sudo asterisk -rx "pjsip show endpoint 1000" | grep -i "aor\|contact" || true
echo "---"
sudo asterisk -rx "pjsip show endpoint 1000web" | grep -i "aor\|contact" || true

echo ""
echo "Done. Try the SIP phone's 'Register from URL' flow again. If it STILL fails (especially"
echo "over a real mobile data connection rather than wifi), the separate, previously-documented"
echo "possibility is a raw-UDP-SIP block somewhere on the mobile network path itself (see"
echo "PARENA/ops/asterisk/pjsip_carepyre_webphone.conf's own header comment) -- the in-browser"
echo "webphone (wss://, port 443) is the known-working fallback for that case."
