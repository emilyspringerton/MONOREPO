# ENVIRONMENT_BOOTSTRAP.md — clone the repos, get the toolchain up

**Status:** written 2026-10-31. This is the *environment* half of a bootstrap: which repos have to be
cloned and in what layout, plus the toolchain they need. `BOOTSTRAP.md` (repo root) is the other half —
reaching IDUNA in GKE, setting the gcloud project, and the `/home/fatbaby` path traps. Read this first,
then that one.

Each section is idempotent. Re-running it on a box that's already part-way through should be a no-op,
not a re-clone.

---

## 1. What "bootstrapped" means

The anchor repo (`MONOREPO`) is cloned, every sub-repo is cloned *inside it* as its own independent
git repo, `go.work` resolves, and `emily` is installed on `PATH`. Services do not need to be running
for any of that — service recovery is `start.sh` / `EMILY/docs/REBOOT_RUNBOOK.md`, not this doc.

| Path | What it is |
|---|---|
| `MONOREPO/` | this repo — the workspace anchor, `go.work`, docs umbrella, `*.sh` entry points |
| `MONOREPO/*/` | every other repo, each its own `.git` — **not** submodules, no pinned commits |

The historical home is `/home/fatbaby`. That path is hardcoded in `start.sh`, `run.sh`,
`emily session new`, and the CLI's default secrets paths, so either put the tree there or symlink it
(§6).

---

## 2. Prerequisites

| Tool | Why | Check |
|---|---|---|
| `git` | everything | `git --version` |
| an SSH key on the GitHub account | `git@github.com:` clone/push | `ssh -T git@github.com` → `Hi emilyspringerton!` |
| **Go 1.26.8** | `go.work` declares `go 1.26.8` | `go version` |
| `gcc`/`clang` + `make` | PARENA's C target, SHANKPIT, BIG_O | `cc --version` |
| `gcloud` + `kubectl` | GKE access to the `emily` namespace | `kubectl version --client` |
| `bazelisk` | SHANKPIT, BIG_O, PARENA CI parity | `bazel --version` |
| `python3` | `gpt2-alpine-c` tooling, assorted scripts | `python3 -V` |

No SSH key yet:

```bash
ssh-keygen -t ed25519 -C "$(whoami)@$(hostname)" -f ~/.ssh/id_ed25519
cat ~/.ssh/id_ed25519.pub      # add to github.com -> Settings -> SSH and GPG keys
ssh -T git@github.com          # expect "Hi <account>!"
```

HTTPS clones work too (the repos are public for read), but pushes need credentials either way —
SSH is the convention here, so the commands below use it.

---

## 3. Clone the anchor, then the repos inside it

```bash
export MONOREPO_DIR="${MONOREPO_DIR:-/home/fatbaby}"

git clone git@github.com:emilyspringerton/MONOREPO.git "$MONOREPO_DIR"
cd "$MONOREPO_DIR"

for repo in \
  EMILY IDUNA SHANKPIT PRRJECT_FATBABY emily.cli EDIS gpt2-alpine-c \
  PARENA BIG_O WOTAN OKEMILY NOOBTOPIA \
  NORN SKULDMARK
do
  [ -d "$repo" ] || git clone "git@github.com:emilyspringerton/$repo.git" "$repo"
done
```

`[ -d "$repo" ] ||` is what makes it re-runnable. Nothing here touches a repo that already exists,
so a partial box finishes rather than re-cloning 60 MB of `EMILY`.

**`NORN` and `SKULDMARK` are not `go.work` modules but are just as mandatory** (added 2026-11-03).
Five modules carry `replace norn => ../NORN` / `replace skuldmark => ./SKULDMARK`, so without those
two clones `go build` fails in `EMILY/emily-agent`, `IDUNA`, `PRRJECT_FATBABY`, `SHANKPIT` and
`emily.cli` while `EDIS` and `gpt2-alpine-c` still build — a failure pattern that reads like broken
code rather than a missing clone. Don't enumerate these by hand: ask the `go.mod` files.

```bash
find . -maxdepth 3 -name go.mod -not -path './.git/*' -print0 \
  | xargs -0 grep -hoE '=>[[:space:]]*\.{1,2}/[A-Za-z0-9._/-]+' \
  | sed -E 's/=>[[:space:]]*//; s#^(\.\./|\./)+##' | sort -u
```

---

## 4. Why each repo is on that list

Grouped by what breaks without it, so a stripped-down box can still be useful.

### Required by `go.work` — omit one and every workspace-mode `go` command fails

`go.work` `use`s seven paths. Four of them are *not* obviously part of "the monorepo" and were the
real gap on the last box (see `BOOTSTRAP.md` "Workspace gaps"):

| Path | Module purpose |
|---|---|
| `EMILY/emily-agent` | Emily Prime agent, RSI cron, FCM, ops agent (:8086) — **inside the EMILY clone**, not a separate repo |
| `IDUNA` | platform IAM, Apples ledger, HEIMDAL sprints (:8080) |
| `SHANKPIT` | server-authoritative UDP FPS + DragonsNShit world backend (:6969) |
| `PRRJECT_FATBABY` | SEC/PR financial signal pipeline + emily-agent |
| `emily.cli` | the `emily` operator binary — also the source of the `session:` commit trailer |
| `EDIS` | WordPress plugin suite (PHP; not part of `go test`, but `go.work` lists it) |
| `gpt2-alpine-c` | GPT-2 C inference engine + Emily Prime fine-tune pipeline |

