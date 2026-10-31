# NAMED_NOT_DONE.md — every gap the 2026-10-30/31 session named, and its status

**Status:** opened 2026-10-31. Source: `var/freebuff/freebuff-chat-2026-10-30T22-11-21.091Z.md`
(150k lines, 141 messages, the whole previous session). Every item below is quoted or paraphrased
from that session's own "Not done", "Named limitations", "Limits" and "Still open" sections — the
places where work was *claimed* complete but a deliberate slice was left.

This doc exists because those sections are spread across ~25 turns of one enormous transcript, and
a named gap that nobody re-reads is just an unknown gap.

## How to read this

- **A gap is closed when a check runs**, not when code is written. This box has `gcc`, `make`,
  `python3` and `node`; it has **no Go, no Lua, no bazel, no SDL2 headers and no GPU/display**.
  Anything that needs those stays open by definition and is labelled so.
- Items are grouped by subsystem, not by the order they were found.
- `docs/ENVIRONMENT_BOOTSTRAP.md` covers getting the box to a state where more of this is
  verifiable — several gaps below are closed *only* by having a toolchain.

---

## 1. What is verifiable on this box

| Tool | Present | Consequence |
|---|---|---|
| `gcc`, `make` | yes | SHANKPIT's 21 `test-*` targets are real checks (`make test-empire-rules`, `test-lofts`, …) |
| `python3` | yes | `tools/local_nock.py`, `scripts/bake_levels.py`, NOCK store/validate paths |
| `node` | yes | `node --check` on the editor's scripts and any JS module; no browser |
| SDL2 headers | **no** | `make lobby` cannot even compile — every client/render claim is reviewable only |
| GPU / display | **no** | nothing visual is ever "seen"; visual claims are rules claims |
| `go` | **no** | IDUNA, `emily.cli`, `emily-agent`, `IDUNA.GAME`, PITVIPER unbuildable |
| `lua` / `luajit` | **no** | NOOBTOPIA's Luau modules and generated Lua never execute; only the C emitted from the same `.prn` runs |
| `bazel` | **no** | PARENA/SHANKPIT/BIG_O Bazel targets unbuildable; `make` is the substitute |
| `kubectl` | no | IDUNA is unreachable without the `BOOTSTRAP.md` port-forward |

---

## 2. The gaps, by subsystem

Legend: **[C]** closable and checkable here · **[T]** needs a toolchain this box lacks ·
**[V]** needs eyes on a display.

### 2.1 Netcode / replication — the largest real cluster

| # | Gap | Flags |
|---|---|---|
| N1 | **No kit-call packet.** Gadget keys are local/sandbox only and do nothing in `STATE_GAME_NET`, where the server owns spawning. | [C] |
| N2 | **Drones are not replicated in snapshots** to remote clients (aircraft exist locally only). | [C] |
| N3 | **No zone packet.** A LAN friend cannot join a procedural zone — the seed is host-local, so co-op is the local half only. Phase 2 of `docs/GFD_UNIFICATION.md`. | [C] |
| N4 | **Imported skins don't replicate** — a coop peer sees the server's `forced_kit` or the usual heuristic. | [C] |
| N5 | **Claims and stockpiles are per-host**; EMPIRE territory does not replicate (nodes/claims themselves are level-authored now). | [C] |
| N6 | **Net clients draw no projectiles at all** — pre-existing: projectiles aren't on the wire, so a networked grenade is server-side only. | [C] |
| N7 | **No burning-car fire state on the wire** — the hull and blast are the local sim's. | [C] |

### 2.2 Gameplay systems

