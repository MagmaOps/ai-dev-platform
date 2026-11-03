#!/usr/bin/env bash
# Start a new agent: clone a repo into /workspace/<task>, create branch ai/<task>,
# open a Herdr workspace there and start Claude Code in it.
#
#   new-agent <owner/repo> <task>
#   new-agent MagmaOps/some-repo fix-login
#
# Attach afterwards with `herdr` (the Windows launcher does this for you).
set -euo pipefail

die() { echo "new-agent: $*" >&2; exit 1; }

[ "$#" -eq 2 ] || die "usage: new-agent <owner/repo> <task>"
repo=$1
task=$2

[[ $repo =~ ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ ]] || die "repo must look like owner/name"
[[ $task =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "task must be lowercase letters, digits and dashes"

dir=/workspace/$task
[ ! -e "$dir" ] || die "$dir already exists (pick another task name)"

# The Herdr CLI needs a running server, and the server only starts with a client.
# Hold it with a detached client in a hidden tmux session; real clients attach alongside it.
if ! herdr status server 2>/dev/null | grep -q 'status: running'; then
  tmux new-session -d -s herdr-host -x 200 -y 50 herdr
  for _ in $(seq 1 20); do
    herdr status server 2>/dev/null | grep -q 'status: running' && break
    sleep 0.5
  done
  herdr status server 2>/dev/null | grep -q 'status: running' || die "herdr server did not start"
fi

git clone "https://github.com/${repo}.git" "$dir"
git -C "$dir" checkout -b "ai/${task}"

out=$(herdr workspace create --cwd "$dir" --label "$task")
jq -e '.result.workspace' >/dev/null <<<"$out" || die "could not create Herdr workspace: $out"
pane=$(jq -r '.result.root_pane.pane_id' <<<"$out")
ws=$(jq -r '.result.workspace.workspace_id' <<<"$out")

herdr pane run "$pane" claude >/dev/null
herdr workspace focus "$ws" >/dev/null

echo "Agent '${task}' started in ${dir} on branch ai/${task}. Attach with: herdr"
