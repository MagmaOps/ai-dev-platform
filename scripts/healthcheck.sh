#!/usr/bin/env bash
# Verifies the dev environment. Never prints credential values.
# Exit code 0 = healthy, 1 = a required tool or directory is missing.
set -u

fail=0

for tool in claude gh git node python3 jq curl bash rg herdr tmux new-agent; do
  if command -v "$tool" >/dev/null 2>&1; then
    echo "ok       tool: $tool"
  else
    echo "MISSING  tool: $tool"
    fail=1
  fi
done

if [ -d /workspace ] && [ -w /workspace ]; then
  echo "ok       /workspace is writable"
else
  echo "MISSING  /workspace not writable"
  fail=1
fi

if [ "$(id -u)" = "0" ]; then
  echo "FAIL     running as root"
  fail=1
else
  echo "ok       running as non-root ($(id -un))"
fi

# Credentials: report presence only.
for var in GH_TOKEN CLAUDE_CODE_OAUTH_TOKEN; do
  if [ -n "${!var:-}" ]; then
    echo "ok       credential set: $var"
  else
    echo "warn     credential not set: $var"
  fi
done

# Default plugins: informational only, never fails the healthcheck.
skills_status=$HOME/.cache/claude-skills/status
if [ -r "$skills_status" ]; then
  state=$(sed -n 's/^state=//p' "$skills_status")
  case $state in
    ok)       echo "ok       skills: $(sed -n 's/^ref=//p' "$skills_status") plugins: $(sed -n 's/^plugins=//p' "$skills_status")" ;;
    disabled) echo "ok       skills: disabled" ;;
    *)        echo "warn     skills: $state ($(sed -n 's/^reason=//p' "$skills_status"))" ;;
  esac
else
  echo "warn     skills: install-skills.sh has not run"
fi

if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
  echo "WARN     ANTHROPIC_API_KEY is set; Claude Code may bill the API instead of the subscription"
fi

exit "$fail"
