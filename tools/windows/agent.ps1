<#
.SYNOPSIS
  Connect to the Claude agent Pod in the homelab (Herdr session), optionally starting a new agent first.

.EXAMPLE
  agent                                      # attach to the running Herdr session
.EXAMPLE
  agent -Repo MagmaOps/some-repo -Task fix-login   # clone, branch ai/fix-login, start claude, then attach

Detach with Ctrl+B then Q. Agents keep running; run `agent` again to reattach.
#>
param(
    [string]$Repo,
    [string]$Task,
    [string]$Namespace = 'ai-development',
    [string]$Deployment = 'claude-dev'
)

$ErrorActionPreference = 'Stop'

if (($Repo -and -not $Task) -or ($Task -and -not $Repo)) {
    throw 'Give both -Repo and -Task, or neither.'
}

Write-Host "Waiting for $Deployment to be ready..."
kubectl rollout status "deployment/$Deployment" -n $Namespace --timeout=120s
if ($LASTEXITCODE -ne 0) { throw "Deployment $Deployment is not ready." }

if ($Repo) {
    kubectl exec "deployment/$Deployment" -n $Namespace -- new-agent $Repo $Task
    if ($LASTEXITCODE -eq 3) { Write-Host "Task '$Task' already exists; attaching to the running session." }
    elseif ($LASTEXITCODE -ne 0) { throw 'new-agent failed (see message above).' }
}

kubectl exec -it "deployment/$Deployment" -n $Namespace -- herdr
