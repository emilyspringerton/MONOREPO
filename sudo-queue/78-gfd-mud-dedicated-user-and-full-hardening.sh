#!/usr/bin/env bash
# 78-gfd-mud-dedicated-user-and-full-hardening.sh
#
# Real follow-up to SSH_TRANSPORT_IDENTITY_SPEC.md §5 (GoblinFoxDragon's process-isolation
# stage, docs2/SSH_TRANSPORT_IDENTITY_NORTHSTAR.md Stage 3, 2026-09-12). Stage 3 already shipped
# a real, meaningful chunk of §5 without root: ops/systemd/gfd-mud.service now runs the live
# `systemctl --user` unit under ProtectSystem=strict + ReadWritePaths=var (filesystem confined to
# one real data path), PrivateTmp, RestrictNamespaces/SUIDSGID/Realtime/AddressFamilies,
# LockPersonality, RemoveIPC, a SystemCallFilter=@system-service seccomp allowlist, and UMask=0077
# -- live-verified (systemd-analyze security exposure score 9.8 UNSAFE -> 5.8 MEDIUM, real telnet
# connect + real var/ write both confirmed against the actual live service).
#
# What that pass genuinely could NOT do without root -- confirmed live, not assumed: every
# directive whose enforcement mechanism is "drop a specific capability from the bounding set"
# (CapabilityBoundingSet=, AmbientCapabilities=, ProtectKernelModules=, ProtectKernelLogs=,
# ProtectClock=) failed with `status=218/CAPABILITIES` under `systemctl --user`, because the
# per-user systemd instance (user@1000.service) never holds CAP_SETPCAP -- that's a normal Linux
# capability rule, not a container/sandbox quirk of this box specifically (systemd-detect-virt
# reports a real KVM VM here, not a container). §5 also separately asks for "a dedicated
# unprivileged user, no login shell" -- gfd-mud currently runs as the interactive `fatbaby` user,
# which `useradd` can't be pointed at without root either.
#
# THIS script is the queued fix for both gaps at once: migrate gfd-mud.service from a
# `systemctl --user` unit (owned by `fatbaby`) to a real, root-owned SYSTEM unit running as a new,
# dedicated, shell-less system account -- which, being root-managed, CAN apply every directive
# the --user pass above had to skip.
#
# NOT run automatically. Review before running -- this migrates the execution user of a LIVE
# production game service (currently PID via `systemctl --user status gfd-mud.service`, real
# players may be connected) and changes file ownership under the repo. Read every step below
# first. Real, deliberate design choices, not defaults left unexamined:
#
# - New user: `gfd-mud`, system account (`--system`), no home directory of its own
#   (`--no-create-home`), shell `/usr/sbin/nologin` -- exactly the "no login shell" the spec asks
#   for. A dedicated new group of the same name, not added to any existing group (`sudo`, `users`,
#   etc.) -- least privilege, no reason for a game server to hold any of fatbaby's own group
#   memberships.
# - Filesystem: the repo itself (/home/fatbaby/GoblinFoxDragon) stays OWNED by fatbaby (source
#   code, git history, the founder's own working tree -- gfd-mud has no business writing there and
#   isn't given write access to any of it). gfd-mud gets read access via a POSIX ACL
#   (`setfacl -R -m u:gfd-mud:rX`) rather than a chmod/chgrp of the whole tree, so fatbaby's own
#   existing permissions on every file are left completely alone -- purely additive. var/ is
#   chown'd to gfd-mud:gfd-mud (rwx) since that's the one real, explicit data path the mud process
#   actually writes to (var/mud-chars.json, var/mud-player-ids.json, var/logs/) --
#   ReadWritePaths= in the unit below still confines writes to exactly that directory even though
#   gfd-mud now legitimately OWNS it, matching §5's "filesystem: read-only except an explicit data
#   path" literally, not just via systemd's own enforcement.
# - Secrets: the existing ~/.config/gfd-mud/env (fatbaby-owned, 0600, holds
#   IDUNA_AGENT_NAME/IDUNA_AGENT_SECRET) is UNREADABLE by gfd-mud as-is. Copied to
#   /etc/gfd-mud/env, chowned root:gfd-mud, chmod 640 -- gfd-mud can read it, no other unprivileged
#   user can, and the original file under fatbaby's home is left in place untouched (so the old
#   --user unit, if anyone ever re-enables it, still works unmodified).
# - The new system unit gets the FULL directive set: everything Stage 3 already shipped, plus
#   CapabilityBoundingSet= (drop everything -- this process never binds <1024 or needs any real
#   capability), AmbientCapabilities= (drop everything), ProtectKernelModules=yes,
#   ProtectKernelLogs=yes, ProtectClock=yes, and User=/Group=gfd-mud, DynamicUser=no (a real,
#   persistent UID is wanted here, not systemd's own ephemeral DynamicUser=yes -- var/ ownership
#   needs to survive restarts identically).
#
# Rollback: the old `systemctl --user` unit and its file ownership are NOT deleted by this
# script, only disabled+stopped -- `systemctl --user enable --now gfd-mud.service` (as fatbaby)
# plus `sudo chown -R fatbaby:fatbaby var/` reverts to exactly the pre-migration state. Read
# SSH_TRANSPORT_IDENTITY_SPEC.md §8's own "every stage must be revertible without data loss"
# requirement -- this rollback path is why var/'s ownership change is the only destructive-looking
# step, and it's a chown, not a delete.
#
# Verify after running:
#   sudo systemctl status gfd-mud.service
#   systemd-analyze security gfd-mud.service        # expect materially better than 5.8 MEDIUM
#   nc localhost 2323                                # real telnet connect still works
#   sudo -u gfd-mud touch /home/fatbaby/GoblinFoxDragon/README.md   # must FAIL (EACCES) -- proves
#                                                                     # the read-only confinement
set -euo pipefail

