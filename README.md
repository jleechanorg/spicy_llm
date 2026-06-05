# spicy_llm

Local abliteration research — testing **[Heretic](https://github.com/p-e-w/heretic)** + [Ollama](https://ollama.com) pipelines for "decensoring" (removing safety alignment from) LLMs on Apple Silicon.

> **What this is now:** an evidence repo with a partial local/GCP harness. It has
> committed run reports, raw outputs, a local Open WebUI launcher, and a Cloud Run
> image recipe. It does **not** yet contain a complete fresh-clone Heretic
> ablation pipeline or benchmark harness. Originated from a Slack discussion
> ([thread](https://jleechanai.slack.com/archives/C09GRLXF9GR/p1780291876.887979))
> about applying [p-e-w/heretic](https://github.com/p-e-w/heretic) (22.4k ⭐,
> AGPL-3.0) to consumer Mac hardware.

## Hardware target

- **Apple M4 Pro**, 14 cores, 51 GB unified memory, Metal 3
- macOS Darwin 24.5.0, Python 3.12, Ollama ≥ 0.5

## Why "spicy"

Abliterated models are colloquially called "uncensored" or "spicy" in the open-source LLM community. The name is honest about what the tool produces and avoids euphemism.

## Repository layout

```
spicy_llm/
├── AGENTS.md                 # project instructions for agents
├── CLAUDE.md                 # Claude-facing project instructions
├── README.md                 # this file — current status and quick start
├── USAGE_POLICY.md           # model/tool license + usage notes
├── install.sh                # optional local Open WebUI launcher for Ollama
├── beads/                    # br issue-tracking data for this repo
├── docs/
│   ├── REPRODUCIBILITY_STATUS.md # what is reproducible vs still missing
│   └── RESEARCH_PLAN.md          # M4 Pro test plan, model picks, phases
├── gcp/
│   ├── Dockerfile             # Cloud Run L4 Ollama image recipe
│   ├── README.md              # historical GCP run notes and blocked status
│   ├── entrypoint.sh          # starts Ollama and pulls stock/heretic models
│   └── openwebui/             # Cloud Run + Cloud SQL Open WebUI deployment
├── results/                   # tracked small evidence artifacts; heavy files ignored
│   ├── phase1-smoke/
│   ├── 2026-06-05_erotica-baseline-400/
│   ├── 2026-06-05_erotica-smoke/
│   ├── 2026-06-05_explicit-erotica-scene/
│   ├── 2026-06-05_gcp-phase1-rerun/
│   ├── 2026-06-05_original-elf-erotica-chapter/
│   ├── 2026-06-05_supernatural-bar-flashforward-hidden-prompt/
│   └── 2026-06-05_supernatural-bar-flashforward-violence-after/
└── .gitignore
```

The ignored `heretic/` directory is a local upstream checkout, not committed
source. A note currently exists at `heretic/SOURCE.md`, but because the whole
directory is ignored it is local-only; see
[docs/REPRODUCIBILITY_STATUS.md](docs/REPRODUCIBILITY_STATUS.md) for the
reproduction contract.

## Status — last updated 2026-06-05 01:19 UTC

This tracks the live Slack thread `C09GRLXF9GR`. Read it as a snapshot of what's been learned, not a checklist of dreams.

### ✅ Confirmed working

| Item | Evidence | Date |
|---|---|---|
| **Heretic kernel patches** — both `kernels/layer/layer.py` and `kernels/layer/func.py` default `revision="main"` | Import succeeds cleanly on macOS / Python 3.12 | 2026-06-04 |
| **Heretic runs on MPS** — Qwen3-4B-Instruct-2507 loaded, 7.5 GB allocated / 8 GB reserved, 36 attention+MLP layers identified | Session 2 telemetry | 2026-06-04 |
| **Phase 1 smoke test (prebuilt)** — `svjack/gpt-oss-20b-heretic` (15 GB) pulled into Ollama, decensoring confirmed at the behavior level: stock `gpt-oss:20b` refuses harmful prompt, heretic build complies | Session 3 A/B test | 2026-06-05 |

### ⚠️ Open issues

- **Heretic build crashes on benign prompts** with Ollama 500 error (Session 3). Likely **MPS OOM** — stock (13 GB) + heretic (15 GB) loaded simultaneously = 28 GB on 51 GB unified memory, but model-loading spike or context growth exceeds the 8 GB MPS allocation. Fix: unload stock first, swap models, or run on a single model.
- **DIY ablation stalled at batch-128** during 2026-06-04 run on Qwen3-4B-Instruct-2507. RSS dropped 89 MB → 23 MB (model offloaded silently), `tee` log not flushing for 30+ min, but process stayed alive. Workaround: restart with `--batch-size 32 --max-batch-size 32` to skip the auto-detection that tries 64→128.

### 🛠 Model pick correction

The plan was updated to use **`svjack/gpt-oss-20b-heretic`** (20B MoE, ~15 GB). Hermes verified on 2026-06-05 that `brianmatzelle/gpt-oss-heretic` is the **120B** build — too large for the M4 Pro 51 GB. The plan's pick #1 is now svjack.

### 📋 Next actions

- [ ] Fix the heretic-build crash on benign prompts (unload/swap strategy)
- [ ] Re-run DIY ablation on `gemma3:4b` (or `Qwen3-4B-Instruct-2507`) with `--batch-size 32 --max-batch-size 32` from the start
- [ ] Port kernel patches into `patches/` directory in this repo for reproducibility
- [ ] Write `docs/BENCHMARK_PROTOCOL.md` — fixed prompt set, refusal-rate metric, KL divergence vs stock
- [ ] A/B benchmark stock vs heretic with side-by-side transcripts in `results/`
- [ ] Phase 3: scale up to `gemma3:12b` DIY ablation (20–30 min on M4 Pro)

## Quick start (intended)

```bash
# 1. Install heretic (pinned)
uv tool install heretic-llm

# 2. Start Ollama and pull the expected local models
ollama serve &
ollama pull gpt-oss:20b        # reference baseline
ollama pull svjack/gpt-oss-20b-heretic
ollama pull gemma3:12b         # reference benchmark target

# 3. Smoke test the prebuilt heretic model (no DIY ablation)
ollama run  svjack/gpt-oss-20b-heretic  "Explain how a transistor works."

# 4. Optional: start Open WebUI for local chat
./install.sh
# Open http://127.0.0.1:3100 and select svjack/gpt-oss-20b-heretic:latest

# 5. Optional: ablate a small model end-to-end (DIY)
heretic --model Qwen/Qwen3-4B-Instruct-2507 \
        --batch-size 32 --max-batch-size 32 \
        --print-responses --no-plot-residuals \
        --output-dir ./results/qwen3-4b-heretic
```

`./install.sh` runs Open WebUI in Docker on `127.0.0.1:3100`, connects it to
Ollama at `http://host.docker.internal:11434`, and stores chat history/config
locally in `~/.local/share/open-webui-spicy`. Start Ollama and pull
`svjack/gpt-oss-20b-heretic` before chatting in the UI; the model should appear
as `svjack/gpt-oss-20b-heretic:latest`. Override defaults with environment
variables, for example:

```bash
OPEN_WEBUI_PORT=3101 OPEN_WEBUI_DATA_DIR="$HOME/.local/share/open-webui-test" ./install.sh
```

For hosted GPU testing notes on GCP Cloud Run, see [gcp/README.md](gcp/README.md).
That path contains the L4 GPU Docker image and deploy command, but the committed
2026-06-05 rerun is blocked for `gpt-oss:20b`/`svjack/gpt-oss-20b-heretic`
inference on L4 because MXFP4 requires a compatible GPU path. Treat the URL in
that doc as historical unless you redeploy it.
For hosted browser chat with durable state, see
[gcp/openwebui/README.md](gcp/openwebui/README.md).

See **[docs/RESEARCH_PLAN.md](docs/RESEARCH_PLAN.md)** for the full phased plan, hardware constraints, and the M4 Pro batch-128 workaround.
See **[docs/REPRODUCIBILITY_STATUS.md](docs/REPRODUCIBILITY_STATUS.md)** for
the current fresh-clone gaps and committed evidence index.

## Upstream & references

- [p-e-w/heretic](https://github.com/p-e-w/heretic) — the abliteration tool (22.4k ⭐, AGPL-3.0, v1.3.0)
- [svjack/gpt-oss-20b-heretic](https://ollama.com/svjack/gpt-oss-20b-heretic) — prebuilt 20B MoE on Ollama registry
- [openai/gpt-oss-20b](https://huggingface.co/openai/gpt-oss-20b) — official base model, Apache-2.0
- [openai/gpt-oss](https://github.com/openai/gpt-oss) — official reference repo and usage policy
- [p-e-w/Qwen3-4B-Instruct-2507-heretic](https://huggingface.co/p-e-w/Qwen3-4B-Instruct-2507-heretic) — author's own 16 GB-VRAM pick
- [mlabonne/harmless_alpaca](https://huggingface.co/datasets/mlabonne/harmless_alpaca) — "good" prompts (default in Heretic)
- [mlabonne/harmful_behaviors](https://huggingface.co/datasets/mlabonne/harmful_behaviors) — "bad" prompts (default in Heretic)
- [Originating Slack thread](https://jleechanai.slack.com/archives/C09GRLXF9GR/p1780291876.887979)

## License and usage

This repo contains several different license surfaces:

- **Repository docs/scripts:** AGPL-3.0-or-later, matching upstream [p-e-w/heretic](https://github.com/p-e-w/heretic).
- **Heretic tool:** AGPL-3.0-or-later. If we distribute modified Heretic code or run modified Heretic as a network service, AGPL source obligations may apply.
- **Official `openai/gpt-oss-20b` base model:** Apache-2.0, with OpenAI's gpt-oss usage policy requiring compliance with applicable law.
- **Local `svjack/gpt-oss-20b-heretic` Ollama model:** local `ollama show` embeds Apache-2.0, but the Ollama page has no readme or separate license notes. Treat it as an Apache-2.0-derived community repack with incomplete provenance metadata.
- **Generated outputs:** not licensed as repo code by default. Use outputs subject to applicable law and normal output-risk review.

For redistribution or commercial use, prefer reproducing from the official `openai/gpt-oss-20b` weights and documenting the Heretic ablation process instead of relying only on the community Ollama repack. See [USAGE_POLICY.md](USAGE_POLICY.md).
