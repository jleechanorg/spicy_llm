# Open WebUI on Cloud Run + Cloud SQL

This deploys Open WebUI to the AI Universe GCP project with durable chat/config
state stored in Cloud SQL for PostgreSQL.

## Resources

- Project: `ai-universe-2025`
- Region: `us-central1`
- Cloud Run service: `spicy-openwebui`
- Cloud SQL instance: `spicy-openwebui-pg`
- Database: `openwebui`
- Database user: `openwebui`
- Runtime service account: `spicy-openwebui-runner@ai-universe-2025.iam.gserviceaccount.com`
- Artifact Registry repo: `spicy-openwebui`
- Cloud Run image: `us-central1-docker.pkg.dev/ai-universe-2025/spicy-openwebui/open-webui:main`
- URL: `https://spicy-openwebui-elhm2qjlta-uc.a.run.app`
- Ollama backend: `https://spicy-llm-backend-elhm2qjlta-uc.a.run.app`
- Secrets:
  - `spicy-openwebui-database-url`
  - `spicy-openwebui-secret-key`

## Deploy

Run from the repository root:

```bash
gcp/openwebui/deploy.sh
```

The script uses explicit `--project=ai-universe-2025` and
`--account=jleechan@gmail.com` flags. It does not change global `gcloud`
configuration.

Open WebUI uses:

```text
DATABASE_URL=postgresql://openwebui:<password>@/openwebui?host=/cloudsql/ai-universe-2025:us-central1:spicy-openwebui-pg
```

The full URL is stored only in Secret Manager.

## Notes

- Open WebUI supports PostgreSQL through `DATABASE_URL`; this is the supported
  durable database path for Cloud Run.
- `ENABLE_SIGNUP=True` is intentional for first boot so the first browser user
  can create the initial admin account. Disable signup from the admin UI after
  the admin account exists.
- `OLLAMA_BASE_URL` is optional. Set it before running the script if a reachable
  Ollama endpoint exists. The current spicy_llm backend is:

```bash
OLLAMA_BASE_URL="https://spicy-llm-backend-elhm2qjlta-uc.a.run.app" gcp/openwebui/deploy.sh
```
