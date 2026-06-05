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
