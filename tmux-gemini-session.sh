#!/usr/bin/env bash
# tmux-gemini-session.sh — tmux-wrapped fresh-session entry point for the Gemini CLI.
#
# Founder real-time, 2026-08-30: "copy the prior art of the tmux session launch script" --
# same real reason `tmux-session.sh` exists for `claude`: a bare `gemini` (via `start_gemini.sh`)
# invoked from a plain SSH shell (not tmux, not screen) dies the moment that SSH connection drops
# -- no detached terminal to reattach to, session gone. This is `tmux-session.sh`'s own exact
# survivability pattern (detached tmux session, reattach with `tmux attach`, reuse an existing
# session of the same name instead of erroring on collision), applied to `gemini` instead of
# `claude --dangerously-skip-permissions --continue`.
#
# Real, same-session context this script exists alongside: the Gemini CLI's own auth was just
# fixed (a stale `GOOGLE_GENAI_USE_VERTEXAI=true` in `.bashrc` conflicted with
# `~/.gemini/settings.json`'s own `gemini-api-key` auth mode -- see `.bashrc`'s own updated
# comment) and defaults to `gemini-3.1-pro`, which has zero free-tier quota on the current key --
# `-m gemini-2.5-flash` (confirmed live, has real quota) is passed through by default here rather
# than trusting the CLI's own default routing.
#
# Deliberately mirrors `tmux-session.sh`'s own real scope boundary: this script's only job is
# "get a gemini session running, survivably." It doesn't do any Emily Way orientation (no
# CLAUDE.md/BACKLOG.md onboarding prompt) -- Gemini CLI is a general-purpose coding assistant
# session here, not an Emily Way agent invocation the way `claude` is in `tmux-session.sh`.
#
# Run:
#   ./tmux-gemini-session.sh [session-name] [-- extra gemini args...]

set -euo pipefail

SESSION_NAME="${1:-gemini}"
shift || true
EXTRA_ARGS=("$@")

cd /home/fatbaby

GEMINI_CMD=(gemini -m gemini-2.5-flash "${EXTRA_ARGS[@]}")

# Already inside tmux (this session or a nested call) -- don't wrap again,
# just run gemini directly.
if [ -n "${TMUX:-}" ]; then
  exec "${GEMINI_CMD[@]}"
fi

if ! command -v tmux >/dev/null 2>&1; then
  echo "tmux-gemini-session.sh: tmux not found on PATH -- falling back to a bare (non-survivable) session." >&2
  exec "${GEMINI_CMD[@]}"
fi

if ! command -v gemini >/dev/null 2>&1; then
  echo "tmux-gemini-session.sh: gemini not found on PATH — install via: npm install -g @google/gemini-cli" >&2
  exit 1
fi

# Reuse an existing session of this name instead of erroring on collision --
# founder can re-run this after a disconnect and just get reattached.
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
  echo "tmux-gemini-session.sh: session '$SESSION_NAME' already exists -- attaching." >&2
  exec tmux attach -t "$SESSION_NAME"
fi

tmux new-session -d -s "$SESSION_NAME" -c /home/fatbaby "${GEMINI_CMD[@]}"

echo "tmux-gemini-session.sh: started detached tmux session '$SESSION_NAME'."
echo "Attach with: tmux attach -t $SESSION_NAME"
echo "(Survives a dropped SSH connection -- that's the whole point.)"
exec tmux attach -t "$SESSION_NAME"
