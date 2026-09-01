# Content boundary incident — 2026-09-01

**Status: HISTORY REWRITTEN AND FORCE-PUSHED (2026-09-01). THE INCIDENT IS NOT CLOSED.**

Private material was written into this **public** repository, committed, and pushed.
The working tree was redacted, and on 2026-09-01 the history was rewritten and
force-pushed under explicit operator authorization — **§8B records that execution with
its measurements.** What that did *not* do is remove anything from GitHub's servers:
the orphaned commits and every byte of the four leak blobs **remain fetchable by SHA**
until GitHub runs a server-side garbage collection, which only **GitHub Support** can
be asked to do. That request, and telling the third party, are the operator's and are
**not done**. Nobody may read §8B, or the green gates at the bottom of this file, as a
closure of this incident.

The rule that was broken is stated in [`docs/content-boundary.md`](content-boundary.md):
never quote, paste, excerpt or transcribe content from a private repository into a file
tracked by a public one. Naming a private *path* is fine. Copying what is inside it is not.

> **This document covers TWO waves.** §1–§8 are the first wave: material sourced from a
> private meeting-notes PDF in the `workshop` submodule, including a third party's name.
> **§9 is the second wave** — the `ai_interviewing` and `workshop` matches that §6 named and
> deferred. §9 assesses all 232 of them, redacts the 29 that are real disclosures, and
> states why the other 203 are not. **§8's remediation plan is unchanged by §9** and remains
> prepared, unexecuted, and unauthorized.

---

## 1 · What was disclosed

The source is a meeting-notes PDF at `workshop/chapters/01/… - Notes by Gemini.PDF`,
inside the **private** `workshop` submodule (`private=true` at the provider). It is a
Gemini-generated summary of a private 2026-08-27 screen-recording session between the
operator and one other person.

Three classes of material crossed the boundary.

| # | Class | What it is |
|---|---|---|
| **D1** | **Verbatim prose** | Sentences copied out of the private PDF and presented as quotations. |
| **D2** | **The section-heading list** | The PDF's topic headings, reproduced as a complete list. A complete heading list is a table of contents for a private document: it discloses the full agenda of a private conversation even though no sentence of it is quoted. |
| **D3** | **A third party's full real name** | The full name of the non-operator participant — referred to throughout this document as *the third party named at `docs/workshop-curriculum/RECON.md:138` (pre-redaction)* and never written here. |

**D3 is the most serious of the three**, and it is worth being precise about why: the
private recording's own filename discloses that person's **first name only**. The public
files disclosed **first name plus surname**, together with a date, a subject matter, and
the fact that this identifiable person participated in a private business conversation.
That is personal data about someone who is not the repository owner and who did not
publish it. The operator's own name is not treated as a disclosure here — he owns the
repository — but the other participant's is.

> **Note on the brief that triggered this work.** It located the name at `RECON.md:137`.
> The measured line is **138** (`grep -n` on the pre-redaction blob). Line 137 is the
> preceding line of the same sentence. The discrepancy is recorded rather than quietly
> corrected, because line references in this document are evidence.

## 2 · Where it was — exact locations, pre-redaction

Both files were introduced in a single commit and were **byte-identical in every commit
since** (verified: `git rev-parse <commit>:<path>` returns the same blob for all four).

| File | Blob | Lines | Class |
|---|---|---|---|
| `docs/workshop-curriculum/RECON.md` | `101e019c` | `126–130` — six heading strings inside the §1.3 blockquote | **D2** |
| `docs/workshop-curriculum/RECON.md` | `101e019c` | `138` — the third party's full name | **D3** |
| `docs/workshop-curriculum/RECON.md` | `101e019c` | `138–145` — three quoted sentences plus a quoted tool phrase | **D1** |
| `specs/001-workshop-curriculum-platform/research/transcription.md` | `7c3513d3` | `780` — the third party's full name | **D3** |
| `specs/001-workshop-curriculum-platform/research/transcription.md` | `7c3513d3` | `1112–1117` — seven heading strings, and the third party's full name at `1116–1117` | **D2**, **D3** |
| `specs/001-workshop-curriculum-platform/research/transcription.md` | `7c3513d3` | `1140–1146` — a captured `grep` run **over the private text**, disclosing which proper nouns appear at which line of the private document | **D1** |

**Not treated as a disclosure, deliberately:** the recording's own filename
(`…<first name> AI workflows - 2026_08_27 09_57 CEST - Recording.mp4` — written elided
here, though it appears unelided in the files listed next) appears at `RECON.md:62–65`,
`transcription.md:154` and `:1074`, `quickstart.md:83` and `:284`, and `spec.md:17`. It
carries a **first name only**, it is the artifact's actual name, and the documents are not
actionable without it. It is the pre-existing baseline, not new exposure.
If the operator decides even that is too much, renaming the artifact in the private
submodule is the fix, and it is his call, not an agent's.

## 3 · Which commits carry it — the residual exposure

**This is the part redaction does not touch.**

| Commit | Date | Role |
|---|---|---|
| `63ac4df32e5fd40806a50cd38fde8cdc39587c2c` | 2026-09-01 06:47:32 +0200 | **introduced both files**, with the disclosed content already in them |
| `d0b3c64` · `96b2988` · `ee3933d` | 2026-09-01 | carry the same two blobs, unchanged |

`ee3933d` is the current `HEAD` **and** `origin/main` **and** `github/main`. All three
configured remotes (`origin`, `github`, `upstream`) point at
`git@github.com:milos85vasic/vasic.git`, whose provider visibility is
**`private=false, visibility=public`**. No tag contains `63ac4df`.

So, plainly:

1. **The content is public right now**, in four commits, in a repository anyone can clone.
2. It has been public since **2026-09-01 06:47 CEST**.
3. It may already have been **cloned, forked, mirrored, cached by the provider, scraped, or
   indexed by a search engine or a training crawler.** Whether any of that happened is
   **UNVERIFIED** and, for most of those channels, unverifiable from here.
4. **Redacting the working tree does not remove any of it.** After this change lands, the
   disclosed text is still reachable at `git show 63ac4df:docs/workshop-curriculum/RECON.md`
   by anyone with a clone.

A green `verify-content-boundary.sh` after this change means *"the tip of the tree is
clean"*. It says nothing whatsoever about history. Do not report it as if it did.

## 4 · How it happened, and what actually failed

Not carelessness — **diligence pointed the wrong way**. `docs/content-boundary.md` already
names this exact failure mode: *"An agent told to document the work comprehensively reaches
for an illustrative quote, and the quote is the leak."* Both documents are anti-bluff
reconnaissance records whose whole purpose is to prove claims with evidence. Quoting the
source is the reflex that discipline trains. The authoring agent had no instrument telling
it that the source was on the other side of a visibility boundary.

Three distinct failures, only one of which is now closed:

- **F1 — no boundary rule existed when the content was written.** `docs/content-boundary.md`
  and `scripts/verify-content-boundary.sh` are **untracked, created later the same day**,
  after the leak was already pushed. The gate is a *response* to this incident, not a
  control that failed to fire. **Closed** once those two files are committed and registered.
- **F2 — the gate does not catch class D2, and did not catch this instance of it.** Its
  match window is **eight normalised words**. Five of the seven heading strings are five or
  six words long, so they cannot produce an eight-word shingle and are structurally
  invisible to it. Re-running the same comparison at a **six**-word window found the heading
  list in **both** files, including the reproduction at `transcription.md:1112–1114`, which
  the eight-word gate reported as clean. **Open.**
- **F3 — the gate cannot detect a bare personal name (class D3) at all.** A first-plus-last
  name is two words. No shingle length that would catch it is usable without drowning the
  gate in false positives. Name-class disclosure needs a different mechanism — an explicit
  deny-list of names, held privately — or it needs a human. **Open.**

**The honest reading of F2 and F3: this leak was found by a human-directed audit, not by the
gate. The gate found class D1 only.**

## 5 · What was changed (containment)

Working tree only. **Nothing was committed, pushed, tagged, or rewritten.**

### `docs/workshop-curriculum/RECON.md` — §1.3

- The six heading strings are gone. Replaced by *"a `✍️ Quick notes` section of thematic
  bullets grouped under **six topic headings**"* plus an explicit statement that the strings
  are private and are not reproduced.
