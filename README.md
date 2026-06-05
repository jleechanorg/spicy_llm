# spicy_llm

Local abliteration research — testing **[Heretic](https://github.com/p-e-w/heretic)** + [Ollama](https://ollama.com) pipelines for "decensoring" (removing safety alignment from) LLMs on Apple Silicon.

> **What this is:** a reproducible harness for running directional-ablation abliteration on local models and benchmarking the results against stock baselines. Originated from a Slack discussion ([thread](https://jleechanai.slack.com/archives/C09GRLXF9GR/p1780291876.887979)) about applying [p-e-w/heretic](https://github.com/p-e-w/heretic) (22.4k ⭐, AGPL-3.0) to consumer Mac hardware.

## Hardware target

- **Apple M4 Pro**, 14 cores, 51 GB unified memory, Metal 3
- macOS, Python 3.12, Ollama ≥ 0.5

## Why "spicy"

Abliterated models are colloquially called "uncensored" or "spicy" in the open-source LLM community. The name is honest about what the tool produces and avoids euphemism.

## Repository layout

```
spicy_llm/
├── README.md                 # this file
├── docs/
│   ├── RESEARCH_PLAN.md      # M4 Pro test plan, model picks, phases
│   ├── BENCHMARK_PROTOCOL.md # how to A/B test stock vs abliterated (TODO)
│   └── HERETIC_PATCHES.md    # notes on the kernel patches (TODO)
├── scripts/                  # reproducible run scripts (TODO)
│   ├── run_heretic.sh
│   ├── convert_to_ollama.sh
│   └── benchmark.py
├── results/                  # output models + benchmark logs (gitignored)
└── .gitignore
```

## Quick start (intended)

```bash
# 1. Install heretic (pinned)
uv tool install heretic-llm

# 2. Start Ollama
ollama serve &
ollama pull gpt-oss:20b        # reference baseline
ollama pull gemma3:12b         # reference benchmark target

# 3. Ablate a small model end-to-end
heretic --model google/gemma-3-4b-it \
        --batch-size 32 --max-batch-size 32 \
        --output-dir ./results/gemma3-4b-heretic
```

See **[docs/RESEARCH_PLAN.md](docs/RESEARCH_PLAN.md)** for the full phased plan and per-model commands.

## Upstream & references

- [p-e-w/heretic](https://github.com/p-e-w/heretic) — the abliteration tool
- [mlabonne/harmless_alpaca](https://huggingface.co/datasets/mlabonne/harmless_alpaca) — "good" prompts dataset (default in Heretic)
- [mlabonne/harmful_behaviors](https://huggingface.co/datasets/mlabonne/harmful_behaviors) — "bad" prompts dataset (default in Heretic)
- [Originating Slack thread](https://jleechanai.slack.com/archives/C09GRLXF9GR/p1780291876.887979)

## Status

- [x] Repo scaffold + research plan drafted
- [ ] Heretic kernel patches ported & tested
- [ ] End-to-end gemma3:4b ablation
- [ ] Ollama import + side-by-side benchmark
- [ ] Larger gemma3:12b run

## License

This research repo is **AGPL-3.0** to match the upstream [p-e-w/heretic](https://github.com/p-e-w/heretic) license. Any model output is bound by its own upstream license.
