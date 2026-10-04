#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

echo "🔨 Compilando Keyboard Light Mac..."
mkdir -p build

clang -O3 -fobjc-arc \
  -framework Cocoa \
  -framework AVFoundation \
  -framework AudioToolbox \
  -framework CoreAudio \
  -framework CoreGraphics \
  -framework CoreMedia \
  -framework ScreenCaptureKit \
  -F /System/Library/PrivateFrameworks -framework CoreBrightness \
  src/main.m src/KeyboardController.m src/AudioAnalyzer.m src/AudioCaptureEngine.m src/TypingSpeedometerEngine.m src/AppController.m \
  -o build/keyboard-light

echo "📦 Creando Keyboard Light.app..."
APP_DIR="build/Keyboard Light.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp build/keyboard-light "$APP_DIR/Contents/MacOS/keyboard-light"
cp Info.plist "$APP_DIR/Contents/Info.plist"
if [ -f "assets/AppIcon.icns" ]; then
    cp assets/AppIcon.icns "$APP_DIR/Contents/Resources/AppIcon.icns"
fi

# Ad-hoc code signing so macOS registers entitlements and bundle ID cleanly
codesign --force --deep --sign - "$APP_DIR" 2>/dev/null || true

echo "✅ Compilación exitosa!"
echo "   - Binario CLI: ./build/keyboard-light"
echo "   - App nativa:  ./build/Keyboard Light.app"
