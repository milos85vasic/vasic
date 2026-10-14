# Operator decisions, 2026-10-14 evening session (answers given via interactive questions)

Authority: these are the operator's own answers in this session (counts/ids only; no private content).

| # | Topic | Decision |
|---|---|---|
| 1 | HelixQA all-skipped structured run | exit 2 (undetermined) |
| 2 | Catalogizer helixqa scripts | edit to the 0/1/2 exit contract (test-first, reviewed, local commit) |
| 3 | Shell env | `~/.bash_profile` sources `"$HOME/.bashrc"`; `~/.config/environment.d/60-tmpdir.conf` created |
| 4 | Given-name handle files (26) | forward-redact now (done, 691b9a0; history unchanged) |
| 5 | Workshop LAN exposure | stay loopback-only; ask again after /media review GO |
| 6 | Dirty trees | triage per repo, commit only what is ours, ask per repo for unknown |
| 7 | ai_interviewing / llms_verifier gate work | review, then ff-push inside each repo, then bump umbrella gitlinks |
| 8 | Umbrella push | ff-only push to all upstreams once gates 0-6 are green without bypass |
| 9 | notes (diverged +8/-16) | merge gitflic into local, never force, then ff-push |
| 10 | workshop (144 behind), helix_code (5 behind) | fetch+merge per repo, diff review |
| 11 | nezha leftovers | keep models + key, remove temp files only |
| 12 | Workstation 10.6.100.221 | proceed without; NOT VALIDATED/UNDETERMINED until route fixed |
| 13 | VSC-368/369/370/371 cascades | authorised, one at a time (368, 371, 370, 369) |
| 14 | VSC-285 provider tokens | leave the 6 rows UNVERIFIED |
| 15 | VSC-362 three old findings | repair the rows, then independent review |
| 16 | VSC-367 guard wiring | wire automatically once confirming review is GO |
| 17 | Workshop backlog gates W1/W2 | authorised (VSC-070/079/125/301, WSP-054/062/125/167/168) |
| 18 | WSP-066 / WSP-068 | WSP-068 yes; WSP-066 deferred (record reason) |
| 19 | WSP-028, VSC-300, VSC-078 | agent runs WSP-028 and VSC-300; VSC-078 review package drafted for operator |
| 20 | LMV-003 / VSC-293 | fix per owning repo, one bump at a time |
| 21 | llmctl serving policy | strict by default: FAIL/UNDETERMINED not served; loud opt-out, refused for consumer-facing |
| 22 | Workshop material downloads | keep for signed-in users; audit what is served |
| 23 | source_ref.path in API | redact centrally at serialisation; adapt UI labels |
| 24 | Releases | prepare locally; GitLab releases now; GitHub after operator `gh auth login` |
