#!/bin/zsh
# Usage: scripts/dist.sh <version>
# Tests, builds the release Prism.app stamped with <version>, and writes Prism-<version>.zip, its SHA-256 and the
# release notes into .build/dist. The Release workflow runs this on each tag; run it locally to try a release.
set -euo pipefail

cd "${0:A:h}/.."
version=${1:-}
[[ $version =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]] || { echo "usage: $0 <version, e.g. 1.0.0>" >&2; exit 2 }

# The changelog section between its heading and the next heading or the link list at the bottom. Leading blank lines
# are dropped here, trailing ones by the command substitution.
changes=$(awk -v heading="## [$version]" '
  index($0, heading) == 1 { found = 1; next }
  found && (/^## / || /^\[[^]]+\]: /) { exit }
  found { print }
' CHANGELOG.md | sed -e '/./,$!d' | awk '
  # A release body turns every newline into a line break, so a list item wrapped in the file goes back on one line.
  /^ +[^-* ]/ && n { sub(/^ +/, " "); line = line $0; next }
  n { print line }
  { line = $0; n = 1 }
  END { if (n) print line }
')
[[ -n $changes ]] || { echo "CHANGELOG.md has no ## [$version] section" >&2; exit 1 }

swift test

scripts/package.sh --version $version
app=.build/app/Prism.app
# The screenshot hooks are compiled out of release builds; this catches a configuration mistake that let them back in.
if strings $app/Contents/MacOS/Prism | grep -q "PRISM_DUMP"; then
  echo "debug hooks leaked into the release binary" >&2
  exit 1
fi

dist=.build/dist
rm -rf $dist
mkdir -p $dist
zip=Prism-$version.zip
# ditto keeps the code signature intact; Finder's Compress does too, plain zip may not.
ditto -c -k --keepParent $app $dist/$zip
(cd $dist && shasum -a 256 $zip > $zip.sha256)

cat > $dist/notes.md <<NOTES
$changes

## Install

1. Download \`$zip\` below, unzip it, and drag \`Prism.app\` into Applications.
2. Open the app. macOS says it cannot verify the developer, because Prism is not notarized by Apple: click Done.
3. Open System Settings → Privacy & Security. Near the bottom, find Prism, click Open Anyway, and confirm.

Instead of steps 2 and 3, you can run \`xattr -dr com.apple.quarantine /Applications/Prism.app\` once.

Prism needs macOS 14 or later, on Apple silicon or Intel. SHA-256 of \`$zip\`: \`$(cut -d ' ' -f 1 $dist/$zip.sha256)\`
NOTES

echo "wrote $dist: $zip, $zip.sha256, notes.md"
