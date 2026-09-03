#!/usr/bin/env bash
# Syncs WOTAN repo content to the live site. Nothing else.
# Matches OKEMILY's own okemily-deploy.sh convention exactly -- no dynamic/rendered
# subdirectories exist here yet (WOTAN is a real placeholder page only, see WOTAN/CLAUDE.md), so
# no exclusions are needed today. If a future pass adds anything IDUNA renders straight into
# /var/www/wotan (mirroring OKEMILY's own blog/tyler/prompt-o-verse precedent), add the same
# --exclude here before that happens, not after -- see okemily-deploy.sh's own header comment
# for the real 2026-07-19 outage this discipline exists to prevent.
#
# Requires /var/www/wotan to already exist and be writable by this user -- see
# sudo-queue/48-setup-wotan-nginx-and-dir.sh for the one-time setup (mkdir/chown, nginx site,
# certbot) this script does not perform.
set -euo pipefail
mkdir -p /var/www/wotan
rsync -a --delete /home/fatbaby/WOTAN/ /var/www/wotan/ --exclude='.git' --exclude='ops'
