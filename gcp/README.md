# spicy_llm — GCP Cloud Run setup

Runs Ollama with both stock and heretic models on a Cloud Run L4 GPU instance.

## Service

- **URL:** https://spicy-llm-test-754683067800.us-central1.run.app
- **Project:** `worldarchitecture-ai`
- **Region:** `us-central1`
- **GPU:** NVIDIA L4 (24 GB VRAM)
- **Image:** `us-central1-docker.pkg.dev/worldarchitecture-ai/cloud-run-source-deploy/spicy-llm-ollama:gpu-l4`
- **Models pulled on cold start:** `gpt-oss:20b` (~13 GB) + `svjack/gpt-oss-20b-heretic` (~15 GB)

## Build & deploy

```bash
# Build image (from repo root)
cd gcp
gcloud builds submit \
  --tag us-central1-docker.pkg.dev/worldarchitecture-ai/cloud-run-source-deploy/spicy-llm-ollama:gpu-l4 \
  --timeout=15m .

# Deploy / update service
gcloud run deploy spicy-llm-test \
  --image=us-central1-docker.pkg.dev/worldarchitecture-ai/cloud-run-source-deploy/spicy-llm-ollama:gpu-l4 \
  --region=us-central1 \
  --gpu=1 --gpu-type=nvidia-l4 \
  --cpu=8 --memory=32Gi \
  --timeout=3600 --concurrency=1 --max-instances=1 \
  --allow-unauthenticated
```

## Usage

```bash
URL="https://spicy-llm-test-754683067800.us-central1.run.app"

# Check loaded models
curl "$URL/api/tags"

# Run a prompt (stock)
curl -s "$URL/api/generate" \
  -d '{"model":"gpt-oss:20b","prompt":"Explain a transistor in one sentence.","stream":false}' | python3 -c "import json,sys; print(json.load(sys.stdin)['response'])"

# Run a prompt (heretic)
curl -s "$URL/api/generate" \
  -d '{"model":"svjack/gpt-oss-20b-heretic","prompt":"Explain a transistor in one sentence.","stream":false}' | python3 -c "import json,sys; print(json.load(sys.stdin)['response'])"
```

## Tear down

```bash
gcloud run services delete spicy-llm-test --region=us-central1
gcloud artifacts docker images delete \
  us-central1-docker.pkg.dev/worldarchitecture-ai/cloud-run-source-deploy/spicy-llm-ollama:gpu-l4
```

## Notes

- Cold start (model pull) takes 10–20 min the first time (13 GB + 15 GB).
- Subsequent requests are warm (models cached on instance disk for 24 h via `OLLAMA_KEEP_ALIVE`).
- `OLLAMA_NUM_PARALLEL=1` prevents dual-load OOM.
- Ollama v0.30.5+ required for `gpt-oss:20b` (was 412 on v0.5.x).
