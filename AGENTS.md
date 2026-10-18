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