- The three quoted sentences and the quoted tool phrase are gone. Replaced by a **paraphrase
  written to be a paraphrase** — the same findings (who proposed the curriculum, what end
  state is intended, that hosting the material is an assigned action, that the §3 tooling is
  already in the operator's working set) carried in different words. This was verified, not
  assumed: see §7.
- The third party's name is gone. Replaced by *"a third party whose full name is private
  content and is deliberately not written into this repository."*
- A **Content boundary** callout was added at the end of §1.3, naming the private source
  **by path only** and linking here.

### `specs/001-workshop-curriculum-platform/research/transcription.md`

- **`:780`** — the sentence asserting the two names now says both speakers are named in the
  notes PDF, that this is what makes human attribution cheap, and that the third party's
  name is deliberately not written into this public repository. The *argument* (human
  attribution beats diarization here, because the names are already known) survives intact;
  only the names are withheld.
- **`:1112–1117`** — the seven heading strings and both names are gone. Replaced by *"a
  structured summary organised under **seven topic headings**… The headings span the
  session's technical ground and its business ground"*, with the strings explicitly withheld.
  The *use* the section makes of them — that they are a candidate section outline for FR-011 —
  is unaffected, because that use needs the **count and the shape**, not the text.
- **`:1140–1146`** — the captured `grep` output over the private text is gone. The command is
  retained as a **recipe to run against the private source**, with its output explicitly not
  reproduced. The argument it supported (the PDF contains transcription-class errors, so the
  recording must be authoritative) is preserved by describing the two mis-renderings
  functionally — a one-letter error in the planning toolchain's name, and `llama.cpp` split
  and capitalised as two English words — without pasting the erroneous strings or their
  private line offsets.
- A **Content boundary** callout was added at the end of §8, including the forward-looking
  rule that the transcript, once it exists, is private too: the §5 WER procedure must publish
  **scores**, never the sampled passages, the human reference, or the machine hypothesis.

**Deliberately left in place:** the proper-noun gazetteer list at `transcription.md:1126–1127`
(*MCP, Codegraph, Lumen, llama.cpp, Helix QA, Opus, Fable, RAG*). This is a judgement call and
is recorded as one. These are product and technology names, every one of them already
documented publicly elsewhere in this tree — `Lumen` has its own subsection in `RECON.md` §3.1,
and several have `_content/products/` pages. A vocabulary list of public product names is not a
reproduction of private prose, and the gazetteer is load-bearing for FR-038. If the operator
disagrees, deleting the list costs the document little.

## 6 · What the sweep found that the brief did not name

The brief supplied line numbers from one earlier pass. An independent sweep — comparing every
**six**-word normalised shingle of the private PDF against a **token stream** of every tracked
umbrella file, so that text wrapped across source lines is still matched — found three things
the brief did not:

1. **`transcription.md:1112–1114` reproduces the heading list.** The brief flagged
   `:1113–1116` for this, which is right, but the eight-word gate scores those lines **clean**,
   so anyone re-deriving from the gate alone would have concluded there was nothing there.
   This is F2 above, demonstrated.
2. **`RECON.md:143–144` quotes a tool phrase verbatim** — a six-word run naming two of the
   operator's indexing tools, lifted straight from the PDF. Outside the `:138–142` range the
   brief gave. Redacted.
3. **The name survives locally in `.ashlrcode/genome/knowledge/discoveries-auto.md`**, which
   caches agent tool output and holds a substantial verbatim excerpt of the PDF. It is
   **git-ignored** (`.gitignore:82`) and **untracked** — confirmed against `git ls-files` — so
   it was never published and is **not part of the public exposure**. It is flagged because it
   is a live local copy of private content in a directory that is *mostly* tracked, and one
   `.gitignore` edit away from becoming a second incident. **No action taken** — it is a
   generated cache owned by another tool.

The wider sweep also confirms this incident is **not the only content-boundary finding in the
tree**, and the rest is **out of scope for this work and remains unremediated**. Of the 377
baseline matches, 37 come from the `workshop` submodule (29 from the PDF, 8 from that
submodule's governance carriers appearing in `quickstart.md:315,317`). The other **340 come
from `design-toolkit/` and `ai_interviewing/`** — both private — landing in `_analysis/`,
`_content/products/`, `docs/constitution-adoption/INVENTORY.md`, and, notably,
`RECON.md:408`/`:460`/`:462`/`:489`, which quote private `ai_interviewing` source code and
scripts verbatim. **Those are a separate incident that has not been assessed, decided, or
fixed.** They are a different risk class — the operator's own code and prose rather than a
third party's personal data — but they are on the same public remote.

## 7 · Verification of the redaction

The paraphrases were checked rather than trusted, because a paraphrase written by the same
process that wrote the quote tends to stay too close to it.

Method: normalise the private PDF and each redacted file to lowercase alphanumeric token
streams; build every **six**-word shingle of the PDF; slide the same window over each file's
token stream (crossing line boundaries, so wrapped text cannot hide).

- **Before:** 23 locations, 97 shingles across tracked umbrella files.
- **After:** **9 locations, 54 shingles — every one of them the artifact's own filename and
  timestamp** (`…2026 08 27 09 57 cest…`), the accepted baseline described in §2. **Zero
  prose overlap remains.**
- A `grep -rn` for the third party's surname over the tracked umbrella tree returns **no
  tracked file**. The only surviving hits are in the git-ignored cache described in §6.3.
  (The search term is deliberately not written here — reconstruct it from the pre-redaction
  blob, `git show 63ac4df:docs/workshop-curriculum/RECON.md | sed -n '138p'`, and do not
  paste the result into this repository.)

Gate results are recorded at the end of this document.

## 8 · Full remediation — PREPARED, NOT EXECUTED, NOT AUTHORIZED

**Nothing in this section has been done. Nothing in it may be done by an agent.**

A history rewrite plus a force-push is a destructive operation. Constitution §11.4.113
requires **explicit per-session operator authorization** before any force-push, and the
project carriers additionally require a green §9.1.5 post-op gate. **The operator has not
given that authorization.** This is his decision — it has costs that only he can weigh — and
the plan below exists so that the decision can be made on facts rather than re-derived under
pressure.

### 8.0 · Decide first: is a rewrite even worth it?

Answer this before anything else, because **a rewrite is not a clean undo** (see §8.4), and
the honest answer is sometimes *no*.

It is **worth it** if the third party's identity being publicly linked to this private session
is itself the harm, and reducing the number of people who can casually find it has value.

It is **not worth it** if the content is already mirrored or indexed, in which case the
rewrite costs every collaborator a re-clone and buys close to nothing — and **a targeted
conversation with the third party may be worth more than any git operation.**

The third party is the person with the most at stake and the least say. **Telling them is a
defensible first step regardless of what is decided about git**, and it is the operator's call
to make, not an agent's. This document takes no outward-facing action of any kind.

### 8.1 · Before touching anything

1. **Hardlinked backup of the full repository, including `.git`** (Constitution §9). A history
   rewrite is exactly the destructive class that rule exists for.
2. Record `git rev-parse HEAD` and the current `origin/main`.
3. **Confirm every other active agent and worktree in this tree has stopped.** A rewrite under
   a concurrent writer loses work. At the time of writing, several agents were active here.
4. `git fetch --all` and confirm no unmerged remote work would be discarded.

### 8.2 · The rewrite

Rewrite `63ac4df..HEAD` (four commits), replacing the two blobs with their redacted content
while preserving every other change.

- `git filter-repo --replace-text <rules>` is the appropriate tool — it is the maintained
  replacement for `filter-branch`, and its `--replace-text` mode substitutes the disclosed
  strings without needing the files to be reconstructed by hand.
- **The rules file itself contains the disclosed strings.** It must be written **outside the
  repository**, never committed, and shredded afterwards.
- `filter-repo` removes the `origin` remote by design; it must be re-added deliberately.
- Every commit from `63ac4df` onward gets a **new SHA**. Every existing clone, every open
  branch, and every reference to those SHAs — including any in `CONTINUATION.md` or in these
  governance documents — is invalidated and must be updated. **This document's own §2 and §3
  SHAs become historical references to a discarded history**, which is the correct outcome,
  and the document should say so at that point rather than being edited to hide it.

### 8.3 · The push

`git push --force-with-lease` — never bare `--force`. `--force-with-lease` refuses if the
remote moved since the last fetch; bare `--force` silently destroys whatever it finds.

**This step requires the explicit per-session authorization named above.** Both site
submodules deploy from pushes; `milosvasic.ru` self-publishes via an active workflow that
**must not break** (a documented deviation held for production uptime). Confirm the umbrella
rewrite cannot disturb either before pushing.

### 8.4 · Why the rewrite is still not a complete remedy — state this to the operator plainly

- **GitHub retains force-push-orphaned commits and serves them by SHA** until they are
  garbage-collected, and the timing of that GC is not under the repository owner's control.
  Anyone who recorded `63ac4df` — from a notification email, a webhook payload, an Actions
  log, a PR page, a mirror, or this document — **can still fetch the old content by SHA after
  a successful force-push.** A rewrite alone therefore does **not** end the exposure.
- Ending it requires **asking GitHub Support to purge the orphaned objects and caches**, and
  they are the only party who can. **That is an outward-facing action and is out of scope for
  this work — it is the operator's to initiate, deliberately, not an agent's.** It is listed
  here because a plan that stops at the force-push would be a plan that quietly overstates
  what it achieves.
- **Forks, mirrors and existing clones are unreachable by any of this.**
- **Search-engine and archive caches** persist independently and have their own removal
  processes.
- **Rotation.** No credential, key or token was disclosed — the material is prose and a
  personal name — so there is nothing to rotate in the secrets sense. **Personal data cannot
  be rotated at all**, which is precisely why D3 is the serious class and why §8.0 puts the
  conversation with the third party ahead of the git operation. Before concluding this,
  re-run a secret scan over the affected blobs rather than taking this paragraph's word for it.

### 8.5 · Prevent recurrence

- **Commit and register `scripts/verify-content-boundary.sh`.** It is untracked. R5 in
  `verify-check-registry.sh` will fail until it is entered in `scripts/check-registry.tsv`,
  and that failure is the registry working correctly.
- **Wire it into `scripts/pre-push-gates.sh`.** A boundary check that only runs when someone
  remembers to run it did not prevent this incident and will not prevent the next one.
- **Close F2:** lower the match window, or add a heading-list-specific check that compares
  private headings against public files at their natural length. Pair it with a mutation proof
  that seeds a five-word heading and requires a catch (Constitution §1.1).
- **Close F3:** a privately-held name deny-list, read from outside the tracked tree, so the
  gate can catch a bare personal name without the list itself becoming a disclosure.
- **Assess the 340 out-of-scope matches** in §6 as a separate piece of work with its own
  decision record.

---

## 8A · The remediation, REHEARSED ON A CLONE — NOT EXECUTED, REQUIRES OPERATOR AUTHORIZATION

> **Status: REHEARSED ON A CLONE, NOT EXECUTED — REQUIRES OPERATOR AUTHORIZATION.**
> Nothing in this section was done to `/run/media/milosvasic/DATA4TB/Projects/vasic`.
> No `git push`, no `--force`, no `filter-repo`, no `fetch` touched the real repository.
> Constitution §11.4.113 still requires explicit per-session operator authorization for the
> force-push, and it has still not been given. §8 above is **unchanged**; this section sits
> beside it and records where running the plan corrected it.

**What this section is for.** §8 was a plan that had never been executed even once, so nobody
knew whether it worked. On **2026-09-01** the whole of it was run end to end on a full clone in
a scratchpad, and every claim below is a measurement taken from that run rather than an
expectation. Where the rehearsal contradicts §8, §8A.9 says so explicitly rather than editing
§8 to look right in hindsight.

**Isolation.** All work happened in
`…/scratchpad/rehearsal/` on tmpfs. The real repository was touched only by
`git clone`'s `upload-pack` (read-only), `git cat-file` and `git ls-tree`. Every destructive
command was preceded by a `case "$PWD" in …/rehearsal/run*) … ;; *) exit 1 ;; esac` guard whose
output is quoted in the run log. Eight agents were writing to the real tree throughout; the
clone isolated the rehearsal from them completely, and §8A.9 records what that concurrency
proved about the plan.

### 8A.1 · The exposure, re-measured on the clone

The clone reproduces the leak exactly. §2 and §3 name **two** files; the measurement finds
**four**, because waves 2 and 3 added two more and §8 was never updated to match.

| Path | Blob | Blob bytes | In commits | Disclosed lines | Disclosed bytes |
|---|---|---|---|---|---|
| `docs/workshop-curriculum/RECON.md` | `101e019c2d6d721592f900234300aa7bb1270cff` | 98,599 | all 4 | 36 | 2,501 |
| `specs/001-workshop-curriculum-platform/research/transcription.md` | `7c3513d3fa731142b65849f025f61f966a11d624` | 69,910 | all 4 | 16 | 1,410 |
| `specs/001-workshop-curriculum-platform/research/llm-bridging.md` | `7801a53730c86808caa9cdec3807bac7a977b093` | 61,681 | all 4 | 1 | 121 |
| `specs/001-workshop-curriculum-platform/quickstart.md` | `a4aed8a4ec7793afdc76e773f857dcadaf12d3e8` | 62,324 | **3** — `d0b3c64` onward | 4 | 368 |
| **Total** | **4 distinct blobs** | **292,514** | **4 commits** | **57** | **4,400** |

Each blob is byte-identical in every commit that carries it — a single blob per path, not one
per commit. The four commits are `63ac4df` → `d0b3c64` → `96b2988` → `ee3933d`, all
2026-09-01, all authored `Милош Васић`.

Two further facts, both measured rather than assumed:

- **No other object in history carries any of it.** An exhaustive scan of every object in the
  clone — `git cat-file --batch-all-objects`, which sees reachable, unreachable, packed and
  reflog-held objects alike; **7,505 objects, 6,231 text blobs** — found each of the 51 usable
  disclosed-line literals in **exactly one blob**, and that blob is always one of the four
  above. Nothing else in 103 commits copies the material.
- **No tag and no other branch contains it.** `63ac4df` is an ancestor of `refs/heads/main`
  only. All four tags (`pre-restyle`, `v1.7.1`, `v1.7.2`, `v1.8.0`) predate it.
  `git ls-remote` against the public remote returns **`refs/heads/main` and those four tags and
  nothing else**, so the force-push would touch exactly **one** remote ref — which is also
  precisely what `filter-repo` wrote into `.git/filter-repo/changed-refs`: `refs/heads/main`.

### 8A.2 · Tooling — `git filter-repo` is present

`git-filter-repo` resolves on `PATH` at `/home/milosvasic/.local/bin/git-filter-repo`, backed by
the importable module `git_filter_repo` at
`/home/milosvasic/.local/lib/python3/site-packages/git_filter_repo.py`, against `git 2.50.1`.
**No fallback was needed**: neither `git filter-branch` nor BFG was used, and neither should be.
`filter-branch` is deprecated and would have been dramatically slower on a 3.96 GiB pack, and
BFG is not installed on this host.

### 8A.3 · The procedure that was actually run, with the verification after each step

Every command below was executed, in this order, with the measured wall-clock beside it.
`$SCRATCH` is the scratchpad rehearsal directory; `$W` is `$SCRATCH/work`, held **outside** the
repository. Substitute nothing by hand — the SHAs here are this run's, and a real run must read
its own out of `.git/filter-repo/`.

**Step 0 — hardlinked backup and a recorded starting point (§8.1, unchanged and correct).**
Not re-measured here because the rehearsal's clone *is* the backup; in a real run this is
Constitution §9 and is not optional.

```bash
git rev-parse HEAD                 # ee3933d46211d6001ffc23acab480e0cffdc99c6
git ls-remote git@github.com:milos85vasic/vasic.git   # read-only; no fetch, no object transfer
```
*Verify:* the remote's `refs/heads/main` equals local `HEAD`. It did.

**Step 1 — full clone, all refs, all tags.** `--no-local` forces the git-aware transport, so
the clone is a self-contained copy with no hardlinks into and no alternates pointing at the
real object store. That property is what makes the rest of this safe.

```bash
git clone --no-local --no-single-branch \
  file:///run/media/milosvasic/DATA4TB/Projects/vasic "$SCRATCH/vasic-clone"
```
**Measured: 557.04 s (9 m 17 s), peak RSS 2.26 GB, 4.6 GB on disk, 3.96 GiB pack.**
*Verify:* `HEAD` = `ee3933d…`; 103 commits; 7,505 reachable objects; all four leak blobs
resolve with their documented byte sizes; a single pack, no loose objects.

**Step 2 — pin the redacted replacement content, outside the repository.** For `RECON.md` and
`transcription.md` the working-tree files are redaction-only and were pinned as-is. For
`quickstart.md` and `llm-bridging.md` the working tree also carried **unrelated concurrent
edits from other agents**, so the pinned versions were built as *pre-image plus only the
disclosure hunk*. Each pinned file is fixed by sha256, and the rewrite aborts if a byte moves:

| Pinned file | sha256 | Hunks applied vs pre-image |
|---|---|---|
| `RECON.pinned` | `663fbba60ed81a134d653eaeaa9bd35c06a2464afb5fa4b5f904c9ccc8403d8c` | 4 (waves 1 + 2) |
| `TRANS.pinned` | `a4e2ddf05f42b277e1d13f6406e52fd3509e02476d581e48ca571c1ecd7a1870` | 6 (wave 1) |
| `QUICK.pinned` | `91d33086273443a796558987733f7f5c5812fba0c123fdb48c3a356aa7395f91` | 1 (wave 2 only) |
| `LLMB.pinned` | `b1371f1f77810930aad21637deb94bb0b272a92e6acacc8cbc1424eef407c52c` | 1 (wave 2 only) |

*Verify:* `diff` each pinned file against its pre-image and confirm the hunk count and the
57 removed lines / 4,400 bytes in §8A.1. It matched.

**Step 3 — the rewrite.** Keyed on `blob.original_id`, so the four blobs are replaced wholesale
and **no copy of the disclosed strings exists anywhere in the procedure**:

```bash
cd "$SCRATCH/runB"
case "$PWD" in */scratchpad/rehearsal/runB) : ;; *) echo ABORT; exit 1 ;; esac
export FR_PINNED_DIR="$W"
git filter-repo --blob-callback "$(cat "$W/blob-callback.py")"
```

The callback is 30 lines: a `{blob-sha → pinned-filename}` map, a sha256 assertion per pinned
file, and `blob.data = …`. **Measured: 391.23 s (6 m 31 s), peak RSS 6.04 GB.**
*Verify:* see §8A.4 — all of it.

**Step 4 — the push, rehearsed against a local stand-in remote.** A hardlinked bare clone of
the *pristine* history stands in for GitHub, so the lease semantics are exercised for real
without any network:

```bash
git clone --bare "$SCRATCH/vasic-clone" "$SCRATCH/fake-remote.git"   # 0.02 s, hardlinked
# NEGATIVE CONTROL (§1.1 paired mutation) — a wrong lease MUST be refused:
git push --force-with-lease=refs/heads/main:0000…0000 fakeorigin main
#   ! [rejected]  main -> main (stale info)      remote unchanged at ee3933d
# POSITIVE — the correct lease:
git push --force-with-lease=refs/heads/main:ee3933d46211d6001ffc23acab480e0cffdc99c6 \
         fakeorigin main
#   + ee3933d...b0ab4b4 main -> main (forced update)
```
**Measured: 12.29 s.** Using the explicit `=<ref>:<expected-sha>` form is deliberate — it means
the lease never has to be established by a `git fetch`, and §8A.9 records why that matters.
*Verify:* the negative control was refused and left the remote at `ee3933d`; the positive
updated it to the rewritten tip. Both held.

**Total measured wall-clock for the whole procedure: ≈ 17 m 50 s** (clone 557 s + snapshot 9 s
+ rewrite 391 s + residue scan 7 s + `fsck` 94 s + push 12 s), peak RSS 6.04 GB — about
**10 % of this host's 62 GB**, comfortably inside the §12.6 60 % cap.

### 8A.4 · What the rewrite was verified to have done — exhaustively

Every check below was run against the rewritten clone after the rewrite.

**Residue — nothing of the material survives anywhere.**

- **51 of 51 disclosed-line literals: 0 matches, in 0 blobs**, across all 7,505 objects
  (`--batch-all-objects` covers unreachable and reflog-held objects too, not just what the refs
  reach). Before the rewrite all 51 matched.
- **Name class: 0.** Four distinctive capitalised tokens were derived mechanically as
  *present in the removed lines and absent from every redacted file*, then confirmed to occur in
  ≤ 4 blobs in pristine history. After the rewrite all four are gone from every blob that carried
  them as part of the disclosure. One single occurrence of one token survives, in
  `_analysis/top20/caf-bridle.readme.txt` — a vendored third-party README added in commit
  `dd2d684`, long before this incident, where the word is an ordinary lexical coincidence. It is
  **not** disclosure and it is correct that the rewrite left it alone.
- **The old objects are unresolvable locally.** `git cat-file -t` on `63ac4df`, `ee3933d`,
  `101e019c`, `7c3513d3`, `a4aed8a4` and `7801a537` all return *"could not get object info"*.
  `git reflog --all` is empty and `git fsck --unreachable` reports **0** unreachable objects —
  `filter-repo` expires the reflog and prunes as part of its own run.
- `git fsck` clean in **93.95 s**. 7,505 objects, 3.96 GiB pack — unchanged, as expected: the
  four replaced blobs are of near-identical size.

**Collateral damage — none.** The full tree at `HEAD` was captured before and after and compared
entry by entry (`ls-tree -r -t --full-tree`, **6,246 entries**):

- Path set **identical** — 0 paths added, 0 removed.
- **9 entries changed, and only 9**: the **4 target blobs**, and the **5 tree objects** that are
  exactly their ancestor directories (`docs`, `docs/workshop-curriculum`, `specs`,
  `specs/001-workshop-curriculum-platform`, `specs/001-workshop-curriculum-platform/research`).
- **6,237 of 6,246 entries are byte-identical**, same mode, same type, same object SHA.
- Each rewritten blob is **byte-identical to its pinned file** — verified with `cmp`, all four.
- `git status` in the rewritten clone is **clean**: the rewrite lands the redaction in history
  *and* in the checkout in one operation.

**Identity — 103 commits, 4 SHAs changed, everything else preserved.**

| Old | New (this rehearsal) | Subject |
|---|---|---|
| `63ac4df3` | `fc7574b2` | SpecKit 001 through plan phase… |
| `d0b3c649` | `7b4df26d` | SpecKit 001 through tasks… |
| `96b2988e` | `4ee9e8de` | gates: distinguish 'could not run' from 'failed'… |
| `ee3933d4` | `b0ab4b44` | gates: defer live-production specs… |

- **98 of 103 commit SHAs are unchanged.** Only `63ac4df` and its three descendants move,
  because they are the only commits at or after the earliest rewritten one.
- **Author name, author email, author date, committer name, committer email, committer date and
  subject are byte-identical for all 103 commits** — compared as a sorted stream with SHA, tree
  and parent stripped. `filter-repo` preserves the whole identity envelope; only the SHA moves,
  and it moves because the tree it commits to has changed. That is the definition of a content
  hash working correctly.
- **All four tags unchanged**, all still pointing at their original objects — they predate
  `63ac4df`.
- `.git/filter-repo/first-changed-commits` contains exactly one line, the old→new mapping for
  `63ac4df`. That file is what GitHub Support asks for (§8A.7).

### 8A.5 · What the rewrite changes about identity, stated plainly

Every commit at or after the earliest rewritten one gets a new SHA. Here that is **4 of 103**,
because `63ac4df` is the fourth commit from the tip — the blast radius is small, but it is not
zero, and it is exactly the disruption that makes this a decision rather than a chore:

- Anyone holding a clone has a history that no longer shares a tip with the remote. Their next
  `git pull` will not fast-forward. They must **rebase, not merge** — GitHub's own guidance —
  because merging their old branch back would reintroduce the deleted content.
- Any recorded reference to `63ac4df`, `d0b3c64`, `96b2988` or `ee3933d` — in a notification
  email, a webhook payload, an Actions log, a bookmark, or **in this document's own §2, §3 and
  §9.6** — becomes a reference to a discarded history. §8.2 already predicted this and said the
  document should say so rather than be edited to hide it. It is said here.
- **Three tracked files quote `63ac4df` in prose** and would become dangling evidence
  references: `helix-deps.yaml` (2 places), `scripts/verify-governance-cascade.sh` (1) and
  `scripts/verify-manifest-pins.sh` (2). `filter-repo` rewrites old hashes in **commit
  messages**, not inside blob content, so these survive the rewrite untouched and stale. None is
  functional — all five are anti-bluff evidence citations — but under §11.4.6 a citation that
  no longer resolves is a defect and would need a follow-up commit. **§8 does not mention this.**

### 8A.6 · The consequences, measured rather than assumed

**Gitlinks and `helix-deps.yaml` survive intact — verified, not assumed.**

- `HEAD` carries **9 gitlinks** (`ai_interviewing`, `design-toolkit`, `milosvasic.ru`,
  `monetization`, `submodules/constitution`, `submodules/containers`, `submodules/superspec`,
  `vasic.digital`, `workshop`). After the rewrite all **9 are byte-identical**, and the
  before/after tree comparison reports `gitlinks=0` changed. Across all 103 commits there are
  **93 distinct (path, sha) gitlink pairs** over those same 9 paths, and the rewrite touched
  none of them.
- `helix-deps.yaml` contains **13 `ref:` mentions**, of which **8 are actual `deps[].ref` pins**
  holding **9 distinct 40-hex SHAs**. Every one of them names a commit in a *submodule*
  repository: the intersection of those SHAs with the umbrella's own 103 commits is **empty**.
  The blob SHA of `helix-deps.yaml` at `HEAD` is unchanged by the rewrite, and so is
  `.gitmodules`.
- **Why they survive.** Gitlinks point *outward*. A gitlink is a `commit` entry in the umbrella's
  tree whose SHA belongs to another repository's object graph, which this rewrite never enters.
  The intuition was right; it is now measured. **Cascade check C9 and
  `scripts/verify-manifest-pins.sh` would still pass unchanged after the rewrite.**

**Who actually has the old objects — measured from the provider, read-only.**

| Fact | Measured 2026-09-01 |
|---|---|
| Visibility | `private=false, visibility=public` |
| **Forks** | **0** (`forks_count` 0, `network_count` 0) |
| Watchers / stars | 0 / 0 |
| **Pull requests, any state** | **0** |
| Branch protection on `main` | none — a force-push would not be blocked |
| Repository page views, 14 d | **0** (`count` 0, `uniques` 0) |
| Popular paths / referrers, 14 d | **empty** |
| Clones, 14 d | 62 / 26 unique — **but the window ends 2026-08-31** |

Read those carefully, because they cut both ways.

- **The good news is real.** Zero forks means no fork on the provider retains the objects. Zero
  pull requests means the whole "cached views and references in pull requests" problem — the
  main thing GitHub Support exists to fix here — **does not apply to this repository**. Zero
  page views means nobody browsed the file on github.com.
- **The honest gap.** GitHub's traffic API covers **2026-08-18 … 2026-08-31**, and the leak
  landed **2026-09-01 06:47 CEST**. There is therefore **no clone data yet for the exposure
  window at all**, and whether anyone cloned during it is **UNVERIFIED**. Re-run
  `gh api repos/milos85vasic/vasic/traffic/clones` on 2026-09-02 or later; that is the single
  cheapest piece of evidence available for the §8.0 decision, and it does not exist yet.
- Anonymous clones are invisible to the provider regardless, and search-engine and archive
  caches persist independently with their own removal processes. Neither is measurable from here.

**A force-push does not delete anything on the server — demonstrated, not quoted.** On the
stand-in remote, immediately after a successful `--force-with-lease`:

```
63ac4df3 -> commit          # still resolves
101e019c -> blob            # still resolves, all 98,599 bytes readable by SHA
reachable from any ref? 0   # orphaned — but orphaned is not deleted
```

Only after `git reflog expire --expire=now --all && git gc --prune=now` (11.86 s) did both
become unresolvable. **That is precisely the GitHub situation**, and it is why §8.4 is right
that the rewrite alone is not a remedy: the content stays fetchable by SHA to anyone who
recorded it, until a server-side garbage collection runs, and the timing of that is not the
repository owner's to control. What removes it is a **support request** — §8A.7.

**One incidental finding, checked because it would have been far worse than the incident.**
History contains a **1,784 MB blob** at
`workshop-git-backup-2026-08-29/objects/pack/pack-053fbf69…pack` — a committed copy of the
**entire object store of the private `workshop` submodule** — on commit `a8137db`
("Auto-commit", 2026-08-29). **It is not public.** `a8137db` is not an ancestor of `main`, the
path does not exist at `HEAD`, and `git ls-remote` confirms the public remote carries only
`refs/heads/main` and four tags: the branch `backup/pre-untrack-git-backup-a8137db` exists
**locally only and was never pushed**. No action is required, and one prohibition follows:
**that branch must never be pushed.** It is recorded here because a local-only hazard that
nothing checks is one accidental `git push --all` away from being a much larger incident than
this one.

### 8A.7 · The GitHub Support request — text prepared, DO NOT SEND

**This is an outward-facing action and it is the operator's alone.** Nothing was sent, no issue
was opened, no support portal was contacted. GitHub's own instructions
([Removing sensitive data from a repository](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository))
require the request to name the repository, the number of affected pull requests, and *"the
First Changed Commit(s) reported by git-filter-repo"*. Send it **only after** the force-push has
succeeded — the first-changed-commit mapping does not exist until then.

Two things to fix in the text before sending: replace `<NEW-SHA>` with the value from the real
run's `.git/filter-repo/first-changed-commits` (**not** this rehearsal's — the pinned content
will differ, so the SHA will differ), and re-check the pull-request count if any PR has been
opened since 2026-09-01.

> **Subject:** Request to purge orphaned commits and cached views after a history rewrite — `milos85vasic/vasic`
>
> Repository: `milos85vasic/vasic` (public, owned by me).
>
> I have rewritten this repository's history to remove personal data about a **third party** — a
> named individual who is not me, who did not publish the material, and who has no control over
> it — together with verbatim prose quoted from a private document. The material was committed
> on 2026-09-01 at 06:47 CEST and force-pushed out on <DATE>.
>
> I have already completed the following:
>
> - Rewrote the affected commits with `git filter-repo` and force-pushed the cleaned history to
>   `refs/heads/main` using `--force-with-lease`.
> - Confirmed the sensitive content is absent from every object in the rewritten history.
> - Confirmed there are **no forks** of this repository (`forks_count` 0, `network_count` 0).
> - Confirmed there are **no pull requests** in this repository, in any state — so the count of
>   affected pull requests is **0**.
> - Confirmed no Git LFS objects are involved; the repository declares no LFS filters.
> - Confirmed no other branch or tag contains the affected commits; only `refs/heads/main` was
>   rewritten.
>
> **First Changed Commit, as reported by `git filter-repo`:**
>
> - old: `63ac4df32e5fd40806a50cd38fde8cdc39587c2c`
> - new: `<NEW-SHA>`
>
> The following commits were orphaned by the force-push and, at the time of writing, still
> resolve by SHA at `https://github.com/milos85vasic/vasic/commit/<sha>`:
>
> - `63ac4df32e5fd40806a50cd38fde8cdc39587c2c`
> - `d0b3c6493a7f635a0a71d81f049069fb2741ea9c`
> - `96b2988ef61f4adee1bba51ee1c42efcb5f4408e`
> - `ee3933d46211d6001ffc23acab480e0cffdc99c6`
>
> Please run a garbage collection on the server to expunge these orphaned objects from storage,
> and remove any cached views that still serve them.
>
> On your criterion that support removal is for cases where *"the risk can't be mitigated by
> rotating affected credentials"*: **no credential is involved and none can be rotated.** The
> disclosed material is another person's full name, linked to a dated private business
> conversation, plus prose quoted from a private document. Personal data cannot be rotated,
> reissued or revoked. Rotation is not an available mitigation here, which is precisely why I am
> asking for the purge.
>
> Thank you.

### 8A.8 · Prerequisites the rehearsal showed are load-bearing

- **Commit the working-tree redaction, or fold it into the rewrite — but decide which.** The
  redactions of §5, §9.3 and §9.4 are still **uncommitted working-tree modifications**. The
  procedure in §8A.3 folds them into history directly, which leaves a clean `git status` and no
  second commit. If instead §8's `--replace-text` route is taken, history gets marker lines and
  the working-tree redaction still has to be committed afterwards, as a separate step, with a
  confusing diff. §8 does not sequence this at all.
- **Stop the other agents first, and mean it.** §8.1 item 3 says this. The rehearsal found the
  hard evidence for why: between 14:00 and 17:18 on 2026-09-01, concurrent agents modified
  `quickstart.md` and `llm-bridging.md` for reasons unrelated to any redaction. Had those files
  been substituted wholesale from the live working tree, the rewrite would have injected
  unrelated in-flight work into four commits from earlier that morning.
- **Do not `git fetch` between the rewrite and the push.** Fetching from the un-rewritten remote
  pulls the leaked objects straight back into the cleaned clone. This is why §8A.3 step 4 uses
  the explicit `--force-with-lease=<ref>:<sha>` form, which needs no remote-tracking ref and
  therefore no fetch. §8.1 item 4 recommends `git fetch --all` *before* the rewrite, which is
  fine and correct; the hazard is a fetch *after* it.
- **`filter-repo` removes `origin`** — §8 says so and it is confirmed. It also **converts
  remote-tracking refs into local branches**: `refs/remotes/origin/backup/pre-untrack-…` came
  back as `refs/heads/backup/pre-untrack-…`. Given the 1.78 GB private packfile on that branch
  (§8A.6), the state after a real rewrite is one where a private-object-bearing branch is a
  *local branch* rather than a remote-tracking ref. **Re-add the remote deliberately and push
  one refspec explicitly — never `--all`, never `--mirror`.**

### 8A.9 · Where the rehearsal corrected §8

§8 is left exactly as written above. These are its defects, each found by running it:

1. **"Replacing the two blobs" is wrong — there are four.** §8.2 was written during wave 1 and
   never updated after waves 2 and 3 added `quickstart.md` and `llm-bridging.md`. A rewrite
   scoped to §8.2's two blobs would have left **489 bytes of disclosed material across 5 lines**
   in public history, including the third party's first name used as a person in prose.
2. **§9.6 misstates where `quickstart.md` came from.** It says `quickstart.md` was introduced in
   `63ac4df`. Measured: `git rev-parse 63ac4df:specs/001-workshop-curriculum-platform/quickstart.md`
   fails — the file does not exist in that commit. It was introduced in **`d0b3c64`** and is
   carried by 3 commits, not 4.
3. **`--replace-text` is the wrong instrument, though it does work.** It was run in full as
   Run A: **208.06 s**, and it did reach zero residue on all 51 literals with the same surgical
   4-blob / 5-tree footprint. But getting there required discovering three things §8 does not
   mention. (a) The rules file is line-oriented, so a multi-line quoted passage cannot be one
   rule — it must be decomposed into per-line literals. (b) **Not every removed line is safe to
   use as a rule.** Six of the 57 had to be rejected as too generic to substitute globally
   across all history — one of them is a 3-character markdown fence occurring 38 times in that
   file alone; using it as a rule would have corrupted unrelated content in unrelated commits.
   Each of the six was then individually checked to confirm it carries no disclosure. §8 gives
   no filtering rule and an operator following it literally would have written a destructive
   rules file. (c) It produces history containing `***REDACTED***` marker lines rather than the
   redacted prose, so the working-tree redaction remains a separate uncommitted change.
4. **The `--blob-callback` route is better and needs no secret-bearing rules file at all.**
   §8.2's warning that *"the rules file itself contains the disclosed strings"* — that it must be
   written outside the repository, never committed, and shredded — is correct as far as it goes,
   but it is a hazard that can be **designed out** rather than managed. Keying on
   `blob.original_id` and substituting a pinned redacted file means no artifact of the procedure
   ever contains the disclosed text. It costs **391.23 s instead of 208.06 s**; that is the whole
   price.
5. **§8 has no numbers.** It could not tell the operator that this takes about 18 minutes, needs
   6 GB of RAM and 10 GB of scratch disk, or that a `git fsck` over the result costs another 94
   seconds. A plan that cannot be scheduled is a plan that gets started at the wrong time.
6. **§8 does not mention that five prose citations of `63ac4df` in three tracked files go
   stale** (§8A.5).
7. **§8.4's central claim is now demonstrated rather than asserted** (§8A.6): after a successful
   `--force-with-lease`, the leaked blob remained fully readable by SHA on the remote, and only
   a server-side `gc --prune` removed it.
8. **§8.0's decision inputs were partly measurable all along, and nobody had measured them.**
   Zero forks, zero pull requests, zero page views are facts that materially change the
   cost/benefit — and the one fact that matters most, clone traffic during the exposure window,
   **does not exist yet** and will not until 2026-09-02.

### 8A.10 · Recommendation — rewrite, and treat the support request as the substantive step

This is a recommendation, not a decision. The decision is the operator's and §8.0 correctly
frames it. But the rehearsal changed the balance, so leaving the recommendation unstated would
be a failure to report what was learned.

**The case for leaving history intact.** The material is 4,400 bytes of prose and a name, not a
credential. It has been public for hours in a repository with **zero forks, zero pull requests
and zero recorded page views** — the realistic probability that a human being has read it is
low. A rewrite invalidates 4 commit SHAs, breaks every existing clone, strands five evidence
citations, and — on its own — **removes nothing from GitHub's servers**. If the honest answer to
"who has actually seen this" is "nobody", then a rewrite is ceremony with a real cost and no
benefit. §8.0 is right that this is sometimes the correct answer.

**The case for rewriting.** It is not a credential, and that is the argument *for* acting, not
against. A leaked token can be rotated in a minute and the exposure ends; a person's name linked
to a dated private business conversation **cannot be rotated, ever**. The asymmetry runs the
other way from the usual secrets case. The person carrying the risk is not the person who
published it and has no say in the matter. And the cost is now measured rather than feared:
**about 18 minutes, 4 commits, one remote ref, 6,237 of 6,246 tree entries untouched, all 9
gitlinks and every `helix-deps.yaml` pin intact, all 4 tags intact, 98 of 103 commit SHAs
intact, `git fsck` clean.** Because there are no forks and no pull requests, the two things that
usually make a rewrite ugly do not exist here. This is close to the cheapest a history rewrite
ever gets.

**Recommended: do all three, in this order — and understand that the rewrite is the least
important of them.**

1. **Tell the third party.** §8.0 already says this is defensible regardless of what is decided
   about git, and the rehearsal supports it more strongly: no git operation can undo disclosure
   of a name, and the person concerned is the only party who can judge what the exposure means
   for them. **This is the substantive remedy. The other two are hygiene.** Operator's call, and
   an agent must not take it.
2. **Rewrite and force-push**, using §8A.3, under explicit §11.4.113 authorization, with the
   §9.1.5 post-op gate green. The measured cost is low, the blast radius is small and known, and
   it is the necessary precondition for step 3 — the support request cannot be filed until the
   first-changed-commit mapping exists.
3. **File the support request** (§8A.7). This is the step that actually removes the content from
   GitHub's storage. A rewrite without it leaves all four commits fetchable by SHA for an
   indefinite period, which the demonstration in §8A.6 shows plainly.

**One thing to do before any of it, because it is free and it may change the answer:** re-run
`gh api repos/milos85vasic/vasic/traffic/clones` **on or after 2026-09-02**, when the exposure
window finally appears in the data. If it shows unique cloners during the window, step 1 becomes
urgent. If it shows none, steps 2 and 3 are cheap insurance and step 1 is still right.

**What would change this recommendation:** evidence that the content is already mirrored,
indexed or archived elsewhere. Nothing found so far suggests it is — zero forks, zero page views,
zero referrers — but three of those four channels are unmeasurable from here, and "not measured"
is not "not happened".

---

## 8B · The remediation, EXECUTED — 2026-09-01, under explicit operator authorization

> **Status: EXECUTED AND FORCE-PUSHED.** This was done to
> `/run/media/milosvasic/DATA4TB/Projects/vasic` and to
> `git@github.com:milos85vasic/vasic.git`. §8 and §8A are left **exactly as written**;
> this section sits beside them and records what running the plan for real produced,
> including where the live tree had moved out from under §8A's measurements.

**The authorization (§11.4.113).** Given by the operator in-session, verbatim:
*"Rewrite history + force-push"*, with three conditions — *"Make sure no git history or
codebase is lost, corrupted or broken! Make sure we have on our side all codebase brought
from all upstreams before any force push is performed! Create proper backups too!"* All
three were re-verified independently before anything destructive ran (§8B.1). No
outward-facing action of any kind was taken: **GitHub Support was not contacted, no issue
was opened, and the third party was not contacted.** Those remain the operator's.

### 8B.1 · Preconditions, re-verified rather than inherited

| Condition | How it was verified | Result |
|---|---|---|
| All upstreams present locally | `git ls-remote` against all three remote names, read-only; every object id returned was resolved with `git cat-file -t` | **10 remote refs, 9 distinct objects, all resolved locally.** 0 missing. No `fetch` was run. |
| Backups exist and are complete | `for-each-ref` + `cat-file` inside the bare mirror; `.git` presence and object probes in both hardlinked snapshots | Mirror `…/.vasic-history-mirror-2026-09-01.git`: **11 refs, 104 commits, 4.0 GB**, holds all four leak blobs, all six affected commits, **and** the three dangling blobs and the unreachable `a8137db`. Both snapshots carry their own `.git`. |
| Everything committed and pushed | `git status --porcelain --ignore-submodules=all`; `ls-remote` × 3 | Umbrella working tree **clean**; local `HEAD` = `4df8401c32b6` = `refs/heads/main` on `origin`, `github` **and** `upstream` — which are three *names* for one repository. |
| Gates green | `bash scripts/pre-push-gates.sh` | **rc=0, 8/8 PASS, 214 s** (§8B.7). |

Two facts about the tree had **moved since §8A** and both changed the work:

1. **`HEAD` is `4df8401`, not `ee3933d`.** Two further commits landed —
   `cbdb535` and `4df8401` — and **`cbdb535` committed the working-tree redaction**. So
   the tip was already clean before the rewrite, and the rewrite's whole job was the four
   *historical* commits.
2. **`.gitmodules` now declares 13 gitlinks, not 9**, and the tree at `HEAD` has **6,260**
   entries, not 6,246.

### 8B.2 · The pinned replacements, re-derived against current `HEAD`

§8A's own instruction was followed: **the rehearsal's SHAs were not reused.** Each pinned
file was rebuilt from scratch as *pre-image plus only the disclosure hunks*, by diffing the
pre-image blob against the **current `HEAD`** blob and selecting hunks by hand.

| File | Pre-image blob | `HEAD` blob | Hunks pre→HEAD | Disclosure hunks selected | Unrelated hunks rejected |
|---|---|---|---:|---:|---:|
| `RECON.md` | `101e019c` | `f4724894` | 4 | **4** | 0 |
| `transcription.md` | `7c3513d3` | `c234dde0` | 4 | **4** | 0 |
| `llm-bridging.md` | `7801a537` | `f94054b7` | 5 | **1** | **4** — the `/api/answer`→`/api/ask` route rename |
| `quickstart.md` | `a4aed8a4` | `1c2f577d` | 8 | **1** | **7** — status, script-path and benchmark-path corrections |

Selecting the whole `HEAD` blob for the last two would have injected 11 hunks of unrelated
later work into four commits dated earlier the same morning — the §8A.8 trap, still live.

| Pinned file | Bytes | sha256 |
|---|---:|---|
| `RECON.pinned` | 100,264 | `663fbba60ed81a134d653eaeaa9bd35c06a2464afb5fa4b5f904c9ccc8403d8c` |
| `TRANS.pinned` | 71,655 | `a4e2ddf05f42b277e1d13f6406e52fd3509e02476d581e48ca571c1ecd7a1870` |
| `LLMB.pinned` | 61,695 | `b1371f1f77810930aad21637deb94bb0b272a92e6acacc8cbc1424eef407c52c` |
| `QUICK.pinned` | 62,652 | `91d33086273443a796558987733f7f5c5812fba0c123fdb48c3a356aa7395f91` |

The independent re-derivation reproduced **57 removed lines / 4,400 bytes** — §8A.1's
figures exactly — and **all four sha256 values are identical to the rehearsal's.** Nothing
was copied across; they were rebuilt and then found to agree. That is the strongest
available evidence that the redaction committed at `cbdb535` and the content pinned during
the rehearsal are the same bytes.

### 8B.3 · Scope correction — the exhaustive scan found SEVEN carriers, not four

§8A.1 recorded each of the 51 usable literals in **exactly one** blob. Re-measured at
`4df8401` over **8,185 objects / 6,508 blobs** with `--batch-all-objects`, that is **no
longer true**: **7 distinct blobs** carried disclosed literals.

| Blob | Literals | What it is |
|---|---:|---|
| `101e019c` · `7c3513d3` · `7801a537` · `a4aed8a4` | 30 · 16 · 1 · 4 | the four committed leak blobs of §8A.1 |
| `9ddf0b04` | 11 | **unreachable** — a staged-but-never-committed intermediate of `RECON.md` |
| `a58e8494` · `efa0cc10` | 4 · 4 | **unreachable** — staged-but-never-committed intermediates of `quickstart.md` |

The three extra blobs were confirmed **reachable from no ref and present in no commit tree
of any ref or reflog** — dangling objects left by the commit wrapper's `git add .` over a
partially-redacted working tree. **They were never pushed**, because `git push` transfers
only objects reachable from the pushed ref, so they were never part of the public exposure.
They are recorded because a scan that stopped at §8A's four blobs would have reported them
as absent without ever having looked, and because they are exactly the residue an in-place
rewrite must also clear. **`filter-repo`'s reflog-expire and prune removed all three.**

### 8B.4 · The procedure that was run, with measured wall-clocks

Run **in place** in the live repository — not in a clone — because the tip was already
clean, the three dangling carriers only exist locally, and an in-place run is the only one
that clears them and leaves a correct checkout. `$W` is a scratch directory **outside** the
repository, mode `700`.

| Step | Command | Wall-clock |
|---|---|---:|
| 0 | preconditions + backup verification (§8B.1) | — |
| 1 | pre-image / `HEAD` blob extraction, hunk classification, pinned-file build | ~1 s |
| 2 | **pre-rewrite** residue baseline, all 6,508 blobs | **74.23 s** |
| 3 | `git filter-repo --force --blob-callback "$(cat "$W/blob-callback.py")"` | **12.54 s**, peak RSS **560 MB** |
| 4 | **post-rewrite** residue scan, all 6,230 blobs | **14.23 s** |
| 5 | tree / gitlink / identity / tag comparison | ~6 s |
| 6 | `git fsck` (full) | **5 s** |
| 7 | `bash scripts/pre-push-gates.sh` (8 gates) | **214 s** |
| 8 | negative control — deliberately wrong lease, **must be refused** | 210 s (gates re-run by the hook) |
| 9 | `git push --force-with-lease=refs/heads/main:4df8401… origin main:refs/heads/main` | **242 s** (204 s of it gate 6) |

**Total ≈ 13 minutes**, peak RSS **560 MB** — under **1 %** of this host's 62 GB, far
inside the §12.6 60 % cap. The rewrite itself cost **12.54 s against §8A's 391.23 s**: the
rehearsal paid for a `--no-local` clone of a 3.96 GiB pack, whereas `fast-export` here only
ever sees the **104 reachable commits**, and the 1.78 GB private packfile blob of §8A.6
hangs off an unreachable commit it never visits.

**The `--blob-callback` route was used, as §8A.9(4) recommends.** The callback is a
`{blob SHA → pinned filename}` map with a sha256 assertion per file and an abort on
mismatch. **It was verified to contain none of the 51 literals before it was run.** No
artifact of this procedure ever held the disclosed text.

### 8B.5 · Verification after the rewrite, before the push

- **Residue: 51 of 51 literals, 0 matches, in 0 blobs**, across all **6,230** blobs under
  `--batch-all-objects` — which sees unreachable and reflog-held objects, not only what the
  refs reach. Before the rewrite all 51 matched, in 7 blobs. The scan is the *same script*
  in both directions, so the before-run is its own positive control.
- **All seven leak-bearing blobs and all six affected commits are unresolvable locally.**
  `git cat-file -t` returns *"could not get object info"* for `63ac4df`, `d0b3c64`,
  `96b2988`, `ee3933d`, `cbdb535`, `4df8401`, `101e019c`, `7c3513d3`, `7801a537`,
  `a4aed8a4`, `9ddf0b04`, `a58e8494` and `efa0cc10`.
- **Tree at `HEAD`: 6,260 of 6,260 entries byte-identical. Zero changed.** 0 paths added, 0
  removed. This is *stronger* than §8A's "9 changed" and it is correct, not suspicious: the
  redaction was already committed at `cbdb535`, so the tip needed no change and only the
  four historical commits moved. That the change did land was verified separately — each
  rewritten historical blob is byte-identical to its pinned file, checked with `cmp`, all
  four.
- **Gitlinks: 13 of 13 unchanged at `HEAD`; 102 of 102 distinct `(path, sha)` pairs
  unchanged across all history.** `helix-deps.yaml` and `.gitmodules` keep their blob SHAs
  (`15dc191f`, `830bb3ac`). **No submodule, `.gitmodules` or `helix-deps.yaml` was touched.**
- **Identity: byte-identical for all 104 commits** — author name, author email, author date,
  committer name, committer email, committer date and subject, compared as a sorted stream.
  **98 of 104 commit SHAs unchanged.**
- **All 4 tags unchanged**, still pointing at their original objects — they predate `63ac4df`.
- **`git fsck` clean, rc=0, no output, 5 s. 0 unreachable, 0 dangling, reflog empty.**
  Object count 8,185 → **7,412**; pack 3.96 GiB → **493.21 MiB**, the difference being 180
  unreachable commits, 181 unreachable blobs and 243 unreachable trees that `filter-repo`
  pruned — **all of them preserved in the mirror backup**, which was not gc'd, pruned or
  touched.
- Umbrella working tree **clean**; the pre-existing uncommitted content inside the
  `milosvasic.ru` and `vasic.digital` submodule working trees was **preserved untouched**.

### 8B.6 · The push

`filter-repo` removed the `origin` remote, as §8 predicted; `github` and `upstream`
survived. **It did *not* convert remote-tracking refs into local branches this time** —
checked, per §8A.8: `refs/remotes/github/main` and `refs/remotes/upstream/main` stayed under
`refs/remotes/` and were merely rewritten. `origin` was re-added and the remote
configuration verified byte-identical to the pre-rewrite `git config` dump. **No `git fetch`
was run at any point after the rewrite.**

**Negative control first (§1.1 paired mutation), against the real remote:**

```
git push --force-with-lease=refs/heads/main:000…000 origin main:refs/heads/main
  ! [rejected]  main -> main (stale info)     rc=1
remote before: 4df8401…    remote after: 4df8401…   ← UNCHANGED
```

**Then the authorized push:**

```
git push --force-with-lease=refs/heads/main:4df8401c32b682e5e60693c02daca75799a52c66 \
         origin main:refs/heads/main
  + 4df8401...562ecf9  main -> main (forced update)
```

One explicit refspec. Never `--all`, never `--mirror`, never bare `--force`. **Confirmed
from `git ls-remote`, not from push output**, against each remote name independently — all
three return `562ecf9cca2d01beaf9ba8bde7474c465f0169ee` for `refs/heads/main`, the same
four tags at their original objects, and no other ref. Exactly **one** remote ref was
touched.

### 8B.7 · Commit map — six SHAs moved, and the mapping GitHub Support needs

`.git/filter-repo/first-changed-commits` holds one line, which is the value §8A.7's request
asks for:

> old `63ac4df32e5fd40806a50cd38fde8cdc39587c2c` → new `fc7574b27c7f9298b05bb55cc5a0ba024cb9da5f`

| Old | New | Subject |
|---|---|---|
| `63ac4df3` | `fc7574b2` | SpecKit 001 through plan phase… |
| `d0b3c649` | `7b4df26d` | SpecKit 001 through tasks… |
| `96b2988e` | `4ee9e8de` | gates: distinguish 'could not run' from 'failed'… |
| `ee3933d4` | `b0ab4b44` | gates: defer live-production specs… |
| `cbdb5351` | `25fe585e` | feat(platform): workshop curriculum platform… |
| `4df8401c` | `562ecf9c` | chore(audit): triage the 82 findings… |

Six, not §8A's four, because two commits landed after the rehearsal. **The first four
new SHAs are identical to the rehearsal's**, which independently confirms the pinned
content was reproduced byte-for-byte.

**Stale citations, fixed in a normal follow-up commit.** `filter-repo` rewrites old hashes
in commit *messages*, never inside blob content, so prose citations survive untouched and
dangling. The five §8A.5 named — `helix-deps.yaml` ×2, `scripts/verify-governance-cascade.sh`
×1, `scripts/verify-manifest-pins.sh` ×2 — were repointed at `fc7574b2` with the move
recorded rather than silently applied. Re-derivation found **more than the five**:
`docs/check-registry.md` ×3 (`d0b3c64`/`96b2988`/`ee3933d`), `CONTINUATION.md` ×4, and five
`cbdb535` citations in `.environment-assumptions-allow` ×2, `.hardcoded-paths-allow` ×1 and
`docs/environment-adaptability/AUDIT.md` ×2 — **17 in 8 tracked files**, all repointed.

**The historical SHAs in §2, §3, §8A and §9.6 of this document are deliberately NOT
rewritten.** §8.2 said they would become references to a discarded history and that the
document should say so rather than be edited to hide it. It is said here.

### 8B.8 · What this did NOT do — state this plainly and do not let it be forgotten

**The force-push removed nothing from GitHub.** §8A.6 demonstrated this rather than quoting
it: after a successful `--force-with-lease` on the stand-in remote, `63ac4df` still resolved
and all **98,599 bytes** of `101e019c` were still readable by SHA; only a server-side
`reflog expire` + `gc --prune=now` made them unresolvable. **That is exactly the situation on
github.com right now.** All four orphaned commits — `63ac4df32e5fd40806a50cd38fde8cdc39587c2c`,
`d0b3c6493a7f635a0a71d81f049069fb2741ea9c`, `96b2988ef61f4adee1bba51ee1c42efcb5f4408e`,
`ee3933d46211d6001ffc23acab480e0cffdc99c6` — and every byte of the four leak blobs
**remain fetchable by SHA** from the public repository by anyone who recorded one, and the
timing of GitHub's garbage collection is **not the repository owner's to control**.

Three things this rewrite therefore does not achieve, and one it never could:

1. **Only a GitHub Support purge removes the data from their storage.** The request text is
   prepared at §8A.7 and the first-changed-commit value it needs is in §8B.7. **It has not
   been sent. It is the operator's to send and no agent may send it.**
2. **Telling the third party remains the substantive remedy** (§8A.10 step 1), and it is
   likewise the operator's. No git operation can undo the disclosure of a name.
3. **Forks, mirrors, existing clones, and search-engine and archive caches are unreachable
   by any of this.** Measured 2026-09-01: 0 forks, 0 pull requests, 0 recorded page views —
   but clone traffic for the exposure window still had not appeared in GitHub's API, so
   **whether anyone cloned during it remains UNVERIFIED.** Re-run
   `gh api repos/milos85vasic/vasic/traffic/clones` on or after 2026-09-02.
4. **Nothing can be rotated.** No credential was disclosed. Personal data cannot be
   reissued or revoked, which is why the purge and the conversation matter more than the
   rewrite did.

**Anyone holding a clone must rebase, not merge.** Merging an old branch back would
reintroduce the deleted content into `main`.

**Do not record this incident as closed. The rewrite is the cheapest and least important
of the three steps §8A.10 recommends, and it is the only one that has been done.**

---

## 9 · Second wave — the `ai_interviewing` / `workshop` matches (2026-09-01, later the same day)

§6 flagged "340 out-of-scope matches" from `design-toolkit/` and `ai_interviewing/` as *"a
separate incident that has not been assessed, decided, or fixed."* **This section is that
assessment.** It was carried out against a re-derived fleet, not against §6's figures, and
it **contradicts §6 on two points** — recorded rather than quietly corrected, because §6's
numbers were evidence at the time and the tree has moved since.

### 9.1 · The fleet changed under the instrument, so §6's split no longer holds

Two changes invalidate the §6 attribution:

1. **`design-toolkit` is now PUBLIC.** Measured this run:
   `gh repo view vasic-digital/design-toolkit` → `private=false`, and the gate's own fleet
   derivation classifies it `public  provider:private=false,push=true`. It is therefore no
   longer a private *source* at all. **Content sourced from it is not a disclosure and must
   not be redacted.** Every `design-toolkit`-attributed match in §6 has ceased to exist as a
   finding — not because anything was fixed, but because the boundary moved.
2. **`.gitmodules` grew from 9 gitlinks to 13.** `submodules/LLMProvider`, `submodules/RAG`,
   `submodules/verdict` and `submodules/passage` were added by other work in flight. All four
   are **public**, so they joined the scan targets, not the private corpus.

Re-measured split by private source (`verify-content-boundary.sh`, this tree, 2026-09-01):

| Private source | §6 / brief figure | **Re-measured** |
|---|---:|---:|
| `ai_interviewing` (private=true, verified) | 37 | **216** |
| `workshop` (private=true, verified) | 34 | **16** |
| `monetization` (private=true, verified) | 1 | **0** |
| `design-toolkit` | 1 | **n/a — repository is PUBLIC; not a private source** |
| **Total** | 232 | **232** |

The total agrees; the attribution does not. Any per-repository figure quoted from §6 or from
the brief that prompted this work is **withdrawn**.

### 9.2 · Disposition — three classes, judged individually, not bulk-redacted

**Class R — REAL DISCLOSURE. 29 matches. Redacted (§9.3).** Verbatim private code and
verbatim private prose.

**Class N1 — NOT A DISCLOSURE: shared authorship boilerplate. 22 matches. Left in place.**
Private source `ai_interviewing/platform/qa/challenges/api-challenges.sh`; public side
`scripts/lumen-reindex.sh:63,65`, `scripts/lumen-index-doctor.sh:54,56`,
`scripts/ollama-vulkan-remediation.sh:67`. The matched run is `set -uo pipefail` followed by
the operator's standard `usage()` comment about printing a script's own header block so
`--help` cannot drift out of sync with it. It is a house style the same author writes into
every script he owns, on both sides of the boundary. It describes the **public** script's own
behaviour and discloses nothing whatsoever about the private repository's content. Redacting
it would delete a correct explanatory comment from three working public scripts to conceal
the fact that their author writes comments the same way twice.

**Class N2 — NOT A DISCLOSURE: the public file is the ORIGINAL. 181 matches. Left in place.**
Private sources are `ai_interviewing/docs/project-deep-dives/*.md` and their `.pdf` renders;
public sides are the live website product pages `_content/products/*.md`, the
`_analysis/content-briefs/*`, `_analysis/IMPLEMENTATION-REPORT.md`, `_analysis/top20/*`,
`vasic.digital/_article_src/en/helixtrack-core.md` and its rendered `.html`,
`submodules/containers/docs/test-coverage.{md,html}`,
`submodules/LLMProvider/pkg/discovery/discovery.go`, and the OCR text captured from
screenshots of those same public pages under `_tests/evidence/**`.

**The copy direction is measured, not assumed, and it runs public → private.** First-commit
dates:

| Public side | Added | Private "source" | Added |
|---|---|---|---|
| `_content/products/{HelixConstitution,HelixQA,HelixTrack,HelixTranslate,task_bridge,Qemu-Utils,HelixLLM}.md` | **2026-08-07** | `docs/project-deep-dives/{01,02,03,11,27,31,17}-*.md` | 2026-08-12 … 08-13 |
| `_analysis/content-briefs/{HelixConstitution,HelixTerminator}.md` | **2026-08-07** | `docs/project-deep-dives/{01,12}-*.md` | 2026-08-12 |
| `_analysis/IMPLEMENTATION-REPORT.md`, `_analysis/top20/ATMOSphere-*.readme.txt` | **2026-06-25** | `docs/project-deep-dives/{16,37}-*.md` | 2026-08-13 … 08-14 |

Every public target predates its private counterpart — by five days in the product-page
group and by seven weeks in the `_analysis/` group. The private `ai_interviewing`
deep-dives are **interview-preparation notes that reuse the operator's own already-published
marketing and product copy.** The matched text is that copy: product taglines, feature
descriptions, and public `github.com` URLs.

Redacting these would mean deleting the operator's **live public website content** in order
to hide text that was public first and that the private repository copied *from* it. That is
the over-redaction failure the gate's own header warns about — 24,963 naive hits whose top
thirty were all legitimate. **No action taken, and none should be.**

The `_tests/evidence/**/*.ocr.txt` files deserve one extra sentence: they are OCR output from
screenshots of the already-published pages. They cannot disclose anything the rendered public
page does not already show.

### 9.3 · What was changed in this wave (containment)

Working tree only. **Nothing was committed, pushed, tagged, or rewritten.**

| File | Line(s) | Was | Now |
|---|---|---|---|
| `docs/workshop-curriculum/RECON.md` | `421–425` | A fenced ```sql block reproducing the **verbatim query text** of `store.Search` from private `ai_interviewing/platform/backend/internal/store/store.go` | Path-only pointer to the private file plus a **functional description** — three content tables `UNION ALL`ed, bound `LIKE` patterns over a few short columns, fixed-length excerpt, bound row limit. The finding (naive multi-way `LIKE`, no ranking, no FTS, no semantics, titles only) is stated in full immediately after, unchanged. |
| `docs/workshop-curriculum/RECON.md` | `474–479` | The **verbatim header comment** of private `ai_interviewing/scripts/render-diagrams.sh`, including the quoted phrase about the validator-safe embed | Path-only pointer plus the reasoning **restated independently**: the §11.4.168 export check counts embedded raster images, so a vector-only diagram scores zero on it; raster is load-bearing, vector supplementary. |
| `docs/workshop-curriculum/RECON.md` | `503–505` | An explicit quotation, in quotation marks, of the anti-bluff rule in the header of private `ai_interviewing/platform/qa/helixqa/run-suite.sh` | Path-only pointer plus the rule **restated in different words**: a bank counts as passing only if it terminated successfully *and* left evidence, so neither a skip nor an assertion-free run scores as a pass. |
| `specs/001-workshop-curriculum-platform/quickstart.md` | `315–317` | Two runs of **verbatim prose** from the private `workshop` submodule's governance carriers (`AGENTS.md:89–93` and its three siblings) describing `scripts/self-test.sh` | Path-only pointer plus an independent description: throwaway input, round-trip bit-for-bit check, then deliberate damage to one part with a required rejection. The §1.1 paired-mutation argument — that the green round trip is not evidence on its own — is preserved in full. |

**On the `workshop` carriers specifically.** §11.4.157 propagates governance carriers verbatim
**between carriers**, and a carrier sentence appearing in two carriers is not a leak. That
exemption does **not** reach this case: the destination here is `quickstart.md`, a public spec
document, not a carrier, and the copied text is the workshop project's own
project-specific prose, not inherited constitution text. The already-public filter confirms
it independently — the run does not appear in any second public repository, so it was never
exonerated. It is private prose in a public file, and it was redacted as such.

### 9.4 · Personal data — swept again, and this wave found one more

**No real name is written anywhere in this document, and none was written into any file
changed by this wave.**

- **The third party's surname: 0 occurrences in any tracked file**, in any form. Probed
  directly (surname alone), reversed (`Surname Firstname`) and comma-reversed
  (`Surname, Firstname`) against a concatenation of every tracked text file in the umbrella.
  All three probes returned zero. §7's result holds.
- **A general sweep found no other person.** Every capitalised bigram in the private prose
  corpus — all three private repositories' Markdown and text plus the notes PDF, 42,886 lines
  — was intersected with the tracked public corpus. **68 bigrams overlap and every one of them
  is a product, brand, or technology name** (cross-platform toolkits, protocol names, container tooling and model-hub
  vendors — deliberately described rather than quoted, see the note below). No person's name is among them. A Cyrillic
  name sweep returned nothing.
- **One new finding, now fixed.** `specs/001-workshop-curriculum-platform/research/llm-bridging.md:510`
  used the third party's **first name** as a named speaker in a constructed example question
  for the "misattributed speaker" test class. This is **not** the accepted filename baseline
  of §2 — it is the name used as a person in prose, which attributes participation in a
  private session to an identifiable individual. Replaced with the role reference
  *"the second speaker"*. The test class and its FR-005 link are unaffected. The file now
  contains **0** occurrences.
- **One occurrence left in place, and flagged for the operator rather than decided by an
  agent.** `specs/001-workshop-curriculum-platform/contracts/http-api.md:288` carries the
  first name inside a JSON example chapter `"title"`. It is the recording artifact's own name,
  so it falls inside the §2 baseline — but it is worth the operator's attention because it is
  the one place where that name would be **served by the API and rendered on a page**, rather
  than merely naming a file. §2 already records that renaming the artifact in the private
  submodule is the fix and that it is his call, not an agent's. That remains true here.

### 9.5 · Identified, deliberately NOT redacted, and recorded as a judgement call

`docs/workshop-curriculum/RECON.md` §2.3 also carries an **API route table** (the endpoint
list of the private reference implementation) and a **SQLite table-and-index listing**. Both
are derived from private code, and **neither is a gate match** — they are not prose-shaped, and
the gate's header declares this limit openly: *"Private code copied into a public repository is
outside this instrument and is not claimed to be covered."*

They were left in place because they are the structural **shape** the specification is built
from, and RECON.md's §2 exists to specify the workshop platform by reference to that
implementation. Removing them would destroy the finding rather than redact it. This is a
judgement call, it is a weaker one than the four redactions above, and it is written down so
the operator can overrule it cheaply — deleting the route table and the schema listing costs
the document less than deleting the SQL did.

### 9.6 · This wave is containment too, exactly like the first

Everything §3 says applies unchanged. **The second-wave content is in the same four public
commits and in every commit since.** `docs/workshop-curriculum/RECON.md` and
`specs/001-workshop-curriculum-platform/quickstart.md` were both introduced in `63ac4df` on a
public remote; `research/llm-bridging.md` likewise. Redacting the working tree does not remove
any of it, and **§8's remediation plan is unchanged, still PREPARED, still NOT EXECUTED, and
still NOT AUTHORIZED.** A history rewrite plus force-push requires explicit per-session
operator authorization under §11.4.113 and has not been given.

---

## 10 · Third wave — the `name` class, swept for the first time (2026-09-01, later still)

**Result up front: 125 name-class rows, 20 distinct names by digest, and NOT ONE of them is a
person. Zero redactions. Nothing was changed in any public file.** The reasoning is below, and
it is the reasoning that matters here — the gate is working correctly and its output is
correctly red; what it found in this class is not a disclosure.

### 10.1 · Why this class had never been swept

`scripts/verify-content-boundary.sh` gained a **name-class detector today**, after waves 1 and
2 had already run. Neither earlier pass could have seen this class: it did not exist. §9.4's
personal-data sweep was a hand-built probe over capitalised bigrams; this is the same idea
promoted into the gate, run every time, with the fleet derived rather than assumed. **A class
that was previously unswept is not the same as a class that was previously clean**, so it was
treated as unswept and triaged from zero rather than compared against §9.4's conclusion.

### 10.2 · How the detector builds a candidate, and where its false positives come from

It writes no name down anywhere. Candidates are DERIVED each run by two independent routes:

- **Route (a) — git identities of the private repositories.** These are person names *by
  construction*; no heuristic is involved. Identities that are also git identities of a PUBLIC
  repository are subtracted in both orders, which is how the repository owner's own name is
  excluded without a list.
- **Route (b) — runs of 2–3 consecutively capitalised tokens in private prose, keeping only
  those whose every token is rare in lowercase** across the corpus (rank ≤ `--name-rank` 2000
  **and** count ≥ `--name-mincount` 5 makes a token "ordinary").

**Route (a) contributed ZERO of the 125 surviving rows** — verified by inspecting the
private-source column of every row: not one is the gate's own `<git identity>` marker; all 125
carry an ordinary private FILE path. Every finding in this wave therefore came from route (b),
which the gate's own header already identifies as the heuristic half.

### 10.3 · Method — how each of the 125 was identified without disclosing anything

The gate withholds the matched text by design and prints `personal name #<digest>` plus the
public `file:line`. That discipline was preserved: **no name, and no matched token run, is
written into this document.**

Identification was done locally instead. The digest is a small polynomial hash of the
lowercase key, computed in the gate at the line beginning `awk -F'\t' ... h($5)`. Re-implementing
that hash and the emitter's N-run construction (2–3 consecutively capitalised tokens, folding
every non-alphanumeric to a separator, accumulating across line breaks) makes each digest
resolvable against the public line it was reported at. Re-derive it the same way:

