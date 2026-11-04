#!/bin/zsh
# Usage: scripts/package.sh [--debug] [--install] [--version <version>]
# Builds .build/app/Prism.app from the release configuration; --debug keeps the PRISM_* debug hooks.
# --install replaces /Applications/Prism.app and relaunches it.
set -euo pipefail

cd "${0:A:h}/.."
# The bundle id stays as it was: changing it would drop the person's settings, notification permission and login item.
bundle_id=io.github.zchan0.LumosMaxima
app=.build/app/Prism.app

install=false
configuration=release
version=0.1
usage="usage: $0 [--debug] [--install] [--version <version>]"
while (( $# )); do
  case $1 in
    --debug) configuration=debug ;;
    --install) install=true ;;
    --version) version=${2:?$usage}; shift ;;
    *) echo $usage >&2; exit 2 ;;
  esac
  shift
done

swift build -c $configuration
bin=$(swift build -c $configuration --show-bin-path)

rm -rf $app
mkdir -p $app/Contents/MacOS $app/Contents/Resources
cp $bin/Prism $app/Contents/MacOS/
# actool writes Assets.car for the macOS 26 icon and AppIcon.icns for older systems; a plain .icns gets boxed on macOS 26.
xcrun actool $PWD/Resources/AppIcon.icon --compile $app/Contents/Resources --app-icon AppIcon \
  --platform macosx --target-device mac --minimum-deployment-target 14.0 \
  --output-partial-info-plist $(mktemp) --errors --warnings > /dev/null
# swift build copies a String Catalog without compiling it. The empty en.lproj tells macOS that English is a supported language.
xcrun xcstringstool compile $PWD/Resources/Localizable.xcstrings --output-directory $app/Contents/Resources
mkdir -p $app/Contents/Resources/en.lproj
cat > $app/Contents/Info.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>Prism</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>$bundle_id</string>
    <key>CFBundleLocalizations</key>
    <array>
        <string>en</string>
        <string>zh-Hans</string>
    </array>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Prism</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$version</string>
    <key>CFBundleVersion</key>
    <string>$(git rev-list --count HEAD 2>/dev/null || echo 1)</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 zchan0</string>
</dict>
</plist>
EOF
plutil -lint -s $app/Contents/Info.plist

identity=${LUMOS_SIGN_IDENTITY:-Apple Development: zchan0}
# The keychain keeps revoked copies under the same name; only a line ending right after the quoted name is usable.
fingerprint=$(security find-identity -v -p codesigning | awk -v name="\"$identity\"" '
  { at = index($0, name) }
  at > 0 && at + length(name) - 1 == length($0) { print $2; exit }
')
if [[ -n $fingerprint ]]; then
  codesign --force --sign $fingerprint $app
  echo "signed with $identity ($fingerprint)"
else
  echo "warning: no usable signing identity named \"$identity\", signing ad hoc" >&2
  codesign --force --sign - $app
fi
echo "built $app ($configuration, $version)"

if $install; then
  scripts/install.sh
fi
