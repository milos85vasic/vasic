## specs/008/tasks.md Phase 1 T006 Lint Contradiction Audit

### Findings

1. **`workshop/platform/frontend/` has NO ESLint configuration:**
   - No `.eslintrc*` or `eslint.config.*` files at root
   - `package.json` declares 11 scripts, **none is `lint`**
   - `devDependencies` contain **no** package matching `lint` or `prettier`

2. **`ai_interviewing/platform/frontend/` also has NO ESLint configuration:**
   - No `.eslintrc*` or `eslint.config.*` files at root
   - `package.json` declares 5 scripts, **none is `lint`**
   - No lint-related devDependencies
   - Same Angular CLI structure, same absence of linting tooling

3. **Go `gofmt` status:**
   - `gofmt -l workshop/platform/backend` currently reports **no unformatted files**
   - All Go files in `workshop/platform/backend/` are formatted
   - The original 2026-09-03 report of 3 unformatted files (`cmd/knowledge-registry-backfill/main.go`, `internal/api/publication.go`, `internal/api/passages_publication_test.go`) may have been fixed since then

4. **Task T006 self-contradiction (from the task note):**
   - Task says: "Configure linting/formatting to match the reference module (`gofmt`, Angular ESLint config)"
   - "Match the reference" and "Angular ESLint config" point in opposite directions
   - The reference module (`ai_interviewing/platform/frontend`) has no ESLint config either
   - Neither half can be satisfied as written without operator decisions

### Recommendation

**Option (a): Adopt ESLint + Prettier and diverge from the reference**

This is the recommended resolution because:

1. **The gofmt half is unblocked regardless** — all Go files are already formatted, so `gofmt` work is complete
2. **Adding ESLint + Prettier provides actual tooling** that was absent before, improving code quality even if the reference doesn't use it
3. **The reference's lack of ESLint is not a reason to deprive this project of linting** — the reference also lacks many features this project has
4. **Consistent tooling across the platform** (both frontend and backend having formatter/linter) is valuable for developer experience
5. **The task's intent** ("Configure linting/formatting") is fully achieved; the "match the reference" clause is the problematic part, not the linting itself

The task note itself acknowledges: "either is defensible, neither is this note's to choose" — confirming this requires operator authority, which is the correct governance per §11.4.6.

### gofmt Status

The `gofmt` half of T006 is **unblocked and complete**. All Go files in `workshop/platform/backend/` pass `gofmt` check with no output. The contradiction and blocker concern only the ESLint/Prettier portion for the Angular frontend.