#!/usr/bin/env bash
# Syncs OKEMILY repo content to the live site. Nothing else.
#
# blog/ is EXCLUDED on purpose: it's rendered live by IDUNA's blog handler
# (internal/blog/render.go) straight into /var/www/okemily/blog, and isn't
# part of this git repo at all. A bare `--delete` sync without this
# exclusion wipes every published post the instant this script runs --
# happened for real 2026-07-19, recovered only because the SQLite source of
# truth (IDUNA's var/blog.db) was untouched and could be re-rendered
# (cmd/blog-rerender). Do not remove this exclusion.
#
# tyler/ is EXCLUDED for the identical reason (added 2026-08-06): it's
# rendered live by IDUNA's tyler handler (internal/tyler/render.go) straight
# into /var/www/okemily/tyler, source of truth is IDUNA's var/tyler.db, not
# this repo. Same failure mode as blog/ if this exclusion is ever removed.
#
# blog-manifest.txt is EXCLUDED for the identical reason (added 2026-08-14,
# same session that added it -- found live, the hard way, immediately after
# generating it for the first time): rendered by IDUNA's blog handler
# (internal/blog/render.go's RenderManifest) straight into
# /var/www/okemily/blog-manifest.txt, at the site ROOT rather than under
# blog/, so it wasn't covered by that exclusion either. Source of truth is
# the same var/blog.db as blog/ -- re-render via cmd/blog-rerender if this
# is ever lost the same way blog/ was on 2026-07-19.
#
# prompt-o-verse/ is EXCLUDED for the identical reason (added 2026-08-17):
# rendered live by IDUNA's promptoverse handler (internal/promptoverse/
# render.go) straight into /var/www/okemily/prompt-o-verse, source of truth
# is IDUNA's var/promptoverse.db (+ the generated image files themselves,
# which only exist on disk, not in git). Same failure mode as blog/tyler if
# this exclusion is ever removed.
#
# battlegrounds/ is EXCLUDED for the identical reason (added 2026-08-20):
# the real GFD Battlegrounds WASM build output (~1MB of generated .js/.wasm
# binaries), source of truth is GoblinFoxDragon/apps2/battlegrounds_gui/
# wasm/ (build_wasm.sh), not this repo -- same failure mode as blog/tyler/
# prompt-o-verse if this exclusion is ever removed. Redeploy by copying
# that directory's build output straight into /var/www/okemily/battlegrounds/
# after running build_wasm.sh, same as the others' own render step.
set -euo pipefail
mkdir -p /var/www/okemily
rsync -a --delete /home/fatbaby/OKEMILY/ /var/www/okemily/ --exclude='.git' --exclude='blog' --exclude='tyler' --exclude='blog-manifest.txt' --exclude='prompt-o-verse' --exclude='battlegrounds'
