#!/usr/bin/env bash
# Installs the default Claude Code plugins from a SHA-pinned clone of the skills repo.
# Called by entrypoint.sh. Never fails the container: any problem is logged, recorded in the
# status file and the Pod starts without the plugins (fail-open).
#
# Config (env, from the ConfigMap; the real values live in k3s-lab):
#   CLAUDE_SKILLS_REPO          owner/repo on GitHub, or a full git URL
#   CLAUDE_SKILLS_REF           tag to clone. Empty = feature off.
#   CLAUDE_SKILLS_SHA           full commit the tag must point at. Required when REF is set.
#   CLAUDE_SKILLS_PLUGINS       space-separated plugin names to install
#   CLAUDE_SKILLS_HOOK_PLUGINS  space-separated plugin names allowed to contain hooks
set -u

repo=${CLAUDE_SKILLS_REPO:-}
ref=${CLAUDE_SKILLS_REF:-}
want_sha=${CLAUDE_SKILLS_SHA:-}
plugins=${CLAUDE_SKILLS_PLUGINS:-}
hook_ok=${CLAUDE_SKILLS_HOOK_PLUGINS:-}
dest=$HOME/.local/share/claude-skills
status=$HOME/.cache/claude-skills/status

state=failed
reason=""
installed=""
log() { echo "skills: $*"; }

finish() {
  mkdir -p "$(dirname "$status")"
  { echo "state=$state"; echo "ref=$ref"; echo "sha=${got_sha:-}"; echo "plugins=${installed# }"; echo "reason=$reason"; } > "$status"
  case $state in
    ok)       log "ok $ref ${got_sha:-} plugins:${installed:- none}" ;;
    disabled) log "disabled (CLAUDE_SKILLS_REF is empty)" ;;
    *)        log "FAILED: $reason (Pod continues without the default plugins)" ;;
  esac
  exit 0
}
fail() { reason=$1; finish; }

[ -n "$ref" ] || { state=disabled; finish; }
[ -n "$repo" ] || fail "CLAUDE_SKILLS_REPO is empty"
[[ $want_sha =~ ^[0-9a-f]{40}$ ]] || fail "CLAUDE_SKILLS_SHA must be a full 40-hex commit (refusing an unpinned clone)"
[[ $ref =~ ^[A-Za-z0-9._/-]+$ ]] || fail "CLAUDE_SKILLS_REF has unexpected characters"
case $repo in *://* | /*) url=$repo ;; *) url=https://github.com/$repo.git ;; esac

rm -rf "$dest"
GIT_TERMINAL_PROMPT=0 timeout 60 git -c advice.detachedHead=false clone --quiet --depth 1 --branch "$ref" "$url" "$dest" 2>&1 | sed 's/^/skills: git: /'
[ -d "$dest/.git" ] || fail "clone of $repo at $ref failed"
got_sha=$(git -C "$dest" rev-parse HEAD 2>/dev/null)
if [ "$got_sha" != "$want_sha" ]; then
  rm -rf "$dest"
  fail "REFUSED: $ref is at $got_sha, expected $want_sha"
fi

claude plugin validate "$dest" >/dev/null 2>&1 || fail "claude plugin validate failed on the clone"
mp=$(jq -r '.name // empty' "$dest/.claude-plugin/marketplace.json" 2>/dev/null)
[ -n "$mp" ] || fail "marketplace.json has no name"
claude plugin marketplace add "$dest" >/dev/null 2>&1 || fail "claude plugin marketplace add failed"

has_word() { [[ " $1 " == *" $2 "* ]]; }

# Prints one reason per line for each component this plugin must not have.
# Allowed: skills, commands, and hooks only for plugins in CLAUDE_SKILLS_HOOK_PLUGINS.
problems() { # name dir entry-json
  local n=$1 d=$2 entry=$3 k
  for k in .mcp.json .lsp.json bin monitors agents output-styles themes workflows settings.json; do
    [ -e "$d/$k" ] && echo "has $k"
  done
  for k in mcpServers lspServers modules monitors agents outputStyles themes channels settings experimental; do
    jq -e --arg k "$k" 'has($k)' <<<"$entry" >/dev/null 2>&1 && echo "marketplace entry has $k"
    jq -e --arg k "$k" 'has($k)' "$d/.claude-plugin/plugin.json" >/dev/null 2>&1 && echo "plugin.json has $k"
  done
  jq -e '.modules' "$d/hooks/hooks.json" >/dev/null 2>&1 && echo "hooks.json has modules"
  if [ -e "$d/hooks/hooks.json" ] || jq -e 'has("hooks")' "$d/.claude-plugin/plugin.json" >/dev/null 2>&1 \
     || jq -e 'has("hooks")' <<<"$entry" >/dev/null 2>&1; then
    has_word "$hook_ok" "$n" || echo "has hooks but is not in CLAUDE_SKILLS_HOOK_PLUGINS"
  fi
}

for p in $plugins; do
  entry=$(jq -c --arg p "$p" '.plugins[]? | select(.name == $p)' "$dest/.claude-plugin/marketplace.json")
  src=$(jq -r '.source // empty' <<<"$entry" 2>/dev/null)
  if [ -z "$entry" ] || [[ $src != ./* ]] || [[ $src == *..* ]]; then
    log "WARN $p: not in the marketplace or not a relative path, skipped"; continue
  fi
  bad=$(problems "$p" "$dest/${src#./}" "$entry")
  if [ -n "$bad" ]; then
    log "WARN $p: refused: $(tr '\n' ';' <<<"$bad")"; continue
  fi
  if claude plugin install "$p@$mp" >/dev/null 2>&1; then installed="$installed $p"; else log "WARN $p: install failed"; fi
done

# Nothing installed although something was requested counts as a failure.
if [ -n "$plugins" ] && [ -z "$installed" ]; then fail "no plugin could be installed"; fi
state=ok
finish
