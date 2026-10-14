# BOOTSTRAP.md — fresh-box setup & how to reach IDUNA

Written 2026-10-14 for the next Claude. The founder rebuilds this VM from scratch each time and
forgets to mention a step or two. A prior session burned a lot of time on exactly the two traps
below — read this before trying to authenticate to anything.

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
- **Workspace gaps:** `go.work` lists `EDIS`, `PRRJECT_FATBABY`, `gpt2-alpine-c`, which aren't
  cloned, so any workspace-mode `go` command fails. Use `GOWORK=off` inside a module, or clone them.
- The default `IDUNA_BASE_URL` is `http://localhost:8080`; always override it (see step 4).

## History

- 2026-10-14: first bootstrap on this box, Apple #22255.
