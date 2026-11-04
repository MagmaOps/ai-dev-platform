# Default Claude Code plugins for agent Pods

Every agent Pod starts with a default set of Claude Code plugins, defined in this repo, without baking them into the image or installing them by hand. Today: **caveman** (terse replies) and **ponytail** (smallest-change coding style), both always on.

**Status:** S1 (plugins in the repo) and S2 (startup install) are done and tested locally. S3 (deploy) is not started. Checked against Claude Code 2.1.309, the version pinned in `docker/Dockerfile`.

## How it works

```text
.claude-plugin/marketplace.json     marketplace "magmaops-skills" (repo root)
claude-skills/plugins/<name>/       one self-contained plugin per folder (+ UPSTREAM.md, patches/ if vendored)
claude-skills/tests/hooks-smoke.sh  sandboxed hook test + marketplace validate/install
scripts/install-skills.sh           runs at Pod start (entrypoint.sh), never fatal
```

At start the entrypoint runs `install-skills.sh`, which:

1. clones `CLAUDE_SKILLS_REPO` at tag `CLAUDE_SKILLS_REF` (60 s timeout) and **refuses** unless `HEAD` equals `CLAUDE_SKILLS_SHA` (a missing or malformed SHA is also refused);
2. runs `claude plugin validate`, adds the clone as a `directory` marketplace, and installs each plugin in `CLAUDE_SKILLS_PLUGINS`;
3. skips any plugin that has components outside the policy below;
4. writes `~/.cache/claude-skills/status`, which `healthcheck.sh` reports (warning only).

Config is ConfigMap env vars. The base ships them empty (empty ref = feature off); the real values live in `k3s-lab` next to the pin, so the agent's token cannot change them. The base also sets `CLAUDE_CODE_DISABLE_OFFICIAL_MARKETPLACE_AUTOINSTALL=1`.

Why not the alternatives: the entrypoint clones (rather than `marketplace add owner/repo#tag`) because a marketplace source can pin a tag but not a commit; settings are written by the CLI (not mounted) because Claude Code and Herdr write `~/.claude/settings.json` and a ConfigMap mount is read-only; declaring the marketplace only in settings would install it in the background after the first session started.

**Component policy.** Plugins may contain skills and commands. Hooks only for plugins named in `CLAUDE_SKILLS_HOOK_PLUGINS`. Never MCP/LSP servers, `bin/`, monitors, mods (`modules`), agents, output styles, themes, workflows or plugin `settings.json`.

## The two plugins

Vendored: copied at a fixed upstream commit, trimmed, with a few marked patches. Each plugin's `UPSTREAM.md` records the upstream repo and commit, the licence, SHA-256 of every file (upstream and vendored), the patches, and what was dropped. Both are unofficial copies (caveman's name is a trademark of its author).

| Plugin | Hooks kept | Not kept (why) |
| - | - | - |
| caveman 4.0.1 (Apache-2.0) | SessionStart, SubagentStart, UserPromptSubmit | SessionEnd stats hook (reads whole transcripts, writes history); 20 of 22 skills (incl. `caveman-setup`, which routes a repo through the hosted Caveman Cloud gateway); agents, commands, engine/proxy/extension |
| ponytail 5.3.3 (MIT) | SessionStart, SubagentStart | UserPromptSubmit tracker (no output on normal prompts, spawns a detached import on `/ponytail band import`); the "band" **mod** (runs inside Claude Code, writes a per-turn cost CSV, can POST it to a webhook with a bearer token); 5 of 6 skills |

Patches (diffs in `patches/`, every line marked `MAGMAOPS PATCH`):

- **P1, P4:** disable the statusline nudge in both SessionStart hooks (unpatched, it asks the agent to edit `settings.json` in every fresh Pod) and ponytail's codebase map (it runs `git ls-files` and injects repo-derived names).
- **P2, P3:** exempt explanations from caveman, see next section.

Hook state is about 1 KB under `~/.claude` (`.caveman-*`, `.ponytail-*`, `ponytail-modes/`); nothing is written into the plugin directory. It lives in the container layer, so it is lost on every restart: each new Pod starts always-on, and a "stop caveman" lasts only for its session (`startup` and `clear` re-arm it). No kept hook opens a network connection (reviewed, not enforced).

**Always-on vs "explain substantial changes".** Caveman re-sends "answer only what was asked: no walkthroughs" on every prompt, which would override `CLAUDE.md`'s "explain substantial changes before making them". P2/P3 add: *caveman does not apply to explaining a substantial change, a design or trade-off, a concept the user is learning, or a milestone summary; use normal complete sentences with the reasoning, then resume.* It is in the vendored text so it also holds in other repos. Whether the model obeys it is an S3 acceptance test.

Cost per session: caveman ruleset ~1.1k tokens + ~120 per prompt, ponytail ~0.7k, skill listings ~0.2k. Each subagent spawn adds ~1.8k (both SubagentStart hooks). Hook latency ~75 ms.

## Security

