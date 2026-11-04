# Upstream: ponytail

Trimmed and modified copy of **ponytail** for MagmaOps agent Pods.

| | |
| - | - |
| Upstream | https://github.com/dietrichgebert/ponytail |
| Reviewed commit | `96608e078b2d5ea607c5c3b8b5a54d1c1fba6846` (2026-10-29, plugin version 5.3.3) |
| Licence | MIT (`LICENSE`) |
| Copied on | 2026-11-04 |

## Files

Hashes are SHA-256. "verbatim" means the vendored file equals the upstream file at the reviewed commit. Paths are relative to this directory and to the upstream repo root.

| Path | Upstream sha256 | Vendored sha256 | Status |
| - | - | - | - |
| `hooks/ponytail-config.js` | `ae81c3552064c9a9f0b9c0e8ec8a959af56f5599f0c899dd79659ea9a101dfc4` | `ae81c3552064c9a9f0b9c0e8ec8a959af56f5599f0c899dd79659ea9a101dfc4` | verbatim |
| `hooks/ponytail-instructions.js` | `36521752b3444ef8daa823edaa996170e6af2cd45c82193644acb3a42f3395f4` | `36521752b3444ef8daa823edaa996170e6af2cd45c82193644acb3a42f3395f4` | verbatim |
| `hooks/ponytail-runtime.js` | `52d8e66d542d49217a9eb721942e7bd9f4ee46a56615fb3f53430276cfe3a592` | `52d8e66d542d49217a9eb721942e7bd9f4ee46a56615fb3f53430276cfe3a592` | verbatim |
| `hooks/ponytail-subagent.js` | `8da045eb96b5b919655bf4c12abfc7e5163af29b62b97ccaf633b75099390315` | `8da045eb96b5b919655bf4c12abfc7e5163af29b62b97ccaf633b75099390315` | verbatim |
| `skills/ponytail/SKILL.md` | `9badd22a32e19cb884e46dfa8d3aae82bb81dfa5484105b8b4f0262df823a509` | `9badd22a32e19cb884e46dfa8d3aae82bb81dfa5484105b8b4f0262df823a509` | verbatim |
| `LICENSE` | `fb1bc6909ac3ef82d5c22106e32ef682b0cff66788fa915fb9b53b15c9d2f3ab` | `fb1bc6909ac3ef82d5c22106e32ef682b0cff66788fa915fb9b53b15c9d2f3ab` | verbatim |
| `hooks/ponytail-activate.js` | `6e492e997aa3e01560046daaed288b1cf68c596cc2b227744ec8b9fbdb5a230a` | `364fa732d2d8806c99ab6ba89ab29f0689831a9f28d61f651b3da453c7cd7a94` | patched (P4) |

New (not from upstream): `.claude-plugin/plugin.json` (no `modules`, `userConfig` or `types`), `hooks/hooks.json` (SessionStart and SubagentStart only, shell form, 10 s timeout), `UPSTREAM.md`, `patches/`.

## Patches (`patches/*.patch`, apply with `git apply -p1` from this directory on the pristine upstream file)

| Patch | File | Why |
| - | - | - |
| P4 | `hooks/ponytail-activate.js` | Disables the statusline nudge (asks the agent to edit `settings.json` in every fresh Pod) and the codebase map (runs `git ls-files` and injects repo-derived names into the context). |

Every patched line carries a `MAGMAOPS PATCH` comment.

## Dropped from upstream

The `UserPromptSubmit` hook (`ponytail-mode-tracker.js`): it emits nothing on ordinary prompts, so `/ponytail lite|full|ultra|off` and "stop ponytail" no longer update the hook flag; the model still follows the skill text. The band **mod** (`hooks/band/*`: writes a per-turn cost CSV, can POST it to a webhook with a bearer token), `ponytail-band-import.js`, `ponytail-map.js`, statusline scripts, the `userConfig` (ledger, webhook URL and token, send names), other-host hook files and adapters, and all skills except `ponytail` (`-audit`, `-debt`, `-gain`, `-help`, `-review`).

## State written at runtime (all under `$CLAUDE_CONFIG_DIR`, default `~/.claude`)

`.ponytail-active`, `ponytail-modes/<sha256 of project dir>`. Nothing is written into this plugin directory. No network access; no child process on the kept paths (the only `execFileSync` is the disabled map).

## Upgrading

Never copy over the top. Clone upstream in a scratch directory, `git diff <old>..<new>` over the kept files above, read every hook change in full, re-apply the patch, update this file, run `claude-skills/tests/hooks-smoke.sh`, then PR and review. See `docs/skills-design.md`, "Upgrading a vendored plugin".
