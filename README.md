# AI Development Platform 

Self-hosted, ephemeral Claude Code environment on a k3s homelab. Connect from Windows with `kubectl exec`, give the agent a task, and it works on GitHub feature branches. The Pod is disposable and everything needed to recreate it is in Git and Kubernetes Secrets.

## Status

MVP milestones 1 to 6 done (image, deployment, GitHub auth, Claude auth, replacement and recovery, Job preparation). Next phases are in [docs/design.md](docs/design.md); Job groundwork is in [docs/jobs.md](docs/jobs.md).

## Use it

```powershell
agent                                          # attach to the agent Pod (Herdr session)
agent -Repo MagmaOps/<repo> -Task <task-name>  # start a new agent on branch ai/<task-name>
```

(`agent` is `tools/windows/agent.cmd`; fallback: `kubectl exec -it deployment/claude-dev -n ai-development -- bash`.)

Work that is not pushed to GitHub is lost when the Pod is replaced. Details in [docs/operations.md](docs/operations.md).

## Build and test the image locally

```bash
docker build -f docker/Dockerfile -t magmakomer/claude-dev:<version> .
docker run --rm magmakomer/claude-dev:<version> healthcheck.sh
```

Pinned versions are build args at the top of the Dockerfile: `NODE_VERSION`, `GH_VERSION`, `CLAUDE_CODE_VERSION`. Auto-update is disabled in the image; upgrade by bumping the arg and rebuilding.

## Layout

- `docker/` image definition
- `scripts/` container entrypoint, healthcheck and `new-agent`
- `tools/windows/` the `agent` launcher for your Windows workstation
- `k8s/base/` Kustomize base (no environment values); `k8s/overlays/homelab/` for standalone `kubectl apply -k`
- `docs/` [architecture](docs/architecture.md), [authentication](docs/authentication.md), [operations](docs/operations.md), [jobs](docs/jobs.md), [design](docs/design.md)

Deployment is GitOps through the `k3s-lab` repo (`apps/ai-dev-platform/`), which also holds the SealedSecrets.
