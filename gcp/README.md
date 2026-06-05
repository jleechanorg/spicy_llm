# spicy_llm — GCP Cloud Run setup

L4 Ollama harness for Phase 1 A/B abliteration research.

**Option A (current — Q4_K_M GGUF, L4-compatible):**
- Stock:       `hf.co/unsloth/gpt-oss-20b-GGUF:gpt-oss-20b-Q4_K_M` (~10 GB)
- Optional derestricted: `hf.co/Mungert/gpt-oss-20b-Derestricted-GGUF:gpt-oss-20b-Derestricted-q4_k_m` (~16 GB)

**Why Option A:** Prior attempt (2026-06-05) used MXFP4 gpt-oss:20b + svjack/gpt-oss-20b-heretic.
Both failed with "device kernel image is invalid" — MXFP4 requires Blackwell (sm_100+), not L4
(Ada Lovelace, sm_89). Option A uses Q4_K_M GGUF pulled from HuggingFace, which runs on any
CUDA-capable GPU. See `results/2026-06-05_gcp-phase1-rerun/`.

## Service

- **URL (after deploy):** https://spicy-llm-test-elhm2qjlta-uc.a.run.app
  *(URL is stable across redeploys of the same service name)*
- **Project:** `ai-universe-2025`
- **Region:** `us-central1`
- **GPU:** NVIDIA L4 (24 GB VRAM)
- **Image:** `us-central1-docker.pkg.dev/ai-universe-2025/spicy-ollama-gpu/spicy-llm-ollama:gpu-l4`
- **Ollama:** `0.12.3` pinned for L4/sm_89 CUDA compatibility with gpt-oss.

Status: live in `ai-universe-2025` as `spicy-llm-test`.

## Build & deploy

```bash
# Build image (from gcp/ dir)
cd /path/to/spicy_llm/gcp
gcloud builds submit \
  --project=ai-universe-2025 \
  --account=jleechan@gmail.com \
  --tag us-central1-docker.pkg.dev/ai-universe-2025/spicy-ollama-gpu/spicy-llm-ollama:gpu-l4 \
  --timeout=20m .

# Deploy / update service
gcloud run deploy spicy-llm-test \
  --image=us-central1-docker.pkg.dev/ai-universe-2025/spicy-ollama-gpu/spicy-llm-ollama:gpu-l4 \
  --project=ai-universe-2025 \
  --account=jleechan@gmail.com \
  --region=us-central1 \
  --gpu=1 --gpu-type=nvidia-l4 --no-gpu-zonal-redundancy \
  --cpu=8 --memory=32Gi \
  --port=11434 \
  --timeout=3600 --concurrency=1 --max-instances=1 \
  --set-env-vars=PULL_DERESTRICTED=false \
  --allow-unauthenticated
```

## Run Phase 1 probes

After the service is live and the stock model has pulled (~5–10 min cold start):

```bash
cd /path/to/spicy_llm
URL="https://spicy-llm-test-elhm2qjlta-uc.a.run.app"

# Wait for model pulls to finish
curl -s "$URL/api/tags" | python3 -c "import json,sys; [print(m['name']) for m in json.load(sys.stdin)['models']]"

# Run automated Phase 1 A/B probes (requires both models loaded)
./scripts/run_phase1_probes.sh "$URL"
```

Results land in `results/<DATE>_gcp-phase1-option-a/responses/`.

## Manual checks

```bash
URL="https://spicy-llm-test-elhm2qjlta-uc.a.run.app"

# Check loaded models
curl -s "$URL/api/tags"

# Quick benign sanity check (run first to confirm model + refusal rate)
STOCK="hf.co/unsloth/gpt-oss-20b-GGUF:gpt-oss-20b-Q4_K_M"
curl -s "$URL/api/generate" \
  -d "{\"model\":\"$STOCK\",\"prompt\":\"Name three large European rivers.\",\"stream\":false}" \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['response'])"
```

## Tear down

```bash
gcloud run services delete spicy-llm-test \
  --project=ai-universe-2025 \
  --account=jleechan@gmail.com \
  --region=us-central1 \
  --quiet
gcloud artifacts docker images delete \
  us-central1-docker.pkg.dev/ai-universe-2025/spicy-ollama-gpu/spicy-llm-ollama:gpu-l4 \
  --project=ai-universe-2025 \
  --quiet
```

## Notes

- Cold start for the stock model usually takes 5–10 min. Pulling both models can
  take 30–40 min and may exceed the practical writable cache budget on Cloud Run.
- Set `PULL_DERESTRICTED=true` to attempt the derestricted model. Add
  `REQUIRE_DERESTRICTED=true` only for research runs where the service should fail
  closed if the derestricted pull fails.
- HF GGUF pull requires Ollama ≥ 0.4.x. The container pins `0.12.3` because a
  later `0.30.5` runner reproduced `CUDA error: device kernel image is invalid`
  on Cloud Run L4/sm_89 during generation.
- Subsequent requests are warm (models cached for 24 h via `OLLAMA_KEEP_ALIVE`).
- `OLLAMA_NUM_PARALLEL=1` prevents dual-load OOM.
- For MXFP4 models (original gpt-oss:20b, svjack heretic): need Blackwell GPU, not L4.
- Bead: jleechan-y39
