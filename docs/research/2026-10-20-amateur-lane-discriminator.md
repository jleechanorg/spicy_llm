# Amateur lane: what actually separates amateur from studio

**Date:** 2026-10-20
**Source:** operator feedback on the iteration-10 index in `#spicy-feedback`
(thread `1792527791.358379`, query `amateur white young blowjob`):
*"None of these seem like amateur — for amateur usually name isn't there."*

## The observation, measured against our own candidate set

**[MEASURED]** All 8 rows posted in iteration 10 carry the performer's name in the
title:

| # | Title carries | Reading |
|---|---|---|
| 1 | Emma Starletto | studio-marketed |
| 2 | Emma Starletto | studio-marketed |
| 3 | Mazzy Grace | studio-marketed |
| 4 | Mazzy Grace | studio-marketed |
| 5 | Sera Ryder | studio-marketed |
| 6 | Sera Ryder | studio-marketed |
| 7 | April Paisley | studio-marketed |
| 8 | April Paisley | studio-marketed |

So the amateur axis was never tested in that iteration. Frame judging at 25/50/75
measured *act hold* over a set that was **100% studio-marketed**. A row can hold the
act 3/3 and still be the wrong population for an amateur query.

## The discriminator to apply (amateur lane)

A row is **amateur-true** only when all of these hold:

1. **No performer name in the title.** Amateur/homemade uploads are uploader-phrased
   ("my gf", "wife", "amateur couple", "self shot", "homemade", "real", first-person
   POV). A title that names the performer is a studio-marketing pattern — the vendor
   is selling a person, not a scene.
2. **No performer-table hit.** If the vendor's structured metadata names a performer
   who resolves in our `performers` table, the row is professional output regardless
   of its genre tags.
3. **Not a studio brand channel.** Uploader/channel is not a known production brand
   or a studio's own series label.

A row that names a performer is still a legitimate result — it belongs in the
**pro/milestone performer** bucket and must be labelled as such, never counted
toward an amateur verdict.

## Why the vocabulary alone cannot fix this

`amateur` is a vendor **genre tag**, applied by studios to their own releases. In
`spicy-search`, `production:amateur` is satisfied by that tag alone
(`lib/quality/attributes.ts` `PRODUCTION_SYNONYMS`, read via
`sceneSatisfiesAttribute(title, tags)` in `lib/quality/scoring.ts`), and
`compareCandidates` then breaks ties *in favour* of the amateur hit. A studio scene
carrying `amateur` therefore pays the full production weight. The missing signal is a
**contradiction**: a named performer in the title, or a pro-brand channel, against an
amateur claim. Tracked as bead `spicy-fjy` in `spicy-search` (score term, demotion
only — no row dropped).

## Reporting rule for this lane

When a query asserts amateur/homemade, report the amateur-true count separately from
the pro-bucket count, and state the candidate-set composition. "3/3 holds the act" on
a studio-only set is not evidence about amateur content.
