#!/usr/bin/env bash
# Wires the real Twilio SIP trunk + CarePyre phone extension into this box's already-running,
# real Asterisk instance (sudo-queue/50 already installed it). Kanban: "ok we have a platform we
# have a pbx we have a sip phone do all the plumbing while i sign up for twillio."
#
# Real, additive deploy -- does NOT overwrite Asterisk's own existing pjsip.conf/extensions.conf
# (both real, large Debian-shipped sample files, ~30-80KB each) the way sudo-queue/50 correctly
# DID overwrite the small, security-critical manager.conf. Instead: three new, focused config
# files (PARENA/ops/asterisk/*.conf) get copied in and pulled in via a real, standard Asterisk
# `#include` line, added once (idempotent -- checks first) at the end of each existing file.
#
# Real config templates, both reviewed and real (not guessed): PARENA/ops/asterisk/
#   pjsip_carepyre_phone.conf  -- extension 1000, the CarePyre SIP Phone's own account
#   pjsip_twilio_trunk.conf    -- the Twilio trunk (IP-ACL auth, no digest crypto needed --
#                                 this box's real, static public IP is in the ACL you'll add on
#                                 Twilio's side, not the other way around)
#   extensions_carepyre.conf   -- the dialplan connecting the two
#
# STILL NEEDED FROM YOU (real, cannot be automated without your Twilio account existing yet):
# see PARENA/docs/TWILIO_SETUP_CHECKLIST.md for the exact Twilio Console steps once you've
# signed up -- this script leaves __TWILIO_TRUNK_DOMAIN__ as a real, visible placeholder in the
# deployed config until you run this script's own follow-up sed (printed at the end).
set -euo pipefail

ASTERISK_CONF_DIR=/etc/asterisk
REPO_ASTERISK_DIR=/home/fatbaby/PARENA/ops/asterisk

echo "[1/6] Generate a real, fresh secret for extension 1000 (never hardcoded, never printed to"
echo "      this repo or any agent's terminal)"
PHONE_SECRET="$(openssl rand -hex 16)"
sed "s/__CAREPYRE_PHONE_SECRET__/${PHONE_SECRET}/" \
  "${REPO_ASTERISK_DIR}/pjsip_carepyre_phone.conf" | sudo tee "${ASTERISK_CONF_DIR}/pjsip_carepyre_phone.conf" > /dev/null

echo "[2/6] Copy the Twilio trunk + dialplan config as-is (real placeholder domain still in"
echo "      pjsip_twilio_trunk.conf until you have a real Twilio trunk to fill it in with)"
sudo cp "${REPO_ASTERISK_DIR}/pjsip_twilio_trunk.conf" "${ASTERISK_CONF_DIR}/pjsip_twilio_trunk.conf"
sudo cp "${REPO_ASTERISK_DIR}/extensions_carepyre.conf" "${ASTERISK_CONF_DIR}/extensions_carepyre.conf"
sudo chown asterisk:asterisk "${ASTERISK_CONF_DIR}"/pjsip_carepyre_phone.conf \
  "${ASTERISK_CONF_DIR}"/pjsip_twilio_trunk.conf "${ASTERISK_CONF_DIR}"/extensions_carepyre.conf
sudo chmod 640 "${ASTERISK_CONF_DIR}"/pjsip_carepyre_phone.conf

echo "[3/6] Wire the new files in via #include (idempotent -- only adds the line once)"
grep -qF '#include pjsip_carepyre_phone.conf' "${ASTERISK_CONF_DIR}/pjsip.conf" 2>/dev/null || \
  echo '#include pjsip_carepyre_phone.conf' | sudo tee -a "${ASTERISK_CONF_DIR}/pjsip.conf" > /dev/null
grep -qF '#include pjsip_twilio_trunk.conf' "${ASTERISK_CONF_DIR}/pjsip.conf" 2>/dev/null || \
  echo '#include pjsip_twilio_trunk.conf' | sudo tee -a "${ASTERISK_CONF_DIR}/pjsip.conf" > /dev/null
grep -qF '#include extensions_carepyre.conf' "${ASTERISK_CONF_DIR}/extensions.conf" 2>/dev/null || \
  echo '#include extensions_carepyre.conf' | sudo tee -a "${ASTERISK_CONF_DIR}/extensions.conf" > /dev/null

echo "[4/6] Reload Asterisk's config (PJSIP + dialplan only, no restart -- doesn't drop any"
echo "      real, in-progress call)"
sudo asterisk -rx "pjsip reload"
sudo asterisk -rx "dialplan reload"

echo "[5/6] Verify"
sudo asterisk -rx "pjsip show endpoint 1000"
sudo asterisk -rx "pjsip show endpoint twilio-endpoint"
sudo asterisk -rx "dialplan show carepyre-internal"

echo ""
echo "[6/6] Real secret for extension 1000 -- register a real SIP softphone (Zoiper, Linphone)"
echo "      with this to test the phone side right now, independent of Twilio:"
echo "  Server:   198.58.107.85 (or carepyre.org once DNS/SRV is pointed here)"
echo "  Port:     5060, UDP"
echo "  Username: 1000"
echo "  Password: ${PHONE_SECRET}"
echo ""
echo "Done. Once you have a real Twilio Elastic SIP Trunk (see"
echo "PARENA/docs/TWILIO_SETUP_CHECKLIST.md for the exact Console steps), fill in the real"
echo "domain with:"
echo '  sudo sed -i "s/__TWILIO_TRUNK_DOMAIN__/yourtrunkname.pstn.twilio.com/" /etc/asterisk/pjsip_twilio_trunk.conf'
echo '  sudo asterisk -rx "pjsip reload"'
