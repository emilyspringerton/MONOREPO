#!/usr/bin/env bash
# Second-pass diagnostic for the real, persistent 403 Forbidden on extension 1000's own REGISTER
# (sudo-queue/54 confirmed the deployed password/realm/auth config all look structurally
# correct on paper -- this pass captures Asterisk's own live, verbose PJSIP trace DURING a real
# register attempt, the one thing that actually shows WHY the digest comparison fails).
#
# RUN THIS AS YOURSELF (fatbaby) -- NOT with `sudo ./55-....sh`. Same real convention every other
# script in this queue follows.
if [ "$(id -u)" -eq 0 ]; then
  echo "ERROR: run this script as yourself (fatbaby), not via sudo." >&2
  exit 1
fi

set -uo pipefail

OUT="/home/fatbaby/EMILY/var/carepyre-phone-403-verbose.txt"
TRACE="/tmp/carepyre-asterisk-console-$$.txt"

{
  echo "=== $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
  echo ""
  echo "--- real asterisk log directory/files ---"
  sudo find /var/log/asterisk -maxdepth 2 -type f 2>&1
  echo ""
  echo "--- turning on pjsip debug logging + attaching a live console for ~10s while a real"
  echo "    register attempt runs ---"
} > "${OUT}" 2>&1

sudo asterisk -rx "pjsip set logger on" >> "${OUT}" 2>&1
sudo asterisk -rx "core set verbose 5" >> "${OUT}" 2>&1

# Attach a live, read-only console in the background for a real, bounded window, capturing
# whatever Asterisk prints (including the pjsip packet trace) while the test REGISTER below runs.
sudo timeout 10 asterisk -rvvvvv > "${TRACE}" 2>&1 &
CONSOLE_PID=$!
sleep 2

PW="$(grep -oP '(?<=CAREPYRE_PHONE_1000_PASSWORD=).*' /home/fatbaby/EMILY/var/carepyre-phone-secret.env 2>/dev/null)"
if [ -n "${PW:-}" ]; then
  python3 - "198.58.107.85" "${PW}" >> "${OUT}" 2>&1 <<'PYEOF'
import socket, sys, hashlib, re, secrets

server, password = sys.argv[1], sys.argv[2]
port = 5060
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.settimeout(5)
s.connect((server, port))
local_ip, local_port = s.getsockname()

def send_register(auth_header, cseq, call_id, from_tag, branch):
    aor = f"sip:1000@{server}"
    req = (
        f"REGISTER sip:{server} SIP/2.0\r\n"
        f"Via: SIP/2.0/UDP {local_ip}:{local_port};branch={branch}\r\n"
        f"Max-Forwards: 70\r\n"
        f"From: <{aor}>;tag={from_tag}\r\n"
        f"To: <{aor}>\r\n"
        f"Call-ID: {call_id}\r\n"
        f"CSeq: {cseq} REGISTER\r\n"
        f"Contact: <sip:1000@{local_ip}:{local_port}>\r\n"
        f"Expires: 3600\r\n"
    )
    if auth_header:
        req += f"Authorization: {auth_header}\r\n"
    req += "Content-Length: 0\r\n\r\n"
    s.send(req.encode())
    return s.recv(8192).decode(errors="replace")

call_id = secrets.token_hex(8) + "@" + local_ip
from_tag = secrets.token_hex(4)
branch = "z9hG4bK" + secrets.token_hex(4)
resp1 = send_register(None, 1, call_id, from_tag, branch)
print("--- first REGISTER response ---")
print(resp1)

m = re.search(r'(?i)^(WWW-Authenticate|Proxy-Authenticate):\s*(.+)$', resp1, re.M)
if not m:
    print("no challenge header found, stopping")
    sys.exit(0)
challenge = m.group(2)
def field(name):
    fm = re.search(name + r'="?([^",]+)"?', challenge)
    return fm.group(1) if fm else None
realm, nonce = field("realm"), field("nonce")
uri = f"sip:{server}"
ha1 = hashlib.md5(f"1000:{realm}:{password}".encode()).hexdigest()
ha2 = hashlib.md5(f"REGISTER:{uri}".encode()).hexdigest()
response = hashlib.md5(f"{ha1}:{nonce}:{ha2}".encode()).hexdigest()
print(f"HA1={ha1} HA2={ha2} response={response} realm={realm} nonce={nonce}")
auth = f'Digest username="1000", realm="{realm}", nonce="{nonce}", uri="{uri}", response="{response}"'
branch2 = "z9hG4bK" + secrets.token_hex(4)
resp2 = send_register(auth, 2, call_id, from_tag, branch2)
print("--- second (authenticated, no-qop) REGISTER response ---")
print(resp2)
PYEOF
else
  echo "no password found, skipping live re-test" >> "${OUT}"
fi

wait "${CONSOLE_PID}" 2>/dev/null

{
  echo ""
  echo "--- Asterisk's own live console/pjsip trace during that attempt ---"
  cat "${TRACE}" 2>&1
  echo ""
  sudo asterisk -rx "pjsip set logger off" 2>&1
  sudo asterisk -rx "core set verbose 0" 2>&1
} >> "${OUT}" 2>&1

rm -f "${TRACE}"
chmod 644 "${OUT}"
echo "Diagnostics written to ${OUT}"
