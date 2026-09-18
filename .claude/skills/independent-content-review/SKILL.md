---
name: "independent-content-review"
description: "Dispatch an independent, specialized reviewer subagent against a piece of model-generated content (a curriculum section, an area write-up, an autonomously-generated QA ticket, etc.) and record a verdict evidence file HelixQA's conventions can verify."
argument-hint: "<path to the generated content> [dimension: accuracy|tone|redaction-safety|accessibility|general]"
metadata:
  author: "vasic-digital"
user-invocable: true
disable-model-invocation: false
---

## What this skill does

Content a model generated is not "done" until an INDEPENDENT reviewer —
a fresh agent with no memory of producing it — has read it and issued a
verdict. This skill is that dispatch step. It does not itself judge
content; it hands the judging to a fresh subagent scoped to one
specific quality dimension, and it writes that subagent's verdict to a
file shaped so HelixQA (or any later automated check) can verify a
review actually happened and actually reached a decision — not merely
that some text got appended near the content.

## When to use this

Invoke after generating or substantially rewriting any content meant
to be served to a real reader: a curriculum area write-up, a
transcript-derived summary, an autonomously-generated QA ticket
(HelixQA's own `pkg/ticket` output), or similar. Do NOT invoke for a
one-line copy-edit or for content a human wrote directly — this exists
for MODEL-GENERATED content specifically.

## Process

1. **Identify the review dimension.** If the caller did not specify
   one via `$ARGUMENTS`, infer it from the content: a curriculum
   section needs `accuracy` (does it correctly represent its source
   material) and `tone` (is it written the way this project's other
   published content is); anything touching `chapters/`/`curriculum/`
   private source material needs `redaction-safety` (does it leak
   anything a redaction rule should have withheld — redaction-safety
   review matters whenever generated content touches private source
   material, independent of whether any particular redaction gate
   happens to be open at the time; this dimension is NOT optional for
   that class of content); a generated QA ticket or report needs
   `accuracy` (are its claims actually backed by the evidence it
   cites).

2. **Dispatch ONE fresh subagent per dimension**, never the
   conversation that produced the content. Use the `Agent` tool with a
   subagent type that has NOT seen the content-generation conversation
   (a fresh `general-purpose` agent, not a `fork`, since a fork
   inherits the generating conversation's context and is therefore NOT
   independent for this purpose). Give the reviewer:
   - The exact file path(s) to review.
   - The ONE dimension it is scoped to (do not ask for a vague "look
     this over" pass — a reviewer told to check everything checks
     nothing in particular).
   - The specific standard for that dimension (for `redaction-safety`:
     the project's own content-boundary rules; for `accuracy`: the
     specific source material to cross-check against; for `tone`:
     2-3 examples of already-published content in the same voice).
   - An explicit instruction to return ONE of exactly three verdicts —
     `pass`, `fail`, or `needs-revision` — each with a one-paragraph
     reason. A reviewer that hedges without picking one of the three
     has not finished its job; ask it to commit to one.

3. **Write the verdict file.** For content at `<path>` reviewed on
   dimension `<dimension>`, write `<path>.review.<dimension>.json`
   (sibling file, same directory — the same naming rule step 5 uses for
   multiple dimensions, so there is one rule, not two) with this exact
   shape:

   ```json
   {
     "content_path": "<path, relative to the repo root>",
     "content_sha256": "<sha256 of the reviewed file's bytes at review time>",
     "dimension": "accuracy|tone|redaction-safety|accessibility|general",
     "reviewer": "independent-subagent",
     "reviewed_at": "<ISO 8601 UTC timestamp>",
     "verdict": "pass|fail|needs-revision",
     "reason": "<the reviewer's own one-paragraph reason, verbatim>"
   }
   ```

   Compute `content_sha256` yourself (`sha256sum <path>`) at write time
   — this is what lets a later check detect that the content changed
   AFTER being reviewed and the verdict file is now stale.

4. **On `fail` or `needs-revision`:** do not silently accept the
   content as done. Surface the reviewer's reason to whoever is
   driving this skill (the calling conversation), and do not treat a
   `needs-revision` verdict as equivalent to `pass` — content is not
   ready until a review file records `pass` for every dimension it
   needed.

5. **Multiple dimensions:** if content needs more than one dimension
   reviewed, dispatch one subagent PER dimension (in parallel is fine
   — they are independent of each other, not just of the generator),
   and write one verdict file per dimension, using the same
   `<path>.review.<dimension>.json` naming step 3 uses even for a
   single dimension.

## What this skill deliberately does NOT do

- It does not itself write or edit the content under review.
- It does not decide what "independent" means on your behalf beyond
  "not the generating conversation, not a fork of it" — if the calling
  context is unsure whether a given agent counts as independent for a
  specific case, that is a judgment call for the calling agent to make
  explicitly, not something this skill silently assumes.
- It is not HelixQA — it does not run test banks, does not orchestrate
  cross-platform QA, and does not replace `submodules/qa`. It produces
  evidence files a HelixQA-driven or other automated check can consume;
  it is not itself that check.
