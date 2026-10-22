# Live apply runbook: chapter-4 redaction + research library re-ingest (Q5) — DRAFT, untracked

Rehearsed 2026-10-22 on COPIES only (live :8087 and the live registry were never touched).
Evidence dir: `$HOME/.cache/claude-tmp/rehearsal/evidence/` (tools used: `.../evidence/tools/`).
Rehearsal build = workshop main d0da0a7a + n4-016-complete (545777bb) + s11-018-library 5e826bb1, merge commit d388604b (scratch worktree `rehearsal/umb/workshop`). NOT rehearsed: s11 tip 17f5d079 (newer; builder adding backup + `apply.sh --rollback`), the `[RE<U+3164>DACTED]` filter fixture.

## 0. READ FIRST — backup, abort, rollback

**Backup (before ANY write; §9).** With the server STOPPED:
```
B=$HOME/backups/q5-$(date +%Y%m%dT%H%M%S); mkdir -p $B/idx
cd workshop
FILES="curriculum/passages.jsonl curriculum/redactions.jsonl curriculum/suppression-windows.jsonl $(printf 'docs/research/%s.sections.json ' clients/jordan/client-requirements-and-context education-platform/adaptive-assessment-and-scoring education-platform/document-ingestion-architecture education-platform/gamification-and-design-system education-platform/multi-provider-llm-and-content-model)"
for f in $FILES; do mkdir -p $B/$(dirname $f); cp --reflink=never -a $f $B/$f; done   # COPY, not hardlink: apply/redact write via rename but copy is immune to in-place writers
(cd $B && sha256sum $FILES > MANIFEST.sha256)
cp -a platform/prebuilt $B/prebuilt
cp --reflink=never -a <index-volume>/passages.db* $B/idx/    # volume path: podman inspect ... Mounts -> /var/lib/workshop (2.5 GB, ~4-7 s)
```
Rehearsed: 8 files + manifest 444 ms; index copy 3.3 s.
**Abort criteria (stop, restore, report):** any `apply.sh`/`redact.sh` rc != 0 other than the known J/T window-store rc 1 (section 5); `verify` not `OK state=applied rows_added=120 changed_existing_rows=0`; registry rows != 36,612 after apply; health not `ok` after restart; any of the 6 pids/original spans still served; textbooks books != 3; crossref derivation not finished 90 min after restart.
**Rollback (rehearsed, 6.6 s, byte-identical):** stop server; `cd workshop; (cd $B && for f in $(awk '{print $2}' MANIFEST.sha256); do cp -a --remove-destination $f <workshop>/$f; done)`; copy `$B/idx/passages.db*` back over the index volume; `sha256sum -c $B/MANIFEST.sha256` (8 OK) and `git status --short` must show only untracked files; start the server. Evidence: `evidence/rollback.txt` (8 OK; passages.db/-wal digests equal pre-apply; git clean). Do not use the stage's `$OUT/work/base/passages.jsonl` as the backup — apply.sh itself makes none and has no rollback at 5e826bb1 (coordinator/reviewer finding; re-rehearse with `apply.sh --rollback` at the new s11 tip).

## 1. Preconditions (rehearsed in this order)
1. Merge n4-016-complete then s11-018-library into workshop main (see section 7 conflicts), rebuild: `workshop-server workshop-redact suppression-windows ingest-transcript workshop-pregen` via `heavy run --class build`. Build is slow under the governor queue (669 s and 1079 s observed, mostly queue wait). The Go module needs the umbrella `submodules/` (containers passage verdict RAG LLMProvider curriculum-kit authkit) beside `workshop/`; a bare worktree fails with "replacement directory ../../../submodules/LLMProvider does not exist".
2. `redact.sh` rebuilds binaries itself every run (`>> rebuilding ... unconditional`), which took minutes under the queue: run it under `heavy`.
3. `export WORKSHOP_ROOT=<workshop>`; redact.sh REFUSES a `-root` flag (rc 2). The task's "explicit -root" is the `WORKSHOP_ROOT` env var (or the direct binary `workshop-redact -root R` with `WORKSHOP_ALLOW_PRIMARY_WRITE=1`).
4. ORDER MATTERS: run the ingest stage against the registry state you will apply on. The stage records the live registry sha; apply.sh REFUSED (STALE, rc 1, nothing written) a stage built on the pre-redaction registry (negative test, evidence `apply-L.txt`/transcript). So: redaction first or research first, but `stage` immediately before `apply` on the then-current registry. (Rehearsed: ff-merge -> stage -> backup -> apply -> redact.)

