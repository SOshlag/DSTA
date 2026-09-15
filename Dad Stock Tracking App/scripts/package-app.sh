#!/bin/sh
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/Stock Alerts.app"

cd "$ROOT"
swift build -c release --arch arm64 --arch x86_64
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/.build/apple/Products/Release/DadStockAlerts" "$APP/Contents/MacOS/DadStockAlerts"
cp "$ROOT/Packaging/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Packaging/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
chmod +x "$APP/Contents/MacOS/DadStockAlerts"
codesign --force --deep --sign - "$APP"

echo "$APP"
