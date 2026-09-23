#!/usr/bin/env bash
# Wires SHANKPIT's real walkie-talkie PJSIP endpoint + ConfBridge dialplan into this box's
# already-running, real Asterisk instance (the same one CarePyre's phone uses). Founder
# real-time: "add walkie talkie voice coms asterisk based (we have a real asterisk server)
# parena powered." EMILY/BACKLOG.md SECTION 536.
#
# Real, additive deploy -- same real pattern sudo-queue/52-carepyre-asterisk-plumbing-deploy.sh
# already established: does NOT touch CarePyre's own pjsip_carepyre_phone.conf/
# pjsip_twilio_trunk.conf/extensions_carepyre.conf/voicemail_carepyre.conf at all. Two new,
# separate config files (PARENA/ops/asterisk/pjsip_shankpit_walkie.conf,
# extensions_shankpit_walkie.conf) get copied in and pulled in via a real, standard Asterisk
# `#include` line, added once (idempotent -- checks first) at the end of the existing
# pjsip.conf/extensions.conf.
#
# REAL, HONEST GAP this script does NOT fix: no SHANKPIT game client can register here yet --
# SHANKPIT's C client has zero microphone capture/codec/SIP/RTP client code (see
# SHANKPIT/packages/simulation/walkie_talkie.h's own doc comment). This deploy only proves the
# real Asterisk-side channel/ConfBridge plumbing, testable today with any standard SIP softphone
# (Zoiper, Linphone) registered as the shared v0 "shankpit-walkie" identity.
#
# NOT RUN AUTOMATICALLY -- this touches a live, production PBX serving CarePyre's real customer
# calls (shared box, isolated context/extension range). Review, then run by hand when ready.
set -euo pipefail

ASTERISK_CONF_DIR=/etc/asterisk
REPO_ASTERISK_DIR=/home/fatbaby/PARENA/ops/asterisk

echo "[1/5] Generate a real, fresh secret for the shared v0 shankpit-walkie identity (never"
echo "      hardcoded, never printed to this repo or any agent's terminal)"
WALKIE_SECRET="$(openssl rand -hex 16)"
sed "s/__SHANKPIT_WALKIE_SECRET__/${WALKIE_SECRET}/" \
  "${REPO_ASTERISK_DIR}/pjsip_shankpit_walkie.conf" | sudo tee "${ASTERISK_CONF_DIR}/pjsip_shankpit_walkie.conf" > /dev/null
sudo cp "${REPO_ASTERISK_DIR}/extensions_shankpit_walkie.conf" "${ASTERISK_CONF_DIR}/extensions_shankpit_walkie.conf"
sudo chown asterisk:asterisk "${ASTERISK_CONF_DIR}"/pjsip_shankpit_walkie.conf "${ASTERISK_CONF_DIR}"/extensions_shankpit_walkie.conf
sudo chmod 640 "${ASTERISK_CONF_DIR}"/pjsip_shankpit_walkie.conf

echo "[2/5] Wire the new files in via #include (idempotent -- only adds the line once, never"
echo "      touches any existing #include line for CarePyre's own config)"
grep -qF '#include pjsip_shankpit_walkie.conf' "${ASTERISK_CONF_DIR}/pjsip.conf" 2>/dev/null || \
  echo '#include pjsip_shankpit_walkie.conf' | sudo tee -a "${ASTERISK_CONF_DIR}/pjsip.conf" > /dev/null
grep -qF '#include extensions_shankpit_walkie.conf' "${ASTERISK_CONF_DIR}/extensions.conf" 2>/dev/null || \
  echo '#include extensions_shankpit_walkie.conf' | sudo tee -a "${ASTERISK_CONF_DIR}/extensions.conf" > /dev/null

echo "[3/5] Reload Asterisk's config (PJSIP + dialplan only, no restart -- doesn't drop any real,"
echo "      in-progress CarePyre call)"
sudo asterisk -rx "pjsip reload"
sudo asterisk -rx "dialplan reload"

echo "[4/5] Verify"
sudo asterisk -rx "pjsip show endpoint shankpit-walkie"
sudo asterisk -rx "dialplan show shankpit-walkie"

echo ""
echo "[5/5] Real secret -- never printed anywhere but this terminal:"
echo "  shankpit-walkie SIP password: ${WALKIE_SECRET}"
echo ""
echo "Test today with a real SIP softphone (Zoiper/Linphone): register as shankpit-walkie /"
echo "the password above, then dial 2999 (local chatter), 3000-3008 (team channels), or 3999"
echo "(all-call). A second softphone registered the same way and dialing the same extension"
echo "should hear the first live in the ConfBridge."