```bash
bash scripts/verify-content-boundary.sh > /tmp/gate.txt 2>&1   # exit 1 expected
# then, for a row reported as  <pubfile>:<line>  #<digest>:
#   read that public line and rebuild its capitalised 2/3-token runs,
#   hashing each with the gate's own h() to find which run the digest names.
```

**Result: 125 of 125 rows resolved at their exact reported `file:line`, and the 20 digests map
to 20 distinct keys with no hash collision** (checked: no digest resolves to more than one
key). Nothing was left as "could not determine".

### 10.4 · Disposition — 125 FALSE POSITIVES, 0 real names, 0 redactions

All 20 digests resolve to a **product, brand, technology, jurisdiction adjective, protocol
header, web-performance metric, repository name, or a generic document heading**. Described
without quoting them, so this document stays inert:

| Rows | What the digest actually names | Where |
|---:|---|---|
| 20 | a machine-learning model-hub **brand** (2 tokens) | `specs/…/research/transcription.md` ×5 lines |
| 17 | two **LLM-vendor brands** printed adjacently in a provider enumeration | `_content*/sites/vasic-digital.md` ×16, `_tools/translate/glossary.json` |
| 16 | two **jurisdiction/language adjectives** naming Linux distribution families | `_content*/products/Mail-Server-Factory.md` ×16 |
| 16 | the same, as a 3-token run | same 16 files |
| 16 | two more of the same adjectives | same 16 files |
| 16 | two of the operator's **own GitHub repository names**, backtick-quoted in a scaffold list | `_content*/products/Vasic-Digital-Reusable-Module-Suite.md` ×16 |
| 6 | three **vector-database product names** in a slash/comma list (2- and 3-token forms) | `submodules/RAG/README.md:351,426` |
| 5 | a generic **document-type heading** | `design-toolkit/knowledge/platforms/*.md:1` ×5 |
| 3 | a **Web-Vitals metric** name (2- and 3-token forms) | `_analysis/research-best-practices.md:78` |
| 2 | a generic **section heading** | `_analysis/top20/HelixAgent.readme.txt`, `.specify/extensions/superspec/SKILL.md` |
| 2 | a **JavaScript standard-library API** name, inside a minified bundle | `_tests/evidence/final-audit-v1.6.0/cross/lh-*.html` |
| 2 | an **HTTP response-header** name | `docs/workshop-curriculum/RECON.md:532` |
| 1 | a **front-end framework** name preceded by its layer label | `docs/workshop-curriculum/RECON.md:396` |
| 1 | this repository's **own submodule name** | `helix-deps.yaml:365` |
| 2 | that same submodule name plus a **placeholder word**, bridged across a blank line and a fence | `docs/workshop-curriculum/RECON.md:211` |

