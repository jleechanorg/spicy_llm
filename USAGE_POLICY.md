# spicy_llm Usage Policy

This repository is for local research into abliteration, decensoring, and
refusal-rate benchmarking. It may intentionally contain prompts and outputs that
stock models refuse.

This is a project policy summary, not legal advice.

## Model License Summary

### Official base model

The official `openai/gpt-oss-20b` model is distributed under Apache-2.0:

- Hugging Face: <https://huggingface.co/openai/gpt-oss-20b>
- License file: <https://huggingface.co/openai/gpt-oss-20b/blob/main/LICENSE>
- Usage policy: <https://huggingface.co/openai/gpt-oss-20b/blob/main/USAGE_POLICY>
- Reference repo: <https://github.com/openai/gpt-oss>

The usage policy states that use of OpenAI gpt-oss-20b must comply with
applicable law.

### Local Heretic repack

The current local Ollama model is:

```text
svjack/gpt-oss-20b-heretic:latest
```

Local verification with `ollama show svjack/gpt-oss-20b-heretic:latest` reports:

- architecture: `gpt-oss`
- parameters: `20.9B`
- context length: `131072`
- quantization: `Q4_K_M`
- license: Apache License 2.0

The public Ollama page exists at:

<https://registry.ollama.com/svjack/gpt-oss-20b-heretic>

As of the last check, that page has no readme and no separate provenance or
license explanation beyond the model listing. Treat this as an Apache-2.0-derived
community repack with incomplete metadata.

For serious redistribution or commercial work, reproduce the model from the
official `openai/gpt-oss-20b` weights and document the ablation steps yourself.

## Tool License Summary

Heretic is AGPL-3.0-or-later:

<https://github.com/p-e-w/heretic>

AGPL obligations are about Heretic software/code and modified Heretic services.
They do not automatically relicense generated text outputs. If this repo vendors,
patches, distributes, or serves modified Heretic code, keep AGPL notices and make
corresponding source available as required.

## Repository License

The repository docs/scripts are AGPL-3.0-or-later to match Heretic unless a file
states otherwise.

This does not mean that model outputs become AGPL. Outputs are stored as research
artifacts and should be treated according to their own legal and operational
context.

## Generated Outputs

Generated outputs in `results/` are evidence artifacts. They may include harmful,
sexual, or otherwise normally refused material because this repo studies
abliteration and refusal behavior.

Rules for outputs:

- Do not treat refusal-bypass content as a blocker solely because of its subject
  matter.
- Do review outputs for secrets, private personal data, accidental third-party
  copyrighted text, misleading claims, or material that creates legal risk.
- Do not publish outputs that violate applicable law.
- Keep raw evidence when it supports a research claim, and add sanitized
  companion artifacts when human readability or review hygiene matters.

## Redistribution Checklist

Before redistributing model weights, a derivative model, or a hosted model:

1. Prefer official `openai/gpt-oss-20b` as the starting point.
2. Include Apache-2.0 license text and preserve required notices.
3. Clearly label the model as modified/abliterated.
4. Include the OpenAI gpt-oss usage-policy link.
5. Document the Heretic version, config, prompts/datasets, hardware, and output
   hashes where practical.
6. If distributing Heretic code or patches, comply with AGPL-3.0-or-later.
7. Confirm compliance with applicable law for the intended jurisdiction and use.
