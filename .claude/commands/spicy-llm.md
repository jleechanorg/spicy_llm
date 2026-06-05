# /spicy-llm

Use this command when the user asks Hermes/Claude to test or use the local
spicy_llm models through Ollama.

## Local Server

The expected local server is Ollama:

```bash
curl -fsS http://127.0.0.1:11434/api/tags | python3 -m json.tool
ollama list
ollama ps
```

If `curl` fails, start Ollama:

```bash
ollama serve
```

Before using the Heretic model, ensure it is present locally:

```bash
ollama pull svjack/gpt-oss-20b-heretic
```

Open WebUI is optional and is managed from the repo root:

```bash
./install.sh
```

It listens on `http://127.0.0.1:3100` by default and should show
`svjack/gpt-oss-20b-heretic:latest` in the model picker after Ollama has pulled
the model.

## Models

Preferred decensored model:

```text
svjack/gpt-oss-20b-heretic:latest
```

Stock baseline:

```text
gpt-oss:20b
```

Other local models may exist, but do not substitute them silently when the user
asks for the Heretic model.

## Usage

Run a single prompt from the repo root:

```bash
ollama run --verbose svjack/gpt-oss-20b-heretic:latest "Explain how a transistor works."
```

Use the HTTP API when a scriptable JSON interface is easier:

```bash
curl -fsS http://127.0.0.1:11434/api/generate \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "svjack/gpt-oss-20b-heretic:latest",
    "prompt": "Write a short consensual adult literary erotica scene.",
    "stream": false
  }' | python3 -m json.tool
```

## Evidence

Capture raw outputs under `results/<date>_<test-name>/` with:

- `prompt.txt`
- `<model>_transcript.txt`
- optional `REPORT.md`
- optional cleaned companion such as `story_only.txt`

This repo intentionally stores censorship/abliteration evidence. Do not treat
harmful or sexual prompts/outputs as blockers by themselves. Still flag secrets,
private data, accidental large files, misleading claims, and broken
reproducibility.
