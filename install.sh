#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="${OPEN_WEBUI_CONTAINER:-open-webui-spicy}"
IMAGE="${OPEN_WEBUI_IMAGE:-ghcr.io/open-webui/open-webui:main}"
HOST="${OPEN_WEBUI_HOST:-127.0.0.1}"
PORT="${OPEN_WEBUI_PORT:-3100}"
DATA_DIR="${OPEN_WEBUI_DATA_DIR:-$HOME/.local/share/open-webui-spicy}"
OLLAMA_BASE_URL="${OLLAMA_BASE_URL:-http://host.docker.internal:11434}"
WEBUI_AUTH="${WEBUI_AUTH:-False}"
BASE_MODEL="${OLLAMA_BASE_MODEL:-svjack/gpt-oss-20b-heretic:latest}"
TUNED_MODEL="${OLLAMA_TUNED_MODEL:-spicy-heretic:latest}"
CREATE_TUNED_MODEL="${CREATE_TUNED_MODEL:-true}"
SPICY_TEMPERATURE="${SPICY_TEMPERATURE:-0.7}"
SPICY_TOP_P="${SPICY_TOP_P:-0.9}"
SPICY_REPEAT_PENALTY="${SPICY_REPEAT_PENALTY:-1.18}"
SPICY_NUM_PREDICT="${SPICY_NUM_PREDICT:-4096}"
DEFAULT_MODELS="${OPEN_WEBUI_DEFAULT_MODELS:-$TUNED_MODEL}"
TASK_MODEL="${OPEN_WEBUI_TASK_MODEL:-$TUNED_MODEL}"
BYPASS_MODEL_ACCESS_CONTROL="${OPEN_WEBUI_BYPASS_MODEL_ACCESS_CONTROL:-True}"
DEFAULT_MODEL_PARAMS="${OPEN_WEBUI_DEFAULT_MODEL_PARAMS:-{\"think\":\"low\"}}"
ENABLE_EVALUATION_ARENA_MODELS="${OPEN_WEBUI_ENABLE_EVALUATION_ARENA_MODELS:-False}"

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

container_exists() {
  docker inspect "$CONTAINER_NAME" >/dev/null 2>&1
}

container_running() {
  [ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null || true)" = "true" ]
}

use_existing_port_binding() {
  local binding
  binding="$(docker port "$CONTAINER_NAME" 8080/tcp 2>/dev/null | head -n 1 || true)"
  if [ -n "$binding" ]; then
    HOST="${binding%:*}"
    PORT="${binding##*:}"
  fi
}

port_in_use() {
  if command -v lsof >/dev/null 2>&1; then
    lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1
  else
    return 1
  fi
}

wait_for_ui() {
  printf 'Waiting for Open WebUI at http://%s:%s' "$HOST" "$PORT"
  for _ in $(seq 1 90); do
    if curl -fsSI "http://$HOST:$PORT" >/dev/null 2>&1; then
      printf '\n'
      return 0
    fi
    printf '.'
    sleep 1
  done
  printf '\n'
  return 1
}

need_cmd docker
need_cmd curl

docker info >/dev/null 2>&1 || die "Docker is not running or is not reachable"

mkdir -p "$DATA_DIR"

if curl -fsS http://localhost:11434/api/tags >/dev/null 2>&1; then
  printf 'Ollama is reachable at http://localhost:11434\n'
  if [ "$CREATE_TUNED_MODEL" = "true" ]; then
    if command -v ollama >/dev/null 2>&1 && ollama show "$BASE_MODEL" >/dev/null 2>&1; then
      modelfile="$(mktemp)"
      cat > "$modelfile" <<EOF
FROM $BASE_MODEL
PARAMETER temperature $SPICY_TEMPERATURE
PARAMETER top_p $SPICY_TOP_P
PARAMETER repeat_penalty $SPICY_REPEAT_PENALTY
PARAMETER num_predict $SPICY_NUM_PREDICT
EOF
      if ollama create "$TUNED_MODEL" -f "$modelfile" >/dev/null; then
        printf 'Created tuned Ollama model %s from %s\n' "$TUNED_MODEL" "$BASE_MODEL"
      else
        printf '%s\n' "warning: failed to create tuned model $TUNED_MODEL; continuing with Open WebUI setup." >&2
      fi
      rm -f "$modelfile"
    else
      printf '%s\n' "warning: could not create tuned model $TUNED_MODEL; pull $BASE_MODEL first or rerun with CREATE_TUNED_MODEL=false." >&2
    fi
  fi
else
  printf '%s\n' "warning: Ollama is not reachable at http://localhost:11434; start it with \`ollama serve\` before chatting." >&2
fi

if container_exists; then
  if container_running; then
    printf 'Container %s is already running.\n' "$CONTAINER_NAME"
  else
    printf 'Starting existing container %s...\n' "$CONTAINER_NAME"
    docker start "$CONTAINER_NAME" >/dev/null
  fi
  use_existing_port_binding
else
  if port_in_use; then
    die "port $PORT is already in use; rerun with OPEN_WEBUI_PORT=<free-port>"
  fi

  printf 'Creating Open WebUI container %s...\n' "$CONTAINER_NAME"
  docker run -d \
    -p "$HOST:$PORT:8080" \
    --add-host=host.docker.internal:host-gateway \
    -e "OLLAMA_BASE_URL=$OLLAMA_BASE_URL" \
    -e "WEBUI_AUTH=$WEBUI_AUTH" \
    -e "DEFAULT_MODELS=$DEFAULT_MODELS" \
    -e "TASK_MODEL=$TASK_MODEL" \
    -e "BYPASS_MODEL_ACCESS_CONTROL=$BYPASS_MODEL_ACCESS_CONTROL" \
    -e "DEFAULT_MODEL_PARAMS=$DEFAULT_MODEL_PARAMS" \
    -e "ENABLE_EVALUATION_ARENA_MODELS=$ENABLE_EVALUATION_ARENA_MODELS" \
    -v "$DATA_DIR:/app/backend/data" \
    --name "$CONTAINER_NAME" \
    --restart unless-stopped \
    "$IMAGE" >/dev/null
fi

if ! wait_for_ui; then
  docker logs --tail 80 "$CONTAINER_NAME" >&2 || true
  die "Open WebUI did not become ready in time"
fi

cat <<EOF

Open WebUI is ready.

URL:      http://$HOST:$PORT
Data:     $DATA_DIR
Database: $DATA_DIR/webui.db
Container: $CONTAINER_NAME

Before chatting, ensure Ollama is running on the host and the Heretic base model is pulled:
  ollama serve
  ollama pull $BASE_MODEL
The installer creates $TUNED_MODEL with temperature=$SPICY_TEMPERATURE,
top_p=$SPICY_TOP_P, repeat_penalty=$SPICY_REPEAT_PENALTY, and
num_predict=$SPICY_NUM_PREDICT when the base model is available. Use
$TUNED_MODEL in Open WebUI for long creative/RAG chats.

Manage it with:
  docker start $CONTAINER_NAME
  docker stop $CONTAINER_NAME
  docker logs -f $CONTAINER_NAME
EOF
