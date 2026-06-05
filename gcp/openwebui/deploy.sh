#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="${PROJECT_ID:-ai-universe-2025}"
ACCOUNT="${GCLOUD_ACCOUNT:-jleechan@gmail.com}"
REGION="${REGION:-us-central1}"
SERVICE="${SERVICE:-spicy-openwebui}"
INSTANCE="${INSTANCE:-spicy-openwebui-pg}"
DATABASE="${DATABASE:-openwebui}"
DB_USER="${DB_USER:-openwebui}"
RUNTIME_SA_NAME="${RUNTIME_SA_NAME:-spicy-openwebui-runner}"
DATABASE_URL_SECRET="${DATABASE_URL_SECRET:-spicy-openwebui-database-url}"
WEBUI_SECRET_KEY_SECRET="${WEBUI_SECRET_KEY_SECRET:-spicy-openwebui-secret-key}"
ARTIFACT_REPO="${ARTIFACT_REPO:-spicy-openwebui}"
IMAGE="${IMAGE:-${REGION}-docker.pkg.dev/${PROJECT_ID}/${ARTIFACT_REPO}/open-webui:main}"
OLLAMA_BASE_URL="${OLLAMA_BASE_URL:-}"

gcloud_base=(gcloud --project="$PROJECT_ID" --account="$ACCOUNT")

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

secret_exists() {
  "${gcloud_base[@]}" secrets describe "$1" >/dev/null 2>&1
}

random_token() {
  python3 -c 'import secrets, string, sys; n=int(sys.argv[1]); alphabet=string.ascii_letters+string.digits; print("".join(secrets.choice(alphabet) for _ in range(n)))' "${1:-48}"
}

urlencode() {
  python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$1"
}

need_cmd gcloud
need_cmd python3

printf 'Using project=%s account=%s region=%s\n' "$PROJECT_ID" "$ACCOUNT" "$REGION"

"${gcloud_base[@]}" services enable \
  run.googleapis.com \
  sqladmin.googleapis.com \
  secretmanager.googleapis.com \
  iam.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com

if ! "${gcloud_base[@]}" artifacts repositories describe "$ARTIFACT_REPO" --location="$REGION" >/dev/null 2>&1; then
  "${gcloud_base[@]}" artifacts repositories create "$ARTIFACT_REPO" \
    --repository-format=docker \
    --location="$REGION" \
    --description="Open WebUI images for spicy_llm"
fi

"${gcloud_base[@]}" builds submit "$(dirname "$0")" \
  --tag="$IMAGE" \
  --timeout=20m

if ! "${gcloud_base[@]}" sql instances describe "$INSTANCE" >/dev/null 2>&1; then
  "${gcloud_base[@]}" sql instances create "$INSTANCE" \
    --database-version=POSTGRES_15 \
    --region="$REGION" \
    --tier=db-f1-micro \
    --storage-size=10GB \
    --availability-type=zonal \
    --no-backup \
    --no-deletion-protection \
    --quiet
fi

if ! "${gcloud_base[@]}" sql databases describe "$DATABASE" --instance="$INSTANCE" >/dev/null 2>&1; then
  "${gcloud_base[@]}" sql databases create "$DATABASE" --instance="$INSTANCE"
fi

if ! "${gcloud_base[@]}" sql users list --instance="$INSTANCE" --format='value(name)' | grep -Fxq "$DB_USER"; then
  db_password="$(random_token 48)"
  "${gcloud_base[@]}" sql users create "$DB_USER" \
    --instance="$INSTANCE" \
    --password="$db_password"
else
  db_password="$(random_token 48)"
  "${gcloud_base[@]}" sql users set-password "$DB_USER" \
    --instance="$INSTANCE" \
    --password="$db_password"
fi

connection_name="$("${gcloud_base[@]}" sql instances describe "$INSTANCE" --format='value(connectionName)')"
encoded_password="$(urlencode "$db_password")"
database_url="postgresql://${DB_USER}:${encoded_password}@/${DATABASE}?host=/cloudsql/${connection_name}"

if ! secret_exists "$DATABASE_URL_SECRET"; then
  printf '%s' "$database_url" | "${gcloud_base[@]}" secrets create "$DATABASE_URL_SECRET" \
    --replication-policy=automatic \
    --data-file=-
else
  printf '%s' "$database_url" | "${gcloud_base[@]}" secrets versions add "$DATABASE_URL_SECRET" \
    --data-file=-
fi

if ! secret_exists "$WEBUI_SECRET_KEY_SECRET"; then
  random_token 64 | "${gcloud_base[@]}" secrets create "$WEBUI_SECRET_KEY_SECRET" \
    --replication-policy=automatic \
    --data-file=-
fi

runtime_sa="${RUNTIME_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
if ! "${gcloud_base[@]}" iam service-accounts describe "$runtime_sa" >/dev/null 2>&1; then
  "${gcloud_base[@]}" iam service-accounts create "$RUNTIME_SA_NAME" \
    --display-name="Spicy Open WebUI Cloud Run"
fi

printf 'Waiting for runtime service account IAM propagation'
for _ in $(seq 1 30); do
  if "${gcloud_base[@]}" iam service-accounts describe "$runtime_sa" >/dev/null 2>&1; then
    printf '\n'
    break
  fi
  printf '.'
  sleep 2
done
"${gcloud_base[@]}" iam service-accounts describe "$runtime_sa" >/dev/null 2>&1 \
  || die "runtime service account did not become visible: $runtime_sa"

"${gcloud_base[@]}" projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${runtime_sa}" \
  --role=roles/cloudsql.client \
  --quiet >/dev/null

for secret in "$DATABASE_URL_SECRET" "$WEBUI_SECRET_KEY_SECRET"; do
  "${gcloud_base[@]}" secrets add-iam-policy-binding "$secret" \
    --member="serviceAccount:${runtime_sa}" \
    --role=roles/secretmanager.secretAccessor \
    --quiet >/dev/null
done

env_vars="ENV=prod,WEBUI_AUTH=True,ENABLE_SIGNUP=True"
if [ -n "$OLLAMA_BASE_URL" ]; then
  env_vars="${env_vars},OLLAMA_BASE_URL=${OLLAMA_BASE_URL}"
fi

"${gcloud_base[@]}" run deploy "$SERVICE" \
  --image="$IMAGE" \
  --region="$REGION" \
  --platform=managed \
  --port=8080 \
  --cpu=2 \
  --memory=4Gi \
  --min-instances=0 \
  --max-instances=1 \
  --concurrency=20 \
  --timeout=900 \
  --service-account="$runtime_sa" \
  --add-cloudsql-instances="$connection_name" \
  --set-secrets="DATABASE_URL=${DATABASE_URL_SECRET}:latest,WEBUI_SECRET_KEY=${WEBUI_SECRET_KEY_SECRET}:latest" \
  --set-env-vars="$env_vars" \
  --allow-unauthenticated

service_url="$("${gcloud_base[@]}" run services describe "$SERVICE" \
  --region="$REGION" \
  --format='value(status.url)')"

"${gcloud_base[@]}" run services update "$SERVICE" \
  --region="$REGION" \
  --update-env-vars="WEBUI_URL=${service_url}" \
  >/dev/null

cat <<EOF

Open WebUI deployed.

Project:      $PROJECT_ID
Region:       $REGION
Service:      $SERVICE
URL:          $service_url
Cloud SQL:    $connection_name
Database:     $DATABASE
DB user:      $DB_USER
Runtime SA:   $runtime_sa
DB URL secret: $DATABASE_URL_SECRET

First browser visit creates the initial Open WebUI admin account.
EOF
