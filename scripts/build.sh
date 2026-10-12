#!/bin/bash
# Builds a universal (Apple Silicon + Intel) Tinto.app into build/
# Compila Tinto.app universal en build/
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME="Tinto"
BUNDLE_ID="io.github.maggi3mae.tinto"
MIN_MACOS="14.0"
VERSION="${VERSION:-$(cat VERSION)}"
VERSION="${VERSION#v}"
BUILD="build"
APP="$BUILD/$APP_NAME.app"

if ! xcrun --find swiftc >/dev/null 2>&1; then
    echo "Apple Command Line Tools are missing. Opening the installer…"
    echo "Faltan las Command Line Tools de Apple. Abriendo el instalador…"
    xcode-select --install || true
    exit 1
fi

echo "☕ Building $APP_NAME ${VERSION}…"
rm -rf "$BUILD"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# 1. Compile for both architectures and merge
for arch in arm64 x86_64; do
    xcrun swiftc -O -swift-version 5 -target "$arch-apple-macos$MIN_MACOS" \
        Sources/main.swift -o "$BUILD/$APP_NAME-$arch" \
        -framework AppKit -framework IOKit -framework ServiceManagement
done
lipo -create -output "$APP/Contents/MacOS/$APP_NAME" "$BUILD/$APP_NAME-arm64" "$BUILD/$APP_NAME-x86_64"
rm -f "$BUILD/$APP_NAME-arm64" "$BUILD/$APP_NAME-x86_64"

# 2. App icon (drawn by the app itself)
ICONSET="$BUILD/AppIcon.iconset"
mkdir -p "$ICONSET"
"$APP/Contents/MacOS/$APP_NAME" --icon "$BUILD/icon_1024.png"
for size in 16 32 128 256 512; do
    sips -z $size $size "$BUILD/icon_1024.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z $double $double "$BUILD/icon_1024.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET" "$BUILD/icon_1024.png"

# 3. Info.plist (LSUIElement: menu bar only, no Dock icon)
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>CFBundleLocalizations</key><array><string>en</string><string>es</string></array>
    <key>LSMinimumSystemVersion</key><string>$MIN_MACOS</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSHumanReadableCopyright</key><string>MIT License · github.com/Maggi3Mae/tinto</string>
</dict>
</plist>
PLIST

# 4. Ad-hoc signature (no Apple account needed)
codesign --force --sign - "$APP"

echo "✅ $APP"
