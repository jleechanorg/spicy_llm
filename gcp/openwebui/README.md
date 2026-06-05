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
- Default chat/task model: `spicy-heretic:latest`
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

The deploy script sets `DEFAULT_MODELS` and `TASK_MODEL` to
`spicy-heretic:latest` by default. The backend creates that Ollama alias with
lower-temperature, repeat-penalty, and large `num_predict` parameters for long
creative/RAG chats.

It also sets `BYPASS_MODEL_ACCESS_CONTROL=True`. Open WebUI v0.9 filters base
Ollama models for normal users unless matching model/access-grant rows exist in
its database; this solo research deployment exposes the connected Ollama models
directly instead of maintaining per-model grants.

`ENABLE_EVALUATION_ARENA_MODELS` defaults to `False` so Open WebUI does not add
its built-in `Arena Model` pseudo-option to the model picker.

`DEFAULT_MODEL_PARAMS` defaults to `{"think":"low"}`. GPT-OSS models emit
reasoning traces by default; low thinking keeps OpenWebUI chats from spending the
whole token budget on hidden reasoning before visible content.

The live Cloud SQL config filters the connected Ollama server to
`spicy-heretic:latest` only via `ollama.api_configs[0].model_ids`. The backend
may still keep the base Heretic model internally because the tuned alias is
created from it, but Open WebUI should only show the tuned alias.

## Browser Integration Proof

Run the live browser proof from the repository root:

```bash
python3 -m pip install pytest playwright
python3 -m playwright install chromium

SPICY_OPENWEBUI_EMAIL="<test-user-email>" \
SPICY_OPENWEBUI_PASSWORD="<test-user-password>" \
python3 tests/integration/test_openwebui_heretic_only_browser.py
```

The test opens the deployed Open WebUI in Playwright, asserts that `/api/models`
and the model picker expose only `spicy-heretic:latest`, and writes browser
evidence under `results/openwebui-heretic-only-browser/<timestamp>/`:

- `videos/*.webm` from Playwright
- `videos/openwebui_heretic_only.vtt` caption track
- `videos/openwebui_heretic_only_captioned.mp4` when `ffmpeg` is installed
- screenshots and `manifest.json`

Instead of email/password env vars, you can set
`SPICY_OPENWEBUI_STORAGE_STATE=/absolute/path/to/storage_state.json` to reuse a
Playwright-authenticated browser state. The test records whether auth was
required, but it does not write passwords into artifacts.
