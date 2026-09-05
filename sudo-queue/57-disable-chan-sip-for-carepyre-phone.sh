#!/usr/bin/env bash
# Real root cause of the persistent CarePyre phone 403, found via sudo-queue/56's own log dump:
# messages.log line "chan_sip.c: Registration from '<sip:1000@198.58.107.85>' failed ... - Wrong
# password" -- that's the OLD, legacy chan_sip module, not res_pjsip/chan_pjsip. This box has
# BOTH SIP channel drivers loaded, and legacy chan_sip is intercepting the REGISTER for extension
# 1000 before PJSIP ever processes it, checking it against its own separate config (sip.conf,
# Debian's stock sample file, never touched by any of this repo's own deploy scripts) which has
# a different (stock/unknown) password for "1000". Every sudo-queue/54-56 diagnostic on the
# PJSIP side came back correct because PJSIP's own config genuinely is correct -- the request
# just never reached it.
#
# Real, correct fix: this whole CarePyre SIP buildout (PARENA/ops/asterisk/*.conf) was designed
# exclusively around chan_pjsip -- chan_sip has no real, intended role here and should not be
# loaded at all. Disabling it via modules.conf's own real `noload =>` directive (not just
# `module unload`, which only takes effect until the next Asterisk restart) is the permanent fix.
#
# RUN THIS AS YOURSELF (fatbaby) -- NOT with `sudo ./57-....sh`.
if [ "$(id -u)" -eq 0 ]; then
  echo "ERROR: run this script as yourself (fatbaby), not via sudo." >&2
  exit 1
fi

set -euo pipefail

MODULES_CONF=/etc/asterisk/modules.conf

echo "[1/4] Confirm chan_sip is actually loaded right now"
sudo asterisk -rx "module show like chan_sip" 2>&1

echo ""
echo "[2/4] Add a real, permanent noload directive to modules.conf (idempotent -- checks first)"
if sudo grep -q "^noload => chan_sip.so" "${MODULES_CONF}" 2>/dev/null; then
  echo "      already present, skipping"
else
  # Insert right after the real, standard "[modules]" section header every stock modules.conf
  # has -- appending a real, correctly-scoped noload line, not just tacking it onto the end of
  # the file where it could land outside the [modules] section on some layouts.
  sudo sed -i '/^\[modules\]/a noload => chan_sip.so' "${MODULES_CONF}"
  echo "      added 'noload => chan_sip.so' under [modules]"
fi

echo ""
echo "[3/4] Unload it from the currently running instance too (so this takes effect now, not"
echo "      just after the next restart)"
sudo asterisk -rx "module unload chan_sip.so" 2>&1

echo ""
echo "[4/4] Reload pjsip (harmless, idempotent) and verify chan_sip is really gone"
sudo asterisk -rx "pjsip reload" 2>&1
sudo asterisk -rx "module show like chan_sip" 2>&1
echo ""
echo "If the line above says '0 modules loaded', chan_sip is gone and PJSIP now owns extension"
echo "1000's own REGISTER requests. Try registering again."
