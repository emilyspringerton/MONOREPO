# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## What This Is

The `/home/fatbaby` directory is the EINHORN_INDUSTRIAL monorepo home. It is not a single project — it is a collection of repos sharing a Go workspace and a common operating procedure ("The Emily Way").

**Before starting any work, read `EMILY/BACKLOG.md`.** Pick the highest-priority unchecked item in the lowest-numbered open section. This is not optional.

---

## Go Workspace

`go.work` spans five modules. All `go` commands at the repo root resolve across them:

| Module path | What it is |
|---|---|
| `EMILY/emily-agent` | Emily Prime agent — RSI cron, HEIMDAL, FCM, ops agent (:8086) |
| `EDIS` | WordPress plugin suite (PHP; not part of `go test`) |
| `IDUNA` | Platform IAM, Apples ledger, HEIMDAL sprints (:8080) |
| `PRRJECT_FATBABY` | SEC/PR financial signal pipeline + emily-agent (:8080) |
| `emily.cli` | Operator CLI (`emily` binary) |

```bash
# Test all Go modules at once
go test ./...

# Build and install emily CLI
cd /home/fatbaby/emily.cli && ./scripts/build.sh

# Run a specific test
go test ./IDUNA/internal/auth/... -run TestTokenValidation
```

---

## Non-Workspace Repos

These are standalone repos not in `go.work`:

