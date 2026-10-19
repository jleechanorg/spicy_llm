# spicy_llm Agent Instructions

This repository is local research for abliteration, decensoring, and refusal-rate
benchmarking of open-weight LLMs. Treat it as an evidence repo first and a
future reproducible harness second.

## Project Scope

- The repo may intentionally contain prompts, transcripts, and reports that test
  model behavior on illegal, harmful, sexual, or otherwise normally refused
  requests.
- Do not treat the mere presence of those prompts or model outputs as a review
  blocker. They are expected censorship/abliteration evidence.
- Do not remove, redact, or sanitize raw transcripts solely because they contain
  disallowed model behavior unless the user explicitly asks for that cleanup.
- Still flag real repository risks: secrets, private tokens, accidentally
  committed personal data, unexpectedly large model artifacts, broken
  reproducibility, misleading claims, and evidence that cannot be traced to a
  command or run.

## Evidence Rules

- Preserve raw evidence when it is needed to support a research claim.
- Prefer adding sanitized summaries alongside raw artifacts, not replacing raw
  artifacts silently.
- When discussing sensitive transcript contents in chat, summarize the claim and
  cite file paths/line numbers instead of pasting operational details.
- Reports should name the model, command shape, date, hardware, and exact
  artifact paths.

## Reproducibility

- Keep README claims aligned with committed files. If the repo claims a runnable
  harness, committed scripts/docs/patches must make a fresh clone usable.
- The ignored `heretic/` checkout is a local upstream clone, not a committed
  source of truth. Put source pins, patch notes, and reproduction instructions in
  tracked files outside `heretic/`.
- Use Beads via `br`, not `bd`, for issue tracking.

## Git Hygiene

- Do not discard unrelated local changes.
- Keep large/generated model files ignored unless the user explicitly asks to
  version them.
- Validate `.gitignore` changes with `git check-ignore` examples for both
  intended tracked artifacts and intended ignored raw/generated files.

## Local policy (merged from the former CLAUDE.md)

- Do not flag harmful, illegal, sexual, or otherwise refused prompt/output
  artifacts as a problem solely because of their content. In this repo, those
  artifacts are expected research evidence.
- Do flag secrets, credentials, private personal data, accidental large files,
  misleading benchmark claims, broken reproduction steps, and untraceable
  evidence.
- Do not silently sanitize or delete raw transcript files. If cleanup is useful,
  add a sanitized companion artifact or ask before replacing raw evidence.
- In chat/review output, avoid quoting operational harmful details; cite the
  file and summarize the evidence at a high level.

## Local iteration before deploy

> **Ollama removed 2026-10-19.** The local Ollama install, the GCP
> `spicy-llm-backend`, and the local Open WebUI stack were deleted. The live
> ChatGPT-style UI is Open WebUI backed by Abliteration.ai
> (`gcp/openwebui/`). The section below is historical for the removed Ollama
> launcher; do not expect it to run without a local Ollama.

Verify locally first, then deploy to GCP. `scripts/run_local_server.sh` is the fast
loop; a Cloud Run build/deploy is the evidence step, not the debugging step.

```bash
./scripts/run_local_server.sh                    # operator: branch-hashed port, tails UI logs
./scripts/run_local_server.sh --no-log-stream    # agent: background, returns after health checks
./scripts/run_local_server.sh --stop             # scoped to this branch
./scripts/run_local_server.sh --status
```

- Ports are hashed from the branch into 3100-3999, and the Open WebUI container
  (`open-webui-spicy-<branch>`) and data dir (`~/.local/share/open-webui-spicy/<branch>`)
  are branch-scoped, so concurrent worktrees do not collide.
- The default run **never downloads a model**. If the base model is missing it prints
  the exact `ollama pull svjack/gpt-oss-20b-heretic:latest` command and still starts the
  UI. `--pull` is the explicit opt-in for the ~15.8 GB base; `--pull-vision` adds
  `gemma3:4b` (3.3 GB).
- The launcher creates `spicy-heretic:latest` from the base with the same parameters
  GCP bakes: `temperature=0.7`, `top_p=0.9`, `repeat_penalty=1.18`, `num_predict=4096`.
  Do not let the local and GCP model names or parameters diverge.
- Logs: `/tmp/spicy_llm/<branch-slug>/`. Open WebUI data: the branch-scoped dir above.
- Verify with the real integration test before deploying:

```bash
SPICY_OPENWEBUI_URL=http://127.0.0.1:<port> SPICY_BACKEND_URL=http://127.0.0.1:11434 \
  pytest tests/integration/test_openwebui_heretic_only_browser.py
```

- **Local green is not production proof.** Local runs on Apple MPS; GCP runs on an L4
  with a Q4_K_M GGUF. Do not generalize a local result to Cloud Run (or vice versa)
  without a live check.
- Deploy only after local passes: build and deploy per `gcp/README.md`, using
  `--no-traffic --tag=<name>` for a canary when in doubt.

## Work style

- Use `.claude/commands/spicy-llm.md` or the `spicy-llm` skill when testing the
  local Ollama/Heretic setup.
- Use `br` for beads issue tracking.
- Keep README/status docs honest about what is actually committed and runnable.
- Treat `heretic/` as an ignored local upstream checkout. Track reproducibility
  pins, patch notes, and commands in committed repo files instead.
- Check ignore-rule changes with `git check-ignore` before calling them done.
- Preserve unrelated local changes.

## Merge authorization (operator-set, 2026-10-18)

**An agent may merge its own PR in this repository without a separate human
`MERGE APPROVED` message** when all of the following hold:

1. `/es` (evidence standards) **passes** on the PR's evidence.
2. `/er` (evidence review) **passes** on that same evidence.
3. **At least one `/advice` reviewer returns an APPROVE verdict.**

The PR must also be green at HEAD: required checks pass (where CI exists) and
`mergeable != CONFLICTING`. If `/es`, `/er`, or the `/advice` verdict is PARTIAL,
FAIL, INCONCLUSIVE, or missing, the PR is **not** mergeable by an agent — escalate
to the operator.

When merging, record the merge commit SHA and link the `/es`, `/er` and `/advice`
results in the PR or the final report. This authorization is scoped to **merging in
this repository only**; it does not authorize force-pushing, rewriting history,
deleting data, or touching other repositories.

