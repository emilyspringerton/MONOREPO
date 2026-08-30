#!/usr/bin/env bash
# tmux-session.sh — tmux-wrapped fresh-session entry point.
#
# Founder real-time, 2026-08-30: "uh oh we arent in tmux as soon as is
# reasonably possible write me a new claude start up script to start a new
# session my command was like emily session new > sess && claude
# --dangerously check-the-sess-file" — a bare `claude --dangerously-skip-
# permissions` invoked from a plain SSH shell (not tmux, not screen) dies
# the moment that SSH connection drops: no detached terminal to reattach to,
# session gone. This script is that same two-step command
# (`emily session new > sess` then `claude --dangerously-skip-permissions`
# pointed at the sess file), but re-execs itself inside a detached tmux
# session first so the Claude process survives a dropped connection --
# reattach with `tmux attach -t <name>` from anywhere.
#
# Deliberately narrower than run.sh/start.sh: those two give a fresh session
# the FULL Emily Way orientation (CLAUDE.md, BACKLOG.md, observation-queue
# curation). This script's only job is "get a session running, survivably,
# with its session id discoverable via the sess file" -- the literal ask.
# Use run.sh/start.sh for normal day-to-day orientation; use this one when
# the actual problem is "we're not in tmux right now."
#
# The onboarding prompt below also bakes in a real lesson from a live session
# the same day, so the next fresh agent doesn't have to be walked through it
# by hand again: run.sh/start.sh both `source /home/fatbaby/EMILY/var/
# emily-secrets.env`, which is mode 600 -- readable only by its owner. A
# session running as a different (but group-adjacent) user gets a silent
# `Permission denied` on that `source` line and the whole script dies before
# it ever reaches the actual orientation prompt, with no obvious sign why.
# The founder's own real-time fix, walked through live: don't fight that
# permission error or wait on a chmod -- `emily context build` hydrates the
# same cross-repo context (all Tier 1 golden docs, compiled into
# EMILY/context/full-system-context.md) via pure-CLI extractive summary, no
# secrets file and no ANTHROPIC_API_KEY needed at all. And past that: once
# context is hydrated, the scripts themselves aren't the point -- "we dont
# need the skrips just pay attention the docs will guide us" -- CLAUDE.md
# and BACKLOG.md are the real source of truth a session should be reading
# and following, not any particular wrapper script.
#
# --continue on every invocation, per THE_EMILY_WAY.md Principle 11 ("RSI AGI
# Loop: Always --continue"): a session ended by a dropped connection should
# resume with its prior context intact when re-run, not start blank -- the
# same reason obs-watcher appends --continue to every RSI-cycle invocation.
# Harmless on a genuinely first run (nothing to continue, claude just starts
# fresh).
#
# Run:
#   ./tmux-session.sh [session-name]

set -euo pipefail

SESSION_NAME="${1:-claude}"

cd /home/fatbaby

ONBOARDING='Check the sess file (/home/fatbaby/sess) for the current session id. If you need cross-repo context: run.sh/start.sh both source /home/fatbaby/EMILY/var/emily-secrets.env, which is mode 600 and may not be readable depending on which user this session runs as -- if that (or any other permission error) blocks you, do not fight it, run `emily context build` instead (pure-CLI, no ANTHROPIC_API_KEY needed, writes EMILY/context/full-system-context.md). Then read /home/fatbaby/CLAUDE.md and /home/fatbaby/EMILY/BACKLOG.md in full -- the docs, not any wrapper script, are what should guide the work from here. Follow the Emily Way as you go (Principle 1: backlog first; Principle 18: route founder real-time direction through `emily observe` before acting on it).'

# Already inside tmux (this session or a nested call) -- don't wrap again,
# just do the two-step directly.
if [ -n "${TMUX:-}" ]; then
  emily session new > sess
  exec claude --dangerously-skip-permissions --continue "$ONBOARDING"
fi

if ! command -v tmux >/dev/null 2>&1; then
  echo "tmux-session.sh: tmux not found on PATH -- falling back to a bare (non-survivable) session." >&2
  emily session new > sess
  exec claude --dangerously-skip-permissions --continue "$ONBOARDING"
fi

# Reuse an existing session of this name instead of erroring on collision --
# founder can re-run this after a disconnect and just get reattached.
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
  echo "tmux-session.sh: session '$SESSION_NAME' already exists -- attaching." >&2
  exec tmux attach -t "$SESSION_NAME"
fi

tmux new-session -d -s "$SESSION_NAME" -c /home/fatbaby \
  "emily session new > sess && exec claude --dangerously-skip-permissions --continue \"$ONBOARDING\""

echo "tmux-session.sh: started detached tmux session '$SESSION_NAME'."
echo "Attach with: tmux attach -t $SESSION_NAME"
echo "(Survives a dropped SSH connection -- that's the whole point.)"
exec tmux attach -t "$SESSION_NAME"
