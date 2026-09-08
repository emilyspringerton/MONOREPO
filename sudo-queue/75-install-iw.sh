#!/usr/bin/env bash
# 75-install-iw.sh — installs the real `iw` CLI (part of Linux's own standard nl80211
# userspace tooling), needed by PARENA's new stdlib/pentest/wireless.prn (monitor-mode/channel
# control for the Nexmon-targeting thread, 2026-09-08). Real, safe, additive: a plain apt
# package install, no config changes, no service restarts. Real, checked-live: `ip` is already
# present on this box (iproute2), `iw` is not.
set -euo pipefail
sudo apt-get update
sudo apt-get install -y iw
iw --version
