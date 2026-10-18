#!/usr/bin/env bash
#
# Start the local spicy_llm stack for testing BEFORE touching GCP.
#
#   ./scripts/run_local_server.sh                    # branch-hashed port, real env, tails UI logs
#   ./scripts/run_local_server.sh --no-log-stream    # agent invocation: background, does not block
#   ./scripts/run_local_server.sh --port 3111        # explicit port
#   ./scripts/run_local_server.sh --force-default-port  # fixed 3100 instead of branch-hashed
#   ./scripts/run_local_server.sh --no-webui         # Ollama + models only, no Open WebUI
#   ./scripts/run_local_server.sh --pull             # opt-in: pull the 15.8 GB base model
#   ./scripts/run_local_server.sh --stop | --status  # scoped to this branch
#
# Patterned on jleechanorg/worldarchitect.ai `run_local_server.sh` and
# jleechanorg/spicy-search `scripts/run_local_server.sh`. Mechanics carried over:
#
#   1. Branch-hashed port by default, so concurrent worktrees never collide.
#   2. `--no-log-stream` for agent invocation: without it the script tails logs and blocks.
#   3. Per-branch log directory `/tmp/<repo>/<branch-with-slashes-as-underscores>/`.
#   4. Cleanup of the PREVIOUS run scoped to this branch — never a blanket
#      "kill every ollama/docker process", which would take out other sessions.
#   5. Real health checks before success is declared. A live PID is not proof.
#   6. `--force-default-port` is opt-in only. The hashed port is the default on purpose.
#
# NOT carried over: the worldarchitect Python venv / React split (this repo is an
# Ollama model server plus an Open WebUI container), and the interactive
# "kill all servers?" prompt (unsafe under an agent).
#
# LOCAL-FIRST CONTRACT: this launcher never pulls a model unless --pull is passed.
# The heretic base model is ~15.8 GB; silently downloading it is not acceptable.
# Without it the UI still starts and the script prints the exact pull command.
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_NAME="$(basename "$REPO_ROOT")"
cd "$REPO_ROOT"

# ---- contract shared with gcp/ and install.sh ---------------------------------
DEFAULT_PORT="${OPEN_WEBUI_PORT:-3100}"
HOST="${OPEN_WEBUI_HOST:-127.0.0.1}"
OPEN_WEBUI_IMAGE="${OPEN_WEBUI_IMAGE:-ghcr.io/open-webui/open-webui:main}"
OLLAMA_URL="${OLLAMA_URL:-http://localhost:11434}"
BASE_MODEL="${OLLAMA_BASE_MODEL:-svjack/gpt-oss-20b-heretic:latest}"
TUNED_MODEL="${OLLAMA_TUNED_MODEL:-spicy-heretic:latest}"
VISION_MODEL="${OLLAMA_VISION_MODEL:-gemma3:4b}"
SPICY_TEMPERATURE="${SPICY_TEMPERATURE:-0.7}"
SPICY_TOP_P="${SPICY_TOP_P:-0.9}"
SPICY_REPEAT_PENALTY="${SPICY_REPEAT_PENALTY:-1.18}"
SPICY_NUM_PREDICT="${SPICY_NUM_PREDICT:-4096}"

PORT=""
FORCE_DEFAULT_PORT=0
LOG_STREAM=1
ACTION="start"
DO_WEBUI=1
DO_PULL=0
DO_PULL_VISION=0
DRY_RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --no-log-stream)      LOG_STREAM=0 ;;
    --force-default-port) FORCE_DEFAULT_PORT=1 ;;
    --port)               PORT="${2:?--port needs a value}"; shift ;;
    --no-webui)           DO_WEBUI=0 ;;
    --pull)               DO_PULL=1 ;;
    --pull-vision)        DO_PULL_VISION=1 ;;
    --dry-run)            DRY_RUN=1 ;;
    --stop|--cleanup)     ACTION="stop" ;;
    --status)             ACTION="status" ;;
    -h|--help)            sed -n '2,30p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "unknown argument: $1 (try --help)" >&2; exit 2 ;;
  esac
  shift
done

BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo detached)"
BRANCH_SLUG="$(printf '%s' "$BRANCH" | tr '/' '_' | tr -c 'A-Za-z0-9_.-' '-' | sed 's/-$//')"
[ -n "$BRANCH_SLUG" ] || BRANCH_SLUG="detached"
LOG_DIR="/tmp/${REPO_NAME}/${BRANCH_SLUG}"
LOG_FILE="${LOG_DIR}/local_server.log"
PID_FILE="${LOG_DIR}/ollama.pid"
CONTAINER="${OPEN_WEBUI_CONTAINER:-open-webui-spicy-${BRANCH_SLUG}}"
DATA_DIR="${OPEN_WEBUI_DATA_DIR:-${HOME}/.local/share/open-webui-spicy/${BRANCH_SLUG}}"

C_RESET=$'\033[0m'; C_INFO=$'\033[36m'; C_OK=$'\033[32m'; C_WARN=$'\033[33m'; C_ERR=$'\033[31m'
info() { printf '%s==>%s %s\n' "$C_INFO" "$C_RESET" "$*"; }
ok()   { printf '%s  OK%s %s\n' "$C_OK" "$C_RESET" "$*"; }
warn() { printf '%s WARN%s %s\n' "$C_WARN" "$C_RESET" "$*" >&2; }
die()  { printf '%sFAIL%s %s\n' "$C_ERR" "$C_RESET" "$*" >&2; exit 1; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"; }

# ---- branch-hashed port ------------------------------------------------------
# FNV-1a over the branch name, mapped into 3100..3999 so the range never
# collides with the fixed default or with common tooling ports.
branch_hash_port() {
  local name="$1" hash=2166136261 c
  for (( i=0; i<${#name}; i++ )); do
    c=$(printf '%d' "'${name:$i:1}")
    hash=$(( (hash ^ c) * 16777619 & 0xffffffff ))
  done
  echo $(( 3100 + (hash % 900) ))
}

if [ -n "$PORT" ]; then
  :
elif [ "$FORCE_DEFAULT_PORT" -eq 1 ]; then
  PORT="$DEFAULT_PORT"
else
  PORT="$(branch_hash_port "$BRANCH")"
fi

pid_on_port() { lsof -tiTCP:"$1" -sTCP:LISTEN 2>/dev/null || true; }
port_in_use() { [ -n "$(pid_on_port "$1")" ]; }

container_exists() { docker inspect "$CONTAINER" >/dev/null 2>&1; }
container_running() {
  [ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null || true)" = "true" ]
}

ollama_up() { curl -fsS -m 3 "${OLLAMA_URL}/api/tags" >/dev/null 2>&1; }
model_present() { ollama show "$1" >/dev/null 2>&1; }

# ---- scoped stop -------------------------------------------------------------
stop_ours() {
  local stopped=0
  if command -v docker >/dev/null 2>&1 && container_exists; then
    if container_running; then
      info "stopping container ${CONTAINER}"
      docker stop "$CONTAINER" >/dev/null && stopped=$((stopped+1))
    fi
  fi
  # Ollama is a shared daemon: only stop it if THIS branch's PID file says we
  # started it and that PID still looks like ollama. Never blanket-kill :11434.
  if [ -f "$PID_FILE" ]; then
    local pid; pid="$(cat "$PID_FILE" 2>/dev/null || true)"
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && ps -p "$pid" -o comm= 2>/dev/null | grep -q ollama; then
      info "stopping Ollama started by this branch (pid ${pid})"
      kill "$pid" 2>/dev/null || true
      stopped=$((stopped+1))
    fi
    rm -f "$PID_FILE"
  fi
  [ "$stopped" -eq 0 ] && info "nothing owned by branch ${BRANCH} was running"
  ok "stopped ${stopped} service(s); data under ${DATA_DIR} preserved"
}

show_status() {
  echo "branch:    ${BRANCH}"
  echo "port:      ${PORT} (hashed from branch unless overridden)"
  echo "container: ${CONTAINER} $([ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null || echo false)" = true ] && echo running || echo stopped)"
  echo "data:      ${DATA_DIR}"
  echo "ollama:    ${OLLAMA_URL} $(ollama_up && echo reachable || echo unreachable)"
  echo "models:"
  ollama list 2>/dev/null | sed 's/^/  /' || true
}

if [ "$ACTION" = "stop" ]; then
  stop_ours
  exit 0
fi
if [ "$ACTION" = "status" ]; then
  show_status
  exit 0
fi

if [ "$DRY_RUN" -eq 1 ]; then
  info "dry run: would use port ${PORT}, container ${CONTAINER}, data ${DATA_DIR}"
  info "dry run: ollama=${OLLAMA_URL} base=${BASE_MODEL} tuned=${TUNED_MODEL} webui=${DO_WEBUI}"
  exit 0
fi

# ---- preflight ---------------------------------------------------------------
need_cmd curl
need_cmd ollama
mkdir -p "$LOG_DIR"

if [ "$DO_WEBUI" -eq 1 ]; then
  need_cmd docker
  docker info >/dev/null 2>&1 || die "Docker is not running; start Docker Desktop or pass --no-webui"
fi

# Clean up the previous run of THIS branch before starting (scoped).
if container_exists && container_running; then
  info "replacing this branch's previous container ${CONTAINER}"
  docker stop "$CONTAINER" >/dev/null || true
fi

# ---- Ollama ------------------------------------------------------------------
if ollama_up; then
  ok "Ollama already reachable at ${OLLAMA_URL}"
else
  info "starting ollama serve (log: ${LOG_FILE})"
  nohup ollama serve >>"$LOG_FILE" 2>&1 &
  echo $! > "$PID_FILE"
  for _ in $(seq 1 60); do
    ollama_up && break
    sleep 1
  done
  ollama_up || { tail -n 40 "$LOG_FILE" >&2 || true; die "Ollama did not become ready at ${OLLAMA_URL}"; }
  ok "Ollama ready at ${OLLAMA_URL}"
fi

# ---- models (opt-in downloads only) -----------------------------------------
if ! model_present "$BASE_MODEL"; then
  warn "base model ${BASE_MODEL} is NOT present locally (~15.8 GB)."
  warn "  pull it explicitly:  ollama pull ${BASE_MODEL}"
  warn "  then rerun this script. Nothing was downloaded automatically."
  if [ "$DO_PULL" -eq 1 ]; then
    info "pulling ${BASE_MODEL} (this can take a while)"
    ollama pull "$BASE_MODEL"
  fi
else
  ok "base model present: ${BASE_MODEL}"
fi

if model_present "$BASE_MODEL" && ! model_present "$TUNED_MODEL"; then
  info "creating tuned model ${TUNED_MODEL} from ${BASE_MODEL}"
  modelfile="$(mktemp)"
  cat >"$modelfile" <<EOF
FROM ${BASE_MODEL}
PARAMETER temperature ${SPICY_TEMPERATURE}
PARAMETER top_p ${SPICY_TOP_P}
PARAMETER repeat_penalty ${SPICY_REPEAT_PENALTY}
PARAMETER num_predict ${SPICY_NUM_PREDICT}
EOF
  if ollama create "$TUNED_MODEL" -f "$modelfile"; then
    ok "created ${TUNED_MODEL} (temp=${SPICY_TEMPERATURE} top_p=${SPICY_TOP_P} repeat_penalty=${SPICY_REPEAT_PENALTY} num_predict=${SPICY_NUM_PREDICT})"
  else
    warn "could not create ${TUNED_MODEL}; continuing with the UI pointed at ${TUNED_MODEL}"
  fi
  rm -f "$modelfile"
elif model_present "$TUNED_MODEL"; then
  ok "tuned model present: ${TUNED_MODEL}"
fi

if ! model_present "$VISION_MODEL"; then
  warn "vision model ${VISION_MODEL} not present (optional; used by spicy-search JEV, not this repo's smoke)."
  if [ "$DO_PULL_VISION" -eq 1 ]; then
    info "pulling ${VISION_MODEL}"
    ollama pull "$VISION_MODEL"
  fi
fi

if [ "$DO_WEBUI" -eq 0 ]; then
  info "Ollama-only mode; not starting Open WebUI"
  show_status
  exit 0
fi

# ---- Open WebUI --------------------------------------------------------------
HOST_PORT="$PORT"
if container_exists && ! container_running; then
  info "starting existing container ${CONTAINER}"
  docker start "$CONTAINER" >/dev/null
elif ! container_exists; then
  port_in_use "$PORT" && die "port ${PORT} is already in use; rerun with --port <free-port>"
  info "creating branch-scoped Open WebUI container ${CONTAINER} on ${HOST}:${PORT}"
  mkdir -p "$DATA_DIR"
  docker run -d \
    -p "${HOST}:${PORT}:8080" \
    --add-host=host.docker.internal:host-gateway \
    -e "OLLAMA_BASE_URL=http://host.docker.internal:11434" \
    -e "WEBUI_AUTH=${WEBUI_AUTH:-False}" \
    -e "DEFAULT_MODELS=${TUNED_MODEL}" \
    -e "TASK_MODEL=${TUNED_MODEL}" \
    -e "BYPASS_MODEL_ACCESS_CONTROL=${OPEN_WEBUI_BYPASS_MODEL_ACCESS_CONTROL:-True}" \
    -e "DEFAULT_MODEL_PARAMS=${OPEN_WEBUI_DEFAULT_MODEL_PARAMS:-{\"think\":\"low\"}}" \
    -e "ENABLE_EVALUATION_ARENA_MODELS=${OPEN_WEBUI_ENABLE_EVALUATION_ARENA_MODELS:-False}" \
    -v "${DATA_DIR}:/app/backend/data" \
    --name "$CONTAINER" \
    --restart unless-stopped \
    "$OPEN_WEBUI_IMAGE" >/dev/null
fi

# Adopt the real binding (a pre-existing container may expose a different port).
binding="$(docker port "$CONTAINER" 8080/tcp 2>/dev/null | head -n 1 || true)"
if [ -n "$binding" ]; then
  HOST="${binding%:*}"
  HOST_PORT="${binding##*:}"
fi

info "waiting for Open WebUI at http://${HOST}:${HOST_PORT}"
ready=0
for _ in $(seq 1 90); do
  if curl -fsSI -m 3 "http://${HOST}:${HOST_PORT}" >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 1
done
if [ "$ready" -ne 1 ]; then
  docker logs --tail 80 "$CONTAINER" >&2 || true
  die "Open WebUI did not become ready in 90s"
fi
ok "Open WebUI ready"

# Real API probe, not just a listening socket: Ollama must answer through the
# same host the UI uses.
api_code="$(curl -s -m 10 -o /dev/null -w '%{http_code}' "${OLLAMA_URL}/api/tags" || true)"
if [ "$api_code" = "200" ]; then
  ok "Ollama API probe /api/tags -> 200"
else
  warn "Ollama API probe returned ${api_code}; the UI is up but generation may fail"
fi

cat <<EOF

Local stack ready.
  URL:        http://${HOST}:${HOST_PORT}
  Container:  ${CONTAINER}
  Data:       ${DATA_DIR}
  Ollama:     ${OLLAMA_URL}
  Log:        ${LOG_FILE}
  Stop:       ./scripts/run_local_server.sh --stop

$(if ! model_present "$TUNED_MODEL"; then
  printf '  NEXT: the chat model %s is not installed yet.\n    ollama pull %s\n    ./scripts/run_local_server.sh --no-log-stream\n' "$TUNED_MODEL" "$BASE_MODEL"
else
  printf '  Model: %s is ready.\n' "$TUNED_MODEL"
fi)

GCP parity (do not diverge): BASE_MODEL=${BASE_MODEL} TUNED_MODEL=${TUNED_MODEL}
  temperature=${SPICY_TEMPERATURE} top_p=${SPICY_TOP_P} repeat_penalty=${SPICY_REPEAT_PENALTY} num_predict=${SPICY_NUM_PREDICT}
Test locally, then deploy: see gcp/README.md.
EOF

if [ "$LOG_STREAM" -eq 1 ]; then
  info "tailing container logs (Ctrl-C leaves the container running)"
  exec docker logs -f "$CONTAINER"
fi
