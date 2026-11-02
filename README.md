# AI Development Platform

Self-hosted, ephemeral Claude Code environment for a k3s homelab. See [docs/design.md](docs/design.md) for the full design.

## Status

Milestone 1: development image (`docker/Dockerfile`). No Kubernetes manifests yet.

## Build and test the image locally

```bash
docker build -f docker/Dockerfile -t magmakomer/claude-dev:0.1.0 .

# Start it (idles after running the healthcheck) and inspect
docker run -d --name cdtest magmakomer/claude-dev:0.1.0
docker logs cdtest
docker exec -it cdtest bash
docker rm -f cdtest

# One-off healthcheck
docker run --rm magmakomer/claude-dev:0.1.0 healthcheck.sh
```

Pinned versions are build args at the top of the Dockerfile: `NODE_VERSION`, `GH_VERSION`, `CLAUDE_CODE_VERSION`. Auto-update is disabled in the image; upgrade by bumping the arg and rebuilding.

## Layout

- `docker/` image definition
- `scripts/` container entrypoint and healthcheck
- `docs/` design and (later) operations docs
