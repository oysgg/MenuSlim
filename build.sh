#!/bin/zsh
set -eu
cd "${0:A:h}"
destination="${1:-$PWD/build}"
app="$destination/MenuSlim.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
xcrun swiftc -O -target arm64-apple-macosx14.0 Sources/*.swift -o "$app/Contents/MacOS/MenuSpacing" -framework AppKit -framework SwiftUI
cp -R Resources/*.lproj "$app/Contents/Resources/"
iconset="$destination/.MenuSlim.iconset"
trap 'rm -rf "$iconset"' EXIT
xcrun swift Tools/render_icon.swift "$iconset"
iconutil -c icns "$iconset" -o "$app/Contents/Resources/AppIcon.icns"
cp "$iconset/icon_512x512@2x.png" "$destination/MenuSlim-icon.png"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>MenuSpacing</string>
<key>CFBundleIdentifier</key><string>com.yangshuai.MenuSpacing</string>
<key>CFBundleName</key><string>MenuSlim</string>
<key>CFBundleDisplayName</key><string>MenuSlim</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundleLocalizations</key><array><string>en</string><string>zh-Hans</string></array>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$app"
codesign --verify --strict "$app"
printf '%s\n' "$app"
