#!/bin/zsh
# Usage: scripts/readme-assets.sh
# Regenerates docs/images from a packaged debug build: the icon, the menu bar icons, and in English and Chinese the
# Prism window on Lumos's page and on Portkey's page, each tool's panel, and the Pensieve window, with Lumos counting
# down, sample apps in Portkey and sample items in Pensieve.
set -euo pipefail

cd "${0:A:h}/.."
out=docs/images
work=$(mktemp -d)
trap 'rm -rf $work' EXIT

scripts/package.sh --debug > /dev/null
bin=.build/app/Prism.app/Contents/MacOS/Prism
mkdir -p $out

ictool="$(xcode-select -p)/../Applications/Icon Composer.app/Contents/Executables/ictool"
$ictool Resources/AppIcon.icon --export-image --output-file $out/icon.png \
  --platform macOS --rendition Default --width 256 --height 256 --scale 2

# One 94x26 point cell per icon (columns) and menu bar (rows: light, dark, blue) at 4x.
PRISM_STATUS_CAPTURE=$out/status.png $bin

# <language> <file name suffix>
capture() {
  local dir=$work/$1
  mkdir -p $dir
  PRISM_APPEARANCE=light PRISM_START_LUMOS=1 PRISM_CAPTURE=$dir $bin -AppleLanguages "($1)"
  cp $dir/window-lumos.png $out/window$2.png
  cp $dir/window-portkey.png $out/window-portkey$2.png
  for tool in lumos vitals portkey pensieve; do
    cp $dir/popover-$tool.png $out/popover-$tool$2.png
  done
  cp $dir/pensieve-window.png $out/pensieve$2.png
}
capture en ""
capture zh-Hans -zh

ls -l $out