| Repo | Language | Purpose |
|---|---|---|
| `SHANKPIT` | C/SDL2 + Go | Server-authoritative UDP FPS; Go backend on :6969 |
| `GoblinFoxDragon` | Go | Dragonfly/Bedrock fork; DragonsNShit persistent world engine |
| `MJOLNIR` | Kotlin/Jetpack Compose | Android intelligence terminal; FCM push, Apple feed, WebView |
| `TYLER` | Markdown | TV series bible + episode scripts + universe engine |
| `MoneyPrinterTurbo` | Python | Flat stream video compilation for TYLER episodes |
| `APPLES` | JSON/git | Git-authoritative Apple audit trail (no code; data only) |
| `gpt2-alpine-c` | C + Python | GPT-2 C inference engine + Emily Prime fine-tune pipeline |
| `EmilyOS` | Go | Policy kernel: posture-gated sessions, RBAC, SOC 2 audit log |
| `PITVIPER` | Go | SDL2 terminal emulator with Emily Prime integration hooks |
| `EDIS` | PHP | WordPress plugins fronting FatBaby signalapi and Emily Prime |
| `GOLDENBAND` | C + Go | `.gband` animation asset format + sampler + BVH import pipeline (HQ-SPEC-SIM-100) |
| `EINHORN_SURVIVAL` | Java (Paper config) | Real EINHORN_INDUSTRIAL community Minecraft survival server, live on `:25565` |
| `SKULDMARK` | Go | 25-char instrument identifier format (MIC + symbol + CIK + checksum); public domain (Unlicense) |
| `GTA7` | Java (Paper plugin) | TRAPX doctrine (Field Offices, Watchers, K9, Media, Party Stores) as a Paper plugin on EINHORN_SURVIVAL; scoping doc at `docs/NORTHSTAR.md`, VS0 not yet built |
| `CarePyre` | TBD | New repo (2026-08-10), stub only — no scope/stack decided yet, more founder direction to follow |
| `EXODUS` | Python (planned) | New repo (2026-08-11), scaffolding only — home for REDGARDEN's §25.4 PFSP autocurriculum research, extracted for eventual open release; extraction itself not started, see `EXODUS/README.md` |
| `TTT` | TBD | New repo (2026-08-11), stub only — "Tyler Teaches Typing," real VS0 implementation actually lives in `SHANKPIT`, this repo's own purpose undecided, see `TTT/README.md` |
| `ECOWAR` | C | Hard-forked from REDGARDEN 2026-08-27 (full git history preserved, 446+ commits) — supersedes the 2026-08-20 GFD-battlegrounds_gui-based scoping. Gameplay currently identical to REDGARDEN's `apps/arena`/`apps/arena_server`; own 1v1 matchmaker+bot-pool staged (`:9779`); own 16-card system shipped (first mod to do real PARENA decision logic, not just a trigger). See `ECOWAR/README.md` |
| `PARENA` | C (VS0) | New repo (2026-08-20), NORTHSTAR only — new from-scratch language (S-expression syntax, compile-time region-based memory safety, multi-target C/JVM/TS/Wasm compilation) + editor/plugin API; GFD mod-surface candidate, integration deliberately deferred; VS0 (`parena-c` compiler) scoped with a real Definition of Done, not yet built, see `PARENA/NORTHSTAR.md` |
| `SAND` | PARENA (planned) | New repo (2026-08-20), stub only — a native code editor written in PARENA itself ("S-expression And Not Dumbshit"), same stated mission as PITVIPER ("basically i am extending my IDE which is actually this VPS"); PITVIPER's own Go implementation is unaffected and stays exactly as-is — SAND is a separate, new fork, not a rewrite-in-place. Mod-surface/plugin API is its first real feature, not an afterthought. Not started as actual code yet; named only, see `EMILY/BACKLOG.md` S189-38 for the full naming history (IRONCLAD → JEWEL → SAND). |
| `JEWEL` | Python (real v0) | New repo (2026-08-26) — a real Jupyter kernel/backend for PARENA (`ipykernel.kernelbase.Kernel` subclass, shells out to the real `parena build` compiler + gcc per cell). Distinct from `SAND` (unrelated project that also passed through the "JEWEL" name candidate, see `SAND`'s own row above) and from SARENA_NOTEBOOK (IDUNA portal's *other*, not-yet-started, native-GUI tool row). Served by `jewel-jupyter.service` (user systemd, 127.0.0.1:8890) behind an nginx `/jewel/` proxy on okemily.com gated by HTTP Basic Auth — a deliberate interim measure, per founder: "just use basic auth to protect it for now until we get google oauthg to work", pending IDUNA's Google OAuth devportal gate (blocked on a human-only GCP Console step). Linked from IDUNA's own dev portal (`IDUNA/internal/http/handlers/portal.go`). |
| `skateboard` | C/SDL2 | The historical repo ("SkateChain: The Polyglot Metaverse," the ancestor `SHANKPIT`/REDGARDEN/GFD all descended from — `apps/shank-fps` is SHANKPIT's own direct ancestor) where the Papercraft idea was first scoped (`skateboard/NORTHSTAR.md`, 2026-07-24). Stays as-is, the real audit trail of how that direction got found — the live build is `PAPERCRAFT` (own row below), not this repo. |
| `PAPERCRAFT` | C/SDL2, PARENA mods | New repo (2026-08-28) — "Minecraft meets GTA3, plus Skate2": a single-node persistent, online-only sandbox (not an RPG-first game — that's GFD's own identity; "gfd is designed to be the long running rpg papercraft is a sandbox with mmo dna") in the TRAPX universe, built by iterating SHANKPIT's own C/SDL2 lineage forward, explicitly **not voxels** ("instead of minecraft we iterate shankpit into papercraft"). "Mods first everything" — PARENA embedded as deep as `WEAKNIGHT_BEDROCK_RACERS`' own same-session precedent (`PARENA/stdlib/papercraft/level_mod.prn`, real RPG level-for-XP decision logic, already compiled + tested). Real sibling to `WEAKNIGHT_BEDROCK_RACERS` ("bedrock racers can evolve into papercraft," itself "like the esports, league of legends meets rocket league") — no merge, no hard dependency. `SHANKPIT_CONSTRUCT.txt` (this repo's own root) is the real reference; `SCENE_CITY` is the real default spawn. No quests (GFD's own domain), no combat requirement to start (real, tech-tree-gated/deferred). NORTHSTAR + one real verified PARENA mod only — no server/client host code yet, see `PAPERCRAFT/NORTHSTAR.md`. |
| `BURROW` | Go (planned) | New repo (2026-08-30), NORTHSTAR only — PARENA's fourth real compilation target (after C/TypeScript/Java, all three shipped this same session), a Go emitter designed around a GC-off-safe host: real, honest scope is that v0-shape generated functions never allocate on the Go heap, so a real host (`GoblinFoxDragon`'s own Go backend named as the candidate, not committed to) can safely `debug.SetGCPercent(-1)`/`GOGC=off` around calls into them. Not a special codegen mode, a scope discipline — full rationale, the real Go-specific emitter differences (`if`-as-immediately-invoked-closure, conditional `math/rand` import), and the phased plan are in `BURROW/NORTHSTAR.md`. No `emit_go` code yet. |
| `MISHRI` | JavaScript (Node/mineflayer) | Forked 2026-08-30 from [arpitrajjj/Mishri](https://github.com/arpitrajjj/Mishri) (external, not affiliated with this org) — a human-like Minecraft bot (mineflayer-based movement/chat/perception jitter, mood system) intended for use against this org's own `EINHORN_SURVIVAL` server; use at own risk, `package.json` declares ISC but no `LICENSE` file is present in this fork so the actual terms are ambiguous (see `MISHRI/README.md`'s own "Author & License" section). Real Bazel build added (`bazel test //:test` — hermetic humanness-layer coverage, no `npm install` needed; `bazel run //:install`/`//:mishri` wrap the real, non-hermetic `npm ci`/`npm start`), plus a real CI "Generate Construct Bundle" step matching PARENA's own established convention. |

---

## System Architecture

```
                        ┌──────────────────────────────┐
                        │  EMILY Prime (:8086)          │
                        │  5-min RSI cron cycle:        │
                        │  OBSERVE → DECIDE → ACT → PLAN│
                        └─────┬──────────────┬──────────┘
                              │              │
                    Apples    │     Directed tasks →
                    POST      │     EMILY/signals/tasks/
                              ▼              ▼
                         IDUNA (:8080)  obs-watcher ──► claude --dangerously-skip-permissions
                         (IAM, ledger,               [--continue for AGI loop]
                          HEIMDAL,                         │
                          push tokens)                     ▼
                              ▲              ┌─────────────────────────┐
                              │              │  PRRJECT_FATBABY         │
                    Apples ◄──┘              │  SEC/PR signal pipeline │
                    backed up                │  entity-graph, emily-   │
                    to APPLES git            │  agent, obs-watcher     │
                                             └─────────────────────────┘
                                                        │
                                             ┌──────────┴────────────┐
                                             │  Downstream            │
                                             │  EDIS (WordPress)      │
                                             │  MJOLNIR (Android)     │
                                             │  TYLER + MPT (video)   │
                                             │  SHANKPIT (FPS game)   │
                                             └────────────────────────┘
```

**IDUNA is the central trust authority.** Every service that needs auth gets an ES256 JWT from IDUNA. Never trust tokens from other sources.

**Apples are the audit trail.** Every meaningful cycle outcome is a filed Apple. The git repo `APPLES/` is the durable backup, committed automatically by `emily sync --apples-git-dir`.

**The RSI loop is the product.** Emily Prime (EMILY) plans and triages. Claude Code implements. Observation-watcher dispatches. The loop is: observe → direct task → implement → Apple → repeat.

---

## The Emily Way — Operating Protocol

These are mandatory, not optional:

**1. Backlog First** — Read `EMILY/BACKLOG.md` before any work. Pick the highest-priority `[ ]` in the lowest open section. **Founder real-time direction overrides picking, never overrides logging — it always goes into BACKLOG.md, no exceptions, log-then-work or work-then-log either order is fine but it always lands there.** See `EMILY/docs/THE_EMILY_WAY.md` Principle 1 for the full rationale.

**1a. Route founder input through the observation queue first** — Any founder real-time direction, in any repo (not just FatBaby-flavored asks), gets posted via `emily observe -s info "Founder real-time: <summary>"` before you act on it, then curated/logged into BACKLOG.md, then worked. This is how direction given while you're offline still gets picked up the moment obs-watcher comes back around. See `EMILY/docs/THE_EMILY_WAY.md` Principle 18 ("Pave the Cow Paths"). The `emily observe`/"FatBaby observation" naming is historical and known to be a slight misnomer for non-FatBaby content — use it anyway, don't rename it unprompted. **This includes session-boundary directives, not just feature asks** — "stop," "that's enough for today," "rest," etc. are founder real-time direction too (founder, 2026-08-11, after noticing this wasn't happening automatically). Post the `emily observe` call — which auto-files an Apple — before complying with the stop, not after being asked a second time.

**2. Apple Before Mark-Done** — Every `[x]` in BACKLOG.md requires a prior Apple:
```bash
emily apples post -t completion -repo <REPONAME> "<title>"
# Then mark [x] with Apple ID, commit EMILY/BACKLOG.md, push
```
`emily apples post`, `emily changelog add`, and `emily observe` auto-stamp the active `emily
session` fingerprint (`emily session new`/`current`) as run_id — no flag needed. When hand-editing
BACKLOG.md instead of going through the CLI, append the current session tag yourself so the entry
stays traceable to the session that logged it.

**3. CHANGELOG on every meaningful change**:
```bash
emily changelog add <repo> "<what changed>"
# or: append a dated bullet under ## YYYY-MM-DD in <repo>/CHANGELOG.md
```

**4. Register new golden docs** — Any new NORTHSTAR.md or architecture spec must be added to `EMILY/context/golden-docs-index.md` or Emily Prime cannot see it:
```bash
# Append to EMILY/context/golden-docs-index.md:
# | NAME | <repo>/path/to/doc.md | <tier> | <budget> | one-line description |
cd /home/fatbaby/EMILY && git add context/golden-docs-index.md && git commit -m "golden-index: add NAME" && git push
```

**5. Tests before commit** — `go test ./...` must pass for any Go change before committing.

**6. Commit format**:
```
feat(scope): description
fix(scope): description
docs(scope): description
perf(scope): description
backlog: ✓ S22-01
golden-index: add NAME
```
One atomic thing per commit. Push immediately after — Emily Prime reads the latest state. **Every
commit message body ends with a blank line then `session: <tag>`** (`emily session current`) —
`emily changelog add` and every BACKLOG.md auto-commit do this automatically; hand-written `git
commit -m` calls need it added manually every time (founder, 2026-08-09 — caught this missing
from every commit message despite Apples/CHANGELOG already carrying it).

**7. Multi-repo changes** — Commit each repo independently in dependency order. Reference sibling commits in messages. Update `EMILY/BACKLOG.md` last.

**8. Always commit and push — standing instruction, do not wait to be asked.** When a unit of work is complete (tests pass, feature works, docs updated), commit and push immediately. This is the default behavior in every repo in this monorepo, not an exception that needs re-requesting each session. Only hold off if the user explicitly says to pause on committing for that specific piece of work.

---

## Compression Convention (standing, monorepo-wide)

**LZ4 is the default compression codec across every repo in this monorepo** — founder, real-time:
"omg we need compression stdlibs" → "zip" → "gz" → "lz4" → "lz4 is always the defauolt" → "write
that into all repo claude readmes". Chosen for the same real reason PARENA's own
`stdlib/compress/lz4.prn` names it: keeping interactive protocols (PITVIPER's remote-IDE wire
format, any future wire/IPC format) fast, LZ4's own real niche over gzip/zstd's better ratio but
slower speed. Default to LZ4 for any new compression need anywhere in this monorepo unless a
specific repo's own CLAUDE.md states a real, considered reason to deviate (e.g. a format that
mandates gzip/deflate for compatibility with an external consumer). PARENA's own implementation is
pure-PARENA-scaffolded, not FFI-bound to the reference LZ4 library — see `PARENA/stdlib/compress/
lz4.prn` and `PARENA/STDLIB.md`'s own "compress/lz4" section for the real, current status.

---

## Key Env Vars (shared across repos)

```
ANTHROPIC_API_KEY        — required for emily-agent, obs-watcher, emily backlog promote
IDUNA_BASE_URL           — default: http://localhost:8080
IDUNA_AGENT_NAME         — e.g. EMILY_PRIME, mjolnir-emily
IDUNA_AGENT_SECRET       — M2M credential (auto-loaded from IDUNA/var/agent-secrets.env)
APPLES_GIT_DIR           — /home/fatbaby/APPLES (triggers auto-sync after each Apple POST)
FCM_PROJECT_ID           — Firebase project for MJOLNIR push notifications
```

---

## Per-Repo CLAUDE.md

Each sub-repo has its own CLAUDE.md with commands, stack details, and what not to break. Always read the relevant sub-repo CLAUDE.md before working in that repo. The most important ones:

- `EMILY/CLAUDE.md` — RSI cycle phases, goldenbuild, Emiree gear, backlog protocol
- `IDUNA/CLAUDE.md` — auth model, migration rules, endpoint reference
- `PRRJECT_FATBABY/CLAUDE.md` — pipeline process list, event store invariants, emily-agent tools
- `emily.cli/CLAUDE.md` — full command reference, TUI layout, Apple/CHANGELOG/golden-index protocol
- `SHANKPIT/CLAUDE.md` — UDP FPS architecture, DragonsNShit bridge, season lineage
- `MJOLNIR/CLAUDE.md` — Android build, FCM push registration, notification channels

## Frame-Break Reframing

Founder-sourced prompting technique (REDGARDEN/NORTHSTAR.md §28, full origin in
REDGARDEN/docs2/MULTI_AGENT_RD_RESEARCH_NOTES.md §5): given a request, name the underlying
structural/systemic pattern it's one instance of — one level of abstraction up — as an added
lens during planning/triage/judgment calls. Use it to spot the general case behind a specific
ask. It augments judgment, it does not replace doing the work: direct, concrete execution of
the literal task asked for still happens every time.
