#!/usr/bin/env bash
# Third diagnostic pass for the persistent CarePyre phone 403. sudo-queue/54 confirmed the
# deployed password/realm/auth config all look correct on paper; sudo-queue/55's own digest
# values were independently cross-checked and are mathematically correct against the known
# password (HA1 matched an offline recomputation exactly) -- so this isn't a client-side digest
# bug anymore. sudo-queue/55's own console capture (`asterisk -rvvvvv` piped through `timeout`
# with no real TTY attached) came back as mostly binary NUL padding, useless -- and it grepped
# the wrong log filename (`/var/log/asterisk/full`, which sudo-queue/54 already showed doesn't
# exist; the real file is `/var/log/asterisk/messages.log`). This script fixes both: no console
# attach at all, just a real test REGISTER followed by directly tailing the REAL log file, plus a
# few more `pjsip show` commands that can reveal a non-credential rejection reason (endpoint
# identification failing before auth is even checked, which PJSIP also reports as 403).
#
# RUN THIS AS YOURSELF (fatbaby) -- NOT with `sudo ./56-....sh`.
if [ "$(id -u)" -eq 0 ]; then
  echo "ERROR: run this script as yourself (fatbaby), not via sudo." >&2
  exit 1
fi

set -uo pipefail

OUT="/home/fatbaby/EMILY/var/carepyre-phone-403-log.txt"

{
  echo "=== $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
  echo ""
  echo "--- pjsip endpoint identifier order (global setting -- affects how/whether an incoming"
  echo "    REGISTER even gets matched to endpoint 1000 before auth is checked) ---"
  sudo asterisk -rx "pjsip show settings" 2>&1 | grep -i "identifier"
  echo ""
  echo "--- global res_pjsip settings (full) ---"
  sudo asterisk -rx "pjsip show settings" 2>&1
} > "${OUT}" 2>&1

sudo asterisk -rx "core set debug 3 res_pjsip" > /dev/null 2>&1
sudo asterisk -rx "pjsip set logger on" > /dev/null 2>&1

# Mark a unique point in the log so we can find exactly where our own test attempt's own lines
# start, without needing to guess a timestamp.
MARKER="CAREPYRE_403_DEBUG_MARKER_$$"
sudo asterisk -rx "log message NOTICE \"${MARKER}\"" > /dev/null 2>&1 || \
  sudo asterisk -rx "core show version" > /dev/null 2>&1  # harmless fallback if `log message` isn't a real command on this version

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
print(f"real test Call-ID (grep the log for this): {call_id}")
resp1 = send_register(None, 1, call_id, from_tag, branch)
m = re.search(r'(?i)^(WWW-Authenticate|Proxy-Authenticate):\s*(.+)$', resp1, re.M)
if not m:
    print("no challenge header found:")
    print(resp1)
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
auth = f'Digest username="1000", realm="{realm}", nonce="{nonce}", uri="{uri}", response="{response}"'
branch2 = "z9hG4bK" + secrets.token_hex(4)
resp2 = send_register(auth, 2, call_id, from_tag, branch2)
print("final response:")
print(resp2)
PYEOF
else
  echo "no password found, skipping live re-test" >> "${OUT}"
fi

sleep 1
sudo asterisk -rx "pjsip set logger off" > /dev/null 2>&1
sudo asterisk -rx "core set debug 0" > /dev/null 2>&1

{
  echo ""
  echo "--- last 150 lines of the REAL asterisk log (messages.log) ---"
  sudo tail -150 /var/log/asterisk/messages.log 2>&1
} >> "${OUT}" 2>&1

chmod 644 "${OUT}"
echo "Diagnostics written to ${OUT}"
