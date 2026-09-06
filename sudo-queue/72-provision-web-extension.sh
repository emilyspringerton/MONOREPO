#!/usr/bin/env bash
# Provisions a real "<extension>web" WebRTC/JsSIP endpoint on this box's live Asterisk instance,
# generalizing what sudo-queue/62-carepyre-webphone-deploy.sh did once, by hand, for extension
# 1000 only. Founder real-time, 2026-09-06, after the console's embedded Web Phone worked for
# extension 1000 but nowhere else: "can we have more than just the 1 extension or what? ... if
# its not 1000 im still expecting it to work is that reasonable? i feel like working with
# asterisk is like pulling teeth." Real, honest answer: yes, reasonable -- Asterisk's config is
# flat files that need root + a reload, so a brand new webphone identity can't be self-served by
# IDUNA_PRO on its own. This script is the fix for THAT part: one command per new extension,
# instead of hand-editing pjsip_carepyre_webphone.conf from scratch each time (and re-risking the
# exact AOR-naming bug sudo-queue/71 had to fix).
#
# Usage:
#   ./72-provision-web-extension.sh <extension>
#
# <extension> must already have a real sip_accounts row (assigned via the console's Admin ->
# Users table) -- this script only provisions the real Asterisk side; it does not touch
# IDUNA_PRO's own database.
#
# What it does:
#   1. Generates a real, fresh PJSIP password.
#   2. Appends a NEW [<extension>web] aor/auth/endpoint block to the live
#      /etc/asterisk/pjsip_carepyre_webphone.conf (idempotent -- refuses to run if that
#      extension's block already exists, so it's safe to re-run by mistake).
#   3. Reloads PJSIP and verifies with a REAL end-to-end SIP REGISTER (not just a config dump --
#      see sudo-queue/71's own header comment for why a config-only check isn't good enough).
#   4. Writes the password to EMILY/var/carepyre-<extension>web-secret.env (mode 600).
#   5. Prints the exact WEBPHONE_SECRETS_JSON edit + idunapro restart needed to make the new
#      extension's webphone-credentials endpoint (and therefore the console's embedded Web Phone)
#      actually serve it -- this script does NOT edit ~/.config/idunapro/env itself, since that's
#      a shared file this queue's other scripts also touch and a bad automated edit there is
#      harder to safely undo than one more manual step.
#
# RUN THIS AS YOURSELF (fatbaby) -- NOT with `sudo ./72-....sh` -- same convention as every other
# script in this queue.
if [ "$(id -u)" -eq 0 ]; then
  echo "ERROR: run this script as yourself (fatbaby), not via sudo -- see the header comment" >&2
  echo "above for why. The individual sudo lines inside it will prompt for a password when" >&2
  echo "they actually need one." >&2
  exit 1
fi

set -euo pipefail

EXTENSION="${1:-}"
if [ -z "$EXTENSION" ]; then
  echo "Usage: $0 <extension>" >&2
  echo "  e.g. $0 100" >&2
  exit 1
fi
if ! [[ "$EXTENSION" =~ ^[0-9]+$ ]]; then
  echo "ERROR: extension must be numeric (got '$EXTENSION')" >&2
  exit 1
fi

WEBPHONE_CONF=/etc/asterisk/pjsip_carepyre_webphone.conf
SECTION="${EXTENSION}web"
SECRET_FILE="/home/fatbaby/EMILY/var/carepyre-${SECTION}-secret.env"

echo "[1/6] Check this extension isn't already provisioned"
if sudo grep -q "^\[${SECTION}\]\$" "$WEBPHONE_CONF"; then
  echo "ERROR: [${SECTION}] already exists in ${WEBPHONE_CONF} -- refusing to duplicate it." >&2
  echo "If you need to REGENERATE its password instead, that's a different, not-yet-written" >&2
  echo "script (same shape as sudo-queue/53's own regenerate-1000-password precedent)." >&2
  exit 1
fi

echo "[2/6] Generate a real, fresh PJSIP password"
WEB_SECRET="$(openssl rand -hex 16)"

echo "[3/6] Back up the live file, then append the new endpoint block"
sudo cp "$WEBPHONE_CONF" "${WEBPHONE_CONF}.bak-$(date -u +%Y%m%dT%H%M%SZ)"
sudo tee -a "$WEBPHONE_CONF" > /dev/null <<EOF

; Provisioned $(date -u +%Y-%m-%dT%H:%M:%SZ) by sudo-queue/72-provision-web-extension.sh --
; real WebRTC identity for extension ${EXTENSION}, matching pjsip_carepyre_webphone.conf's own
; original [1000web] block. AOR section is deliberately named "${SECTION}" itself (not a
; descriptive name) -- Asterisk's registrar requires the AOR name to literally equal the
; extension for REGISTER to resolve it (see sudo-queue/71-fix-asterisk-aor-naming.sh's own
; header comment for the full explanation and Asterisk source citation).
[${SECTION}-auth]
type=auth
auth_type=userpass
username=${SECTION}
password=${WEB_SECRET}

