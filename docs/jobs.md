# Preparing for Kubernetes Jobs (design phase 3)

Milestone 6 only prepares the ground. Nothing here is deployed or automated. The example is [examples/claude-job.example.yaml](examples/claude-job.example.yaml).

## Already in place

- **The image supports non-interactive runs.** Its entrypoint runs the healthcheck and then `exec "$@"`, so a Job's `args` replaces the idle `sleep`. `claude` has `-p`, `--permission-mode`, `--allowedTools`, `--output-format` and `--no-session-persistence`.
- **Credentials need no login.** `GH_TOKEN` and `CLAUDE_CODE_OAUTH_TOKEN` come from the existing Secrets, so a disposable Pod starts authenticated.
- **The hardened pod settings carry over.** Non-root, dropped capabilities, no ServiceAccount token, seccomp, resource limits and an `emptyDir` workspace are repeated in the example Job.
- **Git identity and branch protection** already apply: the agent pushes `ai/<branch>` and cannot merge.

## Sketch of one task

1. Create a Job from the template with `REPO`, `BRANCH` and `TASK` set.
2. Pod clones the repo and creates `ai/<BRANCH>`.
3. `claude -p` runs the task with an allowlist of tools.
4. If files changed: commit and push the branch. Otherwise log "No changes made."
5. Job ends. Logs stay for a day (`ttlSecondsAfterFinished`), then Kubernetes removes it.

## Decisions to make before building it

- **Billing.** Anthropic announced that automated `claude -p` / Agent SDK usage would move to a separate, smaller credit and then reportedly paused the change. Check Anthropic's official help center before running Jobs, and watch your usage page after the first one. `--max-budget-usd` applies only to API billing, so it is no safeguard here.
- **Shared usage limit.** All Jobs and interactive sessions draw on one Pro limit. Limit parallelism (for example a queue with concurrency 1).
- **Tool permissions.** The example allows file edits and a few Bash prefixes. A headless run cannot ask for approval, so anything not allowed simply fails. Decide the allowlist per project.
- **Tests before pushing.** The design wants tests run before the push. That needs the repo's toolchain in the image or a per-project image.
- **Per-Job secrets and repos.** One PAT covers every repo it is scoped to. Decide whether tasks need narrower, per-repo tokens.
- **Where logs go.** Pod logs are lost after the TTL. Phase 4 and 5 will need somewhere durable, with no secrets or sensitive prompts in it.
- **Network restriction.** Jobs run with unrestricted egress today. Writing the NetworkPolicy needs the pod, service and LAN CIDRs.
- **Failure handling.** `backoffLimit: 0` means no automatic retry. Retries and usage-limit detection belong to phase 4.

## Why the manifest is not in `k8s/`

`k8s/base` is what Argo CD syncs. A Job there would run on every sync. The example lives under `docs/` so nothing can deploy it by accident.