**No file was edited. No name was redacted, because no name was found.** Redacting any of
these would delete correct technical prose — product comparisons, a distribution matrix, a
provider list, a vector-store enumeration — to conceal words that are not personal data.
That is the over-redaction failure §9.2 already warned about, and the standing instruction to
fix what is found does not license fixing what is not broken.

### 10.5 · The two highest-exposure groups, called out individually

**The 8 rows sourced from the private `workshop` submodule — the most sensitive class in this
tree — are all false positives, and one of them is not even about the workshop.**

| Rows | Public destination | What it is |
|---:|---|---|
| 5 | `specs/…/research/transcription.md` | the model-hub brand of §10.4 row 1. The private-side source path happens to be a `workshop/chapters/01/…` file, but the MATCHED TEXT is a vendor name in a table of model provenances. |
| 1 | `helix-deps.yaml:365` | the submodule's own name, in this repository's dependency manifest. It is the manifest naming its own dependency. |
| 2 | `docs/workshop-curriculum/RECON.md:211` | RECON.md quotes the workshop README's **entire current content** inside a fenced block — a title line and a placeholder word. §10.6 explains why the detector joined tokens across the blank line between them. |

No curriculum text, no recording material, and no participant is involved in any of the eight.

**The 6 rows in the PUBLIC, separately-published `submodules/RAG/README.md` are all false
positives.** Both cited lines (`351`, `426`) enumerate three vector-database products the
module's hybrid retriever can sit on, written as a slash-separated adapter list and as a
comma-separated backend list. The token folding turns `A/B/C` and `A, B, C` into adjacent
capitalised runs, which is exactly the shape a name has. **`submodules/RAG/README.md` was NOT
modified** — no edit, no commit, no gitlink bump. Nothing needs to be published for this repo.

