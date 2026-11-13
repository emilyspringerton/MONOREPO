#!/usr/bin/env bash
# collection-env.sh -- every machine-specific path the Collection of Value work touches, as an
# environment variable. Source it:   . scripts/collection-env.sh
#
# Every variable below honours a value you already exported; the text after ":-" is only the default
# for THIS machine. Nothing else in the Collection's tooling should hard-code a path -- read these.
# Put overrides in ./collection.local.env (git-ignored, sourced first) or export them in your shell.

_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$_here/../collection.local.env" ] && . "$_here/../collection.local.env"

# --- where things live ----------------------------------------------------------------------------
export COLLECTION_WORKSPACE="${COLLECTION_WORKSPACE:-D:/WORKSPACE}"
export COLLECTION_MONOREPO="${COLLECTION_MONOREPO:-$COLLECTION_WORKSPACE/MONOREPO}"
export COLLECTION_TMP="${COLLECTION_TMP:-$COLLECTION_WORKSPACE/tmp}"

# --- the WoW Forever client (read by the probe, the packager and MacroSync's installer) ------------
export WOW_ROOT="${WOW_ROOT:-D:/World of Warcraft}"
export WOW_CLIENT_DIR="${WOW_CLIENT_DIR:-$WOW_ROOT/_forever_}"
export WOW_ADDONS_DIR="${WOW_ADDONS_DIR:-$WOW_CLIENT_DIR/Interface/AddOns}"
export WOW_WTF_DIR="${WOW_WTF_DIR:-$WOW_CLIENT_DIR/WTF}"
# The 12 client locales the localisation rule requires (space separated, in the spec's order).
export WOW_LOCALES="${WOW_LOCALES:-enUS enGB deDE esES esMX frFR itIT ptBR ruRU koKR zhCN zhTW}"
# The client's TOC interface number. Deliberately NO default: it is unconfirmed for WoW Forever, and every
# packager refuses to build without it. Get it in game with  /run print(select(4, GetBuildInfo()))
# and put  WOW_INTERFACE=<number>  in collection.local.env.
if [ -n "${WOW_INTERFACE:-}" ]; then export WOW_INTERFACE; fi

# --- toolchain ------------------------------------------------------------------------------------
export MSYS2_ROOT="${MSYS2_ROOT:-C:/msys64}"
export MSYSTEM="${MSYSTEM:-UCRT64}"
export PARENA_DIR="${PARENA_DIR:-$COLLECTION_MONOREPO/PARENA}"
# The compiler driver. On Windows without SDL2 headers the full `parena` does not link, so this
# defaults to the bootstrap stage; point it at ./parena once that builds.
export PARENA_BIN="${PARENA_BIN:-$PARENA_DIR/.parena-bootstrap}"
# Lua 5.1 -- WoW's dialect -- for the REFLUX/addon tests (MSYS2 package mingw-w64-ucrt-x86_64-lua51).
export LUA51="${LUA51:-lua5.1}"
# Where `scripts/wow-package-refluxcore.sh` builds the RefluxCore addon folder.
export REFLUXCORE_OUT="${REFLUXCORE_OUT:-$PARENA_DIR/build/wow}"
# The SavedVariables journal (Step 6): the in-game addon's folder and global, and the event file the
# external reader (PARENA/scripts/collection-journal-read.sh) appends to. The event file holds the
# founder's own play data, so its default is OUTSIDE every repository (Disputes D-8: stays local).
export COLLECTION_JOURNAL_ADDON="${COLLECTION_JOURNAL_ADDON:-CollectionJournal}"
export COLLECTION_JOURNAL_VAR="${COLLECTION_JOURNAL_VAR:-CollectionJournalDB}"
export COLLECTION_EVENTS="${COLLECTION_EVENTS:-$COLLECTION_WORKSPACE/data/collection/events.ndjson}"
# The Collection event store (Step 7, PARENA/scripts/collection-store-ingest.sh): on-disk compatible with
# PRRJECT_FATBABY's Go eventstore. Play data, so outside every repository (D-8).
export COLLECTION_STORE="${COLLECTION_STORE:-$COLLECTION_WORKSPACE/data/collection/store}"
# Only the optional Go compatibility check reads this.
export PRRJECT_FATBABY_DIR="${PRRJECT_FATBABY_DIR:-$COLLECTION_MONOREPO/PRRJECT_FATBABY}"
# The packaged client (PARENA/scripts/wow-package-collection.sh): journal cap and poll interval, and Fafnir's
# Bed (the inventory manager, spec addon 2): its addon folder and account-wide SavedVariables global.
export COLLECTION_JOURNAL_KEEP="${COLLECTION_JOURNAL_KEEP:-20000}"
export COLLECTION_JOURNAL_POLL_SECONDS="${COLLECTION_JOURNAL_POLL_SECONDS:-5}"
export FAFNIR_ADDON="${FAFNIR_ADDON:-FafnirsBed}"
export FAFNIR_VAR="${FAFNIR_VAR:-FafnirsBedDB}"
export COLLECTION_CLIENT_OUT="${COLLECTION_CLIENT_OUT:-$PARENA_DIR/build/wow/client}"

# --- git over SSH ---------------------------------------------------------------------------------
export COLLECTION_SSH_KEY="${COLLECTION_SSH_KEY:-$HOME/.ssh/id_ed25519_shankpit}"
export GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -i $COLLECTION_SSH_KEY -o IdentitiesOnly=yes}"

# --- make the C toolchain usable from a plain shell -----------------------------------------------
mkdir -p "$COLLECTION_TMP" 2>/dev/null
if command -v cygpath >/dev/null 2>&1; then _t="$(cygpath -u "$COLLECTION_TMP")"; else _t="$COLLECTION_TMP"; fi
export TMP="$_t" TEMP="$_t" TMPDIR="$_t"
unset _t
# Only add the MSYS2 toolchain when gcc is not already reachable (e.g. from Git Bash or PowerShell).
# Inside MSYS2 itself cygpath maps C:/msys64 to "/", and "/"+"/ucrt64/bin" would be "//ucrt64/bin" --
# a UNC network path that silently broke every gcc call. Strip the trailing slash.
if ! command -v gcc >/dev/null 2>&1; then
  if command -v cygpath >/dev/null 2>&1; then _m="$(cygpath -u "$MSYS2_ROOT")"; else _m="$MSYS2_ROOT"; fi
  _m="${_m%/}"
  export PATH="$_m/ucrt64/bin:$_m/usr/bin:$PATH"
fi
unset _here _m

# `. collection-env.sh --print` shows the resolved values.
if [ "${1:-}" = "--print" ]; then
  env | grep -E '^(COLLECTION_|WOW_|MSYS2_|MSYSTEM|PARENA_|LUA51|REFLUXCORE_|FAFNIR_|PRRJECT_)' | sort
  [ -n "${WOW_INTERFACE:-}" ] || echo "WOW_INTERFACE is unset (packagers will refuse; run the in-game probe)"
fi
