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
#   extensions_carepyre.conf   -- the dialplan connecting the two, plus real voicemail-on-
#                                 no-answer and auto-recording (CAREPYRE-9311)
#   voicemail_carepyre.conf    -- the real mailbox extensions_carepyre.conf's Voicemail() call
#                                 falls through to
#
# REAL, HONEST GAP this script does NOT fix: extensions_carepyre.conf's inbound recording
# announcement references custom/this-call-may-be-recorded, a real .wav that doesn't exist yet
# anywhere in this repo (no stock Asterisk sound matches it). Playback() fails silently (calls
# still connect) until a real recording is placed at
# /var/lib/asterisk/sounds/en/custom/this-call-may-be-recorded.wav -- see
# CarePyre/docs/GOOGLE_VOICE_FEATURES_NORTHSTAR.md for the real, named follow-up.
#
# Real Twilio trunk already provisioned (2026-09-05, kanban TWILLIO-OPS-12433, via the API
# once Trust Hub compliance cleared): domain carepyre.pstn.twilio.com is baked directly into
# ops/asterisk/pjsip_twilio_trunk.conf now, not a placeholder -- no manual fill-in step needed.
set -euo pipefail

ASTERISK_CONF_DIR=/etc/asterisk
REPO_ASTERISK_DIR=/home/fatbaby/PARENA/ops/asterisk

echo "[1/6] Generate a real, fresh secret for extension 1000 (never hardcoded, never printed to"
echo "      this repo or any agent's terminal)"
PHONE_SECRET="$(openssl rand -hex 16)"
sed "s/__CAREPYRE_PHONE_SECRET__/${PHONE_SECRET}/" \
  "${REPO_ASTERISK_DIR}/pjsip_carepyre_phone.conf" | sudo tee "${ASTERISK_CONF_DIR}/pjsip_carepyre_phone.conf" > /dev/null

echo "[2/7] Copy the Twilio trunk + dialplan config (real, live trunk domain already baked in)"
sudo cp "${REPO_ASTERISK_DIR}/pjsip_twilio_trunk.conf" "${ASTERISK_CONF_DIR}/pjsip_twilio_trunk.conf"
sudo cp "${REPO_ASTERISK_DIR}/extensions_carepyre.conf" "${ASTERISK_CONF_DIR}/extensions_carepyre.conf"
sudo chown asterisk:asterisk "${ASTERISK_CONF_DIR}"/pjsip_carepyre_phone.conf \
  "${ASTERISK_CONF_DIR}"/pjsip_twilio_trunk.conf "${ASTERISK_CONF_DIR}"/extensions_carepyre.conf
sudo chmod 640 "${ASTERISK_CONF_DIR}"/pjsip_carepyre_phone.conf

echo "[3/7] Real, fresh voicemail PIN for mailbox 1000 (CAREPYRE-9311)"
VM_PIN="$(shuf -i 1000-9999 -n 1)"
sed "s/__VOICEMAIL_1000_PIN__/${VM_PIN}/" \
  "${REPO_ASTERISK_DIR}/voicemail_carepyre.conf" | sudo tee "${ASTERISK_CONF_DIR}/voicemail_carepyre.conf" > /dev/null
sudo chown asterisk:asterisk "${ASTERISK_CONF_DIR}/voicemail_carepyre.conf"
sudo chmod 640 "${ASTERISK_CONF_DIR}/voicemail_carepyre.conf"

echo "[4/7] Wire the new files in via #include (idempotent -- only adds the line once)"
grep -qF '#include pjsip_carepyre_phone.conf' "${ASTERISK_CONF_DIR}/pjsip.conf" 2>/dev/null || \
  echo '#include pjsip_carepyre_phone.conf' | sudo tee -a "${ASTERISK_CONF_DIR}/pjsip.conf" > /dev/null
grep -qF '#include pjsip_twilio_trunk.conf' "${ASTERISK_CONF_DIR}/pjsip.conf" 2>/dev/null || \
  echo '#include pjsip_twilio_trunk.conf' | sudo tee -a "${ASTERISK_CONF_DIR}/pjsip.conf" > /dev/null
grep -qF '#include extensions_carepyre.conf' "${ASTERISK_CONF_DIR}/extensions.conf" 2>/dev/null || \
  echo '#include extensions_carepyre.conf' | sudo tee -a "${ASTERISK_CONF_DIR}/extensions.conf" > /dev/null
grep -qF '#include voicemail_carepyre.conf' "${ASTERISK_CONF_DIR}/voicemail.conf" 2>/dev/null || \
  echo '#include voicemail_carepyre.conf' | sudo tee -a "${ASTERISK_CONF_DIR}/voicemail.conf" > /dev/null

echo "[5/7] Reload Asterisk's config (PJSIP + dialplan + voicemail only, no restart -- doesn't"
echo "      drop any real, in-progress call)"
sudo asterisk -rx "pjsip reload"
sudo asterisk -rx "dialplan reload"
sudo asterisk -rx "voicemail reload"

echo "[6/7] Verify"
sudo asterisk -rx "pjsip show endpoint 1000"
sudo asterisk -rx "pjsip show endpoint twilio-endpoint"
sudo asterisk -rx "dialplan show carepyre-internal"
sudo asterisk -rx "voicemail show users"

echo ""
echo "[7/7] Real secrets -- never printed anywhere but this terminal:"
echo "  SIP softphone (Zoiper, Linphone) -- test the phone side right now, independent of Twilio:"
echo "    Server:   198.58.107.85 (or carepyre.org once DNS/SRV is pointed here)"
echo "    Port:     5060, UDP"
echo "    Username: 1000"
echo "    Password: ${PHONE_SECRET}"
echo "  Voicemail PIN for mailbox 1000 (dial *97 from extension 1000 to check messages):"
echo "    PIN: ${VM_PIN}"
echo ""
echo "Done. The real Twilio trunk (carepyre.pstn.twilio.com, number +17855315546) is already"
echo "wired in -- call extension 1000 with a softphone registered above, or dial a real US"
echo "number from it to test outbound via Twilio. Inbound calls now announce + record"
echo "(REAL GAP: the announcement .wav doesn't exist yet, see"
echo "CarePyre/docs/GOOGLE_VOICE_FEATURES_NORTHSTAR.md) and fall to real voicemail if unanswered."