| # | Gap | Flags |
|---|---|---|
| G1 | **No job is applied to a live match.** The stat bridge exists and is tested, but no call site reads it — a player is 100 HP and stock ROF whatever a save says. | [C] |
| ~~G2~~ | ~~**Allies don't spend or earn EMPIRE influence** on spawn, or when banking gathered resources.~~ — **closed 2026-10-31** at three seams: the rule is in PARENA (`empire-bank-credit`, tested), the hand-in is `story_ai_bank_handins` (verified by a real server link), and the lobby credits it. The lobby line itself was never compiled here — see §4. | [C] |
| ~~G3~~ | ~~**No wave spawner** that emits authored archetypes on a timer.~~ — **scheduler shipped 2026-10-31** (`wave_rules.prn` + `wave_spawner.h` + `story_ai_waves_tick`, 64 checks); the host's arming call is still unwritten. See §4. | [C] |
| ~~G4~~ | ~~**No downed-and-revived state** — allies die outright instead of being rescuable.~~ — **shipped 2026-10-31**: bleed-out window, revive hold and partial restore in PARENA; the respawn is held by `story_ai_downed_tick`, allies only. See §4. | [C] |
| G5 | **Nothing persists** — a character's job/level doesn't survive a restart; a dungeon's difficulty tier is generated but not fed into any stat curve. | [C] |
| G6 | **Tech tree is one node with a flat XP ratio** (500/point, no curve), and the bonus is in-process only, so a server-authoritative match wouldn't see levels. | [C] |
| G7 | **No server authority or persistence for the kit** — `BP_FX_KIT_*` is the single hook a networked kit would use. | [C] |
| G8 | **No cargo bay / rear ramp / airborne spawn / cargo drops** on the aircraft: an interior `Level` travelling inside a moving hull was refused rather than faked. | [C] (logic) |

### 2.3 Animation

| # | Gap | Flags |
|---|---|---|
| A1 | **Nothing draws from the thirteen-clip contract.** The player body is still `compute_player_anim_pose`; `anim_state_for_player` isn't in `main.c`; the NPC kit loader still takes four clip names. | [T] (lobby must compile) |
| A2 | **No Mixamo importer** — the contract is import-*into*, not a converter. | [C] |
| A3 | Sampled channels have never been run through forward kinematics into a skinned draw. | [V] |
| A4 | A body is **a story-AI slot, not a loyal soldier** — placement is real, allegiance isn't. | [C] |

### 2.4 Renderer / materials — almost all unverifiable here

| # | Gap | Flags |
|---|---|---|
| R1 | **Mirror material exists as a draw function but nothing selects it** — `draw_material_mirror_box` waits for a material kind. Sphere map means no parallax and no true reflection. | [C] for the material kind (level data); [V] for the GL path |
| R2 | **No probe bake, no UV-offset draw path, no palette shader, no tint quad wiring** for the Doom/Quake/HL/GTA material vocabulary. | [V] |
| R3 | **A lightning flash doesn't push exposure/bleed**; the litbox shader still takes cone/uniform values rather than a per-pixel environment term. | [V] |
| R4 | **Bedrock Racers' stadium is in no scene** — mesh built, nothing loads or draws it, no car clamped to it, no collision response, no goal shafts in the SDF, no faceted OBB destruction shell. | [C] load+clamp / [V] draw |
| R5 | **Nothing draws water** (buoyancy numbers only); no boat entity; an impact isn't routed through the structure graph. | [V] / [C] |
| R6 | **Widgets draw nothing** — no prompt quad, no panel, no lever or centrifuge mesh (the circuit itself is in the level loop now). | [V] |

### 2.5 Editor / authoring (NOCK + local_nock)

| # | Gap | Flags |
|---|---|---|
| E1 | **No NOCK placement UI for EMPIRE resource nodes or claim cells** — schema, loader, serializer and both hosts are done, so authoring them means hand-editing JSON. | [C] |
| E2 | **local_nock can't edit the recursive lofts tree** — `LevelStore` is flat and `validate_level` requires `walls`, so sub-levels and `objects` are files plus a builder run; there's no object *placement* tool either. | [C] |
| E3 | **The material list can't author mirrors** (see R1). | [C] |
| E4 | **The NPC kit dropdown doesn't list imported skin sets** — an NPC's number is typed by hand from the startup log. | [C] |
| E5 | **No wiring UI for the circuit** — pins are a table of indexes in JSON. | [C] |
| E6 | **No port picker for the NOCK tile** — it always uses 8787. | [C] |
| E7 | **Windows has no bundled `dw_nock.exe`**, so the tile honestly reports "not found" there. | [T] (mingw) |

