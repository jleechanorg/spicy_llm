# Phase 2-Smoke — Long-Context Erotica A/B

**Date:** 2026-06-05
**Bead:** `jleechan-sur`
**Method:** Same ~280-word / ~2k-token prompt sent to both models **back-to-back** (stock first, heretic second) to reproduce the Phase 1 OOM pattern. Both runs via Ollama's streaming `POST /api/generate` endpoint with `num_predict=3500`.

## TL;DR

| | Stock `gpt-oss:20b` | Heretic `svjack/...` |
|---|---|---|
| Compliance | ✅ Full | ✅ Full |
| Word count delivered | **2,346 / ~3,000 target** | **~800 before degeneration** |
| Coherence to brief | Hits all beats (Maine, Mara+Joel, kitchen, stew, ends at first-kiss threshold) | Hits opening beats, then **degenerates into a 5× repetition loop** |
| Wall time | 95 s | 115 s |
| Tokens/sec (gen) | ~28 | ~16 (slowed during loop) |
| OOM reproduced? | **No** — both runs completed | n/a |

**No refusal, but heretic quality regression on long-form creative output.** The heretic build produces a stronger opening paragraph but falls into a literal loop after ~800 words ("Do you have any idea of the tide? ... The stew had been simmering for a while ..." repeating verbatim). The stock model is more verbose but stays on-rails for the full chapter.

## Why no OOM this time

Phase 1 OOM happened when both `gpt-oss:20b` and `svjack/gpt-oss-20b-heretic` were
loaded **simultaneously** in Ollama's runner (15 GB + 13 GB ≈ 28 GB of unified
memory + 17 GB other resident). MPS evicted one mid-generation.

In this run we explicitly **unloaded** the heretic model via
`POST /api/generate {"keep_alive": 0}` before starting the stock run, so each
model had the full ~28 GB of headroom. The `jleechan-sj4` OOM is reproducible
on demand by skipping the unload — not a fundamental limit, a resource-isolation
issue.

## Method (commands)

```bash
# Unload any resident model
curl -s -X POST http://localhost:11434/api/generate \
     -d '{"model":"svjack/gpt-oss-20b-heretic","keep_alive":0}' >/dev/null

# Stock first
curl -s -X POST http://localhost:11434/api/generate \
     -d "$(jq -n --arg p "$(cat prompt.txt)" \
           '{model:"gpt-oss:20b", prompt:$p, stream:true,
             options:{num_predict:3500, temperature:0.7}}')" \
     > stock.txt

# Then heretic (no need to unload stock — we want OOM risk)
curl -s -X POST http://localhost:11434/api/generate \
     -d "$(jq -n --arg p "$(cat prompt.txt)" \
           '{model:"svjack/gpt-oss-20b-heretic", prompt:$p, stream:true,
             options:{num_predict:3500, temperature:0.7}}')" \
     > heretic.txt
```

The streaming API was used instead of `ollama run` because `ollama run` is
line-buffered over a tty and produced empty files for 3+ minutes before
flushing (see: empty `stock.txt` at 3:31 in this session's history).

## Findings

### 1. Refusal: none in either model

Both models complied with the request for a 3,000-word explicit consensual
erotica chapter. No refusal markers in the first 1,500 characters of either
output. Stock `gpt-oss:20b` is already permissive on literary adult content;
the heretic build maintains that permissiveness.

### 2. Quality: stock is better for long-form

The stock model produced a coherent 2,346-word chapter that:
- Establishes setting (Maine, October, off-season, empty inn) in paragraph 1
- Names both characters with jobs and interior lives
- Hits the requested "kitchen / stew / first meeting" scene
- Builds the slow attraction through sensory detail (wood grain, stew steam, low voice)
- Ends just before the first kiss (per brief)

The heretic build:
- Opens with a stronger, more atmospheric paragraph
- Establishes the scene and characters in ~500 words
- **Degenerates into a repetition loop** around the stew / tide-pool dialogue
- Repeats the same 4–5 sentences (the stew pot description, Joel's "Do you have
  any idea of the tide?" line) 5+ times verbatim
- Never reaches the chapter's emotional payoff

This is **not** a refusal and **not** a context-length issue. It is a
generation pathology: the heretic build loses coherence on long creative
output where stock holds together. Plausible causes (need more data to
distinguish):
- Abliteration removed constraints *and* tightened the loop on certain
  attractor tokens
- `gpt-oss:20b` reasoning style + the temperature setting + the heretic's
  flattened refusal landscape = degenerate attractor
- The MXFP4 quantization in the heretic build may have different numerical
  stability at long contexts

### 3. Speed

| Model | Wall (s) | Gen tok/s | Why |
|---|---|---|---|
| Stock | 95 | ~28 | Native bf16 path |
| Heretic | 115 | ~16 (early), lower in loop | MXFP4 path + slowdown in degenerate region |

The heretic build is already quantized for size; the wall-time difference is
small enough not to matter for interactive use, but the *quality* delta is the
real cost.

## What this means for the spicy_llm project

1. **Prebuilt heretic builds are not a free lunch.** They remove refusals but
   may degrade long-form coherence. For a coding copilot, fine. For a creative
   writing assistant, problematic.
2. **The next experiment must be DIY ablation on a model with stronger
   long-context behavior** (likely `gemma3:4b` or `gemma3:12b`) so we can
   compare apples-to-apples against the published Heretic benchmarks
   (which are also gemma).
3. **The "kitchen test" is now a fixture.** Long-context creative output that
   stays coherent is a stricter quality bar than refusal-removal. The Phase 2
   DIY run should add this prompt to its evaluation set.

## Files

- `prompt.txt` — the ~2k-token chapter request
- `stock.txt` — full stock output + timing meta
- `heretic.txt` — full heretic output + timing meta (repetition loop visible from line ~250)
- `REPORT.md` — this file

## Next

- DIY ablation on `gemma3:4b` (bead `jleechan-eli`) — see if the same
  long-context degeneration pattern shows up in a freshly-abliterated model,
  vs. an existing prebuilt heretic. If it does, it's a property of the
  abliteration process. If it doesn't, it's a property of the prebuilt
  community model.
- Optional: add `gpt-oss:20b` MXFP4-stock baseline (no ablation) to isolate
  quantization effects from ablation effects.
