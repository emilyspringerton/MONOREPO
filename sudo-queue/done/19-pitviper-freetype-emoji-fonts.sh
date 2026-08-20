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
#
# Also installs JetBrains Mono (real, open, SIL OFL 1.1-licensed monospace
# -- already named as the intended embedded font in PITVIPER/CLAUDE.md's
# own Stack section, not a new pick) for the F11/F12 "shiny font" toggle,
# founder real-time: "can you please find the nicest monospace public
# domain font you can and add it on a toggle like f11 or f12" -> "keep the
# og font for now" -> "and the toggle switches to the new shiny font".
sudo apt-get update
sudo apt-get install -y libsdl2-ttf-dev fonts-noto-color-emoji fonts-jetbrains-mono
