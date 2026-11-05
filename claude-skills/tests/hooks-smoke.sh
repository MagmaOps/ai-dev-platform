#!/usr/bin/env bash
# Smoke test for the vendored always-on hooks and the marketplace.
#
#   claude-skills/tests/hooks-smoke.sh
#
# Hooks run under Node's permission model: they may read anywhere but write only to the fake
# Claude config dir, and may not start child processes. Everything runs in a temp dir; the real
# ~/.claude is never touched. Needs node 22+; the marketplace checks also need `claude`.
set -u

root=$(cd "$(dirname "$0")/../.." && pwd)
cav=$root/claude-skills/plugins/caveman
pony=$root/claude-skills/plugins/ponytail
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
home=$tmp/home
mkdir -p "$home/.claude" "$home/proj"
sid=11111111-aaaa-bbbb-cccc-222222222222
fail=0

ok()  { echo "ok    $*"; }
bad() { echo "FAIL  $*"; fail=1; }
has() { grep -q -i -- "$2" <<<"$1" && ok "$3" || bad "$3 (missing: $2)"; }
hasnt() { grep -q -i -- "$2" <<<"$1" && bad "$3 (found: $2)" || ok "$3"; }

# run <plugin root> <node args...>; payload on stdin
run() {
  local r=$1; shift
  env -i PATH="$PATH" HOME="$home" CLAUDE_CONFIG_DIR="$home/.claude" CLAUDE_PLUGIN_ROOT="$r" \
    CLAUDE_PROJECT_DIR="$home/proj" CLAUDE_CODE_ENTRYPOINT=cli \
    node --permission --allow-fs-read='*' --allow-fs-write="$home/.claude" "$@"
}
payload() { printf '{"session_id":"%s","cwd":"%s","source":"%s","prompt":"%s","agent_type":"Explore"}' "$sid" "$home/proj" "$1" "$2"; }

echo "== caveman"
out=$(payload startup "" | run "$cav" "$cav/src/hooks/caveman-activate.js") || bad "SessionStart exit code"
has "$out" "CAVEMAN MODE ACTIVE" "SessionStart emits ruleset"
has "$out" "substantial change" "ruleset carries the explanation exemption (P3)"
hasnt "$out" "STATUSLINE" "no statusline nudge (P1)"
out=$(payload startup "fix the failing test" | run "$cav" "$cav/src/hooks/caveman-mode-tracker.js") || bad "UserPromptSubmit exit code"
has "$out" "CAVEMAN MODE ACTIVE (caveman)" "per-turn reminder"
has "$out" "substantial change" "reminder carries the explanation exemption (P2)"
out=$(payload startup "" | run "$cav" "$cav/src/hooks/caveman-activate.js" --subagent) || bad "SubagentStart exit code"
has "$out" "CAVEMAN MODE ACTIVE" "SubagentStart injects ruleset"
payload startup "stop caveman" | run "$cav" "$cav/src/hooks/caveman-mode-tracker.js" >/dev/null || bad "stop caveman exit code"
out=$(payload startup "fix the failing test" | run "$cav" "$cav/src/hooks/caveman-mode-tracker.js")
[ -z "$out" ] && ok "no reminder after 'stop caveman'" || bad "reminder after 'stop caveman'"
out=$(payload startup "" | run "$cav" "$cav/src/hooks/caveman-activate.js" --subagent)
[ -z "$out" ] && ok "no subagent injection while off" || bad "subagent injection while off"
out=$(payload compact "" | run "$cav" "$cav/src/hooks/caveman-activate.js")
hasnt "$out" "CAVEMAN MODE ACTIVE" "compact keeps it off"
out=$(payload clear "" | run "$cav" "$cav/src/hooks/caveman-activate.js")
has "$out" "CAVEMAN MODE ACTIVE" "clear re-arms"

echo "== ponytail"
out=$(printf '{"source":"startup"}' | run "$pony" "$pony/hooks/ponytail-activate.js") || bad "SessionStart exit code"
has "$out" "PONYTAIL MODE ACTIVE" "SessionStart emits ruleset"
hasnt "$out" "STATUSLINE" "no statusline nudge (P4)"
hasnt "$out" "Codebase map" "no codebase map (P4)"
out=$(printf '{"agent_type":"Explore"}' | run "$pony" "$pony/hooks/ponytail-subagent.js") || bad "SubagentStart exit code"
has "$out" "PONYTAIL MODE ACTIVE" "SubagentStart injects ruleset"

echo "== files written"
unexpected=$(cd "$home" && find . -type f ! -name settings.json | grep -v -E '^\./\.claude/(\.caveman-active|\.caveman-mode-log\.jsonl|\.caveman-sessions/[A-Za-z0-9_-]+\.mode|\.ponytail-active|ponytail-modes/[0-9a-f]{64})$' || true)
[ -z "$unexpected" ] && ok "only the expected state files exist" || { bad "unexpected files:"; echo "$unexpected"; }
[ -z "$(find "$cav" "$pony" -newer "$tmp" -type f 2>/dev/null)" ] && ok "plugin directories untouched" || bad "plugin directory modified"

# The marketplace checks use CLI features of the pinned Claude Code, so they run only on that version or newer.
pin=$(sed -n 's/^ARG CLAUDE_CODE_VERSION=//p' "$root/docker/Dockerfile")
have=$(claude --version 2>/dev/null | cut -d' ' -f1)
if [ -z "$have" ]; then
  echo "skip  marketplace checks (claude not found)"
elif [ -n "$pin" ] && [ "$(printf '%s\n%s\n' "$pin" "$have" | sort -V | head -1)" != "$pin" ]; then
  echo "skip  marketplace checks (claude $have is older than the pinned $pin; update it to run them)"
else
  echo "== marketplace (claude $have)"
  cfg=$tmp/cfg; mkdir -p "$cfg"
  export CLAUDE_CONFIG_DIR=$cfg
  claude plugin validate --strict "$root" >/dev/null 2>&1 && ok "validate --strict" || { bad "validate --strict"; claude plugin validate --strict "$root" 2>&1 | tail -8; }
  claude plugin marketplace add "$root" >/dev/null 2>&1 && ok "marketplace add" || bad "marketplace add"
  for p in caveman ponytail; do
    claude plugin install "$p@magmaops-skills" >/dev/null 2>&1 && ok "install $p" || bad "install $p"
  done
  det=$(claude plugin details caveman 2>&1); has "$det" "Hooks (3)" "caveman: 3 hooks"; has "$det" "Skills (2)" "caveman: 2 skills"
  det=$(claude plugin details ponytail 2>&1); has "$det" "Hooks (2)" "ponytail: 2 hooks"; has "$det" "Skills (1)" "ponytail: 1 skill"
  hasnt "$det" "MCP servers ([1-9]" "ponytail: no MCP servers"
fi

[ "$fail" = 0 ] && echo "ALL OK" || echo "FAILURES"
exit "$fail"