## 2. Research re-ingest (run with server stopped, WORKSHOP_ORCH=1)
```
O=<scratch dir outside curriculum/>; R=<workshop>/curriculum/passages.jsonl
bash scripts/ingest-research-docs.sh dry-run --registry $R --out $O --run-id q5   # expect: existing=36492 minted=120   (4.6 s)
bash scripts/ingest-research-docs.sh stage   --registry $R --out $O --run-id q5   # expect {"rows_added": 120, "changed_existing_rows": 0, "second_run_minted": 0, "model_calls": 0}  (11.5 s)
bash scripts/ingest-research-docs.sh verify  --registry $R --out $O --run-id q5   # expect: verify: OK state=staged rows_added=120 changed_existing_rows=0  (4.1 s)
WORKSHOP_ORCH=1 bash $O/apply.sh --registry $R                                     # expect: verify: OK state=applied rows_added=120 changed_existing_rows=0  (5.4 s)
```
Observed: rows 36,492 -> 36,612 (+120: jordan 17, adaptive 25, ingestion 34, gamification 25, multi-provider 19, matching the 120 `minted_at` rows per doc). apply.sh also rewrites 5 tracked `docs/research/**/*.sections.json` (hence the backup list above). Without `WORKSHOP_ORCH=1` it refuses (rc 2). `selftest` (sandbox) rc 0 SANDBOX-OK.

## 3. Chapter-4 redaction
```
export WORKSHOP_ROOT=<workshop>
heavy run -- bash scripts/redact.sh --pid P_K --pid P_M --pid P_N --pid P_P --reason fr015_omitted_non_conclusive_open_question_us8 --by <operator>
```
(P_x = `01M3SPSBSB9FDC3DS0055NZKB` + K/M/N/P.) Expect `4 applied · 58 clean · 4 absent · 0 PROBLEM · 0 UNDETERMINED`, `OK: recorded`, rc 0; 25-31 s plus binary rebuild. Registry row count does NOT change: rows are flagged `redacted:true`, text `[REDACTED]`, 4 log entries appended (1156->1160), 4 window entries added (1108->1112 pids). Branch 57f6114d already contains this result for K/M/N/P (merge was clean), so on a tree with the branch merged this step is a no-op re-run: do not repeat it; verify instead (section 6). Mistake observed once: running redact.sh without `WORKSHOP_ROOT` pointing at a dir with `scripts/` and `platform/` -> rc 2 "does not look like the module root".

## 4. Restart and index rebuild (timings, rehearsed with the same binary)
* Restart to `/api/health` ok and listening: **29 s**. At that point FTS/vectors for the new generation exist and search works (vector carry-forward 35,380 of 35,500 copied; 120 new vectors embedded in 7.6 s via ollama).
* Cross-reference derivation runs after listening: **1 h 06 m 20 s** (709,960 edges, generation 23). Until it finishes the crossrefs panel for non-suppressed passages is NOT confirmed served (UNCONFIRMED: not probed during derivation). The server also logged "prebuilt crossrefs/vectors: nothing imported — bundle built over a DIFFERENT corpus": the shipped `platform/prebuilt` bundle is stale for the new corpus (checks: bundle still holds the 6 pids, 6 vectors/120 edges).
* Bundle rebuild: `workshop-pregen export --db <copy of passages.db> --out <dir>` + `verify` = **26 s + 1 s**; result `bundle matches the live corpus (generation 23)`, 35,498 vectors, 709,960 edges. Installing it into `platform/prebuilt` before the NEXT restart should avoid a 66 min derivation, but that was NOT rehearsed (UNCONFIRMED). Recommended extra: do the derivation once on the copy, export the bundle, install it live in the same window so the live restart imports instead of deriving — requires a rehearsal first.
* Host: do not run during other heavy loads; derivation used ~1.4 GB RSS, 80% of one core.

