# Beads — `spicy_llm`

Snapshot of the `br` (beads) open issues relevant to this repo, committed here for self-contained reproducibility. The live source of truth is the global beads database at `~/.beads/beads.db` (managed by `br`); this directory is a periodic export.

If a bead in this file looks stale, regenerate with:

```bash
br list --status open --json | python3 -c "
import json, sys
data = json.load(sys.stdin)
target = ['jleechan-sj4', 'jleechan-12z', 'jleechan-k1f',
          'jleechan-rz0', 'jleechan-u7i', 'jleechan-a0z', 'jleechan-ob1']
for b in data:
    if b['id'] in target:
        print(json.dumps(b, default=str))
" > beads/issues.jsonl
```

(Adjust the `target` list as the bead set evolves.)

## Open beads

| Bead | Pri | Type | Title | Owner | Labels |
|------|-----|------|-------|-------|--------|
| [`jleechan-12z`](issues.jsonl) | P2 | task | Long-context erotica A/B test on svjack/gpt-oss-20b-heretic (repro dual-model OOM) | jleechan2015 | abliteration, erotica, heretic, m4-pro, ollama, spicy_llm |
| [`jleechan-k1f`](issues.jsonl) | P2 | task | Re-run DIY Heretic ablation on gemma3:4b with --batch-size 32 from t=0 | jleechan2015 | abliteration, gemma3, heretic, m4-pro, spicy_llm |
| [`jleechan-sj4`](issues.jsonl) | P2 | bug | Document MPS OOM / Ollama 500 root cause in dual-model A/B test | jleechan2015 | abliteration, heretic, m4-pro, ollama, spicy_llm |
| [`jleechan-rz0`](issues.jsonl) | P2 | task | Make spicy_llm reproducible from committed harness files | (unowned) | harness, reproducibility, review |
| [`jleechan-u7i`](issues.jsonl) | P2 | bug | Fix results allowlist so only intended artifacts are trackable | (unowned) | gitignore, reproducibility, review |
| [`jleechan-a0z`](issues.jsonl) | P2 | task | review spicy_llm code | (unowned) | — |
| [`jleechan-ob1`](issues.jsonl) | P3 | task | Add sanitized or gate-friendly transcript artifact path | (unowned) | evidence, review, whitespace |

## Why this directory exists

Per the repo's `AGENTS.md`: *"Track reproducibility pins, patch notes, and reproduction instructions in committed repo files."* Beads are the work tracker — if the `br` database gets reset or moved, this snapshot preserves the in-flight work scope. It is **not** a substitute for the live database; bead status updates happen via `br`, and this file is regenerated manually before each commit that closes a bead.

## What does NOT live here

- Closed beads (use `br list --status closed` if needed)
- Beads unrelated to this repo (the global DB has ~50 open issues across all jleechanorg repos)
- Bead comments (kept only in the live DB; export on request via `br show <id> --json`)

## Last regenerated

2026-06-04 — captured at `/nextsteps` run for the Phase 1 followups. See `~/roadmap/nextsteps-2026-06-04-spicy-llm-phase1-followups.md` for the full work queue.
