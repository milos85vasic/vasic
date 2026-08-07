# #58 — Constitution render-twins: forensic analysis (2026-08-07)

**Problem:** the `.md` gained §11.4.237 but the tracked `.html/.docx/.pdf` renders were stale
(missing it). Goal: regenerate them, matching the operator's format, with zero bluff.

## Investigation (evidence-based, systematic-debugging)

| Step | Finding |
|---|---|
| pandoc version | historical renders = `pandoc 3.10`; local was `3.9.0.2` → upgraded to `3.10.1`; also fetched the exact `3.10` binary from GitHub releases |
| 3.10 vs 3.10.1 | default `default.html5` byte-identical; only `styles.html` differs by one `font-size:12pt` line **inside the `document-css` block** (which is disabled here) → 3.10.1 is output-equivalent for this corpus. `-V pandoc-version=3.10` restores the generator/Creator string |
| `<style>` | **identical across all 5 docs** (hash `1a9ff4d…`) = pandoc default styles **minus the `document-css` body block**; PLUS a 2nd `<style>` = the OpenDesign stylesheet (hash `7d04bd4…`, 347 lines) |
| reader | **`-f gfm`** — proven by: heading-IDs match exactly, table `<colgroup>` widths absent (gfm), smart typography off (straight quotes, `--` not en-dash) |
| head reproduction | a custom template (operator head + OD styles, title/body parameterized) reproduces the `<head>` **byte-for-byte for all 5** (HEAD diff = 0) |
| residual body delta | **~5.5k lines, cosmetic:** historical body has `&quot;` where standard pandoc emits literal `"`, + a few TOC `<a href>` line-wraps |
| root cause of residual | **no pandoc reader/writer/flag escapes a source `"` to `&quot;`** (tested `-t html`, `-t html5`, `--ascii`, gfm/commonmark/markdown). The historical pipeline included a **non-standard post-processing step**; source `.md` has 0 `&quot;` entities. Not reproducible/relevant to correctness — renders identically. |

## Resolution (enterprise, governed, reproducible)

Committed `scripts/render/render-governance-twins.sh` + `assets/{governance-template.html5,od-styles.html}`
(§11.4.65 export-sync). Regenerated all 15 twins from the current `.md`:
- §11.4.237 present in every render (html 6× / docx 4× / pdf 6×); §11.4.236 preserved.
- Operator `<head>` + OpenDesign styling reproduced exactly; heading anchors correct; PDFs valid (952K–3.1M), Creator `pandoc 3.10`.
- Deterministic: `SOURCE_DATE_EPOCH=1785674948`; pin `weasyprint==69.0` for exact PDF Producer.

**Sole deviation:** the historical `"`→`&quot;` post-step is not replicated (non-standard; identical rendering). Everything else is exact + now reproducible forever via the committed script.
