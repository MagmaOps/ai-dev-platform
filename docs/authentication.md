# Authentication

Both credentials are Kubernetes Secrets, created as SealedSecrets in the `k3s-lab` repo. Never commit a plaintext Secret, never paste a token into a command line, a chat or a file. Use `read -rsp` so the value stays out of shell history.

## GitHub (`GH_TOKEN`)

A fine-grained PAT for the dedicated agent account `magma-claude-1`.

Requirements when creating it (as the agent account):

- **Resource owner: MagmaOps.** A token owned by the user account cannot write to org repos (it authenticates, then returns 403 on push).
- **Only select repositories**, and only the ones the agent needs. Do not include `k3s-lab` or `k3s-lab-ci`: Argo CD auto-syncs `k3s-lab` `main`.
- Permissions: Contents: Read and write, Pull requests: Read and write, Metadata: Read. Nothing else.
- The org must allow fine-grained PATs, and an owner may need to approve the request.
- Branch protection (pull request required) on every repo the agent can write to. This is what prevents the agent merging; the token alone does not.

Seal and deploy (Git Bash):

```bash
cd /d/Work/projects/k3s-lab
read -rsp "Agent GitHub PAT: " GH_PAT; echo
GH_PAT=$(printf %s "$GH_PAT" | tr -d '[:space:]')   # stray whitespace makes gh report an invalid header

kubectl create secret generic claude-dev-github \
  --namespace ai-development \
  --from-literal=GH_TOKEN="$GH_PAT" \
  --dry-run=client -o yaml \
| kubeseal --format yaml > apps/ai-dev-platform/workload/prod/claude-dev-github-sealed.yaml
unset GH_PAT
```

Commit and push `k3s-lab`, let Argo sync, then restart the Pod (env vars from Secrets are read only at start).

**Expiry:** fine-grained PATs expire. Record the date you chose here: 04/11/2027. Renew by repeating the steps above.

## Claude Code (`CLAUDE_CODE_OAUTH_TOKEN`)

A one-year token from `claude setup-token`, tied to the account owner's Pro subscription. Generate it yourself, on a machine with a browser. It makes model requests only (no Remote Control, no claude.ai connectors) and does not refresh itself.

```bash
cd /d/Work/projects/k3s-lab
read -rsp "Claude OAuth token: " CC_TOKEN; echo
CC_TOKEN=$(printf %s "$CC_TOKEN" | tr -d '[:space:]')

kubectl create secret generic claude-dev-claude \
  --namespace ai-development \
  --from-literal=CLAUDE_CODE_OAUTH_TOKEN="$CC_TOKEN" \
  --dry-run=client -o yaml \
| kubeseal --format yaml > apps/ai-dev-platform/workload/prod/claude-dev-claude-sealed.yaml
unset CC_TOKEN
```

**Expiry:** generated about 2026-11-03, so it stops working about 2027-11. Renew before then.

**Never set `ANTHROPIC_API_KEY`.** It outranks the OAuth token in Claude Code's precedence order and would bill the API instead of the subscription. The healthcheck warns if it is present.

Verify the active method (no token is printed):

```bash
kubectl exec deployment/claude-dev -n ai-development -- claude auth status
# expect: "loggedIn": true, "authMethod": "oauth_token"
```

All agents share one Pro usage limit. Before building headless Jobs (design phase 3), check Anthropic's official help center for how `claude -p` / Agent SDK usage is counted against the subscription; reports on this were conflicting when this was written.

## Gotcha: a new SealedSecret must be listed in kustomization.yaml

Dropping the sealed file into `workload/prod/` does nothing until it is added under `resources:` in `workload/prod/kustomization.yaml`. Because both Secrets are `optional` in the Deployment, the Pod starts anyway and the credential is silently missing. The entrypoint prints which credentials are missing: check `kubectl logs deployment/claude-dev -n ai-development`.
