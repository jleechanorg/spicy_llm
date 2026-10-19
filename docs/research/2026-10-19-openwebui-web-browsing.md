# Web browsing/search for the Abliteration-backed Open WebUI

**Date:** 2026-10-19 · **Live Open WebUI:** `0.9.6` (verified `GET /api/version` on `spicy-openwebui-elhm2qjlta-uc.a.run.app`; release 2026-06-01) · **Target:** `0.12.3` (release 2026-10-16) · **SearXNG:** `https://spicy-search-searxng-elhm2qjlta-uc.a.run.app` (`searxng/2026.10.17+1c10abe2d`, JSON verified 200) · **Model:** `abliterated-model-large-v2` via `https://api.abliteration.ai/v1`.

## Decision table

| Option | Code | Works today | Grounds adult catalogue | Verdict |
|---|---:|---|---|---|
| OWUI built-in search → SearXNG | 0 | Yes (JSON 200) | No | **Do this for general web search** |
| Abliteration server-side web search | 0–1 config | **Yes (verified 2026-10-19)** | No | **Use as an on-demand tool, not static params** |
| OpenRouter `:online` | 0 | No key configured; reported 401 | No | Reject |
| xAI Live Search | moderate | Needs new provider/account | No | Reject |
| Playwright/Aside/Browserbase/Stagehand | high | Yes | Possibly, but fragile/ToS | Overkill; don't |
| Thin OWUI Workspace Tools + service-token route | ~80–110 LOC | Yes via `/api/search` + service token | **Yes** | **Do this for both goals** |

## 1. Open WebUI built-in web search (zero code)

Source of truth is `backend/open_webui/config.py` at v0.12.3 (same names on v0.9.6) — <https://github.com/open-webui/open-webui/blob/v0.12.3/backend/open_webui/config.py#L1168-L1224>. The variables that matter:

| Env var | Default | Notes |
|---|---|---|
| `ENABLE_WEB_SEARCH` | `False` | Global enable; also needs a search engine configured. |
| `WEB_SEARCH_ENGINE` | `''` | Set `searxng`; full enum in the env reference. |
| `SEARXNG_QUERY_URL` | `''` | JSON-capable SearXNG endpoint, e.g. `…/search?q=<query>`. |
| `WEB_SEARCH_RESULT_COUNT` | `3` | Max results; also cap for native `search_web`. |
| `WEB_SEARCH_CONCURRENT_REQUESTS` | `0` | `0` = unlimited; set `1` for rate-limited instances. |
| `BYPASS_WEB_SEARCH_EMBEDDING_AND_RETRIEVAL` | `False` | Use snippets directly, no embedding/RAG. |

**Correction:** `BYPASS_WEB_SEARCH_EMBEDDING` does **not** exist. The real name is `BYPASS_WEB_SEARCH_EMBEDDING_AND_RETRIEVAL` (`config.py` L1179). Docs: <https://docs.openwebui.com/reference/env-configuration#web-search>.

