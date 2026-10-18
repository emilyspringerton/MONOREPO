# MONOREPO

## Coding engine (vLLM + Qwen2.5-Coder-14B) on GKE

A self-hosted OpenAI-compatible coding model in the `emily` namespace. It is an **API, not a website**: you reach it through a `kubectl port-forward` tunnel and talk to it with a coding agent such as Aider.

- Manifest: `EMILY/gitops/clusters/prrject-fatbaby/47-vllm-coder.yaml` (also in `EMILY/gitops/render.sh`); gitops-sync applies it.
- Cluster is **Autopilot**: no node pools. The Spot NVIDIA L4 node is created when the pod is scheduled and removed when it goes away.
- Model is `Qwen/Qwen2.5-Coder-14B-Instruct` with `--quantization fp8` (bf16 is ~28 GB and does not fit the L4's 24 GB). Context is 8192 tokens.
- Weights download into an `emptyDir` on every start (no PVC): expect ~5-10 min cold start.

### Start / stop (stop = no GPU billing)

```bash
kubectl scale deploy/vllm-coder-engine -n emily --replicas=1   # start
kubectl scale deploy/vllm-coder-engine -n emily --replicas=0   # stop when idle
```

Caveat: gitops re-applies `replicas: 1` whenever the EMILY repo HEAD moves. If you scaled to 0 and anything is pushed, scale to 0 again.

### Watch it come up

```bash
kubectl get pods -n emily -l app=vllm-coder-engine -w          # Pending -> Running -> 1/1 READY
kubectl logs -n emily deploy/vllm-coder-engine -f              # download progress, then "Application startup complete"
kubectl exec -n emily deploy/vllm-coder-engine -- du -sh /root/.cache/huggingface
```

Stuck in `Pending` with `GCE out of resources` means Google has no Spot L4s free in that zone. Retry later, or remove `cloud.google.com/gke-spot: "true"` from the manifest to use on-demand (about 2-3x the price, much likelier to get a GPU).

### Use it

Terminal 1 (leave open; restart it after every scale-up):

```bash
kubectl port-forward -n emily svc/coder-engine-service 8000:8000
```

Terminal 2:

```bash
curl localhost:8000/v1/models        # returns JSON once ready
pip install aider-chat
export OPENAI_API_BASE=http://localhost:8000/v1
export OPENAI_API_KEY=dummy          # vLLM does not check it
cd your-project
aider --model openai/Qwen/Qwen2.5-Coder-14B-Instruct --map-tokens 512
```

The service is ClusterIP only and has no auth; do not expose it publicly.
