#!/bin/zsh
# Usage: scripts/release.sh <version> [--install]
# Tests, builds a release LumosMaxima.app stamped with <version>, zips it into .build/dist and creates the local
# tag v<version>. Nothing is pushed. --install installs the app after the tag exists, so a failed install leaves a
# complete release behind.
set -euo pipefail

cd "${0:A:h}/.."
usage="usage: $0 <version, e.g. 1.0.0> [--install]"
version=${1:-}
[[ $version =~ '^[0-9]+(\.[0-9]+){1,2}$' ]] || { echo $usage >&2; exit 2 }
shift
install=false
case ${1:-} in
  "") ;;
  --install) install=true ;;
  *) echo $usage >&2; exit 2 ;;
esac
tag=v$version

if [[ -n $(git status --porcelain) ]]; then
  echo "uncommitted changes" >&2
  exit 1
fi
if ! grep -q "^## \[$version\]" CHANGELOG.md; then
  echo "CHANGELOG.md has no ## [$version] section" >&2
  exit 1
fi
if git rev-parse -q --verify "refs/tags/$tag" > /dev/null; then
  echo "tag $tag already exists" >&2
  exit 1
fi

swift test

scripts/package.sh --version $version
app=.build/app/LumosMaxima.app
# The screenshot hooks are compiled out of release builds; this catches a configuration mistake that let them back in.
if strings $app/Contents/MacOS/LumosMaxima | grep -q "LUMOS_SNAPSHOT"; then
  echo "debug hooks leaked into the release binary" >&2
  exit 1
fi

mkdir -p .build/dist
zip=.build/dist/LumosMaxima-$version.zip
rm -f $zip
# ditto keeps the code signature intact; Finder's Compress does too, plain zip may not.
ditto -c -k --keepParent $app $zip

git tag -a $tag -m "LumosMaxima $version"
echo "released $zip, tagged $tag (not pushed)"

if $install; then
  scripts/install.sh
fi
