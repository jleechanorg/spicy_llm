# spicy_llm — GCP Cloud Run setup

L4 Ollama harness for spicy_llm refusal and decensoring research.

**Current target (local parity):**
- Model: `svjack/gpt-oss-20b-heretic:latest`
- Format: GGUF
- Quantization: Q4_K_M
- Digest observed on Cloud Run: `2d5466a49f621dd4ae654e5c4a349a7d2d4441ad6a6ff40c15779ee66bc7dd1f`

**Compatibility note:** The current `svjack/gpt-oss-20b-heretic` pull is a
Q4_K_M GGUF that runs on Cloud Run L4 with Ollama `0.12.3`. Earlier MXFP4
attempts failed with `CUDA error: device kernel image is invalid` on L4/sm_89;
do not generalize that failure to the current Q4_K_M GGUF target.

## Service

- **URL (after deploy):** https://spicy-llm-backend-elhm2qjlta-uc.a.run.app
  *(URL is stable across redeploys of the same service name)*
- **Service:** `spicy-llm-backend`
- **Project:** `ai-universe-2025`
- **Region:** `us-central1`
- **GPU:** NVIDIA L4 (24 GB VRAM)
- **Image:** `us-central1-docker.pkg.dev/ai-universe-2025/spicy-ollama-gpu/spicy-llm-ollama:gpu-l4`
- **Ollama:** `0.12.3` pinned for L4/sm_89 CUDA compatibility with gpt-oss.

Status: live in `ai-universe-2025` as `spicy-llm-backend`.

Open WebUI is live separately as `spicy-openwebui`:
https://spicy-openwebui-elhm2qjlta-uc.a.run.app

Its `OLLAMA_BASE_URL` is:
https://spicy-llm-backend-elhm2qjlta-uc.a.run.app

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
gcloud run deploy spicy-llm-backend \
  --image=us-central1-docker.pkg.dev/ai-universe-2025/spicy-ollama-gpu/spicy-llm-ollama:gpu-l4 \
  --project=ai-universe-2025 \
  --account=jleechan@gmail.com \
  --region=us-central1 \
  --gpu=1 --gpu-type=nvidia-l4 --no-gpu-zonal-redundancy \
  --cpu=8 --memory=32Gi \
  --port=11434 \
  --timeout=3600 --concurrency=1 --max-instances=1 \
  --set-env-vars=STOCK_MODEL=svjack/gpt-oss-20b-heretic,PULL_DERESTRICTED=false \
  --allow-unauthenticated
```

## Manual checks

After the service is live and the model has pulled:

```bash
URL="https://spicy-llm-backend-elhm2qjlta-uc.a.run.app"
MODEL="svjack/gpt-oss-20b-heretic:latest"

# Wait for model pulls to finish
curl -s "$URL/api/tags" | python3 -c "import json,sys; [print(m['name']) for m in json.load(sys.stdin)['models']]"
```

Use `/api/chat` for gpt-oss probes. `/api/generate` can spend the whole
`num_predict` budget in reasoning/thinking and return no final `response`.

```bash
curl -s "$URL/api/chat" \
  -H "Content-Type: application/json" \
  -d "$(python3 - <<'PY'
import json
print(json.dumps({
    "model": "svjack/gpt-oss-20b-heretic:latest",
    "messages": [{"role": "user", "content": "Name three large European rivers in one short sentence."}],
    "stream": False,
    "options": {"num_ctx": 2048, "num_predict": 256},
}))
PY
)" \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['message']['content'])"
```

## Tear down

```bash
gcloud run services delete spicy-llm-backend \
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

- Cold start for `svjack/gpt-oss-20b-heretic` usually takes several minutes while
  Ollama pulls the ~15 GB model.
- Set `PULL_DERESTRICTED=true` to attempt the derestricted model. Add
  `REQUIRE_DERESTRICTED=true` only for research runs where the service should fail
  closed if the derestricted pull fails.
- HF GGUF pull requires Ollama ≥ 0.4.x. The container pins `0.12.3` because a
  later `0.30.5` runner reproduced `CUDA error: device kernel image is invalid`
  on Cloud Run L4/sm_89 during generation.
- Subsequent requests are warm (models cached for 24 h via `OLLAMA_KEEP_ALIVE`).
- `OLLAMA_NUM_PARALLEL=1` prevents dual-load OOM.
- For MXFP4 models such as original `gpt-oss:20b`, use Blackwell GPU rather than
  L4. The current heretic target is Q4_K_M GGUF, not MXFP4.
- Bead: jleechan-y39
