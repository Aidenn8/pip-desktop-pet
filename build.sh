#!/bin/zsh
# Builds DesktopPet.app into ./build. Pass --install to copy it to ~/Applications and launch it.
set -euo pipefail
cd "$(dirname "$0")"

APP=build/DesktopPet.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Info.plist "$APP/Contents/Info.plist"
cp -R Resources/Fonts "$APP/Contents/Resources/Fonts"

swiftc -O -target "$(uname -m)-apple-macos13.0" \
  -framework AppKit -framework SwiftUI -framework ServiceManagement -framework IOKit \
  Sources/*.swift -o "$APP/Contents/MacOS/DesktopPet"

# Ad-hoc signature so macOS treats it as a proper app locally (not for distribution).
codesign --force --sign - "$APP" >/dev/null
echo "Built $APP"

if [[ "${1:-}" == "--install" ]]; then
  mkdir -p ~/Applications
  pkill -x DesktopPet 2>/dev/null || true
  rm -rf ~/Applications/DesktopPet.app
  cp -R "$APP" ~/Applications/
  open ~/Applications/DesktopPet.app
  echo "Installed to ~/Applications/DesktopPet.app and launched"
fi
