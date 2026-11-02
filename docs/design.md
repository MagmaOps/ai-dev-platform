# AI Development Platform — Technical Design Document

**Project:** ai-development-platform  
**Platform:** Kubernetes (k3s) homelab  
**Client:** Windows 11  
**Primary AI agent:** Claude Code  
**Status:** Initial implementation / MVP

---

## 1. Project objective

Build a self-hosted, reproducible AI development environment running on an existing k3s Kubernetes cluster.

The environment must allow me to connect from my Windows 11 workstation, interact with Claude Code, provide development tasks, and allow the agent to work on GitHub repositories.

The development environment must be ephemeral.

Kubernetes Pods and nodes may disappear frequently because the underlying Proxmox homelab is not always running. I must be able to recreate the complete environment without manually reinstalling tools or reconfiguring everything.

The system should eventually support both:

1. Interactive development sessions.
2. Automated, isolated agent execution through Kubernetes Jobs.

The initial implementation should prioritize the interactive experience while keeping the architecture reusable for automated jobs.

## 2. Existing infrastructure

The existing environment:

- Three physical Proxmox servers.
- One k3s Kubernetes cluster.
- One control-plane node and four worker nodes.
- Argo CD.
- Prometheus and Grafana.
- GitHub repositories.
- Windows 11 as the primary workstation.

The implementation must not assume that a particular Kubernetes node is always available.

Do not introduce additional infrastructure components unless they solve a concrete requirement.

## 3. Architectural principles

### 3.1 Ephemeral compute

- Agent Pods must be disposable.
- No important data should exist exclusively inside a Pod.
- Replacing a Pod must not require manual setup.
- Repositories must be cloned from GitHub when a new environment starts.
- All development tools must be included in a versioned container image.
- No persistent workspace PVC is required for the initial implementation.

### 3.2 Reproducibility

Everything required to recreate the environment must be represented in Git or Kubernetes Secrets.

The container image must include:

- Claude Code.
- Git.
- GitHub CLI (`gh`).
- Node.js.
- Python 3.
- Essential development utilities.
- Bash.
- CA certificates.
- jq and curl.

Use pinned versions where practical.

Do not install all dependencies every time a Pod starts.

### 3.3 Security

- Run containers as a non-root user.
- Never bake credentials into container images.
- Never commit credentials to Git.
- Use Kubernetes Secrets for sensitive information.
- Do not mount the host Docker socket.
- Do not mount the Kubernetes host filesystem.
- Do not provide cluster-admin permissions.
- Do not mount the host kubeconfig.
- Do not give the agent unrestricted Kubernetes API access.
- Restrict GitHub access to explicitly authorized repositories.
- Do not expose the development environment publicly.
- Use resource requests and limits.

The initial agent should have internet egress for GitHub, Anthropic and dependency repositories.

Internal cluster access should be restricted wherever practical.

## 4. Proposed architecture

```text
Windows 11
    |
    | kubectl exec
    |
    v
k3s Cluster
    |
    +-- ai-development namespace
          |
          +-- claude-dev Deployment
          |      |
          |      +-- Claude Code
          |      +-- Git
          |      +-- GitHub CLI
          |      +-- Node.js
          |      +-- Python
          |      +-- /workspace
          |
          +-- ConfigMap
          |
          +-- Kubernetes Secrets
                 |
                 +-- GitHub credentials
                 +-- Claude authentication (if required)
```

External services:

- GitHub: source code and version control.
- Anthropic: Claude model inference.
- GHCR: container image registry.

## 5. Kubernetes resources

Create a dedicated namespace:

`ai-development`

Initial resources:

- Namespace.
- ServiceAccount with no additional Kubernetes permissions.
- ConfigMap for non-sensitive configuration.
- Secret for GitHub credentials.
- Secret for Claude authentication, if using a supported non-interactive subscription authentication method.
- Deployment for the interactive development environment.

Do not create a PVC initially.

Do not create an Ingress or public-facing Service.

The Pod should be accessible using:

```bash
kubectl exec -it deployment/claude-dev \
  -n ai-development -- bash
```

