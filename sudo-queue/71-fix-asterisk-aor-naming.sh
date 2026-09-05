#!/usr/bin/env bash
# Real fix for the SAME symptom sudo-queue/70 tried and failed to fix (founder: "Registering..
# for a long time then failed", then confirmed still broken after running /70). /70's diagnosis
# was WRONG: it assumed the live aors= line was blank, but it was actually already correctly set
# to "carepyre-phone-aor" -- the sed pattern (which only matched a truly empty aors= line) was a
# silent no-op the whole time.
#
# The REAL root cause, found by pulling Asterisk's own res_pjsip_registrar.c source
# (find_aor_name(), res/res_pjsip_registrar.c in asterisk/asterisk on GitHub): the registrar does
# NOT just use whichever single AOR an endpoint lists. It requires the AOR's own section NAME to
# literally equal the REGISTER request's username ("1000"), "username@domain", or
# "username@realm" -- matched first against the To-header URI, then against the auth digest
# username as a fallback. A descriptively-named AOR like "carepyre-phone-aor" can never match
# either pattern, so registration failed with a real 404 ("AOR '' not found for endpoint '1000'")
# no matter what the endpoint's aors= line pointed at. This is why the standard Asterisk PJSIP
# convention reuses the extension number as the section id for aor/auth/endpoint blocks -- not
# just as a style choice, but because the registrar's own matching logic depends on it.
#
# This script renames both AOR sections to match their extension ([1000], [1000web]) in the LIVE
# deployed files, matching this repo's own now-fixed templates
# (PARENA/ops/asterisk/pjsip_carepyre_phone.conf / pjsip_carepyre_webphone.conf), reloads PJSIP,
# and verifies with a REAL end-to-end SIP REGISTER test (not just a config dump) before declaring
# success -- so this script itself won't repeat /70's mistake of trusting a config-only check.
#
# RUN THIS AS YOURSELF (fatbaby) -- NOT with `sudo ./71-....sh` -- same convention as every other
# script in this queue.
if [ "$(id -u)" -eq 0 ]; then
  echo "ERROR: run this script as yourself (fatbaby), not via sudo -- see the header comment" >&2
  echo "above for why. The individual sudo lines inside it will prompt for a password when" >&2
  echo "they actually need one." >&2
  exit 1
fi

set -euo pipefail

PHONE_CONF=/etc/asterisk/pjsip_carepyre_phone.conf
WEBPHONE_CONF=/etc/asterisk/pjsip_carepyre_webphone.conf

echo "[1/5] Show the current, live, real (broken) AOR section names + aors= references"
sudo grep -n "^\[.*aor\]\|^aors=" "$PHONE_CONF" "$WEBPHONE_CONF" || true

echo ""
echo "[2/5] Back up both live files before editing"
sudo cp "$PHONE_CONF" "${PHONE_CONF}.bak-$(date -u +%Y%m%dT%H%M%SZ)"
sudo cp "$WEBPHONE_CONF" "${WEBPHONE_CONF}.bak-$(date -u +%Y%m%dT%H%M%SZ)"

echo ""
echo "[3/5] Rename the AOR sections to match their extension, and point aors= at the new name"
sudo sed -i \
  -e 's/^\[carepyre-phone-aor\]$/[1000]/' \
  -e 's/^aors=carepyre-phone-aor$/aors=1000/' \
  "$PHONE_CONF"
sudo sed -i \
  -e 's/^\[carepyre-webphone-aor\]$/[1000web]/' \
  -e 's/^aors=carepyre-webphone-aor$/aors=1000web/' \
  "$WEBPHONE_CONF"
sudo asterisk -rx "pjsip reload"

echo ""
echo "[4/5] Config-level verify"
sudo asterisk -rx "pjsip show endpoint 1000" | grep -i "aor\|contact" || true
echo "---"
sudo asterisk -rx "pjsip show endpoint 1000web" | grep -i "aor\|contact" || true

echo ""
echo "[5/5] REAL end-to-end verify: send an actual SIP REGISTER (with real digest auth, using"
echo "      extension 1000's real password from EMILY/var/carepyre-phone-secret.env) and confirm"
echo "      Asterisk returns 200 OK, not another 404 -- this is the same check that caught /70's"
echo "      false success."
PHONE_PASSWORD="$(grep '^CAREPYRE_PHONE_1000_PASSWORD=' /home/fatbaby/EMILY/var/carepyre-phone-secret.env | cut -d= -f2)"
python3 - "$PHONE_PASSWORD" <<'PYEOF'
import socket, hashlib, re, random, string, sys
PASSWORD = sys.argv[1]
SERVER = "127.0.0.1"; PORT = 5060; EXT = "1000"
LOCAL_PORT = 5099

def rand_str(n=10):
    return ''.join(random.choice(string.ascii_lowercase + string.digits) for _ in range(n))

def send_recv(sock, msg):
    sock.sendto(msg.encode(), (SERVER, PORT))
    data, _ = sock.recvfrom(8192)
    return data.decode(errors="replace")

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
        "User-Agent: sudo-queue-71-verify/1.0",
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
call_id = rand_str(16) + "@verify71"

r1 = send_recv(sock, build("z9hG4bK" + rand_str(10), call_id, 1))
print("First REGISTER:", r1.splitlines()[0])
realm = re.search(r'realm="([^"]+)"', r1).group(1)
nonce = re.search(r'nonce="([^"]+)"', r1).group(1)
uri = f"sip:{SERVER}"
ha1 = md5(f"{EXT}:{realm}:{PASSWORD}")
ha2 = md5(f"REGISTER:{uri}")
resp = md5(f"{ha1}:{nonce}:{ha2}")
auth = (f'Authorization: Digest username="{EXT}", realm="{realm}", nonce="{nonce}", '
        f'uri="{uri}", response="{resp}", algorithm=MD5')
r2 = send_recv(sock, build("z9hG4bK" + rand_str(10), call_id, 2, auth))
status = r2.splitlines()[0]
print("Authenticated REGISTER:", status)
if "200" in status:
    print("\nSUCCESS: extension 1000 registered for real.")
    sys.exit(0)
else:
    print("\nSTILL FAILING -- do not tell the user this is fixed.")
    print(r2[:500])
    sys.exit(1)
PYEOF
