# Research Plan — Heretic on M4 Pro

**Captured:** 2026-06-05
**Source:** Slack thread `C09GRLXF9GR` (jleechan ↔ hermes) — see [original](https://jleechanai.slack.com/archives/C09GRLXF9GR/p1780291876.887979)

## Goal

Reproducibly abliterate open-weights LLMs on consumer Apple Silicon, import the results into Ollama, and benchmark behavior vs. the stock baseline. The end deliverable is a working pipeline + reproducible numbers, not a packaged product.

## Hardware

| Spec | Value |
|---|---|
| Chip | Apple M4 Pro |
| Cores | 14 |
| Unified memory | 51 GB |
| Metal | 3 |
| macOS | Darwin 24.5.0 |

M4 Pro unified memory is **shared with system**. Batch sizes that overshoot 8 GB MPS allocation may OOM silently.

## Software baseline

- **Ollama** running locally (default `:11434`)
- Already installed models: `gpt-oss:20b` (13 GB), `gemma3:12b` (8.1 GB), `gemma2:2b`, `nomic-embed-text`
- **Heretic** installed via `uv tool install heretic-llm` (or `uv run` from source for development)

## Model picks (ranked for M4 Pro 51 GB)

1. **🥇 `brianmatzelle/gpt-oss-heretic`** — pre-abliterated, Ollama-available
   - 20B MoE, MXFP4-quantized, 13 GB in RAM
   - "the best uncensored model I have tried yet… doesn't destroy the model's intelligence" — Reddit consensus
   - Fits in current RAM with headroom → **best smoke-test target**

2. **🥈 `gemma3:12b` DIY abliteration** — reference benchmark
   - 8.1 GB, the model p-e-w's published 3/100-refusal benchmark is on
   - 20–30 min to abliterate on M4 Pro
   - Apples-to-apples comparison with upstream numbers

3. **🥉 `Qwen3-4B-Instruct-2507-heretic`** — p-e-w's own 16 GB-VRAM pick
   - "the best unquantized abliterated model that I have been able to run on 16gb vram"
   - Fast iteration loop

4. **`gemma3:4b` DIY** — smallest viable end-to-end pipeline test
   - 5 min ablation on M4 Pro
   - Use to validate the pipeline before scaling up

## Phased test plan

### Phase 1 — Smoke test (no ablation)

- Pull `brianmatzelle/gpt-oss-heretic` from Ollama registry
- Send a known refused prompt to both `gpt-oss:20b` (stock) and the heretic build
- Compare response quality, refusal rate, KL divergence (subjective)
- **Pass criteria:** heretic build refuses measurably less, output is still coherent

### Phase 2 — End-to-end local ablation

- Ablate `gemma3:4b` (smallest viable) via Heretic
- Run with conservative batch flags to avoid the M4 OOM trap (see [Known issues](#known-issues))
- Convert HF → GGUF via `llama.cpp/convert_hf_to_gguf.py`
- Import to Ollama via `Modelfile`
- A/B benchmark against `gemma3:4b` stock

### Phase 3 — Scale up

- Re-run ablation on `gemma3:12b` (the reference benchmark target)
- Compare against published p-e-w numbers (3/100 refusals, 0.16 KL)

## Known issues

### M4 Pro batch-size stall

- Heretic's auto batch-size detection tries 64 → 128; **batch 128 hangs on M4 Pro**
- Symptom: process alive, CPU 17–87 %, RSS drops from 89 MB → 23 MB (model temporarily offloaded), `tee` log stops flushing
- Likely root cause: 128-batch test overshoots available MPS memory; model reloads silently and retries
- **Workaround:** force conservative batch from the start

```bash
uv run heretic \
  --model Qwen/Qwen3-4B-Instruct-2507 \
  --batch-size 32 \
  --max-batch-size 32 \
  --print-responses \
  --no-plot-residuals \
  --output-dir ./results/qwen3-4b-heretic
```

### Required Heretic kernel patches

Heretic's bundled `kernels` package has a pinned `revision=` that breaks against the live upstream. Two patches are required before import works:

1. `kernels/layer/layer.py` — default `revision="main"` instead of pinned SHA
2. `kernels/layer/func.py` — same

These were validated locally in the originating session (2026-06-04). Port them into `patches/` here so future runs are reproducible.

## Benchmark protocol (TBD)

To be written into `docs/BENCHMARK_PROTOCOL.md`. Sketch:

- **Prompt set:** 50 safe + 50 unsafe prompts, fixed seed
- **Metrics:**
  - Refusal rate (human-graded OR LLM-graded with stock gpt-oss as judge)
  - KL divergence to stock model on benign inputs
  - MMLU / ARC delta (capability loss)
  - Per-prompt latency on M4 Pro
- **Reporting:** side-by-side table in `results/<run>/REPORT.md` with raw transcripts

## Out of scope

- Jailbreak prompt engineering (this is about *model* modification, not *prompt* modification)
- Production deployment of abliterated models
- Any commercial use of outputs

## Open questions

- Is KL-divergence to the stock model a fair capability-preservation metric on MoE (`gpt-oss:20b`)?
- Does `--print-responses` flush line-by-line under `tee`? (Likely no — the `tee` in the originating session was line-buffered and progress bars used `\r`.)
- What's the M4 Pro break-even point — at what model size does abliteration become faster on cloud GPU?

## Next action

Pick a model (suggest **gpt-oss-heretic** for smoke test) and a phase (suggest **Phase 1**). Record results in `results/<date>-<model>/` and update this doc with findings.
