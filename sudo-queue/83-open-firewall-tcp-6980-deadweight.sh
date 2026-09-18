#!/usr/bin/env bash
# DEADWEIGHT (S503-14): dw_server is live on 0.0.0.0:6980/tcp on this box (user unit dw-server, 3-bot pool
# dw-bot@{ripper,wall,mirror}) and answers on 198.58.107.85 locally, but this sandbox can't verify that an
# OUTSIDE phone can reach it (host firewall / Linode cloud firewall). Same open question as sudo-queue/79 (UDP 6969).
# Idempotent: allows 6980/tcp in ufw if ufw is active, else reports iptables state. Writes the report to
# EMILY/var/firewall-tcp-6980-check.txt. If a Linode Cloud Firewall is attached to this Linode, it must ALSO allow 6980/tcp
# in the Linode Cloud Manager (cannot be done from the box).
#
# RUN THIS AS YOURSELF (fatbaby) -- NOT with `sudo ./83-....sh`.
if [ "$(id -u)" -eq 0 ]; then echo "ERROR: run as yourself, not via sudo." >&2; exit 1; fi
set -uo pipefail
OUT="/home/fatbaby/EMILY/var/firewall-tcp-6980-check.txt"
{
  echo "=== $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
  echo "--- listener ---"; ss -ltnp 2>/dev/null | grep ':6980 '
  echo "--- ufw status BEFORE ---"; sudo ufw status verbose 2>&1
  echo "--- iptables INPUT policy ---"; sudo iptables -S INPUT 2>&1 | head -5
} > "$OUT" 2>&1
if sudo ufw status 2>&1 | grep -qi "Status: active"; then
  sudo ufw allow 6980/tcp comment 'DEADWEIGHT dw_server (S503-14)' 2>&1 | tee -a "$OUT"
  echo "--- ufw status AFTER ---" >> "$OUT"; sudo ufw status 2>&1 >> "$OUT"
else
  echo "ufw not active; iptables policy above decides (ACCEPT policy = already open)." | tee -a "$OUT"
fi
echo "Report: $OUT"
echo "From a phone/other machine: nc -vz okemily.com 6980   (or just open the app and tap PLAY VS BOT)"