### 10.6 · Suggested detector tightening — measured, not guessed; the gate was NOT edited

`scripts/verify-content-boundary.sh` is another agent's file and **was not touched.** These are
proposals with their measured yield against this run's own 125 rows. Each would need a paired
mutation under §1.1 proving a seeded real name still survives it, before adoption.

1. **A hard-separator break in the N pass — the highest-yield and the cheapest in recall.**
   The emitter folds *every* non-alphanumeric to a separator, which is right for the prose class
   (it defeats re-wrapping) but wrong for names: it fuses unrelated proper nouns listed with
   `/`, `,`, `|`, `;`, backticks or brackets into a single "name". Recording a hard-break flag at
   those positions and requiring no hard break *between* the tokens of an N run would drop
   **82 of the 125 rows (66%)**, clearing 7 digests outright. A given name and a surname are not
   separated by a slash, a pipe, a semicolon, a backtick or a bracket, so recall cost is nil for
   those. **The comma is the one to think about**: it alone accounts for 15 of the 82, and
   `Surname, Firstname` is a real name form — but the detector already matches both orders, so
   treating the comma as hard would lose that form unless it is excepted for the 2-token
   reversed case. Excluding the comma entirely still yields **67 rows**.
2. **No bridging across a blank line, in the N pass only.** A name never spans a paragraph
   break. Worth **3 rows**, including 2 of the 8 workshop-sourced ones, at zero recall cost.