The Deployment should maintain one interactive development Pod.

Use a sensible node scheduling strategy that allows recreation on any suitable worker.

Avoid strict node affinity to a specific Proxmox host.

## 6. Authentication

### GitHub

Initially use a fine-grained GitHub Personal Access Token with access restricted to explicitly selected repositories.

The agent should be able to:

- Clone repositories.
- Create branches.
- Commit changes.
- Push branches.

Do not grant organization administration or repository administration permissions.

Avoid placing tokens in Git remote URLs or shell history.

Investigate GitHub App authentication as a future improvement.

### Claude Code

I have an active Claude Pro subscription.

The preferred authentication method is subscription authentication rather than Anthropic API pay-as-you-go billing.

Investigate Claude Code's officially supported authentication options for headless and containerized environments.

Preferred approach:

- Use the supported Claude subscription OAuth authentication.
- Evaluate `claude setup-token` and `CLAUDE_CODE_OAUTH_TOKEN` for non-interactive execution.
- Let the account owner generate and provision their own credential.
- Store credentials outside the container image and Git repository.
- Do not implement unsupported credential extraction or token-sharing mechanisms.
- Do not configure `ANTHROPIC_API_KEY` by default.

If authentication requires interactive login, document the login procedure and the consequences of Pod replacement.

Verify the active authentication method using Claude Code's `/status` command.

Do not silently fall back to paid API billing.

## 7. Container image

Create a Dockerfile under:

`docker/Dockerfile`

Requirements:

- Use a maintained, minimal Linux base image.
- Install Claude Code using Anthropic's official installation method.
- Install Git, GitHub CLI, Node.js and Python.
- Create a non-root development user.
- Create `/workspace`.
- Use a predictable working directory.
- Support interactive Bash sessions.
- Support future non-interactive Claude Code execution.
- Keep the image reasonably small.
- Pin important dependency versions.

Publish the image to GitHub Container Registry.

Do not use `latest` as the production deployment tag.

## 8. Startup behavior

The initial Pod should:

1. Start using the prebuilt development image.
2. Prepare the workspace directory.
3. Verify required tools are installed.
4. Verify that credentials are available without printing their values.
5. Remain available for interactive connections.

Do not automatically start Claude Code before I connect.

I want to decide when to start an interactive session.

Repository cloning should initially be manual so that I can work with different repositories.

Future versions may support configurable automatic repository cloning.

## 9. Windows 11 connectivity

The initial connection mechanism should use kubectl from Windows 11.

Example:

```powershell
kubectl exec -it deployment/claude-dev `
  -n ai-development -- bash
```

Inside the container:

```bash
claude
```

The environment should support normal interactive Claude Code usage.

Document how to exit the session and reconnect.

Do not expose SSH or a public web terminal in the MVP.

Evaluate Herdr as an optional Windows-based agent terminal manager in a later phase.

## 10. Git workflow

The agent must work using feature branches.

Example:

```bash
git clone https://github.com/OWNER/REPOSITORY.git

cd REPOSITORY

git checkout -b ai/implement-feature

claude
```

The agent may:

- Inspect the repository.
- Modify application code.
- Run tests.
- Run linters.
- Create commits.
- Push its feature branch.

The agent must not automatically merge pull requests into the default branch.

Human review is required before merging.

Avoid committing generated files, credentials, local environment files or unrelated changes.

## 11. Initial repository structure

Create the following structure:

```text
ai-development-platform/
│
├── README.md
│
├── docker/
│   └── Dockerfile
│
├── scripts/
│   ├── entrypoint.sh
│   └── healthcheck.sh
│
├── kubernetes/
│   ├── base/
│   │   ├── namespace.yaml
│   │   ├── serviceaccount.yaml
│   │   ├── configmap.yaml
│   │   ├── deployment.yaml
│   │   └── kustomization.yaml
│   │
│   └── overlays/
│       └── homelab/
│           └── kustomization.yaml
│
└── docs/
    ├── architecture.md
    ├── authentication.md
    └── operations.md
