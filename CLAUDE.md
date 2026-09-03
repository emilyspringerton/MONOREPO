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
| `BURROW` | Go + PARENA | New repo (2026-08-30) — a full, feature-for-feature parallel rewrite of the entire PARENA compiler (lexer/parser/region-analyzer/every emit target), written in Go + PARENA itself, leaning directly on PARENA's own already-in-progress self-hosting effort (`selfhost/*.prn`). Corrected in real time from an initial narrower mis-scope ("just a new Go backend"); founder-named Phase 0 acceptance bar: a pure Go+PARENA tool that passes `parena-c`'s own real C test corpus. Phases 1-2 (lexer + parser parity) shipped: real, faithful hand-ports of `src/lexer.c`/`src/parser.c`, verified against all 23 real C-reference test assertions plus a full 111-file real-corpus stress test (zero failures). Still includes a new, native Go emission target designed GC-off-safe, plus a "dogfood it" directive applying that same low-allocation discipline to `burrow`'s own Go implementation. `DUNG` (own row below) is its real, live, flagship dogfooding consumer. Full rationale and phased plan in `BURROW/NORTHSTAR.md`. |
| `DUNG` | Go + PARENA (planned) | New repo (2026-08-30), NORTHSTAR only — "the BURROW editor": a unified terminal emulator + editor rewriting `PITVIPER` (SDL2 terminal, untouched, stays as-is — same real "new fork, not rewrite-in-place" precedent `SAND` already set) and PARENA's own real `stdlib/editor/*.prn` into one application. Bazel-built; the editor domain is a ground-up PARENA-native port compiled via the real `burrow` CLI (not `parena-c` directly) — DUNG is `BURROW`'s own real, live, flagship dogfooding consumer, and its own build is gated on `BURROW`'s own Phase 3-4 (emit capability) landing first. Real UX foundation adopted directly, not invented: `EmilyOS/docs/legacy-archive/gui-v0.1-design-capture.md`'s own already-written "tmux × i3 hybrid" layout model + no-single-click double-click-speed interaction contract + posture-aware non-modal safety feedback. Real new features named: a visor-style drop-down terminal, i3-primitive split panes, a drag-and-drop/load-from-URL chat pane (matching `PITVIPER`'s own already-planned Emily Prime pane milestone). Full rationale and phased plan in `DUNG/NORTHSTAR.md`. No code yet. |
| `MISHRI` | JavaScript (Node/mineflayer) | Forked 2026-08-30 from [arpitrajjj/Mishri](https://github.com/arpitrajjj/Mishri) (external, not affiliated with this org) — a human-like Minecraft bot (mineflayer-based movement/chat/perception jitter, mood system) intended for use against this org's own `EINHORN_SURVIVAL` server; use at own risk, `package.json` declares ISC but no `LICENSE` file is present in this fork so the actual terms are ambiguous (see `MISHRI/README.md`'s own "Author & License" section). Real Bazel build added (`bazel test //:test` — hermetic humanness-layer coverage, no `npm install` needed; `bazel run //:install`/`//:mishri` wrap the real, non-hermetic `npm ci`/`npm start`), plus a real CI "Generate Construct Bundle" step matching PARENA's own established convention. |
| `LO` | Esolang (planned) | New repo (2026-08-30), upstream pre-created ahead of the ask, real critical scoping review only — no compiler code yet. A hyper-minimalist esolang (emojis + colons + one literal vector-constructor string as the entire alphabet, nested ternaries over PARENA's own real base4 state space) sitting under a real, higher-level Lisp-like frontend (`qi`), compiling down to real `.prn` source text for the existing `parena`/`burrow` CLIs to turn into C/TS/Java/Go — LO/`qi` adds no new backend emitters of its own. Source design doc (`LO/LoLanguageSpec.pdf`, a captured Gemini chat transcript) reviewed and critiqued directly, not rubber-stamped: real gaps found (no formal grammar, emoji-tokenization ambiguity, loops/error-handling explicitly unfinished, a real code-size-blowup risk in the spec's own `let`-lowering scheme). Real, current capability audit: `parena` (defstruct/defenum/match/loop/Vec/FFI, real and mature) can plausibly reach most of LO's real feature surface; `burrow` (scalar+flat-struct only, no `let`/construction/`defenum`/`match`/`loop`/`Vec`) can only reach a scalar/flat-struct LO subset — the same real boundary `PARENA`'s own `stdlib/k8s/k8s.prn` vs. `stdlib/k8s/scaling.prn` already drew. Real, phased plan (grammar → LO-to-`.prn` on the narrowest real slice → `qi`'s own frontend → vectors/matrices/patterns/unions) in `LO/NORTHSTAR.md`. |
| `FLASH` | Bash | Forked 2026-08-30 from [`hypriot/flash`](https://github.com/hypriot/flash) (real, credited prior art — a command-line SD-card image writer with WiFi/hostname cloud-init customization) — founder real-time: "we forked it," part of the larger FLASH/HypriotOS/EmilyOS-Pi/PARENA-distro thread (S213). Real Bazel build added (`bazel test //:syntax-check` — hermetic `bash -n`, shellcheck not installed in this sandbox so this is real but narrower than CI's own Docker-shellcheck check, not a silent substitute; `bazel run //:run-flash`/`//:test` wrap the real, non-hermetic script itself / the existing privileged-Docker Bats suite). Two real, found-live Bazel gotchas fixed: an sh_binary target named identically to a real sibling source file is a genuine self-edge dependency cycle (renamed to `:run-flash`); a naive relative `dirname "$0"` path doesn't resolve for a target's own primary executable inside Bazel's runfiles tree (fixed via `$RUNFILES_DIR`). Real, honest, not yet started: the script itself is Mac/Linux-only and explicitly refuses WSL1/WSL2 — no Windows/Git-Bash (MSYS) support exists yet, the founder's own real, current blocker (they're on Windows) for actually running it end-to-end. |
| `image-builder-rpi` | Shell + Vagrant/Docker | Forked 2026-08-30 from [`hypriot/image-builder-rpi`](https://github.com/hypriot/image-builder-rpi) (real, credited prior art — the tool that BUILDS the HypriotOS SD-card image itself, distinct from `FLASH`, which WRITES an already-built image to a card) — same S213 thread, "we forked all the deps" (also includes forks of `hypriot/os-rootfs`, `hypriot/rpi-kernel`). Not yet touched — real, current plan per the founder's own explicit sequencing is to get an existing, already-released upstream HypriotOS image flashed via `FLASH` first ("get something installable"), before touching this repo's own from-scratch image-build pipeline (which needs Vagrant/VirtualBox/Docker+guestfish, a real, separate, heavier lift). |
| `MIXFORGE` | PARENA (planned) | New repo, real source doc pulled in 2026-09-03: `legacy.txt`, a captured AI chat transcript reaching a real, concrete C++/JUCE/Essentia/RubberBand/yt-dlp/SQLite DJ-app design — explicitly rejected here per the founder's own "not the one discussed, built with PARENA" instruction; this repo commits to PARENA end to end instead, the same dogfooding discipline PITVIPER/DUNG/SAND/ECOWAR already follow. Real, preserved feature set from the transcript: paste-a-YouTube-URL track import (with an optional second URL for a separately-supplied instrumental, not AI stem separation) as the explicit first feature, a SQLite-shaped track library, BPM/key detection for harmonic mixing, and Traktor-referenced crossfade/beatmatching (time-stretch/pitch-shift). PARENA-native mapping: built-in `sdl2` + (design-only) `media/audio`/`codec` for playback, real `stdlib/shell.prn` shelling out to the real `yt-dlp` binary for import, FFI-bound `libsqlite3` for the library, and a genuinely new gap named (not just unimplemented, never previously scoped anywhere): key/BPM detection has no PARENA story at all, FFI-binding `aubio` (the transcript's own lighter-weight alternative to Essentia) is the leading real candidate pending its own scoping pass. Licensing explicitly, knowingly deferred per the transcript's own founder quote, not solved. 6-phase delivery plan (import/library first, then playback, then detection, then beatmatching, then streaming) in `MIXFORGE/NORTHSTAR.md`. No code yet. |
| `EMILY_FOR_BUSINESS` | TBD | New repo (2026-09-03), licensing-only so far — upstream pre-created empty, pulled in this session. Real product scope lives in `IDUNA/docs/EMILY_FOR_BUSINESS_NORTHSTAR.md` (S243-02), a grounded scoping pass for the founder's own framing "IDUNA IS THE PRODUCT BASICALLY ZERO TRUST SECURITY AGENT NATIVE" — names a real, direct tension against IDUNA's own standing "not a product, it is the backbone" line, not yet resolved. This repo currently holds **The Emily License v0** (`LICENSE.md`, a real custom source-available license: internal use/modification permitted, offering the software as a platform/hosted service to third parties or redistributing it requires a separate commercial agreement, real explicit liability cap) plus `TRADEMARK.md` (separate name/branding policy, modeled directly on Chef Software's real code-license-vs-trademark-policy split — Chef's own code is actually Apache 2.0, the "Chef model" applied here is specifically the trademark separation, not a source-available code license). Neither legal document has been reviewed by a lawyer yet — both say so explicitly. No product code here yet. |
| `IDUNA_PRO` | Go | New repo (2026-09-03) — the real, standalone, extracted core of `IDUNA`, per founder direction: "we pull some of the more custom stuff out of iduna and the code goes right into the emily for business product IDUNA_PRO." Google OAuth + local password auth, ES256 JWT (hand-rolled on `crypto/ecdsa`, no external JWT library) + refresh/JWKS, M2M agent auth, device flow, hierarchical RBAC, an append-only "Apples" audit ledger, and the unified Splunk-shaped logging backend — checked directly before extraction: zero cross-imports from these packages into any of IDUNA's monorepo-custom code (blog/tyler/promptoverse/mailinglist/vault/drive/statuspage/backlog-kanban). `GOWORK=off` standalone module (own `go.mod`, not part of this monorepo's `go.work`). `go build/vet/test ./...` clean; live-verified booting the real binary against a fresh SQLite file (migrations create exactly the expected core tables), a real self-serve register+login flow issuing a real ES256 JWT. Real, honest, found gap, not fixed yet: `GET /api/v1/identities/me` doesn't resolve a local-auth JWT subject (`local:<N>`) — inherited from IDUNA itself, matters more here since this product leans on self-serve/local auth. `IDUNA` itself is the real control plane that will provision/track `IDUNA_PRO` tenant trials (not built yet, see `IDUNA/docs/EMILY_FOR_BUSINESS_NORTHSTAR.md`). Real, phased, not-yet-built extensibility plan in that same doc: customer-side PARENA mods compiled via `BURROW`'s native Go emission target (not PARENA's own C target — `IDUNA_PRO`'s host is Go, the same real reason `DUNG` needs the Go target too), with `JEWEL` named as a real precedent for an eventual online editor, needing real adaptation rather than reuse as-is. |
| `SPIDERBEETLE` | Java + PARENA | New repo, upstream created by the founder 2026-09-03 for kanban cruise-queue card 32445324, "PARENA android app in JAVA using PARENA using the JAVA emitter." Real, checked-in generated `app/src/main/java/industrial/einhorn/spiderbeetle/generated/BatteryUi.java`, compiled from PARENA's own real `stdlib/android/battery_ui.prn` via PARENA's Java emitter (at its own real Maven/Gradle-convention output path so the package declaration derives automatically) — two real, minimal scalar decision functions (low-battery-warning, brightness-clamp) verified with an actual JDK (`javac`/`java 25.0.4`) against `smoke_test/Main.java`, 7 real assertions, all pass. Found and fixed a real, genuine PARENA compiler bug along the way (in PARENA itself): `(not x)` had no handling anywhere in `src/emit_java.c`, the same real gap already fixed in `src/emit.c` and `BURROW`'s own `emit_c.go`/`emit_go.go`. Real, honest, not yet built: an actual Android project (Gradle/Manifest/Activity) — checked directly, this sandbox has no Android SDK at all, and `MJOLNIR` itself (this monorepo's own real, existing Android app) has no `gradlew` wrapper checked out locally either, confirming even that established app is never actually built here, only via real CI/the founder's own machine. Unlicense (public domain), matching `SKULDMARK`'s own convention. Real, concrete next steps (Gradle skeleton templated on `MJOLNIR`'s own, wiring into a real `BatteryManager`/`WindowManager` Activity callback, a real CI step with the Android SDK) named in `NORTHSTAR.md`, none started. |

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
