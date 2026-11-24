# Upstream sync audit, 2026-11-24

Operator directive: after PRs merge, main must be fully pushed to ALL declared upstreams.
Method: `git remote` plus every pushurl of every remote, and the `upstreams/*.sh` recipes;
read-only `git ls-remote <url> refs/heads/main` per URL; ancestry via `git merge-base --is-ancestor`;
pushes were plain fast-forwards by SHA (`git push <url> <sha>:refs/heads/main`), nothing forced.
Heads are 9-char SHAs read 2026-11-24 (live values move; re-run to re-measure).

## Pushes performed (all fast-forward, ancestry verified first)

| repo | upstream | range |
|---|---|---|
| monetization | gitlab.com/milos85vasic/monetization | 05227b0..0634f36 |
| monetization | gitflic.ru/milosvasic/monetization | 6f04c72..0634f36 |
| monetization | gitverse.ru/milosvasic/monetization | 6f04c72..0634f36 |
| submodules/containers | gitlab.com/vasic-digital/containers | 5ea870a..eb70e05 |
| submodules/qa (HelixQA) | gitlab.com/vasic-digital/HelixQA | b16a089..dc25b8a |
| submodules/qa (HelixQA) | github.com/HelixDevelopment/helixqa (= qa) | b16a089..dc25b8a |
| submodules/challenges | gitlab.com/vasic-digital/challenges | d94e554..04d5c31 |

## After-state table

| repo | upstream | head | status |
|---|---|---|---|
| umbrella vasic | github milos85vasic/vasic (github/origin/upstream remotes, one URL) | 6075448 at audit time (github/main); advances with this PR | CURRENT (single upstream; it is GitHub itself) |
| submodules/constitution | 8 distinct upstreams (codeberg, gitflic, github HelixDevelopment, github vasic-digital, gitlab helixdevelopment1, gitlab vasic-digital, gitverse, m3w) | 6d93ccd19 | CURRENT (all) |
| milosvasic.ru | github milos85vasic | 74c554c9b | CURRENT (single upstream; no push made, production untouched) |
| vasic.digital | github vasic-digital.github.io | 006b834ed | CURRENT |
| design-toolkit | github, gitlab | 1b9abac8c | CURRENT |
| ai_interviewing | github vasic-digital, github milos85vasic | d508b8e16 | CURRENT |
| monetization | github vasic-digital, github milos85vasic, gitlab, gitflic, gitverse | 0634f36fc | CURRENT after push |
| workshop | github vasic-digital, github milos85vasic | 5a7acdd1f | CURRENT (gate not triggered; no push needed) |
| submodules/containers | github (2 URLs: containers, Containers), gitlab (2 URLs) | eb70e0543 | CURRENT after push |
| submodules/LLMProvider = llm_provider | github vasic-digital, gitlab, github HelixDevelopment | 53e4b2ec0 | CURRENT |
| submodules/RAG | github, gitlab | f53c5033f | CURRENT |
| submodules/verdict | github, gitlab | 66984ecac | CURRENT |
| submodules/passage | github, gitlab | 9d97166c4 | CURRENT |
| submodules/curriculum-kit | github, gitlab | 277b96efc | CURRENT |
| submodules/qa (HelixQA) | github vasic-digital, gitlab, github HelixDevelopment x2 | dc25b8aba | CURRENT after push |
| submodules/challenges | github, gitlab | 04d5c31b9 | CURRENT after push |
| submodules/doc_processor | vasic-digital github/gitlab | 12a5fb763 (branch master) | NOT-APPLICABLE-main: all 5 vasic-digital URLs level on `master`; no `main` branch exists there, so the main-directive cannot apply |
| submodules/doc_processor | HelixDevelopment github, helixdevelopment1 gitlab | `main` = 86f1a9835 (github) / bea9e9edb (gitlab); measured vs master 12a5fb763: gitlab main is an ancestor of master (126 behind, merge-base bea9e9edb); github main is DIVERGED (1 unique commit, 126 master-only, merge-base bea9e9edb) | NOT TOUCHED: github main DIVERGED => stop and report per directive; gitlab main is BEHIND master but the repo's canonical branch is master, operator decision whether to ever push main there |
| submodules/llm_orchestrator | github x2, gitlab x2 | c84c410da | CURRENT |
| submodules/llms_verifier | github, gitlab | 94e666d41 | CURRENT |
| submodules/security | github, gitlab | 0513361e2 | CURRENT |
| submodules/vision_engine | github x2, gitlab | d52fa447d | CURRENT |
| submodules/superspec | github WangX0111 | c20ac6c1b | third-party, not ours to push |
| job_seeker (DEV, private) | github vasic-digital (private), github milos85vasic (private) | b45ceb268 | CURRENT on both private upstreams; no push |
| job_seeker_public | public | not probed | fed only by scripts/publish_snapshot.sh; dev repo never pushed to it |
| career_private | github vasic-digital | 0539b6eec | CURRENT |

## Notes and limits

- job_seeker `upstreams/*.sh.disabled` (codeberg, gitflic, gitlab, gitverse, m3w) all target `job_seeker_public`: DISABLED-BY-DESIGN; the shared checkout at 4e1a4cb is 8 behind origin and dirty, so nothing was pushed from it.
- Several first-pass probes timed out at 25 s (empty heads); each was re-probed with a 90 s timeout and resolved.
- The shared LOCAL umbrella checkout is behind github/main and dirty (submodule pointers); it was not touched. The umbrella's only upstream (GitHub) holds main itself, so no push was needed.
- submodules/containers: after our push to GitLab (eb70e05) another session advanced all four URLs to d71b62058; they are level (see appendix).
- Branch name caveat: llm_provider, LLMProvider, llm_orchestrator, vision_engine, doc_processor check out `master` locally; remote main equals it except doc_processor (master only).

## Appendix: post-push `git ls-remote <url> refs/heads/main` for every changed repo (2026-11-24)

```
# monetization
git@github.com:milos85vasic/monetization.git 0634f36fc
git@github.com:vasic-digital/monetization.git 0634f36fc
git@gitlab.com:milos85vasic/monetization.git 0634f36fc
# submodules/containers
git@github.com:vasic-digital/containers.git d71b62058
git@github.com:vasic-digital/Containers.git d71b62058
git@gitlab.com:vasic-digital/containers.git d71b62058
git@gitlab.com:vasic-digital/Containers.git d71b62058
# submodules/qa
git@github.com:HelixDevelopment/helixqa.git dc25b8aba
git@github.com:HelixDevelopment/qa.git dc25b8aba
git@github.com:vasic-digital/HelixQA.git dc25b8aba
git@gitlab.com:vasic-digital/HelixQA.git dc25b8aba
# submodules/challenges
git@github.com:vasic-digital/challenges.git 04d5c31b9
git@github.com:vasic-digital/Challenges.git 04d5c31b9
git@gitlab.com:vasic-digital/challenges.git 04d5c31b9
# monetization extras
git@gitflic.ru:milosvasic/monetization.git 0634f36fc
ssh://git@gitverse.ru:2222/milosvasic/monetization.git 0634f36fc
```

Constitution (pre-existing level, re-verified): codeberg, gitflic, github HelixDevelopment, github vasic-digital, gitlab helixdevelopment1, gitlab vasic-digital, gitverse and m3w all returned 6d93ccd19e1c2fe0e1a97ece22b49e962ef3005e.
Other rows were read in the first pass with the same command and equalled the head shown.
