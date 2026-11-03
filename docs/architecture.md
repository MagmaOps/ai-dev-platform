# Architecture

An ephemeral, interactive Claude Code environment on the k3s homelab. Design rationale and future phases are in [design.md](design.md).

## Components

```text
Windows 11 ── kubectl exec ──> k3s cluster
                                 └─ namespace ai-development
                                      ├─ Deployment claude-dev (1 replica, Recreate)
                                      │    └─ Pod: claude, git, gh, node, python, /workspace (emptyDir)
                                      ├─ ServiceAccount claude-dev (no token, no RBAC)
                                      ├─ ConfigMap claude-dev-config (git identity)
                                      ├─ Secret claude-dev-github   (GH_TOKEN)
                                      └─ Secret claude-dev-claude   (CLAUDE_CODE_OAUTH_TOKEN)
```

External services: GitHub (code), Anthropic (inference), Docker Hub (`magmakomer/claude-dev`, public image).

## Repositories

| Repo | Holds |
| - | - |
| `ai-dev-platform` (this repo) | Dockerfile, scripts, `k8s/base` (no environment values), `k8s/overlays/homelab` (standalone `kubectl apply -k`) |
| `k3s-lab` | Argo CD Application, namespace, image tag pin, git-identity patch, SealedSecrets (`apps/ai-dev-platform/`, `namespaces/ai-development.yaml`) |

Argo CD syncs `k3s-lab/apps/ai-dev-platform/workload/prod`, which pulls `k8s/base` from this repo's `main` over git and patches it.

## Key decisions

- **Ephemeral by design.** No PVC. `/workspace` is an `emptyDir`, so anything not pushed to GitHub is lost when the Pod is replaced.
- **`Recreate` strategy, one replica.** Never two dev Pods at once.
- **No node affinity.** The Pod can run on any worker. The image is public, so any node can pull it.
- **Least privilege.** Non-root (UID 1000), all capabilities dropped, no privilege escalation, seccomp `RuntimeDefault`, no ServiceAccount token, Pod Security `restricted` on the namespace, resource requests and limits. `readOnlyRootFilesystem` is off because Claude Code lives under `/home/dev`.
- **No public exposure.** No Service or Ingress. Access is `kubectl exec` only.
- **git over HTTPS through `gh`.** `GIT_CONFIG_*` env vars set `credential.https://github.com.helper = !gh auth git-credential`, so the token never appears in a remote URL or on-disk config.
- **Pinned image.** Tools are pinned by Dockerfile build args; Claude Code auto-update is disabled. Never deploy `latest`.

## Not built yet

NetworkPolicy (egress restriction needs the pod/service/LAN CIDRs), headless Jobs, task queue and observability (design phases 2 to 5).
