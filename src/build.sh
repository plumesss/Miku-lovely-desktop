#!/bin/bash
# Build a silent universal macOS application and DMG from local artwork.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
for prefix in miku miku_chibi miku_crayon; do
  for state in idle blink happy sad sleep; do
    test -f "assets/${prefix}_${state}.png" || { echo "缺少立绘；请参阅 docs/ASSETS.md" >&2; exit 1; }
  done
done
test -f src/AppIcon.icns || { echo "缺少 src/AppIcon.icns" >&2; exit 1; }
python3 src/make_motion.py
python3 src/make_mouths.py
mkdir -p dist
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/miku-macos.XXXXXX")"
export COPYFILE_DISABLE=1
APP="$STAGE/image/MikuDeskPet.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
for arch in arm64 x86_64; do
  swiftc -O -swift-version 5 -target "${arch}-apple-macos13.0" \
    -o "$STAGE/MikuDeskPet-$arch" src/main.swift src/PetMotion.swift src/PetSpeech.swift
done
lipo -create "$STAGE/MikuDeskPet-arm64" "$STAGE/MikuDeskPet-x86_64" -output "$APP/Contents/MacOS/MikuDeskPet"
cp src/Info.plist "$APP/Contents/Info.plist"
cp src/AppIcon.icns LICENSE THIRD_PARTY_NOTICES.md "$APP/Contents/Resources/"
cp -R assets/animation assets/mouths "$APP/Contents/Resources/"
for state in idle blink happy sad sleep; do
  cp "assets/miku_${state}.png" "$APP/Contents/Resources/standard_${state}.png"
  cp "assets/miku_chibi_${state}.png" "$APP/Contents/Resources/chibi_${state}.png"
  cp "assets/miku_crayon_${state}.png" "$APP/Contents/Resources/crayon_${state}.png"
done
# Deliberately never read or copy sounds/. The original local files stay private.
xattr -cr "$APP"
codesign --force --sign - "$APP"
codesign --verify --strict "$APP"
"$APP/Contents/MacOS/MikuDeskPet" --smoke-test
ln -s /Applications "$STAGE/image/Applications"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' src/Info.plist)
hdiutil create -ov -volname MikuDeskPet -srcfolder "$STAGE/image" -format UDZO "dist/MikuDeskPet-${VERSION}-macOS-Universal.dmg"
echo "Built: dist/MikuDeskPet-${VERSION}-macOS-Universal.dmg"