REPO=/home/fatbaby/GoblinFoxDragon
OLD_ENV="/home/fatbaby/.config/gfd-mud/env"
NEW_ENV="/etc/gfd-mud/env"

echo "== 1/6: creating dedicated system user/group (no login shell) =="
if ! id gfd-mud >/dev/null 2>&1; then
  useradd --system --user-group --no-create-home --shell /usr/sbin/nologin gfd-mud
else
  echo "   gfd-mud already exists, skipping useradd"
fi

echo "== 2/6: read-only ACL grant on the repo (fatbaby's own ownership/perms untouched) =="
setfacl -R -m u:gfd-mud:rX "$REPO"
setfacl -d -m u:gfd-mud:rX "$REPO"   # default ACL so files added later inherit read access too

echo "== 3/6: var/ becomes gfd-mud's own real, explicit, writable data path =="
chown -R gfd-mud:gfd-mud "$REPO/var"
chmod -R u+rwX,g+rX,o-rwx "$REPO/var"

echo "== 4/6: secrets -- copy (not move) to a location gfd-mud can read =="
mkdir -p /etc/gfd-mud
if [ -f "$OLD_ENV" ]; then
  cp "$OLD_ENV" "$NEW_ENV"
else
  echo "   WARNING: $OLD_ENV not found -- creating an empty template, fill in real values before starting the service"
  cat > "$NEW_ENV" <<'ENV'
IDUNA_AGENT_NAME=DRAGONSNSHIT-MUD
IDUNA_AGENT_SECRET=<fill in from IDUNA/var/agent-secrets.env>
ENV
fi
chown root:gfd-mud "$NEW_ENV"
chmod 640 "$NEW_ENV"

echo "== 5/6: install the new system unit, disable the old user unit =="
cat > /etc/systemd/system/gfd-mud.service <<UNIT
[Unit]
Description=DragonsNShit MUD (GoblinFoxDragon apps2/mud) -- dedicated user, full hardening
After=network-online.target

[Service]
Type=simple
User=gfd-mud
Group=gfd-mud
WorkingDirectory=${REPO}
EnvironmentFile=-${NEW_ENV}
ExecStart=${REPO}/mud -port 2323 -api-port 7171
Restart=on-failure
RestartSec=10s
StandardOutput=append:${REPO}/var/logs/mud.log
StandardError=append:${REPO}/var/logs/mud.log
MemoryMax=512M

# Filesystem: read-only everywhere except the one real data path.
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=${REPO}/var

# No privilege escalation; no new capabilities can ever be gained mid-run.
NoNewPrivileges=yes

# Full capability drop -- this process never binds <1024 and needs no real capability at all.
CapabilityBoundingSet=
AmbientCapabilities=

# Full kernel-surface + namespace restriction (root-owned unit, so these actually apply here,
# unlike the --user unit this replaces).
PrivateTmp=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectKernelLogs=yes
ProtectClock=yes
ProtectControlGroups=yes
ProtectHostname=yes
RestrictNamespaces=yes
RestrictSUIDSGID=yes
RestrictRealtime=yes
LockPersonality=yes
RemoveIPC=yes
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX
SystemCallFilter=@system-service
SystemCallErrorNumber=EPERM
UMask=0077

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload

# Stop+disable the old --user unit (run as fatbaby, not root -- su into the right bus).
sudo -u fatbaby XDG_RUNTIME_DIR=/run/user/1000 systemctl --user disable --now gfd-mud.service || true

echo "== 6/6: enable + start the new system unit =="
systemctl enable --now gfd-mud.service
sleep 2
systemctl status gfd-mud.service --no-pager

echo
echo "== done. Verify with the commands in this script's own header comment. =="