**Injection vs tool call.** On 0.9.6, unless a model is explicitly `function_calling=native`, OWUI runs `chat_web_search_handler`, generates queries, searches, and injects the results as `files`/RAG context before the completion — automatically, no model tool call (<https://github.com/open-webui/open-webui/blob/v0.9.6/backend/open_webui/utils/middleware.py#L2568-L2575>). On 0.12.3 native tool calling is the default (as of v0.10.0, <https://github.com/open-webui/open-webui/releases/tag/v0.10.0>); OWUI instead exposes built-in `search_web`/`fetch_url` tools and the model decides when to call them (<https://docs.openwebui.com/features/chat-conversations/web-search/agentic-search>). The legacy branch remains at `middleware.py` L2354-L2363. Native requires the model's **Web Search capability** and the **Web Search default feature** (or the chat toggle) — the docs call this out explicitly.

**Exact config for today (0.9.6):**
```env
ENABLE_WEB_SEARCH=true
WEB_SEARCH_ENGINE=searxng
SEARXNG_QUERY_URL=https://spicy-search-searxng-elhm2qjlta-uc.a.run.app/search?q=<query>
SEARXNG_LANGUAGE=en
WEB_SEARCH_RESULT_COUNT=5
WEB_SEARCH_CONCURRENT_REQUESTS=1
BYPASS_WEB_SEARCH_EMBEDDING_AND_RETRIEVAL=true
BYPASS_WEB_SEARCH_WEB_LOADER=true
ENABLE_SEARCH_QUERY_GENERATION=false
ENABLE_WEB_SEARCH_CONFIRMATION=false
```
`BYPASS_WEB_SEARCH_WEB_LOADER=true` keeps OWUI from fetching result pages server-side (snippet-only), avoiding SSRF/anti-bot and latency; the var is documented at <https://docs.openwebui.com/reference/env-configuration#bypass_web_search_web_loader>. For 0.12.3 add `DEFAULT_MODEL_PARAMS={"function_calling":"native"}`, enable the model capability, and enable the Web Search default feature; otherwise set `function_calling` to `legacy` to keep auto-injection.

**Measured today:** `GET /search?q=test&format=json` → 200, 145 results. But `q=brunette videos` returns Wikipedia, Merriam-Webster, Pixabay and Getty stock footage — **not** the spicy-search catalogue. Generic search cannot satisfy goal (b). Also, OWUI's SearXNG client hardcodes `safesearch=1` (<https://github.com/open-webui/open-webui/blob/v0.12.3/backend/open_webui/retrieval/web/searxng.py#L55-L60>); it is not a reliable adult-content filter.

## 2. OpenRouter `:online`

`:online` is shorthand for the `web` plugin and is appended to a model slug, e.g. `openai/gpt-5.2:online`; it runs one search per request and costs extra even on free models. Pricing is per request via OpenRouter credits (Exa $0.007/request, native search passed through from provider): <https://openrouter.ai/docs/guides/features/plugins/web-search> (accessed 2026-10-19). Terms require 18+ and make the account responsible for keys/charges: <https://openrouter.ai/terms>.

**Not viable now.** The Open WebUI deployment only configures the Abliteration key (`OPENAI_API_KEY=<secret: spicy-search-abliteration-key>`; no OpenRouter secret) — `gcp/openwebui/README.md`. No `OPENROUTER_API_KEY` exists in this environment, and the operator reports the former key returns 401 `User not found`; that 401 is **UNVERIFIED** here. Enabling it also sends prompts and search queries to OpenRouter plus its search subprocessor — new data-egress/ToS surface for adult queries.

## 3. Abliteration.ai API

**There is no “Abliteration AI browser” product.** But the API is not text/image-only: official docs list **server-side web search** on all three surfaces and **web fetch** on Anthropic Messages (<https://docs.abliteration.ai/capabilities/web-search>, <https://docs.abliteration.ai/capabilities/web-fetch>, <https://docs.abliteration.ai/models>; accessed 2026-10-19). Chat Completions takes top-level `web_search_options` with `search_context_size` `low|medium|high` = 5/10/20 results; it is **mutually exclusive with `tools`** (both → 400). Enable per account under **Account → Web tools**; project `allowed_domains`/`blocked_domains` act as ceilings. Inline citations are returned.

**Verified 2026-10-19 with the live key** (the account Web-tools toggle is enabled):

- General query, `search_context_size=medium`: HTTP 200, **4.99 s**, **12 URL citations**, 6,196 prompt / 490 completion tokens.
- Legal adult query, `search_context_size=low`: HTTP 200, **18.8 s**, **36 URL citations** (adult sites), **no refusal**, 17,166 prompt / 2,363 completion tokens; `finish_reason=length` at `max_tokens=1024`, so production needs a larger budget.
- Cost at Abliteration's $3/M prompt + $5/M completion: **~$0.02/query** (general/medium) to **~$0.06/query** (adult/low), driven by search-context prompt tokens, not completion.
- Local artifacts: `/tmp/abl_websearch.json`, `/tmp/abl_websearch_adult.json`.

Do **not** put `web_search_options` in static model `custom_params`: OWUI's tool-calling path would send `tools` in the same request, Abliteration returns HTTP 400 for that combination, and a static param would run (and bill) a search on every turn. The supported design is the on-demand `web_search` Workspace Tool in §6, which makes a separate tool-less call with `web_search_options`. Constraints: `web_search_options` is **mutually exclusive with `tools`** (both → 400); the separate `web_search` sub-call must not send `tools`, while the main chat model keeps tool calling enabled for the Workspace Tools. OWUI has no provider-native sources panel, so citations appear inline in the text. It does **not** ground the spicy-search catalogue, so goal (b) still needs the thin catalogue tool.

## 4. xAI Live Search (`search_parameters`)

xAI Chat Completions still documents top-level `search_parameters` with `mode: off|on|auto`, `sources` (default web **and X**), `max_search_results`, `return_citations` (<https://docs.x.ai/developers/rest-api-reference/inference/chat-completions>). The current tool-shaped API is a Responses `web_search` tool (<https://docs.x.ai/developers/tools/web-search>). Web Search is billed $5 per 1,000 calls (<https://docs.x.ai/developers/pricing>).

It is a different provider from Abliteration: a second key, second model, and separate moderation/ToS. Whether it refuses adult content is **UNVERIFIED** (xAI's legal pages returned HTTP 403 here). It cannot ground the spicy-search catalogue, so it fails goal (b).

## 5. Full agent browser SDK

Playwright is a test/automation framework; authenticated sessions require exporting and reusing `storageState` (<https://playwright.dev/docs/auth>). Browserbase sells cloud browsers plus search/fetch (<https://docs.browserbase.com/welcome/introduction>); Stagehand adds AI `act`/`extract`/`observe` (<https://docs.stagehand.dev/v4/first-steps/introduction>); Aside is another hosted browser agent (<https://docs.aside.com/>). Costs: a browser process per session, anti-bot/CAPTCHA handling, cookie/age-gate/login storage, page-layout churn, and site-ToS exposure. For “find me videos” this is a large, brittle subsystem when a catalogue API already returns ranked rows with tags and `source_url`.

## 6. Thin tools inside Open WebUI (recommended)

Do **not** build a new FastAPI/Cloud Run service. OWUI v0.12.3 supports **Workspace Tools** — Python functions stored in its existing Cloud SQL and executed in-process by the OWUI backend (`Settings → Admin → Workspace → Tools`; <https://docs.openwebui.com/features/extensibility/plugin/tools/>). Two tools solve both goals on the SAME `abliterated-model-large-v2` model, with tool calling enabled and **no static `web_search_options`** (static params would 400 against `tools` and bill every turn):

1. `catalogue_search(query, limit<=10)` — calls the spicy-search catalogue and returns `{sceneId,title,url,snippet}`. This is the only path that grounds to real catalogue rows.
2. `web_search(query)` — makes a **separate, tool-less** Abliteration `/v1/chat/completions` call with `web_search_options={"search_context_size":"low"}` and returns the answer plus its URL citations. On-demand only; no per-turn billing, and no `tools` in that sub-call, so the mutual exclusion never fires.

The chat model chooses when to call them. If it fails to call `catalogue_search`, strengthen the tool description or system prompt; if tool calling is weak, fall back to OWUI's native `search_web` with SearXNG (free) rather than rebuilding.

- **Auth boundary (must fix):** `/api/search` returns 401 `age_gate_required`; a shared service-owned `age_ok` cookie would funnel every OWUI user into ONE `clientKey(clientIp, null)` rate-limit bucket and is a reusable age-gate bypass. Add a small **service-token route** in spicy-search (`POST /api/internal/search`, bearer from Secret Manager, explicit 18+ assertion, per-user identity/session id passed by the OWUI tool) — ~30 lines. Do not reuse a global age cookie.
- **18+ enforcement (required, not optional):** OWUI login alone is not an age gate. Create an OWUI group `age-verified`; only its members may use either tool. The Workspace Tool checks the caller's `__user__` group membership and refuses otherwise; the internal route requires the service token **plus** an `age_verified: true` assertion from OWUI. Admins add users only after an explicit 18+ check. This is the enforceable boundary; do not rely on the service token or a per-user id as proof of age.
- **Contract:** `catalogue_search` maps `SearchResult` (`id`, `title`, `tags`, `summary`, `duration_seconds`, `quality`, `source_url`; `spicy-search/lib/types.ts` L132-L147) to `{sceneId,title,url,snippet}`. `web_search` returns `{answer, citations:[{url,title}]}` from the API `annotations`.
- **Size:** ~50–80 lines of Python total (two Workspace Tools) plus a ~30-line internal route. No new service, no container, no OpenAPI server.
- **Latency/reliability:** `/api/search` measured ~7.9 s for a 2-row query; set a 30 s timeout and return a typed failure (not an empty success) on 503 `ai_search_unavailable`. Native web search measured 5–19 s and $0.02–$0.06/call; call it only on demand.

**Alternative if Workspace Tools are unavailable:** OWUI's `external` search engine POSTs `{query,count}` and expects `[{link,title,snippet}]` (<https://github.com/open-webui/open-webui/blob/v0.12.3/backend/open_webui/retrieval/web/external.py#L13-L44>; docs <https://docs.openwebui.com/features/chat-conversations/web-search/providers/external>). A ~50-line adapter can return catalogue rows as `link/title/snippet` and fall back to SearXNG. Downside: only one global engine, so every web search becomes catalogue-first.

## Recommendation

1. **Upgrade to v0.12.3** and add the two **Workspace Tools** above. Keep tool calling enabled; do **not** put `web_search_options` in static model params (that conflicts with `tools` and bills every turn). Gate both tools behind an OWUI `age-verified` group; the tool checks membership and the internal route requires an `age_verified` assertion.
2. **General web search (goal a):** on-demand `web_search` tool (paid, 5–19 s, $0.02–$0.06) plus OWUI's native `search_web` + the SearXNG env block as the free fallback. Use SearXNG when cost/latency matters; use the native tool when citations matter.
3. **“Find me videos” (goal b):** `catalogue_search` → the service-token `/api/internal/search` route. This is the only grounded path; generic web search is not.
4. **Do not** merge catalogue and web results into one engine initially; keep provenance obvious.
5. **Post-upgrade UI test:** `catalogue_search` returns real rows, `web_search` returns citations, no HTTP 400, and the 18+ boundary is enforced.

## Security / ToS caveats

- OWUI has login but **no 18+ gate**; the age gate lives in spicy-search (`gcp/openwebui/README.md`). Both tools must be restricted to an OWUI `age-verified` group (membership checked by the tool; `age_verified` asserted to the internal route). Without this, any logged-in OWUI user could receive adult rows/links.
- SearXNG forwards queries to upstream engines (Google/Bing/etc.; several were “Suspended” during today's probe). Queries leave your infrastructure even though SearXNG is self-hosted (<https://docs.searxng.org/>). Don't send secrets/PII.
- Keep `BYPASS_WEB_SEARCH_WEB_LOADER=true`; server-side page fetching is an SSRF and anti-bot surface. OWUI does ship a metadata-endpoint blocklist (`WEB_FETCH_FILTER_LIST`), but not a general safety guarantee.
- A shared service-owned `age_ok` cookie is a reusable age-gate bypass AND funnels every OWUI user into one rate-limit bucket. Use a purpose-built service token + per-user session id instead; keep the token in Secret Manager.
- Never scrape adult sites with Playwright/Browserbase; site terms, robots, consent and age gates apply, and content may be illegal in some jurisdictions.

## What NOT to build

- A browser-agent fleet or headless-Chrome service for “find videos”.
- A crawler/index/vector store for web or catalogue content.
- A custom search UI, or a public unauthenticated proxy of `/api/search`.
- OpenRouter `:online` on a dead key, or xAI as a second model provider.
- RAG embeddings for web search (`BYPASS_WEB_SEARCH_EMBEDDING_AND_RETRIEVAL=true`).

## Sources

- Open WebUI v0.9.6 / v0.12.3 releases: <https://github.com/open-webui/open-webui/releases/tag/v0.9.6>, <https://github.com/open-webui/open-webui/releases/tag/v0.12.3>.
- OWUI env reference: <https://docs.openwebui.com/reference/env-configuration#web-search>; web search: <https://docs.openwebui.com/features/chat-conversations/web-search>; SearXNG provider: <https://docs.openwebui.com/features/chat-conversations/web-search/providers/searxng>.
- Abliteration: <https://docs.abliteration.ai/capabilities/web-search>, <https://docs.abliteration.ai/capabilities/web-search/openai-chat-completions>, <https://docs.abliteration.ai/capabilities/web-fetch>, <https://docs.abliteration.ai/models>.
- OpenRouter: <https://openrouter.ai/docs/guides/features/plugins/web-search>, <https://openrouter.ai/terms>.
- xAI: <https://docs.x.ai/developers/rest-api-reference/inference/chat-completions>, <https://docs.x.ai/developers/tools/web-search>, <https://docs.x.ai/developers/pricing>.
- Browser SDKs: <https://playwright.dev/docs/auth>, <https://docs.browserbase.com/welcome/introduction>, <https://docs.stagehand.dev/v4/first-steps/introduction>, <https://docs.aside.com/>.
- Local evidence: `gcp/openwebui/README.md`; `spicy-search/lib/types.ts` L132-L147; `spicy-search/docs/research/2026-10-19-head-to-head-verdict.md` L20-L25.
