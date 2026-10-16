#!/usr/bin/env bash
# bake_models.sh — populate $OLLAMA_MODELS at IMAGE BUILD TIME.
#
# Why this exists: Cloud Run's container filesystem is ephemeral. The old image set
# OLLAMA_MODELS=/tmp/ollama, and /tmp in Cloud Run is memory-backed, so every
# instance restart wiped the model store and forced a fresh 15.8 GB pull from the
# Ollama registry (~5.5 min of no service). Baking the blobs into an image layer
# makes a restart a local read instead of a download.
#
# The runtime entrypoint.sh still runs `ollama pull` and `ollama create`; both are
# idempotent and are near-no-ops when the blobs are already present in the image.
#
# Reads (from Docker build ARGs): STOCK_MODEL, TUNED_MODEL, SPICY_* parameters.
set -euo pipefail

MODELS_DIR="${OLLAMA_MODELS:-/models}"
echo "[bake] models dir: ${MODELS_DIR}"
df -h "${MODELS_DIR}" || true

echo "[bake] starting ollama serve"
ollama serve >/tmp/bake-serve.log 2>&1 &
SERVE_PID=$!

for i in $(seq 1 120); do
    if curl -fsS http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
        echo "[bake] ollama is ready after ${i}s"
        break
    fi
    sleep 1
done

if ! curl -fsS http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
    echo "[bake] FATAL: ollama never came up"
    tail -50 /tmp/bake-serve.log || true
    exit 1
fi

echo "[bake] pulling stock model: ${STOCK_MODEL}"
ollama pull "${STOCK_MODEL}"

echo "[bake] creating tuned model: ${TUNED_MODEL}"
# Use a build-only filename. Writing /tmp/spicy-heretic.Modelfile here would leave a
# ROOT-OWNED file in the image layer that the runtime `ollama` user cannot overwrite,
# which crash-looped production (see the note in entrypoint.sh).
cat > /tmp/bake-modelfile <<EOF
FROM ${STOCK_MODEL}
PARAMETER temperature ${SPICY_TEMPERATURE}
PARAMETER top_p ${SPICY_TOP_P}
PARAMETER repeat_penalty ${SPICY_REPEAT_PENALTY}
PARAMETER num_predict ${SPICY_NUM_PREDICT}
EOF
ollama create "${TUNED_MODEL}" -f /tmp/bake-modelfile
rm -f /tmp/bake-modelfile

echo "[bake] baked model list:"
ollama list

echo "[bake] models dir size:"
du -sh "${MODELS_DIR}"

kill "${SERVE_PID}" 2>/dev/null || true
wait "${SERVE_PID}" 2>/dev/null || true
echo "[bake] done"