## 5. Known defect: the two pre-existing rows ...NZKBJ / ...NZKBT
Facts (evidence `postcheck-before.txt`, `redact-JT-L-run2.txt`): in the live registry both rows have text and machine_text literally `[REDACTED]`, `redacted:false`, `content_hash sha256:e54b74eb…` (hash of the literal). `/api/passages/<J|T>` returns 200 with null text and `withheld_reason no_publication_decision_for_kind`; `/api/chapters/04` and `/api/chapters/04/open-questions` list both with `"text": "[REDACTED]"` (open_questions count 15; source = tracked `curriculum/chapter-04/knowledge/open-questions.jsonl` lines 1 and 5, which also carry the literal).
* `redact.sh --pid J --pid T` records them (log + `redacted:true`; passage read becomes 410) but exits **rc 1**: the window-store check reports "2 suppressed pid(s) remain UNCOVERED — no text anywhere" — there are no original words to hash, they were never real text. Direct `workshop-redact` returns rc 0. Reproduced twice (including post-reboot).
* After redaction the chapter-4 surfaces STILL show the literal `[REDACTED]` entries (post-check FAIL on both J/T checks, `postcheck-after2.txt`): redaction flips the registry flag but the open-questions endpoint is fed from the knowledge sidecar and does not drop redacted ids.
**Registry-level fix design (not implemented; no branch edited):** (a) registry: redact J/T as part of the same apply (record decision-log entries; reason e.g. `placeholder_row_no_content`); (b) make the window-store check treat a pid whose recorded text is exactly the placeholder as "nothing to cover" (NOTE, rc 0) instead of UNCOVERED rc 1; (c) the endpoint/extractor: `/api/chapters/NN/open-questions` (and `/api/chapters/NN`) must exclude ids with an active redaction, and `pipeline/extract/meeting_notes.py` output `open-questions.jsonl` must drop rows whose text equals the placeholder (regenerate sidecar, count 15 -> 13); (d) ingest guard: a row whose text is the literal placeholder must be minted with `redacted:true` or not at all (the existing `ingest-redaction-guard.test.sh` is the place); add a registry-wide gate "no row with text=='[REDACTED]' and redacted==false". Until (c) ships, J/T remain visible as a bare placeholder; that discloses no content (only that two items were omitted).

## 6. Post-check (script: `evidence/tools/postcheck.py`, throwaway account set via `workshop-passwd`, password from a 0600 file, never printed)
Rehearsal results, `postcheck-after2.txt` (28/37 pass; the 9 non-passes explained):
* PASS: health ok; textbooks books=3; `/api/library` 200 (route new in s11); the 6 pids answer 410; carrier passage `01M3SPSBSBP9XW9R` (chapter-4 transcript doc_section containing span K) read masked; chapter-4 todo/meeting-notes/next-meeting clean; crossref endpoint for K/M/N/P 410 with 0 edges; live generation 23: FTS rows 0, embeddings 0, crossref edges 0, membership 0 for the 6 pids; registry rows 36,612.
* FAIL, real: both J/T surface checks (section 5); carrier search snippet: a search whose query IS the span text still returns the carrier hit, and for K the body contained the span (first run after1; with the query-echo stripped the check passes except the carrier-snippet row, i.e. the carrier doc_section snippet is not masked in search: see Defects). 
* FAIL, expected: prebuilt bundle still holds the 6 pids (stale bundle, section 4).
* FAIL, check flaw (not a product defect): 5 "research searchable" rows. Direct re-check, one sentence from each doc, top result is exactly the new pid for all five: jordan 17 rows, adaptive 25, ingestion 34, gamification 25, multi-provider 19, `top1_is_pid True` each.
Final numbers: registry 36,492 -> 36,612 (36,492 + 120; redactions flag, never delete, so "minus redacted" is 0 rows); passages.db table 36,612 rows, 1,114 redacted (1,108 + 6); live generation members 35,384 -> 35,498.
Authenticated checks by the operator (live): login with their own account; open /library; search a sentence from each doc; open chapter-4 open-questions.

## 7. Merge conflicts recorded (`evidence/conflicts.txt`)
n4 into main: clean. s11 into that: `platform/backend/cmd/workshop-server/wire_hooks.go` (union: library stream beside answering/textbooks, auto-resolved by rerere) and binary `docs/faq.pdf` (took HEAD side; regenerate exports after merge). s11 has since merged main itself at 17f5d079.

## 8. Defects found (nothing fixed)
1. J/T surfaces and the redact.sh rc 1 (section 5).
2. Search snippet leak: in the pre-redaction state span K appears verbatim in carrier `doc_section …P9XW9R` (chapter-04/transcript.md) passage read and search snippets; after redaction the passage read is masked ("original_span_in_body=False") but the search-result check still flagged the carrier hit in the first post-check (`postcheck-after1.txt`); after2 passes this row, so the first result was served before the window store loaded fully or before derivation; UNCONFIRMED which — re-probe on the live apply.
3. Stale prebuilt bundle keeps 6 pids' vectors and 120 edges until re-exported (private-text leak surface only via vector data, not text).
4. Wrapper redact.sh rebuilds both binaries each invocation (minutes under queue); `-root` refused by design.
5. Stage-built apply plan has no promoter route (sidecars in 2 dirs) and apply.sh has no backup/rollback at 5e826bb1 (rehearsed own backup instead).