3. **`--name-rank 2000` is too small for this corpus, and an absolute rank is not scale-free.**
   Measured over the private prose corpus (941,648 tokens, tracked `*.md`/`*.txt` in the three
   private repositories): the tokens that made these keys look "rare" sit at ranks 2072–12227 —
   e.g. one occurs 65 times at rank 2072, another 58 times at rank 2286, another 62 times at
   rank 2164. Words occurring dozens of times are not rare; they merely fall past an absolute
   cutoff. A **count floor** ("any token occurring ≥ N times in the corpus is ordinary",
   independent of rank) is scale-free where a rank cutoff is not: at N = 20 it would clear
   **13 of the 20 digests**. Combined with proposal 1 it leaves **6 rows** of the 125. This is
   the proposal with a real recall tradeoff — a surname that is also a common word would be
   demoted — so it is the one that most needs its mutation before it ships.
4. *Not recommended without more evidence*: treating an intra-word hyphen as a hard break would
   clear 7 further rows but would break double-barrelled given names, which is a recall loss in
   exactly the class the detector exists for.

### 10.7 · Copy direction was still verified, because it is load-bearing for 85 of the rows

Even though the name class produced no disclosure, the copy direction was measured rather than
assumed for the `_content*` / `_analysis` / glossary cluster — **85 of the 125 rows** — because
if any row there HAD been real, redacting it would have deleted live public website content.
First-commit dates, this repository vs `ai_interviewing`:

| Public side (this repo) | Added | Private counterpart | Added |
|---|---|---|---|
| `_content/products/Mail-Server-Factory.md` | **2026-08-07** | `docs/project-deep-dives/29-mail-server-factory.md` | 2026-08-13 |
| `_content/products/Vasic-Digital-Reusable-Module-Suite.md` | **2026-08-07** | `docs/project-deep-dives/28-reusable-module-suite.md` | 2026-08-13 |
| `_content/sites/vasic-digital.md`, `_analysis/content-briefs/*` | **2026-08-07** | `docs/project-deep-dives/20-llmsverifier.md` | 2026-08-12 |
| `_analysis/research-best-practices.md` | **2026-06-25** | `docs/project-deep-dives/*` (whole tree) | 2026-08-12 … 08-14 |

**The public files predate their private counterparts by five days to seven weeks, so the
public file is the ORIGINAL** and §9.2's Class N2 finding holds unchanged for the name class
too. These rows are doubly not-a-disclosure: the matched text is not a name, *and* the flow
runs public → private.

### 10.8 · This wave changed nothing, so there is nothing new to contain — but §3 still stands

No public file was edited in this wave, so it adds no containment and removes no exposure.
**That does not make the incident smaller.** Everything §3 and §9.6 record is unchanged: the
wave-1 and wave-2 material **is still in the public commits and in every commit since**, and
working-tree redaction never removed it. **§8's remediation plan is untouched by this wave —
still PREPARED, still NOT EXECUTED, still NOT AUTHORIZED.** A history rewrite plus force-push
is destructive, requires explicit per-session operator authorization under §11.4.113, and that
authorization has not been given.

