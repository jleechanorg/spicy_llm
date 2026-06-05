#!/usr/bin/env bash
# entrypoint.sh — start Ollama, pull both models, keep the container alive.
# Designed for Cloud Run with L4 GPU. Idempotent: skips pulls if models exist.
#
# Models (Q4_K_M GGUF — L4-compatible, no MXFP4/Blackwell requirement):
#   stock:      hf.co/unsloth/gpt-oss-20b-GGUF:gpt-oss-20b-Q4_K_M
#   derestricted: hf.co/Mungert/gpt-oss-20b-Derestricted-GGUF:gpt-oss-20b-Derestricted-q4_k_m

set -euo pipefail

echo "[entrypoint] starting ollama serve in background"
ollama serve >/tmp/ollama/serve.log 2>&1 &
SERVE_PID=$!

# Wait for /api/tags to return 200 (max 60s)
for i in {1..60}; do
    if curl -fsS http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
        echo "[entrypoint] ollama is ready after ${i}s"
        break
    fi
    sleep 1
done

if ! curl -fsS http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
    echo "[entrypoint] FATAL: ollama never came up"
    tail -50 /tmp/ollama/serve.log
    exit 1
fi

# Pull both Q4_K_M GGUF models from HuggingFace (idempotent — skips if already cached)
# Note: files are ~9-12 GB each; first cold boot takes ~15-25 min per model
STOCK_MODEL="hf.co/unsloth/gpt-oss-20b-GGUF:gpt-oss-20b-Q4_K_M"
HERETIC_MODEL="hf.co/Mungert/gpt-oss-20b-Derestricted-GGUF:gpt-oss-20b-Derestricted-q4_k_m"

echo "[entrypoint] pulling stock model: ${STOCK_MODEL}"
ollama pull "${STOCK_MODEL}"

echo "[entrypoint] pulling derestricted model: ${HERETIC_MODEL}"
ollama pull "${HERETIC_MODEL}"

echo "[entrypoint] both models pulled. final tag list:"
ollama list

echo "[entrypoint] ready. ollama serve PID=$SERVE_PID"

# Wait on the serve process to keep the container alive.
# If ollama dies, this script exits, container restarts, and we re-run the pulls.
wait $SERVE_PID
