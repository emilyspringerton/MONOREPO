# GEMINI.md — Guidance for Gemini / Antigravity across EINHORN_INDUSTRIAL Monorepo

## What This Is

The EINHORN_INDUSTRIAL monorepo represents a multi-repository ecosystem sharing an overarching operating model: **The Emily Way**.

Authoritative cross-cutting documentation lives in:
- `MONOREPO/CLAUDE.md`: Authoritative ecosystem overview and repo directory.
- `EMILY/BACKLOG.md`: Canonical golden backlog.
- `EMILY/docs/THE_EMILY_WAY.md`: Operating philosophy and principles.

## Core Repositories & Tech Stacks

- **EMILY**: Meta-orchestration agent and RSI loop (:8086, Go).
- **emily.cli**: Human and agent operator CLI (`emily` binary, Go).
- **IDUNA**: Platform IAM, Apples ledger, central trust authority (:8080, Go).
- **SHANKPIT**: Server-authoritative UDP FPS (C/SDL2/OpenGL) + DragonsNShit world (Go/Dragonfly on :6969). Built via Bazel (`bazel build //...`) and Go.
- **BIG_O**: "A SHANKPIT Story" — social stealth, wasteland vector harvesting, off-books lab (C, Bazel).
- **PARENA**: Systems language with compile-time region memory safety.
- **MONOREPO**: The workspace anchor and documentation umbrella.

## The Emily Way — Standing Rules

1. **Backlog First**: Always check `EMILY/BACKLOG.md` before starting work.
2. **Route Founder Direction**: Any real-time direction routes through `emily observe -s info "Founder real-time: <summary>"` first.
3. **Apples Audit Trail**: Every completed task or cycle outcome must have an Apple filed (`emily apples post -t completion ...`).
4. **CHANGELOG**: Keep each repository's `CHANGELOG.md` updated with dated entries.
5. **Compression Standard**: LZ4 is the default compression algorithm monorepo-wide.
6. **CONSTRUCT Files (Principle 21)**: Every release pipeline repo publishes deterministic CONSTRUCT files on push.
7. **Commit & Push Protocol**:
   - Always commit and push immediately upon verification; do not wait to be asked.
   - Format: conventional commits (`feat:`, `fix:`, `docs:`, etc.).
   - Every commit message must end with a blank line and the active session tag trailer:
     ```
     session: <tag>
     ```
     (from `emily session current`).