### 10.9 · One thing the operator should know about THIS file

`docs/content-boundary-incident-2026-09-01.md` is **untracked**, so `git ls-files` does not see
it and the gate never scans it. That is why this wave's edits cannot move the gate's count, and
it is what makes the before/after below a clean A/B. It has a consequence: **§9.4 wrote one of
this wave's false-positive brand pairs into this document in plain text.** If this file is ever
committed — and the `commit` wrapper runs `git add .`, which would stage it — that line will
start producing a name-class row of its own. §10.4 above is written descriptively for exactly
this reason. Either leave the file untracked, or reword that §9.4 line before committing it.

---

## Gate results

Recorded at the end, not the top, so that they are read as evidence and not as a verdict on
the incident. **The incident is not closed. History still carries the content.**

Measured 2026-09-01, working tree, nothing committed.

| Gate | Exit | Result |
|---|---|---|
| `scripts/verify-content-boundary.sh` (wave 1, before) | **1** | LEAK — 377 surviving matches, 0 undetermined |
| `scripts/verify-content-boundary.sh` (wave 1, after) | **1** | LEAK — 232 surviving matches, 0 undetermined |
| `scripts/verify-content-boundary.sh` (**wave 2, before**) | **1** | LEAK — **232** surviving matches, 0 undetermined. Split: `ai_interviewing` 216, `workshop` 16, `monetization` 0, `design-toolkit` n/a (now public). |
| `scripts/verify-content-boundary.sh` (**wave 2, after**) | **1** | LEAK — **203** surviving matches, 0 undetermined. Split: `ai_interviewing` 203, `workshop` **0**. |
| `scripts/verify-content-boundary.sh` (**wave 3, before**) | **1** | LEAK — **367** surviving matches (prose **207**, short **35**, name **125**), 0 undetermined. Split by private source: `ai_interviewing` 117, `workshop` 8 *in the name class*. |
| `scripts/verify-content-boundary.sh` (**wave 3, after**) | **1** | LEAK — **367** surviving matches (prose **207**, short **35**, name **125**), 0 undetermined. **Identical, by design: this wave redacted nothing because it found nothing to redact.** |

### Wave 3 is a null A/B, and that is the correct outcome

The before and after runs are byte-identical in every class. **This is not a failed wave; it is
a swept class with no disclosure in it.** All 125 name-class rows were resolved to their exact
`file:line`, all 20 digests classified, and all 20 are products, brands, technologies,
adjectives, headings or repository names — §10.4. Redacting any of them would have removed
correct technical prose from live public pages to hide words that are not personal data.

**`.content-boundary-allow` was not touched, and no entry was added.** The gate exits 1 and
should: the 242 prose/short rows are the Class N1/N2 judgements of §9.2, still visible on
purpose, and the 125 name rows are visible for the same reason. A reader who disagrees with a
disposition can re-derive it from §10.3 and overrule it.

**On the prose/short totals: 242 here against the 203 recorded at wave-2-after is NOT a
regression this wave caused, and it is not claimed to be a clean comparison either.** Other
agents were active in this tree between the two measurements — `git status` at the start of
wave 3 showed 30+ modified tracked files, including governance carriers and several
`scripts/*.sh` — and the private-side corpus and the gate's derived exoneration sets move with
them, exactly as §"Read the content-boundary numbers carefully" describes for 377 → 232. **The
difference was not attributed, because attributing it would require re-deriving the wave-2
split, and that was not done.** Do not read it as a number this wave is responsible for.

### Wave 2 is a clean A/B, and the −29 is fully attributable

Unlike the 377 → 232 comparison, nothing about the instrument's input changed between the
wave-2 before and after runs: same fleet (13 gitlinks, 3 private), same derived exonerations
(897 path-mask shingles, 786 already-public shingles, 9 declared pairs, 4,043 pardoned),
same 105 not-indexed files, 0 undetermined on both sides. **232 − 203 = 29, and all 29 are
the Class R redactions of §9.3**, confirmed per file:

| Public file | Before | After |
|---|---:|---:|
| `docs/workshop-curriculum/RECON.md` | 13 | **0** |
| `specs/001-workshop-curriculum-platform/quickstart.md` | 16 | **0** |

`workshop` as a private source went **16 → 0**. No other file's count moved.

### The 203 that remain are deliberate, and exempting them would be the bluff

**`.content-boundary-allow` was not touched, and no entry was added to force a green run.**
The gate exits **1**, correctly, and the 203 surviving matches are the Class N1 (22) and
Class N2 (181) rows of §9.2 — the operator's own `usage()` boilerplate, and his own
public-first product copy that the private interview-prep notes reproduce. They are
**judged not to be disclosures, not suppressed**, so they still appear in every run, by
design. A reader who disagrees with the judgement can see the evidence and overrule it.

**A red gate with a true reason beats a green gate with a false one.** Chasing rc=0 here
would require either deleting live public website content or writing allow-list entries that
assert a boundary flow which does not exist. Both are worse than the red.
| `scripts/verify-check-registry.sh` | **0** | 23 PASS / 0 FAIL / 5 DEBT / 0 UNDET. **R5 passes** — `verify-content-boundary.sh` is now registered. The 5 DEBT rows are declared, not fixed, and print by design. |
| `scripts/audit-hardcoded-paths.sh` | **0** | no machine-specific hardcoded paths (6 files explicitly allowed) |

### Read the content-boundary numbers carefully — 377 → 232 is not a clean A/B

**The instrument's input changed between the two runs, so the totals are not
comparable and must not be reported as a 145-match improvement.** Another agent was
concurrently building `workshop/platform/**` — a Go backend and an Angular frontend —
inside the **private** `workshop` submodule, and governance carriers changed under
`submodules/constitution/submodules/design-toolkit/`. Both feed the private-side corpus
the gate indexes, and its *derived* exoneration sets moved accordingly: `already-public`
793 → 786 shingles, `declared exemptions` 5,055 → 4,043 matches pardoned. That is why
files this work never touched — `_analysis/design-research/INCORPORATION-PLAN.md` (55 → 0),
`CATALOG.md` (19 → 0), `docs/constitution-adoption/INVENTORY.md` (12 → 0) and others,
116 matches in total — changed count on their own.

**The attributable figures are per-source, and they are unambiguous:**

- Matches whose private source is the notes PDF: **29 → 0.** Every one is gone.
- `docs/workshop-curriculum/RECON.md`: **42 → 13**, a drop of **exactly 29**. The
  residual 13 are `ai_interviewing`-sourced (`:423`, `:475`, `:477`, `:504`) and belong
  to the separate, out-of-scope incident in §6.
- `specs/…/research/transcription.md`: **0 both times** — the gate never saw this file's
  leak, which is F2.

**The gate still exits 1, and that is correct.** 232 real matches remain, from
`design-toolkit/` and `ai_interviewing/`. **Nobody should exempt them to get a green
run.** `.content-boundary-allow` says so itself: those rows are *"left visible so a human
decides rather than a glob."*

The stronger evidence for this work's own completeness is §7's independent sweep at a
**six**-word window — stricter than the gate — which found **zero** prose overlap
remaining in either redacted file.

---

**Do not close this incident on the strength of the two exit-0 gates above.** They say
the registry is consistent and no hardcoded paths were introduced. They say nothing about
the disclosure, which is still live in `63ac4df` on a public remote.


> **Self-reference guard.** This document deliberately DESCRIBES the false-positive
> classes rather than quoting them. Writing a capitalised two-token pair here in plain
> text would make this file its own name-class source the moment it is tracked — and the
> project commit wrapper runs `git add .`. Re-derive examples from the gate, never from here.
