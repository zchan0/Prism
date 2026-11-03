#!/bin/zsh
# Usage: scripts/readme-assets.sh
# Regenerates docs/images from a packaged debug build: the icon, the menu bar states, the panel in both
# appearances, and the pet awake and asleep.
set -euo pipefail

cd "${0:A:h}/.."
out=docs/images
work=$(mktemp -d)
trap 'rm -rf $work' EXIT

scripts/package.sh --debug > /dev/null
bin=.build/app/LumosMaxima.app/Contents/MacOS/LumosMaxima
mkdir -p $out

ictool="$(xcode-select -p)/../Applications/Icon Composer.app/Contents/Executables/ictool"
$ictool Resources/AppIcon.icon --export-image --output-file $out/icon.png \
  --platform macOS --rendition Default --width 256 --height 256 --scale 2

LUMOS_STATUS_SNAPSHOT=$work/status.png $bin
# The grid is one 94x26 point cell per state (columns) and menu bar (rows: light, dark, blue) at 4x.
cp $work/status.png $out/status.png

LUMOS_SNAPSHOT=$work/panel-light.png $bin
cp $work/panel-light.png $out/panel-light.png
LUMOS_APPEARANCE=dark LUMOS_SNAPSHOT=$work/panel-dark.png $bin
cp $work/panel-dark.png $out/panel-dark.png
LUMOS_PANEL_STATE=asleep LUMOS_SNAPSHOT=$out/panel-asleep.png $bin
LUMOS_SNAPSHOT=$out/panel-zh.png $bin -AppleLanguages "(zh-Hans)" 

LUMOS_PET_CLICK=1 LUMOS_PANEL_CAPTURE=$work/quick.png $bin || true
if [[ -f $work/quick.png ]]; then cp $work/quick.png $out/quick-panel.png; fi

LUMOS_PET_SNAPSHOT=$out/pet-awake.png $bin
LUMOS_PET_STATE=asleep LUMOS_PET_SNAPSHOT=$out/pet-asleep.png $bin

ls -l $out
