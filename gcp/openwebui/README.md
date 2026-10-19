# Open WebUI on Cloud Run + Cloud SQL (Abliteration.ai backend)

This deploys Open WebUI to the AI Universe GCP project with durable chat/config
state stored in Cloud SQL for PostgreSQL. The model backend is
**Abliteration.ai** over its OpenAI-compatible API. There is no Ollama server.

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
- Model backend: `https://api.abliteration.ai/v1` (OpenAI-compatible)
- Default chat/task model: `abliterated-model-large-v2`
- Secrets:
  - `spicy-openwebui-database-url`
  - `spicy-openwebui-secret-key`
  - `spicy-search-abliteration-key` (also used by `spicy-search`)

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

## Abliteration connection

The script configures Open WebUI's OpenAI-compatible provider:

```text
OPENAI_API_BASE_URL=https://api.abliteration.ai/v1
OPENAI_API_BASE_URLS=https://api.abliteration.ai/v1
ENABLE_OPENAI_API=true
OPENAI_API_KEY=<secret: spicy-search-abliteration-key>
DEFAULT_MODELS=abliterated-model-large-v2
TASK_MODEL=abliterated-model-large-v2
DEFAULT_MODEL_PARAMS={"reasoning_effort":"low"}
```

`reasoning_effort=low` matters: the Abliteration models are reasoning models.
At the default effort they can spend the entire completion budget on hidden
reasoning and return empty content. Verified 2026-10-18 on the live API: with
`reasoning_effort=low` all three models returned valid JSON/content in ~1 s with
0–485 reasoning tokens.

The runtime service account is granted `roles/secretmanager.secretAccessor` on
the Abliteration key secret. No Ollama endpoint, model alias, or `OLLAMA_*`
variable is configured.

## Notes

- Open WebUI supports PostgreSQL through `DATABASE_URL`; this is the supported
  durable database path for Cloud Run.
- Email/password signup is OFF by default (`ENABLE_SIGNUP=False`), matching the
  live instance (`enable_signup=false`) and the persisted DB config. For a
  first-boot bootstrap, run `ENABLE_SIGNUP=True gcp/openwebui/deploy.sh`, then
  turn it off again.
- `WEBUI_AUTH=True` is kept: the UI requires a login, and the 18+ age gate lives
  in the `spicy-search` app, not here.
- `BYPASS_MODEL_ACCESS_CONTROL=True` exposes the connected OpenAI models
  directly instead of maintaining per-model grants in the Open WebUI database.
- `ENABLE_EVALUATION_ARENA_MODELS=False` so Open WebUI does not add its built-in
  `Arena Model` pseudo-option to the model picker.
- `DEFAULT_MODEL_PARAMS` is `{"reasoning_effort":"low"}`; it is not the old
  Ollama-only `{"think":"low"}`.
- Any `ollama.api_configs` rows left in the Cloud SQL config are legacy and have
  no effect now that no Ollama connection exists.

## Google SSO

Open WebUI is configured with Google OAuth in addition to email/password:

```text
ENABLE_OAUTH=true
ENABLE_OAUTH_SIGNUP=true
OAUTH_MERGE_ACCOUNTS_BY_EMAIL=true
GOOGLE_CLIENT_ID=754683067800-kd1k17ivqpvdl6s40f4m6tf0arp1s6au.apps.googleusercontent.com
GOOGLE_REDIRECT_URI=https://spicy-openwebui-elhm2qjlta-uc.a.run.app/oauth/google/callback
GOOGLE_CLIENT_SECRET=<secret: spicy-openwebui-google-oauth>
```

- OAuth client: **“Open WebUI (spicy-search) 2”**, a Web application client in the
  `worldarchitecture-ai` project (its consent screen already exists and is
  **External / In production**). The client ID/secret is cross-project; the
  service itself stays in `ai-universe-2025`.
- Authorized redirect URI: `https://spicy-openwebui-elhm2qjlta-uc.a.run.app/oauth/google/callback`.
- **Account linking:** `OAUTH_MERGE_ACCOUNTS_BY_EMAIL=true` so a Google login whose
  email already exists as an email/password user links to that account instead of
  failing with “This email is already registered” (the 2026-10-19 00:15 repro).
- Secret: `spicy-openwebui-google-oauth` in `ai-universe-2025` Secret Manager; the
  runtime SA is granted `secretmanager.secretAccessor`.
- Verified: the login page renders **Continue with Google** and the click redirects
  to Google with the correct `client_id`, `redirect_uri`, and
  `scope=openid email profile`. Completing the sign-in needs the target Google
  account’s password/passkey; the Open WebUI password is not the Google password.
- Consent-screen branding is **WorldArchitect.AI** because the client lives in that
  project. A separate brand requires a consent screen in `ai-universe-2025` and
  Google verification for an external adult-content app.

## Historical: the Ollama backend

The previous deployment used `spicy-llm-backend-elhm2qjlta-uc.a.run.app`
(Ollama + `spicy-heretic:latest`, later `gemma3:4b` for vision). That service
was **deleted on 2026-10-19**; the local Ollama install and model blobs were
removed as well. `gcp/README.md` is retained as historical documentation of that
harness.

## Browser Integration Proof

`tests/integration/test_openwebui_heretic_only_browser.py` was written for the
old `spicy-heretic:latest` Ollama deployment and asserts that model id. It is
**stale** for the Abliteration-backed UI; update `EXPECTED_MODEL` before using
it, or run the proof against `abliterated-model-large-v2`.

```bash
python3 -m pip install pytest playwright
python3 -m playwright install chromium

SPICY_OPENWEBUI_EMAIL="<test-user-email>" \
SPICY_OPENWEBUI_PASSWORD="<test-user-password>" \
python3 tests/integration/test_openwebui_heretic_only_browser.py
```
