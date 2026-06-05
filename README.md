# spicy_llm

Local abliteration research — testing **[Heretic](https://github.com/p-e-w/heretic)** + [Ollama](https://ollama.com) pipelines for "decensoring" (removing safety alignment from) LLMs on Apple Silicon.

> **What this is:** a reproducible harness for running directional-ablation abliteration on local models and benchmarking the results against stock baselines. Originated from a Slack discussion ([thread](https://jleechanai.slack.com/archives/C09GRLXF9GR/p1780291876.887979)) about applying [p-e-w/heretic](https://github.com/p-e-w/heretic) (22.4k ⭐, AGPL-3.0) to consumer Mac hardware.

## Hardware target

- **Apple M4 Pro**, 14 cores, 51 GB unified memory, Metal 3
- macOS Darwin 24.5.0, Python 3.12, Ollama ≥ 0.5

## Why "spicy"

Abliterated models are colloquially called "uncensored" or "spicy" in the open-source LLM community. The name is honest about what the tool produces and avoids euphemism.

## Repository layout

```
spicy_llm/
├── README.md                 # this file — current status
├── docs/
│   ├── RESEARCH_PLAN.md      # M4 Pro test plan, model picks, phases
│   ├── BENCHMARK_PROTOCOL.md # how to A/B test stock vs abliterated (TODO)
│   └── HERETIC_PATCHES.md    # kernel patch notes + reproducibility (TODO)
├── patches/                  # Heretic kernel patches ported here (TODO)
│   ├── layer.py.rev-main
│   └── func.py.rev-main
├── scripts/                  # reproducible run scripts (TODO)
│   ├── run_heretic.sh
│   ├── convert_to_ollama.sh
│   └── benchmark.py
├── results/                  # gitignored — model outputs, A/B transcripts
│   ├── 2026-06-05_svjack-gpt-oss-20b-heretic_smoke/
│   └── 2026-06-04_qwen3-4b_stall/
└── .gitignore
```

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

# 2. Start Ollama
ollama serve &
ollama pull gpt-oss:20b        # reference baseline
ollama pull gemma3:12b         # reference benchmark target

# 3. Smoke test a prebuilt heretic model (no DIY ablation)
ollama pull svjack/gpt-oss-20b-heretic
ollama run  svjack/gpt-oss-20b-heretic  "Explain how a transistor works."

# 4. Ablate a small model end-to-end (DIY)
heretic --model Qwen/Qwen3-4B-Instruct-2507 \
        --batch-size 32 --max-batch-size 32 \
        --print-responses --no-plot-residuals \
        --output-dir ./results/qwen3-4b-heretic
```

See **[docs/RESEARCH_PLAN.md](docs/RESEARCH_PLAN.md)** for the full phased plan, hardware constraints, and the M4 Pro batch-128 workaround.

## Upstream & references

- [p-e-w/heretic](https://github.com/p-e-w/heretic) — the abliteration tool (22.4k ⭐, AGPL-3.0, v1.3.0)
- [svjack/gpt-oss-20b-heretic](https://ollama.com/svjack/gpt-oss-20b-heretic) — prebuilt 20B MoE on Ollama registry
- [p-e-w/Qwen3-4B-Instruct-2507-heretic](https://huggingface.co/p-e-w/Qwen3-4B-Instruct-2507-heretic) — author's own 16 GB-VRAM pick
- [mlabonne/harmless_alpaca](https://huggingface.co/datasets/mlabonne/harmless_alpaca) — "good" prompts (default in Heretic)
- [mlabonne/harmful_behaviors](https://huggingface.co/datasets/mlabonne/harmful_behaviors) — "bad" prompts (default in Heretic)
- [Originating Slack thread](https://jleechanai.slack.com/archives/C09GRLXF9GR/p1780291876.887979)

## License

This research repo is **AGPL-3.0** to match the upstream [p-e-w/heretic](https://github.com/p-e-w/heretic) license. Any model output is bound by its own upstream license.
