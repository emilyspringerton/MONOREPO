# The three-way merge: BIG_O, SHANKPIT, NOOBTOPIA

**Status:** first slice built, plus a Lua target in PARENA. `PARENA/stdlib/noobtopia/{ambient_life,arena_rules}.prn`,
`PARENA/src/emit_lua.c`, `SHANKPIT/packages/simulation/{ambient_life.h,arena_rules_test.c}`,
`NOOBTOPIA/src/{ambient,noobtopia,big_o_witness}.lua` + generated `src/generated/`. Written before the code, per the
standing rule.
**Status (movement slice, 2026-10-31):** second slice built — `PARENA/stdlib/noobtopia/walk_rules.prn` +
`walk_parity.txt`, `SHANKPIT/packages/simulation/{walk_rules.h,walk_rules_test.c}` (emitted `walk_rules.c`),
`NOOBTOPIA/src/wander.lua` + generated `src/generated/walk_rules.lua` + `tests/walk_test.lua`. "Where does it drift"
is now a shared rule, and for the first time the Luau half is **executed**, not just reviewed (§6).
**Founder direction (real-time, 2026-10-30):** *"clone down NOOBTOPIA it is a basic roblox script lets start building in
both directions ... BIG_O is the IP SHANKPIT is the agile implementation NOOBTOPIA is the data for making our world seem
more alive we script in more random interactions like the talking from noobtopia AT THE SAME TIME we start to build BIG_O
into ROBLOX via updating our NOOBTOPIA fork we will figure out how to get it into ROBLOX later write it up as docs first
then implement"*, plus *"PARENA is the gl[ue]"*.

## 1. What each repo is, and what it owns

