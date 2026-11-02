# CLAUDE.md

Self-hosted, ephemeral Claude Code environment on a k3s homelab. The full design is in `docs/design.md`; read it before substantial changes.

## How to work in this repo

- Work milestone by milestone (see design §14). Do not implement future phases early. Stop after each milestone and wait for approval.
- Explain substantial changes before making them. The owner is learning Kubernetes/DevOps.
- Use Kustomize only. No Helm, operators, service meshes or databases without justification.
- Keep manifests compatible with k3s. Follow Kubernetes security best practices (non-root, drop capabilities, no SA token, resource limits).
- Never apply manifests to the cluster, push images, or push to git without explicit approval. Never make destructive changes to the existing cluster.
- Never print, commit or bake in secrets. Secrets are Kubernetes Secrets (SealedSecrets in k3s-lab); this repo holds only names and placeholders.
- Do not set `ANTHROPIC_API_KEY` anywhere. Claude authenticates through the Pro subscription (`CLAUDE_CODE_OAUTH_TOKEN`).

## Layout and conventions

- `docker/Dockerfile` image; build context is the repo root. Image: `magmakomer/claude-dev:<semver>` on Docker Hub (public). Never deploy `latest`.
- `kubernetes/base/` has no homelab values (images, namespace, secrets are set by overlays). `kubernetes/overlays/homelab/` is for standalone `kubectl apply -k`.
- GitOps wiring (Argo CD Application, namespace, sealed secrets) lives in the separate `k3s-lab` repo, following its `apps/job-search-lab` pattern. Reference app: `job-search-lab/k8s`.
- Cluster: k3s, 1 control plane + 4 amd64 workers, Argo CD, Prometheus/Grafana, Sealed Secrets. Namespace: `ai-development`.
- Shell scripts use LF line endings.
- Windows 11 client with PowerShell; the container is Debian-based.
