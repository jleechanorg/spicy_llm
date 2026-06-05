#!/usr/bin/env bash
# entrypoint.sh — start Ollama, pull both models, keep the container alive.
# Designed for Cloud Run with L4 GPU. Idempotent: skips pulls if models exist.

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

# Pull both models (idempotent — Ollama skips files that are already in $OLLAMA_MODELS)
echo "[entrypoint] pulling gpt-oss:20b (this is ~13GB, may take 5-10 min on first boot)"
ollama pull gpt-oss:20b
echo "[entrypoint] pulling svjack/gpt-oss-20b-heretic (this is ~15GB, may take 5-10 min on first boot)"
ollama pull svjack/gpt-oss-20b-heretic

echo "[entrypoint] both models pulled. final tag list:"
ollama list

echo "[entrypoint] ready. ollama serve PID=$SERVE_PID"

# Wait on the serve process to keep the container alive.
# If ollama dies, this script exits, container restarts, and we re-run the pulls.
wait $SERVE_PID