| Repo | Role | Owns | Must never own |
|---|---|---|---|
| **BIG_O** | the IP | the fiction, the signature mechanic (witnessing / decorum), the campaign, the tone, the reference rules (`core/witness_rules.c`, `PARENA/stdlib/big_o/*`) | engine primitives, ambient filler, platform-specific host code |
| **SHANKPIT** | the agile implementation | the engine: destruction, levels, netcode, NPC simulation, PARENA hosts that actually run every tick | the IP's narrative content, the data that makes a street feel inhabited |
| **NOOBTOPIA** | the data + the Roblox surface | ambient behaviour data (lines, ticks, small talk), the Roblox/Luau host, the low-fidelity sandbox where interactions are cheap to try | gameplay authority, the witness *rules* (those are BIG_O's) |
| **PARENA** | **the glue** | every decision that all three must agree on, as integer-in/integer-out pure functions with no host | rendering, dispatch, storage, anything that needs a clock or a socket |

The rule that makes this a merge rather than three codebases that resemble each other: **a decision that two repos must
agree on lives in PARENA, once.** SHANKPIT calls the emitted C; NOOBTOPIA calls a Luau port of the *same* file. Neither
side keeps its own copy of the numbers. When the Luau port and the C disagree, the C is authoritative and the port is the
bug — the same discipline BIG_O already uses for its parity vectors.

```
                       ┌──────────────────────────────┐
                       │  PARENA  stdlib/noobtopia/   │
                       │  ambient_life.prn            │   ← the one copy of every threshold,
                       │  (categories, cooldowns,     │      window, threshold and roll
                       │   picks, speak-or-not)       │
                       └───────┬───────────────┬──────┘
                  parena build │               │ hand-mirrored port (parity-checked)
                               ▼               ▼
                  ┌────────────────────┐   ┌────────────────────┐
                  │ SHANKPIT           │   │ NOOBTOPIA          │
                  │ ambient_life.h     │   │ src/ambient.lua    │
                  │ (C host, per tick) │   │ (Luau host)        │
                  └────────┬───────────┘   └────────┬───────────┘
                           │  lines + categories     │
                           │  generated include      │
                           └──────► data/noob_lines.lua ◄──┘
                                    (NOOBTOPIA is the source of truth for the words)
```

**Data flows one way.** NOOBTOPIA holds the *words* (a Lua data file); SHANKPIT consumes them through a generated C
include (`scripts/gen_ambient_lines.sh`), never by hand-copying strings. So editing a noob's line in NOOBTOPIA and
re-running the generator changes what SHANKPIT NPCs say, with no second edit — and a line that exists in one world and
not the other becomes impossible.

**Decisions flow one way too.** PARENA holds the *numbers*. If a designer wants tired NPCs to talk less, that is one
edit in `ambient_life.prn`, then `scripts/gen_noobtopia_rules.sh` for the Luau side. The Luau file says so at the top.

## 2. Why this is the right seam (and what it deliberately is not)

- **Not a code port.** SHANKPIT is C with a 60 Hz tick and a UDP wire; Roblox is Luau with a managed scheduler. Sharing
  an implementation between them would mean writing the worst of both. Sharing *decisions* is cheap and gives the two
  worlds the same feel.
- **Not a shared engine.** The whole point of SHANKPIT being the "agile implementation" is that it moves fast on real
  primitives. Roblox is where an interaction can be tried in an afternoon with no build step. They are allowed to look
  different; they are not allowed to *disagree* about what a witness is or how long a noob waits before talking again.
- **NOOBTOPIA is data-first, not a second engine.** Its current content is a 60-line script that clones a noob every
  0.1 s, gives it a random line from 20 strings, and moves it every 33 s. That is the honest starting point: 20 strings
  and two timers is exactly the "random interactions" seed, and the value is in the *content* and the *scheduling*, not
  in the script's structure.

## 2b. PARENA emits Lua now (the glue actually glues)

Founder: *"build the shankpit affordances into NOOBTOPIA including combat and slippery physics PARENA IS THE GLUE make
it so PARENA can emit lua or whatever it should be trivial"*.

It was as trivial as the other targets made it: `PARENA/src/emit_lua.{c,h}`, a fourth narrow emitter beside C,
TypeScript and Java, selected by output extension — `parena build rules.prn -o rules.lua` now emits a Lua table module
(`local M = {} ... return M`) that Roblox's `require` and a plain interpreter both understand. Four real lowering
decisions, each of them a way this could have silently broken parity:

| PARENA | Lua | Why |
|---|---|---|
| `=` | `==` | Lua's `=` is assignment |
| `/` on I32 | `//` | Luau floor division; emitting `/` would produce floats and every cross-world comparison would fail for no visible reason |
| `if` | `(cond and then or else)` | the only expression-form conditional Lua has; correct for every integer/string branch this ABI produces |
| `a-b` symbol | `aB` | camelCase, matching the hand-written Luau module it replaces |

`parena build` also gained the `#target {:lua (inline-lua "...")}` escape hatch, same shape C/Java already have.

## 3. The first slice (built in this pass)

**Ambient life: what an NPC says when nothing is happening.**

| Question | Answer lives in | Consumed by |
|---|---|---|
| which *kind* of line fits this mood? | `ambient_life.prn` `ambient-category-for-mood` | SHANKPIT C, NOOBTOPIA Luau |
| how long until this NPC may speak again? | `ambient_life.prn` `ambient-cooldown-ms` | both |
| may it speak *now*? | `ambient_life.prn` `ambient-should-speak` | both |
| which line? | `ambient_life.prn` `ambient-pick` over the data table | both |
| what the lines actually say | `NOOBTOPIA/data/noob_lines.lua` | generated into SHANKPIT |

Categories: `0 GREETING`, `1 QUESTION`, `2 BANTER`, `3 COMPLAINT`, `4 SELF`. Moods are MISHRI's own 8-state enum, which
SHANKPIT already simulates (`packages/simulation/humanness.c`) and BIG_O already vendors — so the same integer means the
same thing in all three repos, which is the entire reason this can be one function.

**Combat and slippery physics** (`stdlib/noobtopia/arena_rules.prn`, same pass, same double emission): weapon damage /
knockback / cooldown / distance falloff on to-hit, and per-surface traction, acceleration, jump impulse, `step-speed`
and `slide-decay`. NOOBTOPIA's noobs now move by asking the rules for their next speed (`wish < 0` = no input = the
surface takes over, which is the whole "slippery" verb), and fight with the same numbers SHANKPIT's C build uses.

The test that pins the feel rather than the formula: releasing on ice travels **more than 3x** as far in 60 ticks as
releasing on concrete. If someone "fixes" the friction table so ice is not slippery, that check fails.

Deliberately deferred in this slice, named so nobody assumes otherwise:

- **No Big-O witness content in the ambient sets.** A noob does not yet gossip about a body it did not see. That is the
  interesting crossover — ambient lines conditioned on *witness state* — and it needs BIG_O's ledger on both sides first.