### Required for real work, not for `go.work`

| Repo | Why clone it |
|---|---|
| `PARENA` | the language; "core deps are PARENA-first" is a standing rule, and it's the glue for the BIG_O/SHANKPIT/NOOBTOPIA merge (`docs/THREE_WAY_MERGE.md`) |
| `BIG_O` | "A SHANKPIT Story" — the IP; reference rules + parity vectors live here |
| `NOOBTOPIA` | ambient-behaviour data + the Roblox/Luau surface of that same merge |
| `WOTAN` | esports/stats hub, static HTML, deploys via `wotan-deploy.sh` |
| `OKEMILY` | okemily.com landing site, deploys via `okemily-deploy.sh` |

Deliberately **not** on the list: the game/asset/legacy repos (`GoblinFoxDragon`, `MJOLNIR`,
`EmilyOS`, `PITVIPER`, `GOLDENBAND`, `skateboard`, `FLASH`, forks …). `CLAUDE.md`'s repo table is the
authoritative catalogue of all of them; clone one individually when a task actually touches it. They
are not needed to build, test, or reach anything above.

---

## 5. Verify before you start working

```bash
cd "$MONOREPO_DIR"

# 1. every module go.work names actually exists
for p in EDIS EMILY/emily-agent IDUNA PRRJECT_FATBABY SHANKPIT emily.cli gpt2-alpine-c; do
  [ -d "$p" ] && echo "ok   $p" || echo "MISSING $p"
done

# 2. every module resolves and builds (this is the real test of the clone list)
#    NOT `go build ./...` from the anchor: the anchor has only go.work and no go.mod, so
#    `./...` fails with "directory prefix . does not contain modules listed in go.work".
for m in ./EDIS ./EMILY/emily-agent ./IDUNA ./PRRJECT_FATBABY ./SHANKPIT ./emily.cli ./gpt2-alpine-c; do
  go build "$m/..." && echo "ok    $m" || echo "FAIL  $m"
done

# 3. install the operator CLI — GOWORK=off, or it inherits the workspace and can fail on a module
#    you don't care about
(cd emily.cli && GOWORK=off ./scripts/build.sh)
emily --help
```

If `go build ./...` fails on a module you don't need, `GOWORK=off` inside that module is the documented
escape hatch — it is not a fix for a missing clone, and a missing clone is what this doc exists to
prevent.

---

## 6. Traps that cost the last session time

- **`/home/fatbaby` is hardcoded.** `start.sh`, `run.sh`, `emily session new`, and the CLI's default
  secrets paths all assume it. On a box rooted elsewhere, prefer `sudo ln -s "$MONOREPO_DIR" /home/fatbaby`
  over editing the scripts. Without it, `emily session new` dies with
  `mkdir /home/fatbaby: permission denied`.
- **The sub-repos are untracked in `MONOREPO`.** There is no `.gitmodules` and no `.gitignore`, so
  `git status` at the anchor shows every clone as `??`. Commit per-repo, in dependency order, and
  **never `git add -A` / `git add .` at the anchor** — you would stage 150 MB of other repos' files
  into `MONOREPO`'s own history.
- **A changed `EMILY` HEAD re-applies gitops**, which can scale a service you deliberately stopped
  back up (see `README.md`'s vLLM note).
- **Never commit secrets.** `EMILY/var/*.env`, `IDUNA/var/agent-secrets.env`, `EMILY/var/cloudflare.md`
  and friends are live credentials. Read them locally, never stage them, never paste them into docs.
- **`gcloud` has no default project after login**, so `projects list` looks empty and
  `get-credentials` returns a misleading `403`. Fix it per `BOOTSTRAP.md` step 2.

---

## 7. Keep the clones in sync

Commits are pushed immediately, in every repo, without waiting to be asked (`CLAUDE.md`
"Commit Protocol"). Every commit message ends with a blank line and the active session tag:

```
session: <tag>
```

`emily session current` prints it. If the CLI isn't installed yet, build a tag in the same shape:

```bash
sess-$(date -u +%Y%m%d-%H%M)-$(openssl rand -hex 4)
```

Pulling all repos at once — `/home/fatbaby` is not one repo, so loop:

```bash
cd "$MONOREPO_DIR"
for d in . EMILY IDUNA SHANKPIT PRRJECT_FATBABY emily.cli EDIS gpt2-alpine-c \
         PARENA BIG_O WOTAN OKEMILY NOOBTOPIA
do
  echo "== $d"; git -C "$d" pull --rebase --autostash
done
```

Dirty trees are common (agents leave work in progress); `--autostash` keeps a pull from stopping on
them, and the stash is restored afterwards. Check `git -C "$d" stash list` if a pull looks like it
lost something.

---

## 8. Next

1. `BOOTSTRAP.md` — gcloud project, cluster credentials, IDUNA port-forward, agent secret, Apples.
2. `EMILY/BACKLOG.md` — pick the highest-priority unchecked item in the lowest-numbered open section.
   That is the standing "before starting any work" rule, not a suggestion.
3. `EMILY/docs/THE_EMILY_WAY.md` — observe → backlog → Apple → CHANGELOG → commit protocol.

## History

- 2026-10-31: written after an environment rebuild where the `go.work` modules `EDIS`,
  `PRRJECT_FATBABY`, `emily.cli` and `gpt2-alpine-c` were the ones missing, while the eight
  "obvious" repos were all present.
