# Collection of Value -- Step 1 findings and Disputes

Written 2026-11-13 from a read-only look at the founder's installed WoW Forever client
(`D:\World of Warcraft`) and at the PARENA / SHANKPIT / PRRJECT_FATBABY checkouts. Governing rule from the
spec: *where a source and the spec disagree the source wins, and the conflict is logged here.* Every fact
below carries one status: **confirmed** (observed on this machine, this session), **retail baseline**
(true of retail WoW as far as the author knows, NOT yet observed on Forever), or **unconfirmed**.

## 0. Ground rules added by the founder (2026-11-13)

### Everything is a REFLUX mod, and REFLUX core is built first

Every Collection addon is a REFLUX mod: it talks to other addons only by dispatching into, and polling,
the shared REFLUX log (`PARENA/stdlib/reflux/reflux.prn`, `cursor.prn`), never by calling another addon
directly. Only a few core pieces are **non-REFLUX core mods** -- the founder's example is colour
correction -- and each one is named as an exception when it is built. REFLUX core therefore gates every
numbered step from 2 on.

Built (PARENA, `make test-reflux-wow`): the `:lua` keys on both REFLUX stdlib files, the WoW host
`PARENA/runtime/wow/reflux_host.lua` (global `RefluxHost`, same 256-row ring and cursor semantics as
SHANKPIT's C host), and `PARENA/scripts/wow-package-refluxcore.sh`, which produces the `RefluxCore` addon
every other addon lists in `## Dependencies:`. Not yet loaded in the real client: that needs
`WOW_INTERFACE` (section 1).

Action-type numbering (COV-REFLUX-IDS, decided 2026-11-13): SHANKPIT holds 1-5, 101-128, 1000-1099 and
1100-1199; the Collection holds **2000-2999**, ten types per addon number 1..100 (addon n owns
2000 + (n-1)*10 .. +9, so Position (26) is 2250-2259). Defined and tested in
`PARENA/stdlib/collection/ids.prn` (PARENA 33411fd); reserved in SHANKPIT's `reflux_runtime.h` (dafa6fc)
so no SHANKPIT family is ever numbered into it. This is an engineering allocation, not a spec fact: the
founder can renumber it freely until the first primitive dispatches (Step 9).

### All configuration is environment-driven

Every machine- or install-specific value the Collection's tooling reads is an environment variable. No
script, Makefile or packager hard-codes a path. Resolution order, highest first:

1. a value already exported in the shell;
2. `MONOREPO/collection.local.env` (git-ignored, one `NAME=value` per line, sourced first);
3. the default written in `MONOREPO/scripts/collection-env.sh` (this machine's layout).

`. scripts/collection-env.sh --print` shows the resolved values. A value that is an **unconfirmed fact**
gets no default at all, and the tool that needs it refuses to run without it. `WOW_INTERFACE` is the
first such value. PARENA's own new targets follow the same rule with `?=` (`LUA51`, `REFLUX_WOW_OUT`).

| Variable | Default here | Used by |
| --- | --- | --- |
| `COLLECTION_WORKSPACE`, `COLLECTION_MONOREPO`, `COLLECTION_TMP` | `D:/WORKSPACE`, `.../MONOREPO`, `.../tmp` | everything |
| `WOW_ROOT`, `WOW_CLIENT_DIR`, `WOW_ADDONS_DIR`, `WOW_WTF_DIR` | `D:/World of Warcraft`, `.../_forever_`, `.../Interface/AddOns`, `.../WTF` | packagers, installer, the SavedVariables reader |
| `WOW_LOCALES` | the 12 spec locales | i18n check |
| `WOW_INTERFACE` | **none** -- from the in-game probe | every `.toc` |
| `MSYS2_ROOT`, `MSYSTEM` | `C:/msys64`, `UCRT64` | C toolchain |
| `PARENA_DIR`, `PARENA_BIN` | `.../PARENA`, `.../.parena-bootstrap` | every build |
| `LUA51`, `REFLUXCORE_OUT` | `lua5.1`, `$PARENA_DIR/build/wow` | REFLUX tests, RefluxCore packager |
| `COLLECTION_JOURNAL_ADDON`, `COLLECTION_JOURNAL_VAR` | `CollectionJournal`, `CollectionJournalDB` | the journal addon and the SavedVariables reader |
| `COLLECTION_EVENTS` | `$COLLECTION_WORKSPACE/data/collection/events.ndjson` -- outside every repo (D-8) | the SavedVariables reader |
| `COLLECTION_JOURNAL_KEEP`, `COLLECTION_JOURNAL_POLL_SECONDS` | `20000` rows, `5` s | the packaged journal addon |
| `FAFNIR_ADDON`, `FAFNIR_VAR` | `FafnirsBed`, `FafnirsBedDB` | Fafnir's Bed (inventory manager) |
| `COLLECTION_CLIENT_OUT` | `$PARENA_DIR/build/wow/client` | `PARENA/scripts/wow-package-collection.sh` |

### The client, and how it ships

`PARENA/scripts/wow-package-collection.sh [--zip] [--install]` builds the client in one folder:

* `AddOns/RefluxCore`
* `AddOns/CollectionJournal` (`/cov`)
* `AddOns/FafnirsBed`, **Fafnir's Bed**, the inventory manager (spec addon 2, named from the spec's own
  list). `/fafnir` gives net inventory and account gold; `/fafnir <name|id|link>` gives who has an item and
  its net count.
* `reader/read-journal.sh`

PARENA CI (`collection_client` job) runs every test on each push, including the packaged addons played end
to end in a stubbed client. On a green push to `main`, the existing auto-release attaches
`CollectionOfValue-<sha>.zip`, **once the repository variable `WOW_INTERFACE` is set**. Until then CI
annotates the run that the zip was skipped, rather than shipping a guessed interface number.
| `COLLECTION_SSH_KEY`, `GIT_SSH_COMMAND` | `~/.ssh/id_ed25519_shankpit` | git over SSH |

## 1. Step 1 -- the WoW Forever addon API

### Confirmed (observed)

| Fact | Value | Where it came from |
| --- | --- | --- |
| Client product code | `wowf` | `.build.info`, `Product` column |
| Client version | `1.60.1.70938` | `.build.info` `Version`, and the file version of `_forever_\Wow.exe` |
| Branch / region | `us` | `.build.info` |
| Game files layout | game data lives in CASC (`Data\`); the running client root is `_forever_\` | directory listing |
| Shipped UI is retail-lineage | `Blizzard_SettingsDefinitions_Shared`, `Blizzard_GamepadSmartNavigation`, `Blizzard_SavedSets`, `Blizzard_AuctionHouseUI`, edit-mode and TTS caches all appear in `WTF` | file names under `_forever_\WTF` |
| SavedVariables location (account) | `_forever_\WTF\Account\SavedVariables\<Addon>.lua` (plus a `.bak` of each) | directory listing |
| SavedVariables location (per account number) | `_forever_\WTF\Account\<account#>\SavedVariables\` | directory listing |
| Macro storage | `_forever_\WTF\Account\<account#>\macros-cache.txt`, with a `.old` backup | directory listing |
| `macros-cache.txt` shape | one entry = a header line (`<kind> <n> <16-hex id> "<name>" "<icon id>"`), the macro body lines, then a line `END` | structure of the founder's current file (2 macros); bodies not recorded here |
| Third-party addon folder | `_forever_\Interface\AddOns` exists and is currently empty | directory listing |

### Not observable from disk -- needs one in-game probe

The interface (TOC) number and the macro limits are produced by the running client, not stored in files this
session can read (Blizzard's own UI is inside CASC; `AddOns` is empty so there is no `.toc` to copy).
Run this once in game, in the chat box, and paste the output back:

```
/run local v,b,d,t=GetBuildInfo() print("build",v,b,d,"toc",t) print("macros",MAX_ACCOUNT_MACROS,MAX_CHARACTER_MACROS) print("C_AddOns",C_AddOns and "yes" or "no") print("locale",GetLocale())
```

| Fact | Retail baseline (UNCONFIRMED on Forever) | Why it matters |
| --- | --- | --- |
| TOC `## Interface:` number | a retail-style 6-digit number; the real value is the 4th value printed by the probe | every shipped `.toc` must declare it or the client marks the addon out of date |
| Account macro slots | 120 (`MAX_ACCOUNT_MACROS`) | MacroSync's load target and prune rule |
| Per-character macro slots | 18 (`MAX_CHARACTER_MACROS`) | same |
| Macro body length | 255 characters | the Macau editor's hard cap and the packager's check |
| Addon metadata API | `C_AddOns.GetAddOnMetadata` (the retail replacement for the global) | which call the loader uses |
| SavedVariables flush | written on logout and on `/reload`, never while playing | defines the latency of the whole event-stream bridge (spec Step 6) |
| Addons have no network | true of retail's Lua sandbox | confirms why the bridge is "SavedVariables out, external reader in" |
| Locale API | `GetLocale()` returns one of the 12 spec locales | the spec's localisation rule depends on it |

Nothing in the table above may be built against until the probe has been run. The Collection's own
instruction was the same: *never guess past a Confirm.*

### What this changes in the spec's plan

* The client is a **retail-lineage** build, not a Classic one. Interface number, macro limits and the
  `C_AddOns` namespace should therefore be expected to follow retail until the probe says otherwise.
  The spec's own phrase "classic-mode walkthrough" describes the guides' playstyle, not the client's API.
* Because SavedVariables is written per account and per character folder, the bridge reader (Step 6) must
  key on `<account#>` and character, and must tolerate the `.bak` file existing next to each `.lua`.
* The macro list can be loaded **either** by an addon calling `CreateMacro`/`EditMacro` **or** by writing
  `macros-cache.txt` offline. The spec chooses the first (`/ascend`). The second is mentioned only because
  the file format is now documented above; it is not recommended (the client rewrites that file).

## 2. Disputes

Format: what the spec says, what the source says, the resolution.

### D-1  The spec says PARENA has no Lua backend. It has one.

* **Spec (Dependency plan, step 2):** "PARENA currently targets C, LLVM, WASM, TypeScript and Java, but not
  Lua." Status **Missing**.
* **Source:** `PARENA/src/emit_lua.c` (505 lines), the `.lua` output route in `parena build`, and
  `make test-emit-lua` (43 passed, 0 failed on 2026-11-13). It already generates the Luau modules NOOBTOPIA
  and SHANKPIT's rules share (`stdlib/shankpit/*_rules.prn`).
* **Resolution (source wins):** step 2 is re-scoped from "build a Lua backend" to "extend the existing one to
  what MacroSync needs". Its v0 limit is real and was hit while testing step 0: it accepts only numbers,
  strings, symbols, binary operators, `if`, `not`, `and` and calls, and refuses `defn` parameters that carry
  `Arena`/region annotations. Addons that need tables, loops or WoW API globals are the remaining work.

### D-2  The spec says the event store is "JSONL ... from PRRJECT_FATBABY". It is a sequenced Go store.

* **Spec (step 7):** "the JSONL append-only store from the PRRJECT_FATBABY port".
* **Source:** `PRRJECT_FATBABY/eventstore/` -- `Event{ID, Type, Source, OccurredAt, IngestedAt, PartitionKey,
  Identity, Data, Metadata}`, `Record{Sequence, Event, AppendedAt}`, and an `EventStore` interface with
  `Append`, `ReadFrom`, `Scan`, `LatestSequence`; a PARENA seqlock already exists
  (`PARENA/stdlib/eventstore/seqlock.prn`).
* **Resolution:** keep the append-only journal and the monotonic `Sequence`, as the spec intends. The spec's
  event record (ID, type, character, time, zone, coordinates, payload) maps onto the Go envelope as
  `Data` (zone/coordinates/character) with `Source` = the primitive's id. Step 5's schema should be defined
  as that mapping, versioned, before any primitive is written. Not yet decided: whether character/zone move
  into first-class fields.

### D-3  "marketcal ported to PARENA" -- the Go original is a US stock-market calendar, not a WoW calendar.

* **Spec (addon 99, step 8):** "Market Calendar: marketcal ported to PARENA: reset times, events and patch
  dates lined up with price history."
* **Source:** `PRRJECT_FATBABY/internal/marketcal/marketcal.go` answers *"is the NYSE open"* (weekend and
  NYSE-holiday rules, Good Friday via the Meeus/Jones/Butcher Easter algorithm). It has no notion of WoW
  weekly resets, events or patches.
* **Resolution:** the port is still worth doing (the date arithmetic is reusable and the spec says the Go
  code is ground truth), but addon 99's WoW-specific content (reset times, events, patch dates) is **new
  work, not a port** and needs its own data source. Treat the two as separate items.

### D-4  "Wotan ... brought back online on Vultr" -- the repo it would deploy is a placeholder.

* **Spec:** the Wotan hub is a full CurseForge-class site; Wotan and Iduna come back online on Vultr.
* **Source:** the monorepo `CLAUDE.md` describes `WOTAN` as a static HTML/CSS placeholder split out of
  `OKEMILY/tournaments.html` and "not deployed"; IDUNA is documented as running in GKE (namespace `emily`),
  with a `wotan-deploy.sh` at the monorepo root.
* **Resolution:** step 13 stays a stub as the spec says, but "back online" overstates the starting point for
  Wotan. Also note IDUNA's recorded home is GKE, so "IDUNA on Vultr" is a **migration decision**, not a
  restart. Needs the founder's call before step 13.

### D-5  Name collision: "wow-wire" in SHANKPIT is not the WoW client's wire.

* **Source:** `PARENA/stdlib/shankpit/wow_wire.prn` is SHANKPIT's own macro/mod network policy (target
  slots, cast queue, ack timing) for SHANKPIT's game, not anything about World of Warcraft's macros.
* **Resolution:** no action beyond a warning: a search for "wow macro" in the repos lands on SHANKPIT's file
  first. The Collection's macro limits come from the probe above, not from that file. Its `wow-macro-max-clauses`
  of 4 is a SHANKPIT cap and must not be read as WoW's.

### D-6  The spec says the PARENA tree to use is a "clean-room rewrite or the existing one". Resolved.

* **Source:** PARENA is one live repository with the compiler in `src/`; `BURROW` is a separate Go rewrite
  and is not the target of any step here.
* **Resolution:** step 0 was built in the existing `PARENA/src` (commit `8c54369`).

### D-7  Spec inconsistency: the roadmap says 100 addons but Step 9's primitives list names 7 of them.

* **Spec:** "Primitives (addons 23 to 29, 49, 74)" plus the kickoff's build order "Position (26), Quest
  Offer (23), Quest Turn-in (24), Loot (25), Mail Ledger (51), AH Scan (74), then the rest."
* **Source:** the spec itself. Mail Ledger (51) is in the kickoff order but not in the "23 to 29, 49, 74"
  range, and Comms Primitive (49) is in the range but not in the kickoff order.
* **Resolution (pending):** treated as one primitive set of 9: 23-29, 49, 51, 74 -> that is ten once 51 is
  added. Needs the founder to confirm the intended set before step 9. Not guessed.

### D-8  Spec states a data rule that the comms addons make easy to break.

* **Spec:** "comms data stays local and private to Emily. Other players' messages ... are never published
  or shared."
* **Source:** the same spec lists the Wotan hub's "one-click install" and a public registry; the event
  stream is also what "Jon Stockwell reads outside the game".
* **Resolution:** not a conflict yet, a constraint to enforce: the Comms Primitive (49) and Comms Timeline
  (50) must write to a stream partition that no publish, upload or registry step can read. Record this as an
  acceptance test when step 9 starts.

### D-9  "PARENA has a Lua backend" (D-1) -- but its output could not load in WoW.

* **Source:** `PARENA/src/emit_lua.c` was written for Luau (Roblox, NOOBTOPIA). Its `/` helper used `//`,
  which Luau and Lua 5.3+ accept and Lua 5.1 -- WoW's dialect -- rejects as a syntax error, so every
  emitted module would have failed to load in the client. Its tests never ran a Lua 5.1 interpreter.
* **Resolution:** fixed in PARENA (`math.floor`, same result for I32), and `make test-reflux-wow` now runs
  emitted modules under a real Lua 5.1. Step 2's "extend the Lua backend" includes keeping that test
  green: anything emitted must load in 5.1.

## 3. Status of the numbered steps (2026-11-13)

| Step | Status |
| --- | --- |
| 0 Translation core module | **Built**, `PARENA` commit `8c54369`. `make test-i18n` 44/44. Placeholder strings are extracted and checked but not yet lowerable |
| REFLUX core (gates 2+) | **Built** for WoW: host, `:lua` stdlib keys, RefluxCore packager; 37/37 + 5/5 under Lua 5.1. Not loaded in the client yet (needs `WOW_INTERFACE`) |
| 1 WoW Forever addon API | **Partly confirmed** (table above). Interface number and macro limits need the in-game probe |
| 2 PARENA Lua backend | **Extended** (PARENA 3d4c666, e3e92fa): `lua/` bridge to WoW globals/tables/methods, escaped strings, `do`, `lua/set!`/`lua/aset!`; all executed under Lua 5.1. Not yet: event handlers (a defn as a callback), `while`/`loop` (recursion works) |
| 3 LO front end | Open. The LO grammar and emoji set are a spec "Confirm" -- `LO/` holds only a NORTHSTAR and a captured design doc |
| 4 In-game REFLUX library | **Built** = RefluxCore (section 0) |
| 5 Event record | **v1 defined** in `PARENA/stdlib/collection/journal.prn`, mapped onto the Go envelope (D-2) |
| 6 SavedVariables bridge | **Both halves built, neither run against the real client.** In game (PARENA 76a5d50, 11e57a0; 53/53 under Lua 5.1): REFLUX poll -> per-character journal, overwritten rows counted in `lost`, a size cap (`journal-trim`) that drops from the low end and never moves `nextSeq`. Outside (PARENA 7f95946, `scripts/collection-journal-read.sh`, 38/38 + wrapper check): reads every `Account/*/*/*/SavedVariables/CollectionJournal.lua` with no globals and an instruction budget, appends new rows to `COLLECTION_EVENTS` as eventstore `Event` lines (checked to unmarshal into the Go struct), dedups on `character:seq`, reports trimmed-before-read gaps (exit 3). Not yet: the addon glue and `.toc` (need the probe); feeding the NDJSON into the Go store's `Append` (Step 7) |
| Addon 2 Unified Inventory | **Built as Fafnir's Bed** (PARENA f32974c model, 1a4e173 client; client_test 36/36 under Lua 5.1): bags, bank, mail, gold, net inventory, who-has-this; changes dispatched as REFLUX 2010-2012 and journalled. Not yet run in the real client (needs the probe) |
| Client + CI | **Built** (PARENA 1a4e173, 1daf0ba): one package, tested on every push, attached to each auto-release once `WOW_INTERFACE` is set as a repository variable. PARENA CI was red (Windows self-hosting step, winnt.h `TokenType`) and no release had been cut since 2026-10-02; fixed in a70bf8a |
| 7-14 | Not started |
