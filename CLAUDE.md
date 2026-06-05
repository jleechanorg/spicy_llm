# spicy_llm Claude Instructions

This repo is for local abliteration and decensoring research. Raw prompts and
model transcripts may intentionally include content that normal production
assistants refuse.

## Local Policy

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

## Work Style

- Use `.claude/commands/spicy-llm.md` or the `spicy-llm` skill when testing the
  local Ollama/Heretic setup.
- Use `br` for beads issue tracking.
- Keep README/status docs honest about what is actually committed and runnable.
- Treat `heretic/` as an ignored local upstream checkout. Track reproducibility
  pins, patch notes, and commands in committed repo files instead.
- Check ignore-rule changes with `git check-ignore` before calling them done.
- Preserve unrelated local changes.
