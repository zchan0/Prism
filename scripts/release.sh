#!/bin/zsh
# Usage: scripts/release.sh <version>
# Checks that main is ready for <version>, tries the release locally with scripts/dist.sh, then pushes the tag
# v<version>. The tag starts the Release workflow, which builds Prism on GitHub and publishes it; this script waits for
# the workflow and prints the release link.
set -euo pipefail

cd "${0:A:h}/.."
version=${1:-}
[[ $version =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]] || { echo "usage: $0 <version, e.g. 1.0.0>" >&2; exit 2 }
tag=v$version
fail() { echo "$1" >&2; exit 1 }

[[ $(git branch --show-current) == main ]] || fail "not on main"
[[ -z $(git status --porcelain) ]] || fail "uncommitted changes"
git fetch -q origin main
[[ $(git rev-parse HEAD) == $(git rev-parse origin/main) ]] || fail "main and origin/main differ; push or pull first"
grep -qE "^## \[$version\] - [0-9]{4}-[0-9]{2}-[0-9]{2}$" CHANGELOG.md || fail "CHANGELOG.md has no ## [$version] - <date> section"
! git rev-parse -q --verify refs/tags/$tag > /dev/null || fail "tag $tag already exists here"
[[ -z $(git ls-remote --tags origin refs/tags/$tag) ]] || fail "tag $tag already exists on GitHub"

# A local trial first, so a failing test or build stops the release before anything is pushed.
scripts/dist.sh $version

git tag -a $tag -m "Prism $version"
git push origin $tag
commit=$(git rev-parse HEAD)

# The run shows up a few seconds after the push.
for _ in {1..30}; do
  run=$(gh run list --workflow release.yml --event push --limit 10 --json databaseId,headSha \
    --jq "map(select(.headSha == \"$commit\")) | first | .databaseId // empty")
  [[ -n $run ]] && break
  sleep 2
done
[[ -n ${run:-} ]] || fail "the Release workflow did not start; see https://github.com/zchan0/Prism/actions"
gh run watch $run --exit-status
gh release view $tag --json url --jq .url
