#!/usr/bin/env bash
# RED/GREEN regression for Google SSO linking to an existing email/password account.
#
# Repro (screenshot 2026-10-19 00:15): "Uh-oh! This email is already registered."
# Open WebUI only links an OAuth identity to an existing user when
# OAUTH_MERGE_ACCOUNTS_BY_EMAIL=true. This asserts the deploy script wires it.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEPLOY="$ROOT/gcp/openwebui/deploy.sh"
README="$ROOT/gcp/openwebui/README.md"
fail=0

check() {
  local label="$1" file="$2" pattern="$3"
  if grep -qF "$pattern" "$file"; then
    printf 'PASS: %s\n' "$label"
  else
    printf 'FAIL: %s (missing: %s)\n' "$label" "$pattern" >&2
    fail=1
  fi
}

check "deploy.sh defines the merge default" "$DEPLOY" \
  'OAUTH_MERGE_ACCOUNTS_BY_EMAIL="${OAUTH_MERGE_ACCOUNTS_BY_EMAIL:-True}"'
check "deploy.sh wires the merge into the service env" "$DEPLOY" \
  'OAUTH_MERGE_ACCOUNTS_BY_EMAIL=${OAUTH_MERGE_ACCOUNTS_BY_EMAIL}'
check "README documents the merge" "$README" 'OAUTH_MERGE_ACCOUNTS_BY_EMAIL'

if [ "$fail" -ne 0 ]; then
  echo "RESULT: FAIL"
  exit 1
fi
echo "RESULT: PASS"