- Skills are instructions to an agent with bash, `GH_TOKEN` and `CLAUDE_CODE_OAUTH_TOKEN`; hooks are code that runs outside Claude Code's sandbox as the same user, with those tokens in its environment. Changes to `claude-skills/` get PR plus human review; hook changes are read in full.
- **The agent can push to this repo and tags are unprotected today** (its token has `push`; the only ruleset covers `main`). It could move a release tag onto an unreviewed commit. Defences: the SHA pin in `k3s-lab` (unreachable for the agent's token) and an **owner-only tag ruleset** on `skills-v*`. `scripts/release-skills.sh` creates it (owner only, S3).
- The repo is public: no secrets, hostnames or cluster details in any skill. Clones are anonymous; if it ever becomes private the existing `gh` credential helper and `GH_TOKEN` suffice.
- `DISABLE_AUTOUPDATER=1` (already in the image) stops plugin auto-update, so a Pod runs exactly the commit it installed. The clone is writable by the agent (same UID), which only affects that Pod until restart.
- Optional hardening for later: run hooks as `node --permission --allow-fs-write=$CLAUDE_CONFIG_DIR …` (denies child processes and other writes; does not restrict network or env). `hooks-smoke.sh` already runs them that way.
- If `allowManagedHooksOnly` is ever set, plugin hooks stop unless the plugins are force-enabled in managed settings.

## Release and rollback

1. Feature branch, `hooks-smoke.sh` passes, PR, review, merge.
2. **Owner**, on their own machine with `gh` logged in as admin: `scripts/release-skills.sh X.Y.Z` (dry run), then `--apply`. It checks you are on a clean, current `main` and that the smoke test passes, creates the owner-only `skills-v*` tag ruleset on the first run, tags `main` and pushes the tag, then prints the values for `k3s-lab`. It refuses to run for a non-admin login, so the agent's token cannot use it.
3. In `k3s-lab`, set `CLAUDE_SKILLS_REF` and `CLAUDE_SKILLS_SHA` (and the plugin lists). Argo syncs the ConfigMap; **the running Pod does not change** (env is read at container start).
4. When agents have pushed their work: `kubectl rollout restart deployment/claude-dev -n ai-development`.
5. Verify: `kubectl logs deployment/claude-dev -n ai-development | grep skills:` and `kubectl exec deployment/claude-dev -n ai-development -- claude plugin list`.

Rollback: previous tag and SHA, same steps. Tags are never moved or deleted.

## Failure behaviour

Fail-open: the script always exits 0 and the Pod starts. The failure is logged, written to the status file and shown by the healthcheck.

| Cause | Result |
| - | - |
| GitHub down, bad tag, bad repo, 60 s timeout | no plugins, reason in log/status |
| Commit differs from `CLAUDE_SKILLS_SHA`, or SHA missing | clone deleted, nothing installed |
| Plugin with a forbidden component or an unlisted hook | that plugin skipped, others install |
| All requested plugins skipped | counted as failed |

No automatic retry: re-run `install-skills.sh` in the Pod and start a new session, or restart the Pod. An agent started while this runs, or after a failure, has no caveman/ponytail; S3 adds a readiness probe so the Windows launcher waits for the status file.

## Verified (S1/S2, local, isolated `HOME`/`CLAUDE_CONFIG_DIR`)

- `hooks-smoke.sh` (25 checks): hooks under Node's permission model, correct output, exemption text present, no nudge or map, only the expected state files; `validate --strict`, marketplace add, install, component counts. It fails when a patch is removed.
- Vendored files equal upstream (verbatim) or upstream plus the listed patch, checked with `git apply`.
- `install-skills.sh`: disabled; good install (re-run is idempotent); wrong SHA; no SHA; bad tag; bad repo; unlisted hook; `.mcp.json`; unknown plugin; nothing installable. Always exit 0. Entrypoint wiring checked with a path-adjusted copy.
- A live `claude -p` session start ran both SessionStart hooks from the installed plugins (`CLAUDE_PLUGIN_ROOT` resolves to the clone).
- An interactive start registers the official marketplace in ~3 s; with the env var set it did not.
- Hook processes can be assumed to inherit the Pod environment; hooks need only a writable `~/.claude`, which Claude Code needs anyway (`readOnlyRootFilesystem` is off, see `architecture.md`).

**Not tested yet (S3 acceptance):** UserPromptSubmit and SubagentStart in a live session (only synthetic payloads); model compliance with the exemption; hook crash/timeout behaviour; several agents in one Pod; the Docker image itself (no Docker here, so `docker build` has not been run).

## Milestones

- **S1 done:** marketplace, both plugins, provenance, patches, smoke test.
- **S2 done:** `install-skills.sh`, entrypoint and healthcheck wiring, Dockerfile `COPY`, `.dockerignore`, ConfigMap keys.
- **S3 next (owner steps marked):** build and push image 0.2.0 and bump the tag in `k8s/base`, `overlays/homelab` and `k3s-lab`; readiness probe (checks the status file; added together with the new image so the old image is never left unready); *owner:* run `scripts/release-skills.sh` (ruleset + first tag); paste the printed ref, SHA and plugin lists into `k3s-lab`; sync and restart; acceptance on the real Pod (live hooks, exemption behaviour, bad-ref run, Pod replacement); document release and rollback in `operations.md` and the layout in `architecture.md`.
- **Later:** `scripts/check-vendored.sh` (automates the upstream-hash check), Node-permission wrapper for hooks, headless Jobs (caveman starts inactive under `claude -p` unless `CAVEMAN_DEFAULT_MODE` is set; ponytail is active), `CLAUDE_SKILLS_REQUIRED` fail-closed for Jobs, more one-shot skills.

## Upgrading a vendored plugin

Never copy over the top. Clone upstream in a scratch directory, `git diff old..new` over the files listed in `UPSTREAM.md`, read every hook change in full (new `require`s, child processes, network, new state paths), re-apply the patches (`git apply -p1`), update `UPSTREAM.md`, run `hooks-smoke.sh`, then PR.
