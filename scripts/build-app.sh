#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
APP="dist/GlassText.app"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/GlassText "$APP/Contents/MacOS/GlassText"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>GlassText</string>
<key>CFBundleIdentifier</key><string>com.yinwenhao.glasstext</string>
<key>CFBundleName</key><string>GlassText</string>
<key>CFBundleDisplayName</key><string>透明文字</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --deep --sign - "$APP"
ditto -c -k --sequesterRsrc --keepParent "$APP" dist/GlassText-macOS.zip
echo "Built $APP"
