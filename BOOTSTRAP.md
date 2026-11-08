# BOOTSTRAP.md — fresh-box setup & how to reach IDUNA

Written 2026-10-14 for the next Claude. The founder rebuilds this VM from scratch each time and
forgets to mention a step or two. A prior session burned a lot of time on exactly the two traps
below — read this before trying to authenticate to anything.

**This doc starts at step 0 = "the repos are already cloned."** If the box is genuinely fresh, do
`docs/ENVIRONMENT_BOOTSTRAP.md` first — toolchain plus the full clone list (the four `go.work`
modules that are easy to miss: `EDIS`, `PRRJECT_FATBABY`, `emily.cli`, `gpt2-alpine-c`).

## TL;DR — the two traps

1. **`iam.okemily.com` is NOT how agents reach IDUNA.** It's the human SSO login domain
   (`IDUNA/ops/nginx/iam-okemily.conf`). IDUNA runs in GKE (namespace `emily`, `svc/iduna`,
   **no ingress**). Agents/CLI go through a port-forward:
   `kubectl port-forward -n emily svc/iduna 18080:8080` → `IDUNA_BASE_URL=http://localhost:18080`.
   (Agent auth happens to also answer on `iam.okemily.com`, which is what misled the last session.
   Don't use it. Also: `localhost:8080` is NOT IDUNA here — it returns an HTML 404.)
2. **`gcloud config set project` must be run.** The login the founder does leaves *no default
   project*, so `gcloud projects list` is empty and `get-credentials` gives a misleading
   `403 container.clusters.get`. The account is fine; the project just isn't set.

## Cluster facts

| | |
|---|---|
| GCP project | `project-d24a71e9-2daf-4b2d-917` |
| Cluster | `prrject-fatbaby` (region `us-central1`) |
| Namespace | `emily` (IDUNA is `deploy/iduna`, container `iduna`; pod has 4 containers) |

## Steps (idempotent)

```bash
# 0. PATH — gcloud lives in ~/google-cloud-sdk; go in ~/.local/go; emily in ~/.local/bin
export PATH="$HOME/.local/go/bin:$HOME/.local/bin:$HOME/google-cloud-sdk/bin:$PATH"
export USE_GKE_GCLOUD_AUTH_PLUGIN=True

# 1. one-time installs if missing: go 1.26.x (go.dev/dl), then
gcloud components install kubectl gke-gcloud-auth-plugin --quiet
#    If that errors with "installation root of the Cloud SDK could not be located" (it does on the
#    /tools/google-cloud-sdk image, because there is no component manager metadata), install kubectl
#    straight from upstream instead — same binary, no component manager:
#    KV=$(curl -sSL https://dl.k8s.io/release/stable.txt)
#    curl -sSLo "$HOME/.local/bin/kubectl" "https://dl.k8s.io/release/$KV/bin/linux/amd64/kubectl"
#    chmod +x "$HOME/.local/bin/kubectl"
#    (gke-gcloud-auth-plugin has no such standalone path here; it only matters once you're authenticated,
#    at which point an authenticated `gcloud components install` may also start working.)

# 2. THE STEP THAT GETS FORGOTTEN
gcloud config set project project-d24a71e9-2daf-4b2d-917
gcloud container clusters get-credentials prrject-fatbaby --region us-central1
kubectl get pods -n emily          # sanity check

# 3. build + install the emily CLI (GOWORK=off — see "Workspace gaps" below)
cd emily.cli && GOWORK=off ./scripts/build.sh

# 4. reach IDUNA
kubectl port-forward -n emily svc/iduna 18080:8080 &
export IDUNA_BASE_URL=http://localhost:18080
export IDUNA_AGENT_NAME=EMILY-PRIME            # HYPHEN, not underscore (EMILY_PRIME fails)
export IDUNA_AGENT_SECRET=<see below>
emily agents list                  # should print the agent/Apple table
```

## Getting the agent secret

The founder usually hands you one. If not, pull the live value from the pod (local copies drift):

```bash
kubectl exec -n emily deploy/iduna -c iduna -- cat /app/var/agent-secrets.env
```

Lines look like `export IDUNA_SECRET_<NAME>=...` (e.g. `IDUNA_SECRET_CLAUDE3`).
The agent *name* and the secret must match as a pair; a bad pair returns a deliberately generic
`401 AGENT_AUTH_FAILED "invalid agent credentials"` — it does not say whether the agent is
missing, inactive, credential-less or the secret is wrong (`IDUNA/internal/store/sqlite.go`
`AuthenticateAgent`). Don't brute-force names.

**`EMILY/var/iduna_key` is not reliable.** On 2026-10-14 it held a 64-hex value that IDUNA
rejected for `clade3`. The pair that worked was `EMILY-PRIME` + the secret the founder pasted.
Treat that file as a hint, not truth. **Never commit secrets or paste them into docs.**

## Posting an Apple

`emily apples post` needs a title **and a body** (stdin or arg) plus a run_id, else
`400 source_repo, run_id, apple_type, title, and body are required`:

```bash
emily apples post -t completion -r EMILY --run-id "$(emily session current)" "<title>" "<body>"
```

## Known gaps on this box (not fixed)

- **`/home/fatbaby` is hardcoded** in `emily session new`, the CLI's default secrets paths and
  `start.sh`/`run.sh`. This box is `/home/ubuntu/MONOREPO`. `emily session new` fails with
  `mkdir /home/fatbaby: permission denied` (no sudo). Workaround: build a tag by hand,
  `sess-$(date -u +%Y%m%d-%H%M)-$(openssl rand -hex 4)`, and pass `--run-id`. Real fix:
  `sudo ln -s /home/ubuntu/MONOREPO /home/fatbaby`.
- **Workspace gaps:** `go.work` lists `EDIS`, `PRRJECT_FATBABY`, `emily.cli`, `gpt2-alpine-c`, which
  weren't cloned, so any workspace-mode `go` command failed. Fix is to actually clone them — the loop
  is in `docs/ENVIRONMENT_BOOTSTRAP.md` §3; `GOWORK=off` only papers over it per-module.
  **`NORN` and `SKULDMARK` are two more** (found 2026-11-03): neither is a `go.work` module, but five
  modules `replace` them by local path, so a box missing them builds `EDIS`/`gpt2-alpine-c` fine and
  fails five others with `reading NORN/go.mod: no such file`. Both are in §3's clone loop now.
- **`go build ./...` at the anchor is not a valid check** — the anchor has `go.work` and no `go.mod`,
  so it exits 1 with `directory prefix . does not contain modules listed in go.work`. Build per
  module (`go build ./IDUNA/...`); §5 of the environment doc has the loop.
- The default `IDUNA_BASE_URL` is `http://localhost:8080`; always override it (see step 4).

## History

- 2026-10-14: first bootstrap on this box, Apple #22255.
- 2026-11-03: bootstrap on a `/content/MONOREPO` box (Claude Code web sandbox, root, no gcloud login).
  Go 1.26.8 → `~/.local/go`, kubectl v1.37.2 standalone → `~/.local/bin`, `emily` 1.0.0 built
  (`GOWORK=off ./scripts/build.sh`) and all seven `go.work` modules build clean. `NORN` + `SKULDMARK`
  discovered as required-but-unlisted clones. `/home/fatbaby` symlinked to the box's real path, so
  `emily session new` works here. **Blocked at step 2:** `gcloud auth list` shows `No credentialed
  accounts`, so the project/cluster/IDUNA-port-forward half genuinely needs the founder's
  `gcloud auth login` — nothing local can substitute for it.
- 2026-11-03 (second run, same `/content/MONOREPO` box, root, gcloud installed at
  `/tools/google-cloud-sdk`): the box had reset to toolchain-less again, so §2-§6 of the environment
  doc were re-run from scratch. Go 1.26.8 → `~/.local/go`, kubectl v1.37.2 standalone →
  `~/.local/bin` (the `gcloud components install` "installation root ... could not be located" error
  is confirmed live on this image), 14 repos cloned over SSH (IDUNA/SHANKPIT/PARENA were already
  present), all seven `go.work` modules build clean, `emily` 1.0.0 installed, `/home/fatbaby`
  symlinked so `emily session new` works. Note: do **not** export `GOFLAGS=-mod=mod` here — workspace
  mode rejects it and every module "fails" with a misleading `-mod may only be set to readonly`.
  Same step-2 blocker as the earlier run: `gcloud auth list` → `No credentialed accounts`, so the
  project/cluster/IDUNA half still needs the founder's `gcloud auth login`.
- 2026-11-04 (third run, same `/content/MONOREPO` box, root, gcloud at `/tools/google-cloud-sdk`):
  toolchain was gone again, so §2-§6 were re-run. Go 1.26.8 → `~/.local/go`, kubectl v1.37.2
  standalone → `~/.local/bin`, eight repos cloned (EDIS, PRRJECT_FATBABY, emily.cli, gpt2-alpine-c,
  OKEMILY, NOOBTOPIA, NORN, SKULDMARK — PARENA/BIG_O/WOTAN already present), all seven `go.work`
  modules build clean, `emily` 1.0.0 installed, `/home/fatbaby` symlinked and writable, existing
  session `sess-20261103-0121-04484fc1` picked up. **Step 2 still blocked:** no credentialed gcloud
  account, so `get-credentials` fails with "You do not currently have an active account selected".
  `gcloud config set project` does now stick — only the account is missing.
- 2026-11-04 (fourth run, same `/content/MONOREPO` box, root, gcloud at `/tools/google-cloud-sdk`):
  toolchain gone again, so §2-§6 re-ran. Go 1.26.8 → `~/.local/go`, kubectl v1.37.2 standalone →
  `~/.local/bin` (the `gcloud components install` root error is still live on this image, so the
  upstream kubectl path remains the only working one), eight repos cloned (PRRJECT_FATBABY,
  emily.cli, EDIS, gpt2-alpine-c, OKEMILY, NOOBTOPIA, NORN, SKULDMARK), all seven `go.work` modules
  build clean, `emily` 1.0.0 installed, `/home/fatbaby` symlinked and writable, PATH and
  `USE_GKE_GCLOUD_AUTH_PLUGIN` now persisted in `~/.bashrc` so step 0 isn't hand-typed each shell.
  Existing session `sess-20261103-0121-04484fc1` picked up. **Step 2 blocked again:** `gcloud auth
  list` → `No credentialed accounts`, so `get-credentials` fails on "no active account" and
  `kubectl get pods -n emily` returns `the server could not find the requested resource`. Same
  verdict as the two runs before it: nothing local substitutes for the founder's `gcloud auth login`.
- 2026-11-08 (`/home/ubuntu/MONOREPO` box, user `ubuntu`, **no sudo**, gcloud at `/tools/google-cloud-sdk`):
  EMILY/IDUNA/SHANKPIT/PARENA/GOLDENBAND present; eleven repos cloned (PRRJECT_FATBABY, emily.cli, EDIS,
  gpt2-alpine-c, BIG_O, WOTAN, OKEMILY, NOOBTOPIA, NORN, SKULDMARK). System `/usr/bin/go` auto-fetched
  the 1.26.8 toolchain via `GOTOOLCHAIN`, so no `~/.local/go` install was needed. kubectl v1.37.2 standalone
  → `~/.local/bin`, all seven `go.work` modules build clean, `emily` 1.0.0 installed. **New trap:** the image
  exports `CLOUDSDK_CONFIG=/content/.config`, which `ubuntu` can't write, so every gcloud command errors with
  `Unable to create private file [/content/.config/credentials.db]`. Fix: `export CLOUDSDK_CONFIG=$HOME/.config/gcloud`
  (now in `~/.bashrc` with PATH). `/home/fatbaby` symlink not made (no sudo), so `emily session new` still
  needs the hand-built tag. **Step 2 blocked as before:** `No credentialed accounts` — needs the founder's
  `gcloud auth login`.

## 2026-11-08 — LLVM 18 wasm toolchain without sudo (PARENA wasm builds)

`build_brawlpit_wasm.sh` and the other PARENA wasm scripts expect LLVM 18 at `~/.local/opt/llvm-toolchain`.
`wasm-ld` lives in **`lld-18`**, which the recipe in `PARENA/docs/LLVM_BACKEND_NORTHSTAR.md` leaves out.
Verified on this box:

```
mkdir -p /tmp/llvmdeb && cd /tmp/llvmdeb
apt-get download llvm-18 lld-18 libllvm18 liblld-18
for d in *.deb; do dpkg-deb -x "$d" ~/.local/opt/llvm-toolchain; done
LLVM_TOOLCHAIN_ROOT=~/.local/opt/llvm-toolchain PARENA/scripts/build_brawlpit_wasm.sh /tmp/bp.wasm
```

The script's zero-import check only runs when `node` is installed, and it prints "0 imports" either way.

## 2026-11-03 — what `make lobby` actually needs on a fresh box

Found while wiring the salvage slices. Seven packages and two sibling checkouts, in the order they bite:

```
apt-get install -y libsdl2-dev libsdl2-ttf-dev libgl1-mesa-dev libglu1-mesa-dev libmbedtls-dev
git clone ../EDITOR.GAME     # the lobby links editor_full.o; without it: "No rule to make target ... editor_stdlib_gen.c"
git clone ../PELLEGRINO      # then `bash scripts/fetch_mbedtls.sh` -- its vendored mbedtls has
                             # memory_buffer_alloc, which the system package does not, and the phone browser needs it
```

`make server` needs none of that and is the check to prefer for simulation work. Also: the repo's own
`LOBBY_SRC` was missing `packages/simulation/dw_play.c` (eleven `dw_play_*` symbols undefined) — fixed in
SHANKPIT, so a stale checkout will still show that error and is not this box's problem.
