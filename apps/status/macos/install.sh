#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
swift build -c release
APP="$HOME/Applications/DX Status.app"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/DXStatus "$APP/Contents/MacOS/DXStatus"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>DXStatus</string>
<key>CFBundleIdentifier</key><string>gg.dawson.dx-status</string>
<key>CFBundleName</key><string>DX Status</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.2.0</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
if [[ "${1:-}" != "--no-open" ]]; then open "$APP"; fi
printf 'Installed %s\n' "$APP"
