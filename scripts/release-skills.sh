#!/usr/bin/env bash
# OWNER ONLY. Releases the skills plugins: creates the owner-only tag ruleset (first run only),
# tags the current main as skills-vX.Y.Z and pushes the tag. Run it on your own machine with `gh`
# logged in as a repo admin. Never use the agent's token: it must not be able to do this.
#
#   scripts/release-skills.sh 0.1.0           # checks everything, prints what it would do
#   scripts/release-skills.sh 0.1.0 --apply   # does it
#
# Afterwards it prints the values to put in k3s-lab (this script does not touch that repo).
set -euo pipefail

ver=${1:-}
apply=0; [ "${2:-}" = "--apply" ] && apply=1
[[ $ver =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "usage: $0 X.Y.Z [--apply]" >&2; exit 2; }

tag=skills-v$ver
repo=${REPO:-$(git remote get-url origin | sed -E 's#^((https?|ssh)://)?([^@/]+@)?[^:/]+[:/]##; s#\.git$##')}
cd "$(git rev-parse --show-toplevel)"

die() { echo "release-skills: $*" >&2; exit 1; }
run() { if [ "$apply" = 1 ]; then "$@"; else echo "[dry-run] $*"; fi; }

echo "== checks ($repo, $tag)"
[ "$(git rev-parse --abbrev-ref HEAD)" = main ] || die "not on main"
[ -z "$(git status --porcelain)" ] || die "working tree is not clean"
git fetch -q origin main
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] || die "local main differs from origin/main (pull or push first)"
git rev-parse -q --verify "refs/tags/$tag" >/dev/null && die "tag $tag already exists locally"
[ -z "$(git ls-remote --tags origin "$tag")" ] || die "tag $tag already exists on origin (tags are never moved)"
[ "$(gh api "repos/$repo" --jq .permissions.admin)" = true ] \
  || { [ "$apply" = 1 ] && die "this gh login is not an admin of $repo"; echo "note: this gh login is not an admin of $repo; --apply would stop here"; }
claude-skills/tests/hooks-smoke.sh >/dev/null || die "claude-skills/tests/hooks-smoke.sh failed (run it to see why)"
echo "ok"

echo "== tag ruleset"
if [ -n "$(gh api "repos/$repo/rulesets" --jq '.[] | select(.name == "skills-tags") | .id')" ]; then
  echo "ruleset skills-tags already exists"
else
  # Only repo admins (bypass) can create, move or delete skills-v* tags.
  json='{"name":"skills-tags","target":"tag","enforcement":"active",
    "conditions":{"ref_name":{"include":["refs/tags/skills-v*"],"exclude":[]}},
    "bypass_actors":[{"actor_id":5,"actor_type":"RepositoryRole","bypass_mode":"always"}],
    "rules":[{"type":"creation"},{"type":"update"},{"type":"deletion"},{"type":"non_fast_forward"}]}'
  run gh api -X POST "repos/$repo/rulesets" --input - <<<"$json"
fi

echo "== tag"
sha=$(git rev-parse HEAD)
run git tag -a "$tag" -m "Skills $ver" "$sha"
run git push origin "$tag"

cat <<EOF

== values for k3s-lab (apps/ai-dev-platform, ConfigMap patch)
CLAUDE_SKILLS_REPO: "$repo"
CLAUDE_SKILLS_REF: "$tag"
CLAUDE_SKILLS_SHA: "$sha"
CLAUDE_SKILLS_PLUGINS: "caveman ponytail"
CLAUDE_SKILLS_HOOK_PLUGINS: "caveman ponytail"
Then, when agents have pushed their work: kubectl rollout restart deployment/claude-dev -n ai-development
EOF
[ "$apply" = 1 ] || echo "(dry run: nothing was changed)"
