#!/usr/bin/env bash
# Real, direct answer to kanban PBX-SRE-12442 ("what is the proper SRE way to get Asterisk
# running... do you just wanna yolo install it until we dev our own?"): yes, install the real
# Debian/Ubuntu `asterisk` package on this same box for now -- PARENA's own PBX story
# (PARENA/docs/PBX_ASTERISK_NORTHSTAR.md) is deliberately "bind to a real, already-running
# Asterisk" via AMI, not "build a PBX from scratch," so a real Asterisk instance is a genuine
# prerequisite, not a stopgap to be embarrassed about. "Yolo" here means "don't build custom
# infrastructure for this" (a plain apt package + its own default systemd unit), NOT "skip real
# security basics" -- the three real, checked-not-assumed things below are what keep this from
# being reckless on a box that's already public-internet-facing (iduna.farthq.com):
#
# 1. Port conflict, found live via `ss -tulnp`: Asterisk's default built-in HTTP server (ARI,
#    ATTENDED transfer UI, etc.) binds :8088, which is ALREADY this box's gpt2-alpine-c model
#    server (`python3 scripts/serve.py --model ft --port 8088`). PARENA's own committed plan
#    is AMI-only (TCP 5038, not ARI/HTTP -- see the northstar doc's own "AMI first, not
#    ARI/AGI" finding), so the fix is not "move it to another port," it's "turn it off
#    entirely" -- one real config line, http.conf's own `enabled=no`.
# 2. AMI (manager.conf) is real, plain-text, unencrypted auth over TCP -- there is no reason
#    for it to ever be reachable from outside this box (PARENA's own AMI client runs on this
#    same box), so it's bound to 127.0.0.1 only, with a real, freshly-generated secret (never a
#    default/placeholder password) printed ONLY to this script's own local stdout when it
#    actually runs -- never captured or echoed by anything else, matching this session's
#    standing "never print secrets to the agent's own terminal" rule (this script runs under
#    the founder's own real root session, not the agent's).
# 3. SIP/RTP DO need to be reachable from the real internet for a real call to work -- opened
#    narrowly: UDP 5060 (SIP signaling) and a deliberately NARROWED RTP range (10000-10099,
#    100 ports -- rtp.conf's own real default is 10000-20000, a needlessly wide 10,000-port
#    firewall opening for an interim, low-volume deployment; 100 concurrent RTP streams is far
#    more than this box needs right now, and the range can be widened later in one line if it
#    ever isn't).
#
# Never run manually as root outside this queue's own convention -- see sudo-queue/README.md.
set -euo pipefail

sudo apt-get update
sudo apt-get install -y asterisk

# --- 1. Disable the built-in HTTP/ARI server (real :8088 conflict, see header) ---
sudo sed -i \
  -e 's/^enabled\s*=\s*yes/enabled=no/' \
  /etc/asterisk/http.conf
# Confirm no plain `enabled = yes` line survives under [general] (the sed above only rewrites an
# EXISTING `enabled=yes`; a fresh Debian package ships one, but this doesn't blindly assume it).
if grep -qE '^\s*enabled\s*=\s*yes' /etc/asterisk/http.conf; then
  echo "FATAL: /etc/asterisk/http.conf still has an enabled=yes line -- fix manually before continuing." >&2
  exit 1
fi

# --- 2. AMI: localhost-only bind, a real generated secret, never a placeholder ---
AMI_SECRET="$(openssl rand -hex 24)"
sudo tee /etc/asterisk/manager.conf > /dev/null <<EOF
[general]
enabled = yes
port = 5038
bindaddr = 127.0.0.1

[parena]
secret = ${AMI_SECRET}
deny = 0.0.0.0/0.0.0.0
permit = 127.0.0.1/255.255.255.255
read = system,call,agent,log,verbose,command,dtmf,reporting,cdr,dialplan
write = system,call,agent,log,verbose,command,dtmf,reporting,cdr,dialplan
EOF
sudo chmod 640 /etc/asterisk/manager.conf
sudo chown root:asterisk /etc/asterisk/manager.conf

# --- 3. Narrow the RTP port range before opening it in the firewall (see header) ---
sudo sed -i \
  -e 's/^rtpstart\s*=.*/rtpstart=10000/' \
  -e 's/^rtpend\s*=.*/rtpend=10099/' \
  /etc/asterisk/rtp.conf
grep -q '^rtpstart=10000' /etc/asterisk/rtp.conf || echo 'rtpstart=10000' | sudo tee -a /etc/asterisk/rtp.conf > /dev/null
grep -q '^rtpend=10099' /etc/asterisk/rtp.conf || echo 'rtpend=10099' | sudo tee -a /etc/asterisk/rtp.conf > /dev/null

# --- Firewall: only what real external calls actually need ---
sudo ufw allow 5060/udp comment 'Asterisk SIP signaling'
sudo ufw allow 10000:10099/udp comment 'Asterisk RTP media (narrowed from the 10000-20000 default)'
# Deliberately NOT opening 5038 (AMI) or 8088 (HTTP/ARI, now disabled) -- neither should ever be
# internet-reachable.

# --- Enable via the package's own real, default systemd unit -- no custom unit needed ---
sudo systemctl enable --now asterisk
sudo systemctl restart asterisk

echo "--- asterisk status ---"
sudo systemctl status asterisk --no-pager | head -10
echo
echo "--- ports now listening (expect 5060 udp, 5038 tcp on 127.0.0.1 only, NOT 8088) ---"
sudo ss -tulnp | grep -i asterisk || true
echo
echo "--- ufw rules just added ---"
sudo ufw status verbose | grep -iE "5060|10000"
echo
echo "AMI (PARENA) secret -- copy this into PARENA's own AMI client config now, it is not saved"
echo "anywhere else by this script:"
echo "  username: parena"
echo "  secret:   ${AMI_SECRET}"
