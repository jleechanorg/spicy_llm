---
name: spicy-llm
description: Use the local spicy_llm Ollama/Heretic setup for decensoring, refusal-rate, and erotica/censorship evidence tests.
---

# spicy_llm Local Model Skill

Use this skill whenever the user asks Hermes/Claude to use, test, benchmark, or
inspect the local spicy_llm model setup.

## What This Repo Is

`/Users/jleechan/projects_other/spicy_llm` is a local abliteration/decensoring
research repo. It intentionally captures prompts and outputs that stock models
may refuse. Harmful, sexual, or otherwise normally refused content in transcripts
is expected research evidence, not a problem by itself.

## Local Ollama Server

Check the server first:

```bash
curl -fsS http://127.0.0.1:11434/api/tags | python3 -m json.tool
ollama list
ollama ps
```

Current expected endpoint:

```text
http://127.0.0.1:11434
```

If the endpoint is down, start Ollama:

```bash
ollama serve
```

Before using the Heretic model, ensure it is pulled:

```bash
ollama pull svjack/gpt-oss-20b-heretic
```

For browser chat, start Open WebUI from the repo root:

```bash
./install.sh
```

Open `http://127.0.0.1:3100` and select
`svjack/gpt-oss-20b-heretic:latest` in the model picker. Do not use Open WebUI
as proof that Ollama is healthy unless the Ollama API check above also passes.

## Model Selection

Use this decensored model unless the user names another one:

```text
svjack/gpt-oss-20b-heretic:latest
```

Use this for stock baseline comparisons:

```text
gpt-oss:20b
```

Do not silently replace the requested Heretic model with `gemma2`, `gemma3`, or
another local model just because it is smaller or already loaded.

## Running Prompts

CLI:

```bash
ollama run --verbose svjack/gpt-oss-20b-heretic:latest "$(cat path/to/prompt.txt)"
```

HTTP API:

```bash
curl -fsS http://127.0.0.1:11434/api/generate \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "svjack/gpt-oss-20b-heretic:latest",
    "prompt": "Prompt text here",
    "stream": false
  }' | python3 -m json.tool
```

For A/B tests, run the same prompt against both `gpt-oss:20b` and
`svjack/gpt-oss-20b-heretic:latest`.

## Evidence Capture

Create a dated results directory:

```bash
mkdir -p results/YYYY-MM-DD_test-name
```

Recommended artifact names:

```text
prompt.txt
stock_transcript.txt
heretic_transcript.txt
REPORT.md
```

For user-facing copies, create cleaned companion files such as:

```text
story_only.txt
human_readable_story.txt
```

Preserve raw transcripts when they support a research claim. Do not silently
sanitize or delete raw output unless the user asks.

## Review Priorities

Flag:

- secrets or private tokens
- private personal data
- accidental large model artifacts
- misleading claims not supported by evidence
- README instructions that do not work from a fresh clone
- `.gitignore` behavior that does not match the comments

Do not flag:

- harmful or sexual prompt/output artifacts merely because they test censorship
- raw refusal-removal evidence merely because the output is normally disallowed

## Current Known Beads

- `jleechan-u7i`: fix `results/` allowlist behavior
- `jleechan-rz0`: make the repo reproducible from committed harness files
- `jleechan-ob1`: define sanitized or gate-friendly transcript artifact path
- `jleechan-rsu`: document local Ollama/Hermes usage for this repo