[${SECTION}]
type=aor
max_contacts=1
remove_existing=yes
qualify_frequency=60

[${SECTION}]
type=endpoint
context=carepyre-internal
disallow=all
allow=opus,ulaw
auth=${SECTION}-auth
aors=${SECTION}
webrtc=yes
dtls_auto_generate_cert=yes
direct_media=no
EOF
sudo asterisk -rx "pjsip reload"

echo ""
echo "[4/6] Config-level verify"
sudo asterisk -rx "pjsip show endpoint ${SECTION}" | grep -i "aor\|contact" || true

echo ""
echo "[5/6] REAL end-to-end verify: an actual SIP REGISTER, not just a config dump"
python3 - "$WEB_SECRET" "$SECTION" <<'PYEOF'
import socket, hashlib, re, random, string, sys
PASSWORD, EXT = sys.argv[1], sys.argv[2]
SERVER = "127.0.0.1"; PORT = 5060
LOCAL_PORT = random.randint(20000, 60000)

def rand_str(n=10):
    return ''.join(random.choice(string.ascii_lowercase + string.digits) for _ in range(n))

def send_wait(sock, msg, prefix, tries=5):
    sock.sendto(msg.encode(), (SERVER, PORT))
    text = ""
    for _ in range(tries):
        data, _ = sock.recvfrom(8192)
        text = data.decode(errors="replace")
        if text.startswith(prefix):
            return text
    return text

def build(branch, call_id, cseq, auth=None):
    lines = [
        f"REGISTER sip:{SERVER} SIP/2.0",
        f"Via: SIP/2.0/UDP 127.0.0.1:{LOCAL_PORT};branch={branch};rport",
        "Max-Forwards: 70",
        f"From: <sip:{EXT}@{SERVER}>;tag={rand_str(8)}",
        f"To: <sip:{EXT}@{SERVER}>",
        f"Call-ID: {call_id}",
        f"CSeq: {cseq} REGISTER",
        f"Contact: <sip:{EXT}@127.0.0.1:{LOCAL_PORT}>",
        "Expires: 3600",
        "User-Agent: sudo-queue-72-verify/1.0",
    ]
    if auth:
        lines.append(auth)
    lines += ["Content-Length: 0", "", ""]
    return "\r\n".join(lines)

def md5(s):
    return hashlib.md5(s.encode()).hexdigest()

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.bind(("127.0.0.1", LOCAL_PORT))
sock.settimeout(5)
call_id = rand_str(16) + "@verify72"

r1 = send_wait(sock, build("z9hG4bK" + rand_str(10), call_id, 1), "SIP/2.0")
print("First REGISTER:", r1.splitlines()[0])
realm = re.search(r'realm="([^"]+)"', r1).group(1)
nonce = re.search(r'nonce="([^"]+)"', r1).group(1)
uri = f"sip:{SERVER}"
ha1 = md5(f"{EXT}:{realm}:{PASSWORD}")
ha2 = md5(f"REGISTER:{uri}")
resp = md5(f"{ha1}:{nonce}:{ha2}")
auth = (f'Authorization: Digest username="{EXT}", realm="{realm}", nonce="{nonce}", '
        f'uri="{uri}", response="{resp}", algorithm=MD5')
r2 = send_wait(sock, build("z9hG4bK" + rand_str(10), call_id, 2, auth), "SIP/2.0")
status = r2.splitlines()[0]
print("Authenticated REGISTER:", status)
if "200" not in status:
    print("\nSTILL FAILING -- do not tell the founder this extension is ready.")
    print(r2[:500])
    sys.exit(1)
print("\nSUCCESS.")
PYEOF

echo ""
echo "[6/6] Save the password"
umask 077
cat > "$SECRET_FILE" <<EOF
# CarePyre Web Phone extension ${SECTION} PJSIP password -- generated $(date -u +%Y-%m-%dT%H:%M:%SZ)
# by sudo-queue/72-provision-web-extension.sh.
CAREPYRE_WEBPHONE_${SECTION^^}_PASSWORD=${WEB_SECRET}
EOF
chmod 600 "$SECRET_FILE"

echo ""
echo "Done. Extension ${SECTION} is real and registers correctly."
echo ""
echo "One more manual step to make the console's Web Phone actually serve it: edit"
echo "~/.config/idunapro/env, add \"${EXTENSION}\":\"${WEB_SECRET}\" to the existing"
echo "WEBPHONE_SECRETS_JSON value (create it if it doesn't exist yet, e.g."
echo "WEBPHONE_SECRETS_JSON={\"${EXTENSION}\":\"${WEB_SECRET}\"}), then restart idunapro:"
echo "  systemctl --user restart idunapro.service"
