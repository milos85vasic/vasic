# Merge-settings change, 2026-11-24 (Roadmap-Item: VSC-417)

Per `docs/governance/OPERATOR-DECISION-PR-DELIVERY-2026-11-24.md`: squash and rebase merges disabled, merge commits only,
on the project's own repositories. Each `<owner>__<repo>.before.json` / `.after.json` is the GitHub API repository
settings subset (no secrets) read before and after
`gh api -X PATCH repos/OWNER/REPO -F allow_squash_merge=false -F allow_rebase_merge=false -F allow_merge_commit=true`.

Scope: the 5 `milos85vasic` repos (vasic, milosvasic.ru, ai_interviewing, monetization, workshop_curriculum) and the
`vasic-digital` repos this project consumes or owns (challenges, containers, curriculum-kit, design-toolkit, DocProcessor,
helix_qa, job_seeker, career_private, LLMOrchestrator, LLMProvider, LLMsVerifier, passage, RAG, security,
vasic-digital.github.io, verdict, VisionEngine). Not touched: third-party `WangX0111/superspec`, `HelixDevelopment/*`,
and the other repositories of the `vasic-digital` organisation that are not part of this project's fleet.
The first VisionEngine PATCH failed with a transient `unexpected EOF` (state re-read: unchanged) and was retried once.
