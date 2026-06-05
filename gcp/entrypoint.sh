#!/usr/bin/env bash
# entrypoint.sh — start Ollama, pull configured models, keep the container alive.
# Designed for Cloud Run with L4 GPU. Idempotent: skips pulls if models exist.
#
# Models (Q4_K_M GGUF — L4-compatible, no MXFP4/Blackwell requirement):
#   stock:      hf.co/unsloth/gpt-oss-20b-GGUF:gpt-oss-20b-Q4_K_M
#   derestricted: hf.co/Mungert/gpt-oss-20b-Derestricted-GGUF:gpt-oss-20b-Derestricted-q4_k_m

set -euo pipefail

echo "[entrypoint] starting ollama serve in background"
ollama serve &
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
    exit 1
fi

# Pull Q4_K_M GGUF models from HuggingFace (idempotent — skips if already cached).
# The stock model is required for the live chat service. The derestricted model
# is optional because some HF GGUF manifests can fail late in Ollama pull; do not
# let that keep Cloud Run in a restart loop.
STOCK_MODEL="${STOCK_MODEL:-hf.co/unsloth/gpt-oss-20b-GGUF:gpt-oss-20b-Q4_K_M}"
HERETIC_MODEL="${HERETIC_MODEL:-hf.co/Mungert/gpt-oss-20b-Derestricted-GGUF:gpt-oss-20b-Derestricted-q4_k_m}"
PULL_DERESTRICTED="${PULL_DERESTRICTED:-false}"
REQUIRE_DERESTRICTED="${REQUIRE_DERESTRICTED:-false}"

echo "[entrypoint] pulling stock model: ${STOCK_MODEL}"
ollama pull "${STOCK_MODEL}"

if [ "${PULL_DERESTRICTED}" = "true" ]; then
    echo "[entrypoint] pulling derestricted model: ${HERETIC_MODEL}"
    if ! ollama pull "${HERETIC_MODEL}"; then
        echo "[entrypoint] WARNING: derestricted model pull failed"
        if [ "${REQUIRE_DERESTRICTED}" = "true" ]; then
            echo "[entrypoint] FATAL: REQUIRE_DERESTRICTED=true, exiting"
            exit 1
        fi
    fi
else
    echo "[entrypoint] skipping derestricted model pull (PULL_DERESTRICTED=false)"
fi

echo "[entrypoint] final tag list:"
ollama list

echo "[entrypoint] ready. ollama serve PID=$SERVE_PID"

# Wait on the serve process to keep the container alive.
# If ollama dies, this script exits, container restarts, and we re-run the pulls.
wait $SERVE_PID
