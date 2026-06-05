# Reproducibility Status

**Last updated:** 2026-06-05

This repository is currently an evidence repo with a partial harness. It has
enough committed material to inspect prior local and GCP experiments, but not
enough to reproduce every claimed pipeline step from a fresh clone without
manual setup.

## What is reproducible from committed files

- `install.sh` starts Open WebUI in Docker against a local Ollama server. It is a
  chat UI launcher only; it does not install Heretic, patch Heretic, run
  ablation, convert models to GGUF, or benchmark outputs.
- `results/phase1-smoke/REPORT.md` documents the first local stock-vs-heretic
  smoke test and points to committed prompt/transcript artifacts in the same
  directory.
- `results/2026-06-05_erotica-smoke/REPORT.md` documents the long-context local
  A/B run, including the unload strategy used to avoid simultaneous model
  residency. Raw prompt/output files are committed beside it.
- `results/2026-06-05_erotica-baseline-400/REPORT.md` is a pre-bead quick check,
  not a full A/B benchmark. Treat it as evidence that the prompt path worked, not
  as a refusal-rate comparison.
- The single-model creative-output runs under `results/2026-06-05_*` include
  prompts, metadata, and raw responses for `svjack/gpt-oss-20b-heretic:latest`.

## What is documented but blocked or historical

- `gcp/` contains a Cloud Run L4 Docker image and deploy recipe for Ollama.
- `results/2026-06-05_gcp-phase1-rerun/REPORT.md` and `summary.json` record the
  actual GCP result: both `gpt-oss:20b` and `svjack/gpt-oss-20b-heretic` pulled,
  but inference was blocked because MXFP4 kernels require a compatible GPU path
  and Cloud Run L4 is Ada Lovelace. CPU fallback was OOM-killed in the 32 GB
  container.
- The GCP service URL in `gcp/README.md` is historical. The report says the
  service was torn down after the run to avoid idle GPU cost.

## What is not yet a fresh-clone harness

- There is no committed `scripts/` directory with a repeatable local ablation,
  conversion, or benchmark command.
- There is no committed `patches/` directory containing the Heretic kernel
  revision fixes described in `docs/RESEARCH_PLAN.md`.
- There is no committed `docs/BENCHMARK_PROTOCOL.md`; benchmark metrics and
  prompt-set design are still sketched in `docs/RESEARCH_PLAN.md`.
- There is no committed `Modelfile` or GGUF conversion path for importing a DIY
  ablated model into Ollama.
- The ignored `heretic/` checkout is not a source of truth. Because `.gitignore`
  ignores `heretic/`, the local `heretic/SOURCE.md` note is not committed.

## Current upstream source contract

For DIY Heretic work, recreate the upstream checkout manually:

```bash
git clone https://github.com/p-e-w/heretic.git heretic
cd heretic
git checkout v1.3.0
```

The PyPI tool path used in docs is:

```bash
uv tool install heretic-llm
```

Before this becomes a true reproducible harness, the repo should commit either
patch files or exact patch instructions outside ignored `heretic/`, plus the
commands that turn a patched Heretic run into an Ollama-loadable model.

## Minimal fresh-clone smoke path

1. Install Docker, Ollama, `curl`, and `uv` outside this repo.
2. Start Ollama locally.
3. Optionally run `./install.sh` to start Open WebUI on `127.0.0.1:3100`.
4. Pull the prebuilt model with `ollama pull svjack/gpt-oss-20b-heretic`.
5. Re-run one of the local report command shapes from `results/*/REPORT.md`.

That path reproduces prebuilt-model probing. It does not reproduce DIY
abliteration yet.
