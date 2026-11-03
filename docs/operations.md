# Operations

All commands run in Git Bash or PowerShell with `kubectl` pointed at the homelab cluster.

## Connect (Windows launcher)

Agents run inside [Herdr](https://github.com/ogulcancelik/herdr) in the Pod, so they keep running when your connection drops. Use the launcher in `tools/windows/`:

```powershell
agent                                            # attach to the Herdr session
agent -Repo MagmaOps/<repo> -Task <task-name>    # clone, branch ai/<task-name>, start claude, then attach
```

To use `agent` from any terminal, add `D:\Work\projects\ai-dev-platform\tools\windows` to your PATH (it contains `agent.cmd`), or run `.\tools\windows\agent.ps1`. For a one-click Windows Terminal profile, add this to `profiles.list` in its settings:

```json
{ "name": "Claude agents", "commandline": "powershell -NoProfile -File D:\\Work\\projects\\ai-dev-platform\\tools\\windows\\agent.ps1" }
```

The launcher waits for the Deployment to be ready, then runs `kubectl exec`. Plain `kubectl exec -it deployment/claude-dev -n ai-development -- bash` still works as a fallback.

### Herdr basics

- Detach: `Ctrl+B` then `Q`. Agents keep running. Run `agent` again to reattach.
- Workspace = project, tab = layout, pane = a real terminal. `Ctrl+B` then `?` lists the keys; `v` splits right, `-` splits down, `c` new tab, `w` switch workspace.
- The sidebar shows each agent as working, blocked, idle or done.
- Several clients can attach at once.
- Inside the Pod, `new-agent <owner/repo> <task>` does the same as the launcher's `-Repo/-Task` (clone to `/workspace/<task>`, branch `ai/<task>`, Herdr workspace running `claude`).
- To stop everything cleanly: `herdr server stop` (this ends all panes).

Herdr survives a dropped connection, **not** Pod replacement. If the Pod is recreated, the panes and agents are gone. Push often.

## Work on a repository by hand

```bash
cd /workspace
git clone https://github.com/MagmaOps/<repo>.git && cd <repo>
git checkout -b ai/<short-description>
claude
```

The agent works on feature branches and pushes them. Merging into the default branch needs a pull request and human review (enforced by branch protection, not by the token). One shared Pod means one 2 CPU / 4Gi budget and one Pro usage limit: two or three agents at a time is realistic.

## What survives a Pod replacement

| Survives | Lost |
| - | - |
| Image and tools, git identity, `GH_TOKEN`, `CLAUDE_CODE_OAUTH_TOKEN` (all come from the image, ConfigMap, Secrets) | Everything in `/workspace` and `/home/dev` that is not pushed to GitHub, Claude Code session history, first-run preferences |

**Push your work before the Pod can disappear.** The homelab may be shut down, and nodes can be drained.

## Recover the environment

The Deployment recreates a deleted or evicted Pod automatically. If the Pod is gone because the cluster was down, it comes back by itself when the cluster does; nothing needs reinstalling.

Check health:

```bash
kubectl get pod -n ai-development -l app.kubernetes.io/name=claude-dev -o wide
kubectl logs deployment/claude-dev -n ai-development       # healthcheck output at start-up
kubectl exec deployment/claude-dev -n ai-development -- healthcheck.sh
kubectl exec deployment/claude-dev -n ai-development -- gh auth status
kubectl exec deployment/claude-dev -n ai-development -- claude auth status
```

Force a fresh Pod (also picks up a changed Secret or ConfigMap):

```bash
kubectl rollout restart deployment/claude-dev -n ai-development
```

Tested: deleting the Pod recreates it in about 2 seconds, with all tools, GitHub login and Claude login working and `/workspace` empty.

## Troubleshooting

| Symptom | Likely cause |
| - | - |
| `claude` asks for a login method | `CLAUDE_CODE_OAUTH_TOKEN` is missing. Check the sealed file is listed in `workload/prod/kustomization.yaml`, Argo has synced, and the Pod was restarted after the Secret appeared. |
| `gh`: `invalid header field value for "Authorization"` | Whitespace in the token. Re-seal with `tr -d '[:space:]'`. |
| `git push` returns 403 but the web UI works | Token resource owner is the user, not MagmaOps, or it lacks Contents: Read and write, or an org owner has not approved it. |
| `git push` to the default branch rejected (`GH013`) | Expected. Push a feature branch and open a pull request. |
| `ANTHROPIC_API_KEY` warning at start-up | Something set an API key; remove it, or Claude Code will bill the API. |

## Upgrade the image

1. Bump the version build args in `docker/Dockerfile` (`NODE_VERSION`, `GH_VERSION`, `CLAUDE_CODE_VERSION`, and `HERDR_VERSION` together with `HERDR_SHA256` from https://herdr.dev/latest.json).
2. `docker build -f docker/Dockerfile -t magmakomer/claude-dev:<new-version> .` and test locally.
3. `docker push magmakomer/claude-dev:<new-version>`.
4. Update the tag in `k8s/base/kustomization.yaml` and in `k3s-lab` `workload/prod/kustomization.yaml`, commit and push both. Argo rolls out the new Pod.

Do not deploy `latest`.

## Renew credentials

See [authentication.md](authentication.md). Calendar the GitHub PAT expiry and the Claude token expiry (about one year after 2026-11-03).
