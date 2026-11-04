# claude-skills

Claude Code plugins that every agent Pod loads at start. This repo is also a plugin marketplace: `.claude-plugin/marketplace.json` at the repo root lists the plugins under `claude-skills/plugins/<name>/`. These are for the agents working in *other* repositories; this repo's own agent context is `CLAUDE.md`.

Design, security model and rollout: [docs/skills-design.md](../docs/skills-design.md). Nothing here is applied to the cluster by itself: the Pod's entrypoint clones a SHA-pinned release tag (milestone S2) and installs from it.

## Plugins

| Plugin | What | Upstream | Licence |
| - | - | - | - |
| `caveman` | terse replies, always on | https://github.com/juliusbrussee/caveman | Apache-2.0 |
| `ponytail` | smallest-change coding style, always on | https://github.com/dietrichgebert/ponytail | MIT |

Both are **vendored** (copied at a fixed commit, trimmed, with a few marked patches), not linked. Each plugin's `UPSTREAM.md` records the upstream repo, commit, file hashes, patches and what was dropped.

## Rules

- Each plugin is self-contained: no `../` paths, no symlinks between plugins.
- Allowed components: skills and commands. Hooks only for plugins named in the Pod's hook allowlist (`caveman`, `ponytail`). Never MCP servers, LSP servers, `bin/`, monitors or mods (`modules`).
- Hooks must be reviewed in full, run no network access, and write only under `$CLAUDE_CONFIG_DIR`.
- Never edit a vendored file without a `MAGMAOPS PATCH` comment, a file in `patches/` and an `UPSTREAM.md` update.
- No secrets, hostnames or cluster details in any skill: the repo is public.

## Test

```bash
claude-skills/tests/hooks-smoke.sh
```

Runs the hooks in a sandbox (Node permission model, temp config dir) and validates and installs the marketplace in an isolated `CLAUDE_CONFIG_DIR`. It never touches `~/.claude`.

## Release

Feature branch, PR and review, then the owner creates the `skills-vX.Y.Z` tag and updates the pin in `k3s-lab`. See the design note, "Release and rollback". 
