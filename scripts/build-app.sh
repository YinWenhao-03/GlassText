#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
APP="dist/GlassText.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
# Universal binary, built with Command Line Tools; full Xcode is not required.
for architecture in arm64 x86_64; do
  swift build -c release --arch "$architecture" --scratch-path ".build/$architecture"
done
arm_bin=$(swift build -c release --arch arm64 --scratch-path .build/arm64 --show-bin-path)
intel_bin=$(swift build -c release --arch x86_64 --scratch-path .build/x86_64 --show-bin-path)
lipo -create "$arm_bin/GlassText" "$intel_bin/GlassText" -output "$APP/Contents/MacOS/GlassText"
cp Assets/AppIcon.icns "$APP/Contents/Resources/GlassText.icns"
rm -f "$APP/Contents/Resources/AppIcon.icns"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>GlassText</string>
<key>CFBundleIdentifier</key><string>com.yinwenhao.glasstext</string>
<key>CFBundleName</key><string>GlassText</string>
<key>CFBundleDisplayName</key><string>透明文字</string>
<key>CFBundleIconFile</key><string>GlassText.icns</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.6.5</string>
<key>CFBundleVersion</key><string>11</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
if [[ -n "${GLASSTEXT_SIGN_IDENTITY:-}" ]]; then
  codesign --force --options runtime --timestamp --sign "$GLASSTEXT_SIGN_IDENTITY" "$APP"
else
  codesign --force --sign - "$APP"
fi
ditto -c -k --sequesterRsrc --keepParent "$APP" dist/GlassText-macOS.zip
if [[ -n "${GLASSTEXT_NOTARY_PROFILE:-}" ]]; then
  [[ -n "${GLASSTEXT_SIGN_IDENTITY:-}" ]] || { echo "Notarization requires a Developer ID identity."; exit 1; }
  xcrun notarytool submit dist/GlassText-macOS.zip --keychain-profile "$GLASSTEXT_NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP"
  ditto -c -k --sequesterRsrc --keepParent "$APP" dist/GlassText-macOS.zip
fi
codesign --verify --strict "$APP"
lipo -info "$APP/Contents/MacOS/GlassText"
shasum -a 256 dist/GlassText-macOS.zip > dist/SHA256SUMS.txt
echo "Built $APP"
