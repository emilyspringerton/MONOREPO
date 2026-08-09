#!/usr/bin/env bash
# run.sh — general-purpose fresh-session entry point.
#
# Starts a new Claude Code session with a clean context window (no
# --continue) so routine work sessions don't inherit an ever-growing
# token history the way the --agi loop's --continue chaining does.
# Points the session at the standard Emily Way orientation: CLAUDE.md,
# then the observation queue (anything the founder fired in while no
# session was live — see THE_EMILY_WAY.md Principle 18), then BACKLOG.md,
# then get to work. Tags the session up front via `emily session new` so
# every Apple/CHANGELOG/observation this session produces is traceable to
# it from the very first command, not just from whenever someone
# remembers to run it mid-session.
#
# Use this for normal day-to-day work. Use start.sh instead right after
# a VM reboot to hydrate/restart the service stack via REBOOT_RUNBOOK.md.
#
# Run:
#   ./run.sh

set -euo pipefail

source /home/fatbaby/EMILY/var/emily-secrets.env
source /home/fatbaby/IDUNA/var/agent-secrets.env

cd /home/fatbaby

emily session new || true

claude --dangerously-skip-permissions "Read /home/fatbaby/CLAUDE.md in full, then /home/fatbaby/EMILY/BACKLOG.md. Before picking anything, check for founder input that arrived while no session was live: run 'emily backlog curate --all' to pull any uncurated FatBaby observations into BACKLOG.md's INTAKE QUEUE, and read that queue plus the top of SECTION 170 for anything not yet scoped into a real sprint item. Scope and log any of it per the backlog protocol first (Apple before mark-done, backlog first per THE_EMILY_WAY.md Principle 1). Then pick the highest-priority unchecked item in the lowest-numbered open section. Follow The Emily Way as you work it: any new founder real-time direction this session gets posted via 'emily observe' before you act on it (Principle 18), Apple before mark-done, CHANGELOG on every meaningful change, go test ./... before commit, correct commit format, and for multi-repo changes commit each repo independently in dependency order with EMILY/BACKLOG.md updated last."
