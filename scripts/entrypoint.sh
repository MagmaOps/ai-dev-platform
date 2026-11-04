#!/usr/bin/env bash
# Verifies the environment, then stays alive so you can `kubectl exec` into it.
# Claude Code is not started automatically.
set -u

echo "== claude-dev starting =="
# Default Claude Code plugins (never fatal; see docs/skills-design.md).
/usr/local/bin/install-skills.sh
/usr/local/bin/healthcheck.sh || echo "Healthcheck reported problems (see above)."

echo "== ready; connect with: kubectl exec -it deployment/claude-dev -n ai-development -- bash =="

# Run the given command if one was passed (e.g. `docker run ... bash`), else idle.
if [ "$#" -gt 0 ]; then
  exec "$@"
fi

# As PID 1, a bare `sleep` ignores SIGTERM and Pod deletion would wait out the grace period.
trap 'exit 0' TERM INT
sleep infinity &
wait $!
