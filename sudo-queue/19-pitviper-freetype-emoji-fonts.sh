#!/usr/bin/env bash
# Installs the real, color-capable text-rendering stack PITVIPER needs to
# render emoji: SDL2_ttf (font rendering, FreeType underneath, color-glyph
# support in the 2.20+ series this repo's own libsdl2-ttf-dev candidate is)
# plus a real color emoji font (Noto Color Emoji). Founder, real-time:
# "build all emojis into pitviper" -> AskUserQuestion confirmed "load a
# real color emoji font" over a small hand-drawn monochrome subset.
# PITVIPER's own font system today (internal/font/font.go) is a
# procedurally-drawn monochrome bitmap atlas with no path to color glyphs
# at all -- this is real prerequisite infrastructure for the code change
# that follows, not optional polish. EMILY/BACKLOG.md S189-18.
set -euo pipefail
sudo apt-get update
sudo apt-get install -y libsdl2-ttf-dev fonts-noto-color-emoji
