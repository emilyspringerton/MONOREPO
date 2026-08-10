#!/usr/bin/env bash
# start.sh — post-reboot hydration entry point.
#
# Launches a fresh Claude Code session with no memory of prior conversations and
# gives it a two-phase brief: (1) recover the service stack via
# EMILY/docs/REBOOT_RUNBOOK.md (self-contained, carries the full IDUNA/FatBaby/
# EMILY restart procedure), THEN (2) the same full Emily Way context hydration
# run.sh gives a normal day-to-day session -- CLAUDE.md, BACKLOG.md, session
# tagging, and curating anything the founder fired into the observation queue
# while the box was down (THE_EMILY_WAY.md Principle 18).
#
# 2026-08-10, founder: "ok all in on updating our start.sh script for maximum
# context hydration" -> "but we need the gold standard of context hydration."
# Before this update, start.sh only ever pointed a fresh session at the reboot
# runbook -- it never read CLAUDE.md, never read BACKLOG.md, never tagged a
# session, never curated the observation queue. A session that only recovers
# the service stack and stops there is exactly the "hollow" boot run.sh's own
# doc comment already warns about for its own case -- ported that same
# hydration here rather than leaving start.sh as a narrower, second-class
# entry point.
#
# Order matters: service recovery has to come FIRST, because observation-queue
# curation (`emily backlog curate --all`) depends on IDUNA actually being up
# and healthy -- curating against a dead IDUNA would just fail silently or
# stall, not a real hydration step yet at that point in the boot sequence.
#
# Use this right after a VM reboot/box upgrade. Use run.sh for normal
# day-to-day work sessions where no service recovery is needed.
#
# Run:
#   ./start.sh

set -euo pipefail

source /home/fatbaby/EMILY/var/emily-secrets.env
source /home/fatbaby/IDUNA/var/agent-secrets.env

cd /home/fatbaby

emily session new || true

claude --dangerously-skip-permissions "This is a post-reboot/post-upgrade session -- work it in two phases, in this order, not interleaved.

PHASE 1 -- service recovery. Read /home/fatbaby/EMILY/docs/REBOOT_RUNBOOK.md in full, then follow it step by step to verify and finish bringing the IDUNA/FatBaby/EMILY stack back up. Check what's already running before starting anything (systemd + linger may have already brought most of it back on their own -- the runbook's own 'What's now systemd-supervised' table lists everything that should have auto-started; verify against that list with 'systemctl --user list-unit-files --state=enabled' rather than assuming). Work through the runbook's own manual-restart list (services with no systemd unit -- currently gpt2-alpine-c's serve.py and cmd/broker, but re-check the runbook itself since that list can grow), then its verification steps. Confirm curl -sf localhost:8080/health passes before moving to Phase 2 -- Phase 2's own observation-queue curation needs a live IDUNA.

PHASE 2 -- full Emily Way context hydration, same as a normal run.sh session. Read /home/fatbaby/CLAUDE.md in full, then /home/fatbaby/EMILY/BACKLOG.md. Check for founder input that arrived while no session was live (real risk after a reboot specifically -- direction could have come in during the downtime with nothing running to pick it up): run 'emily backlog curate --all' to pull any uncurated FatBaby observations into BACKLOG.md's INTAKE QUEUE, and read that queue plus the top of SECTION 170 for anything not yet scoped into a real sprint item. Scope and log any of it per the backlog protocol first (Apple before mark-done, backlog first per THE_EMILY_WAY.md Principle 1).

Then report a clear status summary covering BOTH phases: what's up, what's down, anything that needed attention in Phase 1; and what (if anything) was sitting uncurated in the observation queue in Phase 2. Only after that summary, pick the highest-priority unchecked BACKLOG item in the lowest-numbered open section and start working it, following The Emily Way as you go: any new founder real-time direction this session gets posted via 'emily observe' before you act on it (Principle 18), Apple before mark-done, CHANGELOG on every meaningful change, go test ./... before commit, correct commit format, and for multi-repo changes commit each repo independently in dependency order with EMILY/BACKLOG.md updated last."
