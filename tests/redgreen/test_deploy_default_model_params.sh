#!/usr/bin/env bash
# RED/GREEN regression for the DEFAULT_MODEL_PARAMS default in
# gcp/openwebui/deploy.sh.
#
# Finding: a PRE-SET valid value gains an extra closing brace because the `}`
# inside the `${VAR:-...}` default word is parsed as the end of the expansion.
# Unset and empty are correct.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

LINE="$(grep -m1 '^DEFAULT_MODEL_PARAMS=' gcp/openwebui/deploy.sh)"
if [ -z "$LINE" ]; then
  echo "FAIL: DEFAULT_MODEL_PARAMS assignment not found" >&2
  exit 2
fi

fail=0

run_case() {
  local label="$1" preset="$2" expected="$3" got
  if [ "$preset" = "__UNSET__" ]; then
    got="$(env -u DEFAULT_MODEL_PARAMS bash -c "${LINE}; printf '%s' \"\$DEFAULT_MODEL_PARAMS\"")"
  else
    got="$(DEFAULT_MODEL_PARAMS="$preset" bash -c "${LINE}; printf '%s' \"\$DEFAULT_MODEL_PARAMS\"")"
  fi
  printf '%s got=[%s] expected=[%s]\n' "$label" "$got" "$expected"
  if [ "$got" != "$expected" ]; then
    printf 'FAIL: %s\n' "$label" >&2
    fail=1
  fi
}

# A pre-set value must pass through byte-for-byte.
run_case PRESET '{"reasoning_effort":"high"}' '{"reasoning_effort":"high"}'
# Unset and empty must use the default exactly.
run_case UNSET '__UNSET__' '{"reasoning_effort":"low"}'
run_case EMPTY '' '{"reasoning_effort":"low"}'

if [ "$fail" -ne 0 ]; then
  echo "RESULT: FAIL"
  exit 1
fi
echo "RESULT: PASS"
