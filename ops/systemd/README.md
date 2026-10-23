# zero-gap daily timer — install / uninstall notes (spec 010, T070/T072)

Prepared, **not installed**. Installing a user timer changes host configuration, so it is an
operator action (queued as item `OQ-S5-TIMER`, see `docs/zero-gap/operator-queue-S5.md`).

Install (user units, no root):

    R=$(git rev-parse --show-toplevel)
    mkdir -p ~/.config/systemd/user
    for u in zero-gap-daily.service zero-gap-daily.timer; do
        sed "s#@REPO@#$R#g" ops/systemd/$u > ~/.config/systemd/user/$u
    done
    systemd-analyze --user verify ~/.config/systemd/user/zero-gap-daily.service ~/.config/systemd/user/zero-gap-daily.timer
    systemctl --user daemon-reload
    systemctl --user enable --now zero-gap-daily.timer
    systemctl --user list-timers zero-gap-daily.timer
    # one on-demand run (same script the timer runs):
    bash scripts/zero-gap-daily.sh --now

Rollback / uninstall:

    systemctl --user disable --now zero-gap-daily.timer
    rm -f ~/.config/systemd/user/zero-gap-daily.service ~/.config/systemd/user/zero-gap-daily.timer
    systemctl --user daemon-reload

Preconditions: `.remember/.gitignore` must ignore the state dir (the job refuses otherwise);
for the timer to run while logged out, `loginctl enable-linger $USER` (operator decision).
The job never commits and never writes a tracked file; its output is
`.remember/logs/zero-gap/{<date>.json,ops-registry.jsonl,reopen-queue.jsonl}`.
