# Clean control: quotes the rule, cites private paths by path only (synthetic)

No record may use guessing language such as `probably`, `likely` or 'maybe' when it reports a cause (§11.4.6).
The forbidden vocabulary is listed so that the rule can be quoted: "probably", "seems", "appears to".
UNCONFIRMED: the cause might be a stale cache; this line is a marked hypothesis.
PENDING_FORENSICS: the timeout is perhaps a DNS failure.
UNKNOWN: whether the retry is probably the cause; nothing was measured.
Hypothesis (tested and refuted): the failure was presumably caused by SIGPIPE.
> A quoted reviewer remark: it is likely fine.

The recording lives at workshop/chapters/01/session.mp4 and the notes at ai_interviewing/docs/notes.md.
The detector looks for `SPEAKER 1:` turns and `[00:01:12]` timestamps; the rule is stated, not copied.
Measured at 2026-09-25T21:04:31 with commit 3532d730a919117d12a14cc723385ff13f3e8c35.
A digest: sha256 973e473c823b4a13f0e1d2c3b4a5968778695a4b3c2d1e0f9e8d7c6b5a493827.
A ULID: 01J8ZK5Q2W3E4R5T6Y7U8I9O0P.
An alphabet is not a secret: safe = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._~/+:@,=-".

Re-derive the state of the private submodule by path:

```bash
git -C workshop status --short
ls workshop/chapters/01/
```

```
the root cause is likely a race; a fenced example is not a statement
```

Placeholders are not credentials: PASSWORD={CHANGE_ME}, token=$ZG_TOKEN, api_key=<your-key>.
The gate refused 3 of 3 planted secrets and printed only redacted digests.

The start script `workshop/platform/scripts/restart.sh` is "outside the umbrella build scope" by ruling (a backticked path is a reference).
  workshop/pipeline/venv/bin/python -c "import json, sys; print(json.dumps(sys.argv))"
Go test names are identifiers — TestT057_LessonSectionIsNotAdvertisedBecauseNothingIndexesIt passed.
A run directory is a path (an identifier) — workshop/evidence/knowledge-pipeline/20260902T200902Z-acb8265b/reconcile_and_taxonomy.
A ULID route is an identifier: GET /api/passages/01M1ET0MFM0EYA5TACY1R1JWEQ returned 200.
An SSH remote with variables is not a credential: git remote add github git@github.com:$ORG/$SUBMODULE_NAME.git
The firewall rule forbids nothing here, and the word guess names the rule; "probably" is quoted.
The token appears in 3 files; measured with git grep.
The ruling "the start script workshop/platform/scripts/start.sh rebuilds a missing binary" stands (the path sits inside the author's own quoted sentence).

Create `workshop/pipeline/extract/planted_example.py` with a failing test:

```python
def test_planted_example():
    assert 1 + 1 == 2
```