```

Adjust the structure only when there is a clear reason.

Never commit populated Secret manifests containing credentials.

Provide safe examples or placeholders for local secret creation.

## 12. Future development phases

Do not implement these features in the initial MVP.

### Phase 2: Improved interaction

- Integrate Herdr or another terminal manager.
- Support multiple interactive agent sessions.
- Support multiple repositories.
- Improve workspace isolation.

### Phase 3: Automated agent execution

Introduce Kubernetes Jobs.

Each task should:

1. Create a disposable Pod.
2. Clone a specified repository.
3. Create a feature branch.
4. Execute Claude Code in headless mode.
5. Run tests.
6. Commit and push changes.
7. Save execution logs.
8. Complete and terminate the Job.

### Phase 4: Task management

- Task queue.
- Task status.
- Retry handling.
- Usage-limit detection.
- Optional scheduled execution.
- Human approval before merging.

### Phase 5: Observability

Integrate with existing Prometheus and Grafana.

Monitor:

- Agent Pod availability.
- Job execution duration.
- Job success and failure.
- CPU and memory consumption.
- Restart counts.
- Queue length.
- Task execution history.

Do not expose credentials or sensitive prompts in metrics or logs.

## 13. Operational requirements

The environment must be easily replaceable.

Test these scenarios:

1. Delete the agent Pod.
2. Verify Kubernetes recreates it.
3. Confirm that the development tools are still available.
4. Confirm that GitHub authentication works.
5. Confirm that Claude authentication works or document the required re-authentication.
6. Clone a repository again.
7. Make and push a test commit.
8. Recreate the Pod on another worker node.
9. Confirm that the environment works without access to the original node's local filesystem.

Document the recovery process.

## 14. Implementation strategy

Implement incrementally.

Do not generate the complete platform in one step.

Use these milestones:

**Milestone 1:** Build and test the development Docker image.

**Milestone 2:** Deploy the interactive development Pod to k3s.

**Milestone 3:** Configure GitHub authentication and repository access.

**Milestone 4:** Configure and verify Claude Pro authentication.

**Milestone 5:** Verify complete Pod replacement and recovery.

**Milestone 6:** Prepare the environment for future Kubernetes Jobs.

At the end of each milestone:

- Explain what was implemented.
- Explain the important design decisions.
- Provide commands to verify functionality.
- Run relevant tests.
- Document any limitations.
- Stop and wait for human approval before starting the next milestone.

## 15. Definition of Done for MVP

The MVP is complete when:

- The container image builds successfully.
- The image is available in GHCR.
- Argo CD or kubectl can deploy the environment.
- The agent runs as a non-root user.
- I can connect from Windows 11.
- Claude Code runs interactively.
- Claude authenticates using my Pro subscription without unintended API billing.
- The agent can clone a private GitHub repository.
- The agent can create a branch, commit and push changes.
- Deleting and recreating the Pod does not require rebuilding the environment.
- No critical data depends on the original Pod or Kubernetes node.
- Documentation explains how to operate and recover the environment.

---

## Instructions to the implementation agent

You are acting as a senior platform engineer implementing this design.

The owner of this project wants to learn Kubernetes and DevOps, not simply receive generated YAML.

Follow these rules:

1. Start by reviewing the design and identifying technical concerns.
2. Ask for missing infrastructure information rather than assuming it.
3. Explain the implementation before making substantial changes.
4. Work milestone by milestone.
5. Do not implement future phases prematurely.
6. Do not introduce Helm, operators, service meshes, databases or unnecessary controllers without justification.
7. Follow Kubernetes security best practices.
8. Use Kustomize for Kubernetes configuration.
9. Keep the implementation compatible with k3s.
10. Never make destructive changes to the existing cluster.
11. Never apply manifests to the cluster without explicit approval.
12. Never expose or print secrets.
13. Never commit credentials.
14. Provide exact verification commands.
15. Stop after each milestone and wait for approval.

**First task:** Review this design, identify any technical problems or missing decisions, and propose the implementation plan for Milestone 1. Do not start writing code until the owner approves the plan.