#!/usr/bin/env bash
# Installs freetds-bin system-wide, giving this box a real, persistent `tsql` on PATH --
# S498 (2026-09-18), founder real-time: "we need to put in PARENA primatives for MSSQL and double
# down on all the unix socket stuff and raw socket stuff." PARENA/stdlib/log/projector.prn's new
# `project-mssql!` shells out to `tsql` (FreeTDS's own CLI, the real MSSQL/TDS equivalent of the
# `sqlite3`/`mysql`/`psql` CLIs this file's own sibling functions already shell out to), same
# real "shell out to the dialect's own CLI" convention sudo-queue/45 (now archived/removed after
# running) already established for sqlite3/postgresql-client.
#
# This session already validated the real command construction (a real fast, non-hanging
# "Connection refused" against an unreachable host, and `dbinit`/`dblogin`/etc. dblib ABI symbols
# confirmed present) WITHOUT root, by using `apt-get download freetds-bin` (fetches the .deb, no
# install, no root needed) + `dpkg-deb -x` (extracts to /tmp, no root needed) -- that workaround
# is real and it's how PARENA's own stdlib/tests actually got verified this session, but it only
# persists for this one sandbox session's own /tmp lifetime, and the freetds-common package
# already on this box only ships the shared library (`libsybdb.so.5`, confirmed present via
# `ldconfig -p`), not the `tsql` CLI binary itself. This script makes it a real, permanent,
# system-wide install instead, so `make test-log-projector`'s own optional
# `command -v tsql`-gated live check (matching the same convention test_log_projector.c already
# uses for sqlite3) actually runs the real live path on future sessions, not just the stub-shell
# path.
#
# RUN THIS AS YOURSELF (fatbaby) -- NOT with `sudo ./82-....sh`. It uses sudo internally only for
# the one actual apt-get install step.
if [ "$(id -u)" -eq 0 ]; then
  echo "ERROR: run this script as yourself (fatbaby), not via sudo." >&2
  exit 1
fi

set -euo pipefail

echo "[1/2] Installing freetds-bin (the real tsql CLI; freetds-common/libsybdb.so.5's own shared"
echo "      library dependency is already installed on this box, confirmed live this session)"
sudo apt-get update
sudo apt-get install -y freetds-bin

echo "[2/2] Verifying tsql is now really on PATH and actually runs"
command -v tsql
tsql -C | head -3
echo "Done -- tsql is now a real, permanent, system-wide CLI on this box."