- **No Roblox publishing.** Luau modules are written and loadable, but getting them into a place is a separate, later
  conversation (the founder's own words: "we will figure out how to get it into ROBLOX later").
- **No audio.** Both worlds are text-only today.

## 3b. The second slice: where it drifts, and when (2026-10-31)

The first slice unified what a noob *says* and left movement explicitly alone. This slice is that debt: NOOBTOPIA's
original script wandered on a 33 s timer, SHANKPIT NPCs stood still, and MAGIC — neither could be shared because
neither was decided anywhere.

`PARENA/stdlib/noobtopia/walk_rules.prn` now decides the whole movement question, integer in / integer out, emitted
twice exactly like the first slice:

| Question | Answer | Consumed by |
|---|---|---|
| may it pick a new destination now? | `walk-should-choose` over `walk-idle-ticks` | both |
| which of 8 compass headings? | `walk-heading` (+ `walk-heading-dx/dy`) | both |
| how long is this leg? | `walk-leg-length` | both |
| how fast does it walk? (permille) | `walk-mood-speed-permille` | both |
| does the destination stay in its own street? | `walk-within-leash` (squared, no sqrt) | both |

The two hosts integrate with the **same integer algorithm**, which is what makes the two worlds comparable at all:
no floats, no `Vector3`, no clock in the rules; a target is one leg along a heading, rejected if it leaves the leash
(all 8 headings tried), and movement is one whole unit per tick gated by a permille credit. So a STARTLED noob
(0 permille) is *frozen* — a state, not a slow speed — a TIRED one (400) steps twice every five ticks, and neither
world can move half a unit.

**Parity vectors are real now, not aspirational.** `PARENA/stdlib/noobtopia/walk_parity.txt` holds 13 rows of
(mood, since, seed) → (idle, choose, heading, leg, speed, unit vector), generated from the C and hand-checked. Both
`make test-walk-rules` (SHANKPIT) and `lua tests/walk_test.lua` (NOOBTOPIA) assert that same file, so a drifting port
is a red test on one side rather than a quiet divergence.

### Bug the executed port found

Running the Luau for the first time found a real cross-world defect the reviewed-but-unexecuted code had carried:
the seed mixer. `ambient_life.h`'s `(seed * 1103515245 + 12345) & 0x7FFFFFFF` needs 61 bits for a seed near 2^31, and
Roblox's numbers are IEEE doubles (exact to 2^53), so the low bits are rounded away — seed 2147483646 yields
`2087949151` exactly but `2087949312` in double arithmetic, i.e. two different universes from one seed. Plain `lua`
5.4 has 64-bit integers and hides it entirely, which is exactly why this needed a runtime that models Luau, not just
any Lua.

The movement slice therefore uses MINSTD (`* 48271 mod 2^31-1`, peak ~1e14, exact in both) and says so in both hosts.
`ambient_life`'s own mixer is left as-is and named here rather than silently changed: the fix belongs with whoever
next touches the ambient seed stream, and it changes every existing ambient draw.

## 4. Building BIG_O into Roblox (the second direction)

The port order is chosen by *what survives losing the engine*, not by what is most fun:

1. **Witness / decorum rules** (`NOOBTOPIA/src/big_o_witness.lua`, this pass). Pure: witness count in, group state out.
   1 witness = catatonic denial; 5+ = aggressive silencing; a compromised witness helps cover it up. Nothing about this
   needs SHANKPIT — which is exactly why it ports first, and it is the IP's signature mechanic, not a side system.
2. **Costume / zone decorum deltas** next: also pure, also needs no engine.
3. **Day/night + weather** (`BIG_O` scenarios 30–35 are already a specification): a clock and a flag set, no rendering.
4. **Anything that needs the destruction model** last, or never: Roblox has its own.

The Luau modules are written to run **headless** — no `game`, no `Instance`, no `wait()` at module load — so a plain Lua
interpreter can test them, and the Roblox host (`src/noobtopia.lua`) is the only file that touches `workspace`. That
split is why the rule layer is testable at all, and it mirrors BIG_O's own "rules core + host" discipline.

## 5. What "done" looks like for the merge

- One PARENA file per shared decision, and **parity vectors** (the same seeds in, the same answers out) checked on both
  sides in CI — BIG_O's existing parity-vector pattern, applied between C and Luau.
- The NOOBTOPIA line data is the only place a line is written; SHANKPIT's copy is generated.
- Every claim in this doc has a check that fails when it stops being true (this pass: `make test-ambient-life` in
  SHANKPIT, `tests/ambient_test.lua` in NOOBTOPIA, and `scripts/gen_ambient_lines.sh` failing loudly if the data file
  stops parsing).
- The words "not verified" appear only where they are true.

## 6. Honest limits of this pass

- **The Luau half is executed now, on plain Lua 5.4**, which is how the seed-mixer bug above was found. That is not
  Luau and not Roblox: `lua` 5.4 has 64-bit integers where Luau has doubles, so the test run can only prove the parts
  that do not depend on number representation — it cannot prove the ambient mixer, and it would have hidden this bug
  if the walk slice had reused that mixer. `lua tests/ambient_test.lua` and `lua tests/walk_test.lua` both run clean.
- **Roblox is unverified by definition here.** No Studio, no place file, no publishing.
- The SHANKPIT host is wired only into a headless test, not into the lobby's NPC draw loop — the lobby cannot be compiled
  in this sandbox (no SDL2 headers), which is the same standing limit the rest of the engine work carries.
