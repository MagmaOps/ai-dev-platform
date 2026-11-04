# Upstream: caveman

Unofficial, trimmed and modified copy of **caveman** for MagmaOps agent Pods. Not affiliated with or endorsed by the author. "Caveman" is a trademark of Julius Brussee (see upstream `TRADEMARKS.md`); the name is used here only to refer to the upstream project.

| | |
| - | - |
| Upstream | https://github.com/juliusbrussee/caveman |
| Reviewed commit | `2e068f735253cce28256744804785f01887d9646` (2026-11-01, plugin version 4.0.1) |
| Licence | Apache-2.0 (`LICENSE`); `NOTICE` and `LICENSE-MIT` kept verbatim (pre-3.0.0 contributions stay MIT) |
| Copied on | 2026-11-04 |

## Files

Hashes are SHA-256. "verbatim" means the vendored file equals the upstream file at the reviewed commit. Paths are relative to this directory and to the upstream repo root.

| Path | Upstream sha256 | Vendored sha256 | Status |
| - | - | - | - |
| `src/hooks/caveman-config.js` | `64762133d3467b1f4ea479c0d4fbb40a141a3f0e4423e8fd37688e8233aab4c6` | `64762133d3467b1f4ea479c0d4fbb40a141a3f0e4423e8fd37688e8233aab4c6` | verbatim |
| `src/hooks/caveman-parse.js` | `595d7bbb4634c7533cf16705314d8e58b7c8409ab0426f2b076a1b85d821ecce` | `595d7bbb4634c7533cf16705314d8e58b7c8409ab0426f2b076a1b85d821ecce` | verbatim |
| `LICENSE` | `cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30` | `cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30` | verbatim |
| `LICENSE-MIT` | `5eb826cd03151bcc7cce3f80d40e87733237fedfc6c36d6908aca5fd650a0bdb` | `5eb826cd03151bcc7cce3f80d40e87733237fedfc6c36d6908aca5fd650a0bdb` | verbatim |
| `NOTICE` | `20112dc6e62e91da4f03c29fd10cfa41743a9c526389fdf1396c3649c18216fc` | `20112dc6e62e91da4f03c29fd10cfa41743a9c526389fdf1396c3649c18216fc` | verbatim |
| `src/hooks/caveman-activate.js` | `c7e06f2766c616ac791a923d8c2c5bfa654742cbcd5e86d18575b529ce48d9f9` | `0646919bef100e43cfffc2bbc47957da513fd347971ea7e5174842025c5d2539` | patched (P1) |
| `src/hooks/caveman-mode-tracker.js` | `354e273df2ee4308bf35dc3ac11c0d80eb60da60d099b32e0d921cc2f0882d99` | `fb43ce3f8154417e2f8a6f3fb97e58504612efd7e7ca4f9e3e647942aeb150ef` | patched (P2) |
| `skills/caveman/SKILL.md` | `415d43518f2b1a9498c15a445d4657117b129ee5e81b19454ce348439cc6672b` | `241f325dbb37bf9a01dcdd195c71a9c9bc7b7505c968f1ccfc5784f242a45528` | patched (P3) |
| `skills/ultracave/SKILL.md` | `a8da5b0b3501b853e1b98f2ae09fe8dc9c0edf481b1d3fa9529f8557011c1ef8` | `2a71173fa3098362f8a8e9e14ac8ebdc93b471da7e401119e50c5ff3de86545f` | patched (P3) |

New (not from upstream): `.claude-plugin/plugin.json` (three hooks, shell form, 10 s timeout, `${CLAUDE_PLUGIN_ROOT}`), `UPSTREAM.md`, `patches/`.

## Patches (`patches/*.patch`, apply with `git apply -p1` from this directory on the pristine upstream files)

| Patch | File | Why |
| - | - | - |
| P1 | `src/hooks/caveman-activate.js` | Stop after emitting the ruleset; skips the statusline "setup" nudge, which would ask the agent to edit `settings.json` in every fresh Pod. |
| P2 | `src/hooks/caveman-mode-tracker.js` | Per-turn reminder exempts explanations of substantial changes (see docs/skills-design.md). |
| P3 | `skills/caveman/SKILL.md`, `skills/ultracave/SKILL.md` | Same exemption in the skill text. |

Every patched line carries a `MAGMAOPS PATCH` comment (Apache-2.0 section 4(b)).

## Dropped from upstream

Hooks: `SessionEnd` / `caveman-stats.js` (reads whole transcripts, writes history), `cavecrew-model-overrides.js`, statusline scripts, install/uninstall scripts, other-host hooks. Skills: all except `caveman` and `ultracave` (including `caveman-setup`, which routes a repo through the hosted Caveman Cloud gateway, and `caveman-compress`). Agents (`cavecrew-*`), `commands/`, `engine/`, `proxy/`, `mcp/`, `browse/`, the browser extension and everything else. `/caveman-stats` and `/megacave` are therefore inert or fall back to a built-in one-line ruleset.

## State written at runtime (all under `$CLAUDE_CONFIG_DIR`, default `~/.claude`)

`.caveman-active`, `.caveman-sessions/<session>.mode`, `.caveman-mode-log.jsonl`. Nothing is written into this plugin directory. No network access, no child process on the kept paths.

## Upgrading

Never copy over the top. Clone upstream in a scratch directory, `git diff <old>..<new>` over the kept files above, read every hook change in full (new `require`s, child processes, network, new state paths), re-apply the patches, update this file, run `claude-skills/tests/hooks-smoke.sh`, then PR and review. See `docs/skills-design.md`, "Upgrading a vendored plugin".
