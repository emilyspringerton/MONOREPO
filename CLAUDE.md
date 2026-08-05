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

**2. Apple Before Mark-Done** — Every `[x]` in BACKLOG.md requires a prior Apple:
```bash
emily apples post -t completion -repo <REPONAME> "<title>"
# Then mark [x] with Apple ID, commit EMILY/BACKLOG.md, push
```

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
One atomic thing per commit. Push immediately after — Emily Prime reads the latest state.

**7. Multi-repo changes** — Commit each repo independently in dependency order. Reference sibling commits in messages. Update `EMILY/BACKLOG.md` last.

**8. Always commit and push — standing instruction, do not wait to be asked.** When a unit of work is complete (tests pass, feature works, docs updated), commit and push immediately. This is the default behavior in every repo in this monorepo, not an exception that needs re-requesting each session. Only hold off if the user explicitly says to pause on committing for that specific piece of work.

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
