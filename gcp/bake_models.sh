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

# Vision model for spicy-search's JEV tag-verification lane (`lib/ai/jev.ts` posts scene
# thumbnails to `OLLAMA_BASE_URL` + `OLLAMA_VISION_MODEL`). spicy-search may send images to
# NOTHING except this host (AGENTS.md: third-party multimodal hosts ban nudity on the input
# side), so the ability to *see* must exist here or that lane cannot run at all.
#
# Only multimodal tags are valid here - a text-only pull would silently degrade JEV to
# `llm-unavailable` for every scene while looking like a successful bake. `ollama show`
# reports the `vision` capability; the bake fails loudly if it is missing.
VISION_MODEL="${VISION_MODEL:-gemma3:4b}"
if [ -n "${VISION_MODEL}" ]; then
    echo "[bake] pulling vision model: ${VISION_MODEL}"
    ollama pull "${VISION_MODEL}"
    if ! ollama show "${VISION_MODEL}" 2>/dev/null | grep -q '^ *vision *$'; then
        echo "[bake] FATAL: ${VISION_MODEL} reports no 'vision' capability; JEV would degrade"
        ollama show "${VISION_MODEL}" || true
        exit 1
    fi
    echo "[bake] ${VISION_MODEL} advertises the vision capability"
fi

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
