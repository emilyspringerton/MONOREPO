# TRAPX VS0: the sandbox, and what is actually in it (2026-11-04)

TRAPX is the GTA-shaped urban sandbox on the SHANKPIT lineage: a city that watches, remembers and reacts, with
Field Offices, K9 doctrine and BIG_O's witness loop underneath. Its product northstar is the TrapX document; this
file is the engineering record of the first playable slice, and it follows the same rule as every other slice in
`THREE_WAY_MERGE.md`: **a decision two worlds must agree on lives in PARENA, once.**

## The slice

| Piece | Where | State |
|---|---|---|
| the rules | `PARENA/stdlib/trapx/trapx_rules.prn` | built, emitted to C **and** to JS |
| the shared fixture | `PARENA/stdlib/trapx/trapx_parity.txt` (88 rows) | generated from the C, asserted from both sides |
| the C host | `SHANKPIT/packages/simulation/trapx.{h,c}` | `make test-trapx` — 169 checks, 88 rows |
| the mods-first bus | `SHANKPIT/packages/simulation/trapx_events.{h,c}` | same test |
| the browser host | `WOTAN/trapx/trapx-city.js` + `trapx-host.js` | `node scripts/trapx-rules-test.mjs` — 140 checks, 88 rows |
| the wasm city | `PARENA/stdlib/trapx/web/{tp_mem,tp_city,tp_api}.prn` → `WOTAN/trapx/trapx.wasm` | built by `scripts/build_trapx_wasm.sh`; 0 imports, no allocator, fixed 8 MB; pinned to the JS city by `scripts/trapx_wasm_test.mjs` |
| the page | `WOTAN/trapx/index.html`, `css/wotan-trapx.css` | written, never opened in a browser |
| the identity | `IDUNA` `games.Registry["trapx"]` + migration | `go build` green, no route yet |

VS0 is two scenes and no more: **200 Detroit Apartment** (residential, Jiangshi Watcher density, two Field Offices)
and **201 Detroit School** (custody zone, one Field Office, quieter). A scene outside those two is refused by
`trapx-scene-known` rather than silently simulated, because six districts that do not exist should not be playable
by accident.

## What the rules decide

Everything a designer would otherwise have to state twice:

- **Watchers.** Alertness gains `density/100 + heat/50 - 6` per quiet tick, capped at 12 a tick and 0..100 overall —
  the apartment notices at +9, the school at +4, and a meter that can slam calm→alarm in a frame is a jump scare,
  not a Watcher. Trust moves +3 per clean receipt and **-7** per dirty one: being caught costs more than honesty earns.
- **Enforcement 0..4.** Level 1 on any one of the northstar's three triggers (alertness ≥ 65, trust ≤ -20, heat ≥ 50);
  2..4 require a hot alertness *and* a hot street, so no single dial escalates a patient player. The Media layer
  starts talking at level 2 or alertness 75.
- **Heat** per action, multiplied by the street's own enforcement — the feedback loop that makes level 3 feel
  different from level 0.
- **Field Offices.** Claim cost rises with what you already hold, and the custody zone costs 50 more. Flow per tick
  falls with enforcement; Pressure grows with attention, enforcement and the number of offices you are holding;
  Attention decays 4 a tick with no dogs out and rises 7 a unit with them.
- **K9 Doctrine.** 0.85^n as integers — 1000, 850, 722, 613, 521, then a 443 floor — so C and the browser cannot
  round a swarm differently.
- **The Rogue Swarm** needs all three: integrity < 20, attention ≥ 80, pressure ≥ 60. Any one alone is a bad
  afternoon, not a swarm.
- **Receipts.** A deterministic chained digest per entry. Not a security primitive: a tamper-evident *ordering*,
  which is the part a replay needs.
- **BIG_O, the city's half.** A killing in public is +8 heat and +4 a witness, and -4 trust and -6 a witness. The
  witnesses' own STATES stay in `big_o/witness_rules.prn` — the city and the witnesses are two observers and are
  allowed to disagree, which is exactly why this is a separate decision.

## MODS FIRST, honestly

"Mods first" cannot mean registering callbacks here: PARENA VS0 has no function pointers or closures, the same
finding ECOWAR's Living Map recorded rather than faked. So the API is **the event vocabulary plus ordered delivery**:

- every transition announces one of ten named events (`tick`, `claim`, `contest`, `k9`, `alert`, `enforce`,
  `receipt`, `kill`, `rogue`, `portal`) into a 256-entry ring, newest first, with a sequence that survives wrapping;
- a mod is a **name, a subscription mask and a priority**, registered by name (duplicates refused, not overwritten);
- one delivery pass per event returns the interested mods highest priority first, ties on registration order;
- a disabled mod is delivered nothing, and a mod wants only what it asked for.

Adding a mod changes no city code. What is still missing for a true out-of-tree plugin is a way to load *code* —
named, not pretend.

## The two surfaces, and why they are not merged

`SHANKPIT 460` (`/shankpit-460/`) and `Bedrock Racers` (`/bedrockracers/`) are each a complete committed wasm module:
zero imports, no allocator, fixed memory. There is no shared ABI to combine, so "combining" them honestly means
**one shell and one identity** — the TRAPX page embeds both and shares the IDUNA session — not one merged binary.
Faking a merge would have been the exact kind of claim this repo refuses to make.

**Corrected 2026-11-04:** the sentence that stood here ("No wasm was built for this slice, and none was
needed") was true of the first slice and is no longer true of the repo. The city now IS a wasm module:
`PARENA/stdlib/trapx/web/tp_{mem,city,api}.prn` compiled to wasm32 by `scripts/build_trapx_wasm.sh`
(parena -> opt -> llc -> wasm-ld), shipped as `WOTAN/trapx/trapx.wasm`. It holds the same promises as the
other four web games: **no allocator, zero imports, fixed 8 MB memory**, and every threshold is still a
call into `trapx_rules.prn` rather than a literal in the host. The earlier claim's reason is also worth
keeping straight: the box that wrote the first slice had no `clang`/`wasm-ld`/`ziglang`. That was a
statement about a machine, not about the design -- LLVM 18 is installable, and here it is installed.

## Limits, named

- **Nothing here has been played.** No Roblox, no browser, no Studio. The page is reviewed; the C is executed.
- **The city has no authority.** It lives in the page and resets on reload; IDUNA has the identity row but no
  `/api/v1/games/trapx/...` route, so no receipts are persisted.
- **SHANKPIT's host is not called by the lobby** — that cannot be compiled on this box — so the C host is proven by
  its test, not by a running game.
- **No third host.** NOOBTOPIA has the cosy verbs from the previous slice; TRAPX has not been emitted to Luau, because
  no Roblox place needs the city yet. Adding one is a `gen_rules.sh` line, not a rewrite.
- **Feel is not measured.** Whether an apartment that notices in nine seconds is *tense* is a human question.
