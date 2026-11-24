| launcher | step | command | rc |
|---|---|---|---|
| ai_interviewing | start-help | `bash start.sh --help` | 0 |
| ai_interviewing | start-unknown-flag | `bash start.sh --bogus` | 0 |
| ai_interviewing | start-runner-docker | `bash start.sh --runner=docker` | 2 |
| ai_interviewing | start-runner-bogus | `bash start.sh --runner=bogus` | 2 |
| ai_interviewing | start-runner-novalue | `bash start.sh --runner` | 2 |
| ai_interviewing | env-docker | `env CONTAINERS_RUNNER=docker bash start.sh` | 2 |
| ai_interviewing | stop-runner-docker | `bash stop.sh --runner=docker` | 2 |
| ai_interviewing | restart-runner-docker | `bash restart.sh --runner=docker` | 2 |
| ai_interviewing | status-before | `bash status.sh` | 0 |
| ai_interviewing | health-curl | `curl -sS -m 5 -o /dev/null -w HTTP %{http_code}\n http://127.0.0.1:18099/api/health` | 0 |
| ai_interviewing | real-read | `curl -sS -m 5 -o /dev/null -w HTTP %{http_code} bytes %{size_download}\n http://127.0.0.1:18099/` | 0 |
| ai_interviewing | double-start-runner-podman | `bash start.sh --runner=podman` | 0 |
| ai_interviewing | double-start-runner-auto | `bash start.sh --runner=auto` | 0 |
| ai_interviewing | double-start-env-podman | `env CONTAINERS_RUNNER=podman bash start.sh` | 0 |
| ai_interviewing | stop | `bash stop.sh` | 0 |
| ai_interviewing | status-stopped | `bash status.sh` | 0 |
| ai_interviewing | health-after-stop | `curl -sS -m 3 http://127.0.0.1:18099/api/health` | 7 |
| ai_interviewing | stop-again | `bash stop.sh` | 0 |
| ai_interviewing | restart-when-stopped-runner-podman | `bash restart.sh --runner=podman` | 0 |
| ai_interviewing | health-after-restart | `curl -sS -m 5 -o /dev/null -w HTTP %{http_code}\n http://127.0.0.1:18099/api/health` | 0 |
| ai_interviewing | restart-when-running-runner-auto | `bash restart.sh --runner=auto` | 0 |
| ai_interviewing | stop-runner-podman | `bash stop.sh --runner=podman` | 0 |
| ai_interviewing | logs | `tail -3 ../run/server.log` | 1 |
| job_seeker | usage | `bin/jsstack` | 1 |
| job_seeker | unknown-subcommand | `bin/jsstack bogus` | 1 |
| job_seeker | probe-default | `bin/jsstack probe` | 0 |
| job_seeker | probe-runner-podman | `bin/jsstack probe --runner=podman` | 0 |
| job_seeker | probe-runner-docker | `bin/jsstack probe --runner=docker` | 2 |
| job_seeker | probe-runner-bogus | `bin/jsstack probe --runner=bogus` | 2 |
| job_seeker | probe-runner-novalue | `bin/jsstack probe --runner` | 2 |
| job_seeker | probe-env-docker | `env CONTAINERS_RUNNER=docker bin/jsstack probe` | 2 |
| job_seeker | probe-env-podman | `env CONTAINERS_RUNNER=podman bin/jsstack probe` | 0 |
| job_seeker | probe-flag-auto-over-env-docker | `env CONTAINERS_RUNNER=docker bin/jsstack probe --runner=auto` | 0 |
| job_seeker | port | `bin/jsstack port` | 1 |
| job_seeker | status-before-up | `bin/jsstack status -container jobseeker-gate` | 2 |
| job_seeker | down-when-not-up | `bin/jsstack down -file deploy/compose.yml` | 1 |
| job_seeker | live-h3-runner-docker | `make live-h3 RUNNER=docker` | 2 |
| job_seeker | live-h3-runner-bogus | `bash gates/live_h3.sh --runner=bogus` | 2 |
| job_seeker | live-h3-runner-novalue | `bash gates/live_h3.sh --runner` | 2 |
| job_seeker | live-h3-env-docker | `env CONTAINERS_RUNNER=docker bash gates/live_h3.sh` | 2 |
| job_seeker | live-h3-prove-failure | `bash gates/live_h3.sh --prove-failure` | 0 |
| job_seeker | verify-runner-flag | `bash gates/verify_runner_flag.sh` | 0 |
| job_seeker | live-h3-runner-podman | `make live-h3 RUNNER=podman` | 0 |
| job_seeker | jobseekerd-help | `bin/jobseekerd -h` | 1 |
| job_seeker | jobseekerd-runner-flag | `bin/jobseekerd --runner=podman` | 1 |
| milosvasic.ru | help-flag | `bash start.sh --help --dry-run` | 0 |
| milosvasic.ru | unknown-flag-dry | `bash start.sh --bogus --dry-run` | 0 |
| milosvasic.ru | default-dry | `bash start.sh --dry-run` | 0 |
| milosvasic.ru | runner-podman-dry | `bash start.sh --runner=podman --dry-run` | 0 |
| milosvasic.ru | runner-auto-dry | `bash start.sh --runner=auto --dry-run` | 0 |
| milosvasic.ru | container-dry | `bash start.sh --container --dry-run` | 0 |
| milosvasic.ru | env-podman-dry | `env CONTAINERS_RUNNER=podman bash start.sh --dry-run` | 0 |
| milosvasic.ru | flag-auto-over-env-docker-dry | `env CONTAINERS_RUNNER=docker bash start.sh --runner=auto --dry-run` | 0 |
| milosvasic.ru | runner-docker-refused | `bash start.sh --runner=docker --dry-run` | 2 |
| milosvasic.ru | env-docker-refused | `env CONTAINERS_RUNNER=docker bash start.sh --dry-run` | 2 |
| milosvasic.ru | runner-bogus | `bash start.sh --runner=bogus --dry-run` | 2 |
| milosvasic.ru | runner-novalue | `bash start.sh --runner --dry-run` | 2 |
| milosvasic.ru | runner-docker-container-refused | `bash start.sh --runner=docker --container --dry-run` | 2 |
| milosvasic.ru | real-serve-http | `curl -sS -m 5 -o /dev/null -w HTTP %{http_code} bytes %{size_download}\n http://127.0.0.1:14000/` | 0 |
| qa-up | help | `bash scripts/qa-up.sh --help` | 0 |
| qa-up | unknown-flag | `bash scripts/qa-up.sh --bogus` | 2 |
| qa-up | only-bogus | `bash scripts/qa-up.sh --only nope` | 2 |
| qa-up | only-novalue | `bash scripts/qa-up.sh --only` | 2 |
| qa-up | runner-docker-refused | `bash scripts/qa-up.sh --only vd --runner=docker` | 0 |
| qa-up | runner-bogus | `bash scripts/qa-up.sh --only vd --runner=bogus` | 0 |
| qa-up | runner-novalue | `bash scripts/qa-up.sh --only vd --runner` | 2 |
| qa-up | env-docker-refused | `env CONTAINERS_RUNNER=docker bash scripts/qa-up.sh --only vd` | 0 |
| qa-up | start-vd | `bash scripts/qa-up.sh --only vd` | 0 |
| qa-up | double-start-vd | `bash scripts/qa-up.sh --only vd` | 0 |
| qa-up | workshop-runner-docker-refused | `bash scripts/qa-up.sh --only workshop --runner=docker` | 2 |
| qa-up | ai-runner-bogus-refused | `bash scripts/qa-up.sh --only ai --runner=bogus` | 2 |
| qa-up | env-docker-workshop-refused | `env CONTAINERS_RUNNER=docker bash scripts/qa-up.sh --only workshop` | 2 |
| qa-up | workshop-reuse-live | `bash scripts/qa-up.sh --only workshop --runner=podman` | 0 |
| qa-up | mv-no-rebuild | `bash scripts/qa-up.sh --only mv --no-rebuild` | 0 |
| qa-up | ai-start-runner-podman | `bash scripts/qa-up.sh --only ai --runner=podman` | 0 |
| qa-up | ai-double-start | `bash scripts/qa-up.sh --only ai` | 0 |
| qa-up | curl-8401/ | `curl -sS -m 5 -o /dev/null -w HTTP %{http_code}\n http://127.0.0.1:8401/` | 0 |
| qa-up | curl-8084/ | `curl -sS -m 5 -o /dev/null -w HTTP %{http_code}\n http://127.0.0.1:8084/` | 0 |
| qa-up | curl-8099/api/health | `curl -sS -m 5 -o /dev/null -w HTTP %{http_code}\n http://127.0.0.1:8099/api/health` | 0 |
| qa-up | curl-8087/api/health | `curl -sS -m 5 -o /dev/null -w HTTP %{http_code}\n http://127.0.0.1:8087/api/health` | 0 |
| qa-up | stop | `bash scripts/qa-up.sh --stop` | 0 |
| qa-up | stop-again | `bash scripts/qa-up.sh --stop` | 0 |
| qa-up | runner-bogus-stop | `bash scripts/qa-up.sh --stop --runner=bogus` | 0 |
| umbrella-go-tools | runtime-probe-default | `<scratch>/gobin/runtime-probe` | 0 |
| umbrella-go-tools | runtime-probe-runner-podman | `<scratch>/gobin/runtime-probe --runner=podman` | 0 |
| umbrella-go-tools | runtime-probe-runner-docker | `<scratch>/gobin/runtime-probe --runner=docker` | 2 |
| umbrella-go-tools | runtime-probe-runner-bogus | `<scratch>/gobin/runtime-probe --runner=bogus` | 2 |
| umbrella-go-tools | runtime-probe-runner-novalue | `<scratch>/gobin/runtime-probe --runner` | 2 |
| umbrella-go-tools | runtime-probe-env-docker | `env CONTAINERS_RUNNER=docker <scratch>/gobin/runtime-probe` | 2 |
| umbrella-go-tools | runtime-probe-flag-auto-over-env-docker | `env CONTAINERS_RUNNER=docker <scratch>/gobin/runtime-probe --runner=auto` | 0 |
| umbrella-go-tools | site-build-help | `<scratch>/gobin/site-build -h` | 0 |
| umbrella-go-tools | site-build-runner-docker | `<scratch>/gobin/site-build -workload jekyll --runner=docker` | 2 |
| umbrella-go-tools | site-build-runner-bogus | `<scratch>/gobin/site-build -workload jekyll --runner=bogus` | 2 |
| umbrella-go-tools | site-build-env-docker | `env CONTAINERS_RUNNER=docker <scratch>/gobin/site-build -workload jekyll` | 2 |
| umbrella-go-tools | port-discover-help | `<scratch>/gobin/port-discover -h` | 1 |
| umbrella-go-tools | port-discover-lookup | `<scratch>/gobin/port-discover -registry <scratch>/pdreg -name retest-x -default 18555` | 1 |
| umbrella-go-tools | ocr-help | `<scratch>/gobin/ocr -h` | 0 |
| umbrella-go-tools | ocr-runner-docker | `<scratch>/gobin/ocr --runner=docker` | 2 |
| umbrella-go-tools | ocr-runner-bogus | `<scratch>/gobin/ocr --runner=bogus` | 2 |
| umbrella-go-tools | ocr-env-docker | `env CONTAINERS_RUNNER=docker <scratch>/gobin/ocr` | 2 |
| umbrella-tools | hawkscan-runner-docker | `bash hawkscan/run.sh --runner=docker` | 2 |
| umbrella-tools | hawkscan-runner-bogus | `bash hawkscan/run.sh --runner=bogus` | 2 |
| umbrella-tools | hawkscan-runner-novalue | `bash hawkscan/run.sh --runner` | 2 |
| umbrella-tools | hawkscan-env-docker | `env CONTAINERS_RUNNER=docker bash hawkscan/run.sh` | 2 |
| umbrella-tools | hawkscan-podman-nokey | `bash hawkscan/run.sh --runner=podman` | 0 |
| umbrella-tools | helixtranslate-local-docker | `bash helixtranslate-local.sh --runner=docker` | 2 |
| umbrella-tools | helixtranslate-local-bogus | `bash helixtranslate-local.sh --runner=bogus` | 2 |
| umbrella-tools | helixtranslate-local-env-docker | `env CONTAINERS_RUNNER=docker bash helixtranslate-local.sh` | 2 |
| umbrella-tools | od-daemon-runner-docker | `bash od/start-daemon.sh --runner=docker --help` | 1 |
| umbrella-tools | od-daemon-runner-novalue | `bash od/start-daemon.sh --runner` | 2 |
| umbrella-tools | od-daemon-help | `bash od/start-daemon.sh --help` | 1 |
| umbrella-tools | deploy-langs-prove-args | `bash deploy-langs.sh --prove-args` | 0 |
| umbrella-tools | ocr-run-prove-args | `bash containers/compose/ocr-run.sh --prove-args` | 3 |
| workshop-main | help | `bash scripts/start.sh --help` | 0 |
| workshop-main | start-unknown-flag | `bash scripts/start.sh --bogus` | 2 |
| workshop-main | start-runner-flag | `bash scripts/start.sh --runner=podman` | 2 |
| workshop-main | stop-help | `bash scripts/stop.sh --help` | 0 |
| workshop-main | status-before | `bash scripts/status.sh` | 1 |
| workshop-main | start-default | `bash scripts/start.sh` | 0 |
| workshop-main | status-up | `bash scripts/status.sh` | 0 |
| workshop-main | health-curl | `curl -sS -m 5 -w \nHTTP %{http_code}\n http://127.0.0.1:8087/api/health` | 0 |
| workshop-main | real-read | `curl -sS -m 10 -o /dev/null -w HTTP %{http_code} bytes %{size_download}\n http://127.0.0.1:8087/` | 0 |
| workshop-main | double-start | `bash scripts/start.sh` | 0 |
| workshop-main | stop | `bash scripts/stop.sh` | 0 |
| workshop-main | status-stopped | `bash scripts/status.sh` | 1 |
| workshop-main | stop-again | `bash scripts/stop.sh` | 0 |
| workshop-main | health-after-stop | `curl -sS -m 3 http://127.0.0.1:8087/api/health` | 7 |
| workshop-main | stop-bogus | `bash scripts/stop.sh --bogus` | 2 |
| workshop-main | restart-help | `bash scripts/restart.sh --help` | 0 |
| workshop-main | restart-when-stopped | `bash scripts/restart.sh` | 0 |
| workshop-main | status-after-restart | `bash scripts/status.sh` | 0 |
| workshop-main | health-after-restart | `curl -sS -m 5 -w  HTTP %{http_code}\n http://127.0.0.1:8087/api/health` | 0 |
| workshop-main | restart-when-running | `bash scripts/restart.sh --skip-quiescence-check` | 0 |
| workshop-main | health-after-restart2 | `curl -sS -m 5 -w  HTTP %{http_code}\n http://127.0.0.1:8087/api/health` | 0 |
| workshop-main | restart-destroy-refused | `bash scripts/restart.sh --destroy-volumes` | 2 |
| workshop-main | restart-dry | `bash scripts/restart.sh --dry-run` | 0 |
| workshop-main | logs | `podman logs --tail 5 workshop-curriculum_platform_1` | 0 |
| workshop-runner-branch | help | `bash scripts/start.sh --help` | 0 |
| workshop-runner-branch | bogus-flag | `bash scripts/start.sh --bogus` | 2 |
| workshop-runner-branch | runner-docker-refused | `bash scripts/start.sh --runner=docker` | 2 |
| workshop-runner-branch | runner-bogus | `bash scripts/start.sh --runner=bogus` | 2 |
| workshop-runner-branch | runner-novalue | `bash scripts/start.sh --runner` | 2 |
| workshop-runner-branch | runner-empty | `bash scripts/start.sh --runner=` | 2 |
| workshop-runner-branch | env-docker-refused | `env CONTAINERS_RUNNER=docker bash scripts/start.sh` | 2 |
| workshop-runner-branch | stop-runner-docker | `bash scripts/stop.sh --runner=docker` | 2 |
| workshop-runner-branch | restart-runner-docker | `bash scripts/restart.sh --skip-quiescence-check --runner=docker` | 2 |
| workshop-runner-branch | precedence-flag-over-env | `env CONTAINERS_RUNNER=docker bash scripts/start.sh --runner=bogus` | 2 |
| workshop-runner-branch | start-runner-podman-altport | `bash scripts/start.sh --runner=podman --port 18087 --wait-healthy 120` | 1 |
| workshop-runner-branch | start-runner-podman-altport | `bash scripts/start.sh --runner=podman --port 18087 --wait-healthy 120` | 0 |
| workshop-runner-branch | status-up | `bash scripts/status.sh` | 0 |
| workshop-runner-branch | health-curl | `curl -sS -m 5 -o /dev/null -w HTTP %{http_code}\n http://127.0.0.1:18087/api/health` | 0 |
| workshop-runner-branch | real-read | `curl -sS -m 10 -o /dev/null -w HTTP %{http_code} bytes %{size_download}\n http://127.0.0.1:18087/` | 0 |
| workshop-runner-branch | double-start-runner-auto | `bash scripts/start.sh --runner=auto --port 18087` | 0 |
| workshop-runner-branch | double-start-env-podman | `env CONTAINERS_RUNNER=podman bash scripts/start.sh --port 18087` | 0 |
| workshop-runner-branch | precedence-flag-auto-over-env-docker | `env CONTAINERS_RUNNER=docker bash scripts/start.sh --runner=auto --port 18087` | 0 |
| workshop-runner-branch | stop-runner-podman | `bash scripts/stop.sh --runner=podman` | 0 |
| workshop-runner-branch | stop-again-runner-podman | `bash scripts/stop.sh --runner=podman` | 0 |
| workshop-runner-branch | restart-when-stopped-runner-podman | `bash scripts/restart.sh --skip-quiescence-check --runner=podman --port 18087` | 0 |
| workshop-runner-branch | health-after-restart | `curl -sS -m 5 -o /dev/null -w HTTP %{http_code}\n http://127.0.0.1:18087/api/health` | 0 |
| workshop-runner-branch | restart-when-running-runner-auto | `bash scripts/restart.sh --skip-quiescence-check --runner=auto --port 18087` | 0 |
| workshop-runner-branch | stop-final | `bash scripts/stop.sh --runner=podman` | 0 |
