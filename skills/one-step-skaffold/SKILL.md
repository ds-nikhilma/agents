---
name: one-step-skaffold
description: >
  Skaffold a lightning-core LRO service, its worker and its smoketest under my alias in d2, run the
  smoketest against the aliased LRO, tear everything down, and triage any failure from the logs.
  Wraps ~/Desktop/projects/one-step-skaffold/one-step-skaffold.sh. Use when I say "skaffold X",
  "run the smoketest for X against my build", "one-step-skaffold X", "test X end to end in d2",
  "which of our services skaffold green", or /one-step-skaffold.
user-invocable: true
argument-hint: "<service> [more services...] [-a alias] [-w worker] [--no-worker] [--keep] [--timeout s]"
allowed-tools:
  - Read
  - Bash
  - Monitor
  - TaskStop
---

# one-step-skaffold

The script does the orchestration. It is deterministic and handles process-group signals, the
`api.go` address patch and revert, and teardown. **Never re-implement its steps by hand.** This
skill decides the inputs, runs the script, watches it, and diagnoses failures.

- Script: `~/Desktop/projects/one-step-skaffold/one-step-skaffold.sh`
  (repo `github.com/ds-nikhilma/one-step-skaffold`). Run `--help` for the flags. If the script is
  not there, ask before cloning it: `git clone https://github.com/ds-nikhilma/one-step-skaffold.git ~/Desktop/projects/one-step-skaffold`.
- Default alias: `nm` (mine). Anyone else must pass `-a`; ask them if they didn't. Defaults: namespace `core`, context `lightning-d2`.
- Logs: `$TMPDIR/one-step-skaffold/<alias>/{worker,lro,smoketest}.log`.

## 1. Resolve inputs

- **Service(s)**: from `$ARGUMENTS`. If none were given, ask. Several services → run them one at a
  time, never in parallel: they share the alias, the log directory and the d2 objects.
- **Checkout**: the script must run inside a lightning-core git checkout. If the current directory is
  one (`git rev-parse --show-toplevel` contains `services/<service>`), use it. Otherwise use
  `~/Desktop/projects/lightning-core`. Before running, tell me its branch and whether it is dirty,
  because the build uses the working tree as it is. The script patches and restores
  `services/<svc>/api.go` itself, so don't stash or edit that file.
- **Worker**: let the script auto-detect. If it dies with "several worker Deployments match", show
  me the list and ask which one, then rerun with `-w`. Use `--no-worker` only when I ask for it, or
  when the script says no worker exists and the service clearly has none.

## 2. Preflight (cheap, before the long run)

Run these together and stop with a clear fix if any fails:

```bash
docker info >/dev/null 2>&1 && echo docker-ok
gcloud auth print-access-token >/dev/null 2>&1 && echo gcloud-ok
gcloud auth application-default print-access-token >/dev/null 2>&1 && echo adc-ok
for b in dscore skaffold kubectl git; do command -v $b >/dev/null || echo "missing $b"; done
```

If gcloud or ADC fails, I have to log in myself. Tell me to type:
`! gcloud auth login && gcloud auth application-default login`

## 3. Run

A run can take up to about 50 minutes (20-minute cold build plus the 30-minute smoketest), which is
longer than a foreground Bash call allows. Start it with Bash `run_in_background: true`:

```bash
cd <checkout> && ~/Desktop/projects/one-step-skaffold/one-step-skaffold.sh <service> -a <alias> [flags] 2>&1
```

Wait for the completion notification. Don't poll in a loop. If I want progress, read the tail of
the background output or of the log files. If I ask to stop, send `kill -INT <script pid>`
(the script's own trap runs teardown). Never `kill -9` the script, and never kill dscore pids
directly: dscore only honours a SIGINT sent to its process group.

## 4. Report and triage

Exit codes: `0` PASS, `1` smoketest Failed, `2` timeout, `3` dscore exited before the job was
created, `130`/`143` interrupted. Any other non-zero code is a `die` from preflight or rollout.

On failure, read the right log and match it against this table before guessing:

| Symptom (script output or log) | Likely cause | Fix |
| --- | --- | --- |
| `Reauthentication failed`, `cannot reach namespace` | gcloud session expired | I re-login (step 2), then rerun |
| `no Deployment '<svc>'` / `no CronJob '<svc>-smoketest'` | wrong name, or the service has no deployed smoketest | check `kubectl -n core get deploy,cronjob \| grep <svc>`; no CronJob means the service can't be smoketested this way |
| `several worker Deployments match` | versioned or accelerator workers | ask which one, rerun with `-w` |
| `expected exactly 1 'address =' const` | `api.go` has an unusual shape | show me the file; it needs a hand patch, so don't edit it without asking |
| missing generated Go package / proto import errors in `lro.log` or `worker.log` | stale codegen | `cd services/<svc> && rm -f .sync-protos.done .generated-rpcs.done && make generate-rpcs`, then rerun once |
| `dscore exited before deployment ... appeared` | build failure | read the last ~80 lines of that log and report the real compiler or docker error |
| `failed to become ready` | crashloop or image pull | `kubectl -n core describe deploy/<name>-<alias>` plus pod logs |
| exit 1, smoketest logs show assertion or RPC errors | real test failure, or the LRO/worker under test is broken | quote the failing assertion. Say whether it looks like my change or a pre-existing d2 problem by checking if the scheduled d2 smoketest CronJob is also failing |
| exit 2 timeout | worker never picked up the work item, or GPU pool scheduling | check the worker log and pod scheduling events |
| `leftover resources` / `VirtualServices still routing` warnings | teardown incomplete | show me the exact `kubectl delete` command the script printed; ask before running it |

Apply at most one automatic fix-and-rerun per service: the codegen fix, or a `-w` choice I confirmed.
Ask me before anything that edits code, deletes cluster objects, or reruns more than once.

## 5. Output

For one service, give a short verdict line (PASS/FAIL/TIMEOUT/ABORTED), the cause in one sentence,
the evidence (2–5 log lines) and the next step.

For several services, give a table: service | worker used | result | cause | log path. Then list
the failures that share a cause.

Always confirm that nothing was left behind: no `-<alias>` deployments or services in `core`.
Remind me if a `--keep` session is still running and how to stop it.
