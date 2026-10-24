#!/bin/bash
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/MikuDeskPet.app"
cd "$ROOT"

# Check local-only resources before generating files or replacing an existing app.
for prefix in miku miku_chibi miku_crayon; do
  for state in idle blink happy sad sleep; do
    if [ ! -f "assets/${prefix}_${state}.png" ]; then
      echo "缺少素材: assets/${prefix}_${state}.png；请按 docs/ASSETS.md 准备已授权资源。" >&2
      exit 1
    fi
  done
done
for i in $(seq -w 1 10); do
  if [ ! -f "sounds/voice_selfep_piapro_21_${i}.m4a" ]; then
    echo "缺少音频: sounds/voice_selfep_piapro_21_${i}.m4a；请按 docs/ASSETS.md 准备已授权资源。" >&2
    exit 1
  fi
done
if [ ! -f src/AppIcon.icns ]; then
  echo "缺少 src/AppIcon.icns；请按 docs/ASSETS.md 准备图标。" >&2
  exit 1
fi

echo "==> 生成动态帧"
python3 src/make_motion.py
python3 src/make_mouths.py

echo "==> 编译 Swift"
swiftc -O -swift-version 5 -o "$ROOT/MikuDeskPet" src/main.swift src/PetMotion.swift src/PetSpeech.swift

echo "==> 组装 .app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/MikuDeskPet" "$APP/Contents/MacOS/MikuDeskPet"
cp src/Info.plist "$APP/Contents/Info.plist"
cp src/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp LICENSE THIRD_PARTY_NOTICES.md "$APP/Contents/Resources/"
# 动态帧
cp -R assets/animation "$APP/Contents/Resources/animation"
cp -R assets/mouths "$APP/Contents/Resources/mouths"
# 素材
for f in idle blink happy sad sleep; do
  cp "assets/miku_$f.png" "$APP/Contents/Resources/standard_$f.png"
done
for f in idle blink happy sad sleep; do
  cp "assets/miku_chibi_$f.png" "$APP/Contents/Resources/chibi_$f.png"
done
for f in idle blink happy sad sleep; do
  cp "assets/miku_crayon_$f.png" "$APP/Contents/Resources/crayon_$f.png"
done
mkdir -p "$APP/Contents/Resources/sounds"
# Use only the explicitly prepared project resources, never temporary downloads.
for i in $(seq -w 1 10); do
  cp "sounds/voice_selfep_piapro_21_${i}.m4a" "$APP/Contents/Resources/sounds/voice_${i}.m4a"
done

echo "==> Ad-hoc 签名"
codesign --force -s - "$APP" 2>/dev/null || true

echo "==> 完成: $APP"
