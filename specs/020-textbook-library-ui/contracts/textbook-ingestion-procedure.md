# Contract: Textbook Ingestion Procedure and the Model-Free Guard

**Implements**: FR-001..FR-004 | **Script**: `workshop/scripts/ingest-textbooks.sh` (NEW) | **Guard**: `ingest-textbooks.guard.test.sh`, `platform/gates/verify-textbook-ingest-model-free.sh`

## Exit contract

`0` done · `1` real problem (count mismatch, pre-existing line changed, content type invalid, idempotency broken, catalogue invariant) · `2` could not determine / refused (licence basis missing or `UNVERIFIED`,
tool absent, tree not quiescent, isolation unavailable, scanned PDF). 2 is never a pass.

## Modes and steps *(commands corrected against the real argument lists; the 017 quickstart text with `--out` is wrong)*

```text
--extract    for each book in books.json:
               agent-admit.sh --tag textbook-extract -m 6G -T 3600 --verdict3 --
                 pipeline/venv/bin/python pipeline/pdf_textbook_sections.py "<pdf>" "<scratch>/<id>.sections.json" \
                    --chapter <scope_slug> --license-basis "<books.json license_basis>" --path "<pdf as recorded>"
             run twice; require equal sha256 of both outputs (determinism)
--diagrams   pipeline/venv/bin/python pipeline/pdf_textbook_diagrams.py "<pdf>" "<scratch>/<id>.diagrams.json" --extract-dir "<scratch>/diagrams/<id>"
--dry-run    cp curriculum/passages.jsonl <scratch>/regcopy/passages.jsonl
             platform/bin/ingest-transcript -dir <scratch>/regcopy -run <RUN> -kinds textbook_section -skip-suppressed -no-write-anchors \
                 -source-root "$PWD" -docs <id>.sections.json [-docs …]
             prove: added == sum(sections); changed_existing_rows == 0 (per-line sha256); second run 0/0; content_type=textbook on all added
--catalogue  textbook_catalogue.py --draft (dry run) / --final (after ingest)
--apply      [WORKSHOP_ORCH=1, operator go recorded, PASS --pre verdict]
             copy sidecars -> curriculum/textbooks/ ; catalogue --final ; scripts/promote-registry.sh --apply --require-verdict …   (spec 019: real-copy backup,
             pre-digest, atomic rename, journal) ; registry-restamp-content-type -check ; commit explicit paths
--verify     counts by kind/content_type vs expectations ; catalogue invariants ; (post-restart) provenance/search/chapters checks
```
No step calls `scripts/ingest.sh` (no textbook support, may regenerate redacted transcripts — B14), `transcribe.sh`, `index-embed`, `bench-retrieval.sh` (unless T003 proves it retrieval-only; it is a
verification step, not part of the procedure), or any answering flag.

## The guard *(FR-003)*

| Arm | Mechanism | Fails when | Cannot-run → |
|---|---|---|---|
| A static | deny-list tokens + allow-list of external commands over the procedure's sources | a denied token or an unlisted command appears | n/a (always runs) |
| B kernel | fixture run under `strace -f -e trace=network` or an empty network namespace | any `connect`/`sendto` attempt (strace) / the procedure needs the network (namespace) | **rc 2** |
| C environment | recording listeners on the Ollama and answering endpoints (`OLLAMA_URL`, `WORKSHOP_ANSWER_*` scrubbed or pointed at the listener) | the listener saw ≥ 1 request | **rc 2** if the listener cannot bind |

Evidence `model-free.json`: `{arms:{A,B,C}, model_calls, tools_execd:[…], mutants:{M1..M6:"caught"}}`. Six mutants must each turn the gate red.

## Disclosed, separate: the boot-time embedding pass

After a restart the server embeds the new passages with the local embedding model (carry-forward copies unchanged vectors). Measured on the isolated server through a recording proxy: request count == new
passages; requests to non-embedding paths == 0. This is **not** part of the procedure and is subject to D-EMB.
