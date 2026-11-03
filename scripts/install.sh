#!/bin/zsh
# Usage: scripts/install.sh
# Replaces /Applications/LumosMaxima.app with .build/app/LumosMaxima.app and relaunches it.
set -euo pipefail

cd "${0:A:h}/.."
app=.build/app/LumosMaxima.app
installed=/Applications/LumosMaxima.app

# Without this check the installed copy would be deleted before ditto fails.
[[ -d $app ]] || { echo "$app does not exist; run scripts/package.sh first" >&2; exit 1 }
pkill -x LumosMaxima || true
# open would hand the launch to a copy that is still quitting.
while pgrep -x LumosMaxima > /dev/null; do sleep 0.1; done
rm -rf $installed
ditto $app $installed
open $installed
echo "installed $installed"
