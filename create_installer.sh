#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

echo "🔨 1. Compilando aplicación..."
./build.sh

echo "📦 2. Creando Instalador Apple PKG (Instalador guiado)..."
PKG_STAGING="build/pkg_staging"
rm -rf "$PKG_STAGING"
mkdir -p "$PKG_STAGING/Applications"
cp -R "build/Keyboard Light.app" "$PKG_STAGING/Applications/"

pkgbuild --root "$PKG_STAGING" \
         --identifier "com.diegos.keyboard-light-mac" \
         --version "1.0.0" \
         --install-location "/" \
         "build/Keyboard-Light-Mac-Installer.pkg"
rm -rf "$PKG_STAGING"

echo "🗜 3. Creando Paquete de Distribución ZIP..."
ditto -c -k --sequesterRsrc --keepParent "build/Keyboard Light.app" "build/Keyboard-Light-Mac.zip"

echo "💿 4. Intentando generar Imagen de Disco DMG..."
DMG_STAGING="build/dmg_staging"
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"
cp -R "build/Keyboard Light.app" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Aplicaciones"
hdiutil create -volname "Keyboard Light Mac" -srcfolder "$DMG_STAGING" -ov -format UDZO "build/Keyboard-Light-Mac-Installer.dmg" 2>/dev/null || true
rm -rf "$DMG_STAGING"

echo ""
echo "=================================================="
echo "🎉 ¡INSTALADORES CREADOS CON ÉXITO!"
echo "=================================================="
echo "Archivos listos para compartir con cualquier persona:"
echo "  1. Instalador nativo de Apple (Recomendado):"
echo "     👉 build/Keyboard-Light-Mac-Installer.pkg"
echo "  2. Paquete comprimido universal:"
echo "     👉 build/Keyboard-Light-Mac.zip"
if [ -f "build/Keyboard-Light-Mac-Installer.dmg" ]; then
echo "  3. Imagen de disco DMG:"
echo "     👉 build/Keyboard-Light-Mac-Installer.dmg"
fi
echo "=================================================="