### 2.6 World / content

| # | Gap | Flags |
|---|---|---|
| ~~W1~~ | ~~**Upper floors get one zombie each regardless of floor size**~~ — **closed 2026-10-31**: a storey's own deck area now decides who earns a second body (`DECK_AREA_PER_ZOMBIE`, largest decks first until the 69-slot budget is spent), and `--check` asserts it. See §4. | [C] |
| W2 | **A themed interior repeats on every storey** — a six-floor cafe is a cafe on all six, never thinning upstairs. | [C] |
| W3 | **No district simulation**, so the EMPIRE minimap honestly shows only the block you stand on. | [C] |
| W4 | **The live "nextown" level comes from the zombies registry** when online, so a connected run serves the registry's copy until it's re-exported. | [C] |
| W5 | **`strength` is linear in remaining volume** — under-rates a hollow tube, over-rates a piece whose base alone was shot out; a weakest-cross-section model needs per-layer bookkeeping that doesn't exist. | [C] |
| W6 | **Unmodelled structural physics**: shear flow, buckling shape (a pillar holds or fails, it doesn't bow), fatigue, per-cell stress. A dropped slab is one rigid body — no re-fracture on landing, no piling. | [C] |
| W7 | **Stage 2's gameplay half**: a detached piece should remove its structure-graph node and re-evaluate; the graph is built and proven headless but nothing calls it from `brick_world.h`. | [C] |
| W8 | **No gossip-conditioned-on-witness ambient lines, no shared wander targets** in NOOBTOPIA. | [C] |

### 2.7 Infra / CI

| # | Gap | Flags |
|---|---|---|
| I1 | **`go_os_app`'s skip path was never executed** — no Go toolchain, so both the success and failure paths are reviewed, not run. | [T] |
| I2 | **PITVIPER's and IDUNA.GAME's Go modules aren't vendored**, so a release build still needs the network — bounded now, not eliminated. | [T] |
| I3 | **DEADWEIGHT's `GUI_SRC` is a hand-copy** in the release workflow; it has drifted nine times and is the highest-probability future red build. | [C] |
| I4 | **No CI job that builds the OS apps alone** with a small budget, so a module problem holds the whole release. | [C] |
| I5 | **The lobby's APPS page shows a generic "not found"** instead of why an app is missing (not bundled vs. failed to build). | [C] |
| I6 | **A hosted world's server outlives the lobby** (child process) — named as a policy needing a founder call, not a bug. | [C], needs a decision |
| I7 | **`-Wall -Wextra` noise in the lobby** (unused params, `-Wmisleading-indentation`, a `/*` inside a comment, signed/unsigned compare) — invisible in the release build. | [T] (needs SDL2 to compile) |

### 2.8 Deliberately deferred by the founder — do not "fix" without direction

- **Getting NOOBTOPIA into a live Roblox place** — "we'll figure out how to get it into ROBLOX later".
- **A 3-line LocalScript** on the Roblox side firing the `Punch` RemoteEvent; the host warns loudly
  when it's missing rather than failing quiet.
- **Payment processing** in EDGE.GAME (`Stripe`/`Square`/`Tap-to-Pay`) — real money, gated on an
  explicit go-ahead.
- **True planar/cube reflections** — an extra scene render per frame the target can't pay.
- **BR's strafe/attitude jets and wall-driving** — there are no axes for them here.
- **The duplicate trees `apps2/` + `packages2/`** — left alone on purpose.

### 2.9 Closed later in the same session (do not redo)

Recorded so nobody rebuilds them: the widget circuit **is** in the level loop; LAN world **discovery**
shipped; the VEHICLE gadget set closed the vehicles gap; loft **upper-floor population** and
**per-theme loot** shipped; nodes and claims **are** level-authored (schema, loader, serializer,
both hosts); `--coop-host` is one command.

---

## 3. Work queue

Ordered by what this box can actually finish. Status moves only when a check runs.

- [ ] N1 kit-call packet (net path)
- [ ] N3 zone packet for co-op
- [x] G2 allies spend/earn EMPIRE influence — closed 2026-10-31, see §4
- [x] G3 authored wave spawners on a timer — scheduler + seam shipped 2026-10-31, arming call open (§4)
- [x] G4 downed-and-revived allies — closed 2026-10-31, see §4
- [x] W1 floor-size-aware upper-floor population — closed 2026-10-31, see §4
- [ ] W7 structure graph hooked into detached pieces
- [ ] E3 mirror material authorable in the level/material list
- [ ] E1 NOCK placement UI for nodes and claim cells
- [ ] I3 kill DEADWEIGHT's hand-copied `GUI_SRC` list
- [ ] I5 lobby APPS page explains *why* an app is missing
- [ ] R4 load and clamp the stadium into a scene (drawing stays [V])
- [ ] A2 Mixamo-to-gband importer

Blocked on a toolchain, listed so they stop looking forgotten: A1, I1, I2, I7 (Go/SDL2), R2, R3, R5,
R6, A3 (GPU/display), E7 (mingw), and everything in §2.8 (founder call).

## 4. Progress log

### 2026-10-31 — G4, downed allies (PARENA + SHANKPIT)

`physics.h` already puts a dead body in `STATE_DEAD` with a respawn timer, so the seam was to **hold** that
timer, not invent a second death path: `story_ai_downed_tick` keeps `respawn_time` a second ahead while an
**ally** is down, accumulates the bleed, releases at the window, and revives on a hold that restores 40% of
the archetype's pool. Zombies are excluded by `empire-downable` — a beast that lingers is a bug, not a
rescue — so every existing level's enemies behave exactly as before.

**Verified:** `make test-empire-rules` green (boundaries at exactly the window and the hold, plus parity
between the generated copy and the `empire_units_rules.h` defaults `story_ai.c` actually reads);
`make test-empire-units` green; `make -B server` links the tick.
**Still open:** nothing watched it happen (no SDL2 to build the lobby), and the revive check is straight-line
hero distance, so a body behind a wall is still reachable.

### 2026-10-31 — G3, the wave scheduler (PARENA + SHANKPIT)

`wave_rules.prn` owns the schedule (20 s first wave, 45 s interval, −3 s per wave to a 15 s floor, size 3
growing to 8) and `wave-should-spawn`. `wave_spawner.h` is the timer: pure, time passed in, and it **leaves
a wave due when the live cap blocks it** rather than advancing — the failure that would quietly end a
survival mode early. `story_ai_waves_tick` spawns the PARENA archetype through `story_ai_spawn_unit` on a
30-unit ring around the origin.

**Verified:** `make test-wave-spawner` **64 checks, 0 failed** (parity of every number against the generated
copy, cap-holds-the-wave, backwards clock, and a 100 000-second session that stops at exactly 8 waves);
`make -B server` links the seam. The first version of this test did not compile at all — its `ok()` helper
took no format arguments and one assertion compared a variable to itself, which `-Werror` caught before the
test could ever pass vacuously.
**Still open:** the arming call. `story_ai_waves_enable(1, now_ms)` is the whole toggle, and I deliberately
did not guess which mode should call it — turning waves on for every level would change existing maps
silently, which is a founder/gameplay decision, not a mechanical one. The ring is also around the world
origin, not level-authored.

### 2026-10-31 — toolchain unblock 2: the headless server links here

`make -B server` links on this box (warnings only, in `witness_ai.c`). That matters more than it sounds:
`story_ai.c`, `empire_units.h` and the whole simulation layer are compiled and linked for real by a
server build, so anything at that seam can be *verified* here even though the client cannot be. The
remaining hard blocker is SDL2 headers, which is the lobby only.

### 2026-10-31 — toolchain unblock: PARENA builds here, so `regen-*` works

Every PARENA-derived number in SHANKPIT (`empire_rules.c`, `material_rules.c`, `slide_rules.c`, …) is
*generated*, and the generator needs PARENA's own compiler. With no bazel on this box that looked like a
dead end; it wasn't. `make .parena-bootstrap` builds the compiler with the system `gcc` in one pass
(one pre-existing warning, `is_pointer_c_type` unused in `src/emit.c`), and
`SHANKPIT/scripts/gen_empire_rules.sh` then regenerates `empire_rules.c` **byte-identically** to the
committed file. That identity check is the point: it means the checked-in generated C really is this
compiler's output, so a diff after a rule change can only be the rule.

This converts the whole "PARENA-first" standing rule from an aspiration into something executable here,
and it is why G2's decision half could start at all.

### 2026-10-31 — G2, decision half (PARENA + SHANKPIT)

`empire-rules.prn` gained `empire-influence-per-banked-unit` (1:1 — one rifleman is 25 banked units) and
`empire-bank-credit(carrying, influence, cap)`, which returns what *fits* rather than performing the
addition, so a full pool clamps instead of eating a hauler's cargo. Eight assertions in
`make test-empire-rules`, including the round trip: banking a rifleman's worth actually buys a rifleman.

**Host half, added the same day:** `story_ai_bank_handins(ServerState *, faction)` walks the AI list, empties
every unit of that faction that is carrying something AND standing within `follow_distance` of its own
spawn point, and returns the units handed in. It returns **units, not influence**, on purpose — the server's
source list does not carry `empire_rules.c`, and converting there would drag the generated rules into a
binary that has no pool. `lobby_empire_sync` then does
`g_empire_influence += empire_bank_credit(banked, g_empire_influence, empire_influence_max())`.

**Verified:** `make -B server` links with the new function in it (so the iteration, the home-distance test
and the types are real), and `make test-empire-rules` covers the worth/clamp maths.
**Not verified, named:** the one-line lobby call is **compiled by nothing on this box** — `main.c` cannot be
built without SDL2 headers — so that wiring is reviewed, not run, and no ally has been watched walking a
node home. A server-side match also still has no influence pool of its own; influence is the phone's, and
the phone is the lobby's.

### 2026-10-31 — W1 closed (SHANKPIT)

`tools/build_loft_city.py` asked for population per **floor** and never per **deck**, so a full 254×68
pair deck and the 254×34 stepped-back storey above it in the same building each got exactly one body.
`population_plan` now takes the levels, measures every storey's own deck (`storey_deck_areas`, the same
predicate the placement loop uses), staffs every upper floor once as before, and then deals the spare
slots out one building at a time — the deck picks *which floor* inside a building, the round-robin
picks *which building* — until `NPC_BUDGET` (69, the engine's own simultaneous-character ceiling) is
spent. The city goes from 61 authored characters to **69**, one extra loft body per building.

Two versions of this rule were wrong before one was right, and both were caught by checks rather than
by reading it back: the first assertion counted ground floors (two by design, not by area) as
deck-earned, and the first allocator handed all eight spare slots to `loft_a`/`loft_b` because every
full pair deck measures the same 21964 and the sort fell through to the name. That is why the split is
stated as it is: **area decides the floor, spread decides the building.**

**Not done, named:** still no window on this box, so the extra bodies are verified as authored data
and a clean parse, never watched fighting; the second body on a floor shares that floor's four
corner spots, so a 254×68 deck still fields at most two; and the population is still authored statically
— no wave spawner (G3) reads this plan.

## History

- 2026-10-31: W1 closed; see §4.
- 2026-10-31: opened. 45 open items across seven subsystems, extracted from the previous session's
  own named-not-done sections and cross-checked against its later turns for work that shipped.
