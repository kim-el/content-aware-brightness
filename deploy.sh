#!/bin/bash
set -e

APP_NAME="ContentAwareBrightness"
BUNDLE_ID="com.kim.ContentAwareBrightness"
SRC_FILE="auto-brightness.swift"
BUILD_DIR="./build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "📦 Packaging $APP_NAME..."

# 1. Cleaner Build
rm -rf "$BUILD_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# 2. Compile
echo "🔨 Compiling Swift binary..."
swiftc -O -Xlinker -F/System/Library/PrivateFrameworks \
       -Xlinker -framework -Xlinker DisplayServices \
       -o "$MACOS_DIR/$APP_NAME" "$SRC_FILE"

# 3. Create Info.plist (LSUIElement = 1 for background app)
echo "📝 Creating Info.plist..."
cat > "$CONTENTS_DIR/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>3.0</string>
    <key>LSUIElement</key>
    <true/> <!-- Runs in background, no Dock icon -->
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
</dict>
</plist>
EOF

# 4. Generate Simple Icon (Yellow Square with Sun hint)
echo "🎨 Generating App Icon..."
ICON_SET="$BUILD_DIR/AppIcon.iconset"
mkdir -p "$ICON_SET"

# Create a 1024x1024 base image (Yellow background)
# Using separate commands to ensure compatibility
# Create blank canvas
sips -s format png --resampleHeightWidth 1024 1024 --padColor FFD700 /System/Library/CoreServices/DefaultDesktop.heic --out "$ICON_SET/icon_1024x1024.png" > /dev/null 2>&1 || true

# If sips failed to create from HEIC (depends on OS), try creating from scratch via empty file? 
# Actually, easier approach: Use a small python script for reliable image generation
python3 -c "from PIL import Image, ImageDraw; img = Image.new('RGB', (1024, 1024), color = (255, 215, 0)); d = ImageDraw.Draw(img); d.ellipse([256,256,768,768], fill=(255,165,0)); img.save('$ICON_SET/icon_1024x1024.png')" 2>/dev/null || echo "⚠️ Python PIL not found, skipping icon generation"

if [ -f "$ICON_SET/icon_1024x1024.png" ]; then
    # Generate sizes
    sips -z 16 16     "$ICON_SET/icon_1024x1024.png" --out "$ICON_SET/icon_16x16.png" >/dev/null
    sips -z 32 32     "$ICON_SET/icon_1024x1024.png" --out "$ICON_SET/icon_16x16@2x.png" >/dev/null
    sips -z 32 32     "$ICON_SET/icon_1024x1024.png" --out "$ICON_SET/icon_32x32.png" >/dev/null
    sips -z 64 64     "$ICON_SET/icon_1024x1024.png" --out "$ICON_SET/icon_32x32@2x.png" >/dev/null
    sips -z 128 128   "$ICON_SET/icon_1024x1024.png" --out "$ICON_SET/icon_128x128.png" >/dev/null
    sips -z 256 256   "$ICON_SET/icon_1024x1024.png" --out "$ICON_SET/icon_128x128@2x.png" >/dev/null
    sips -z 256 256   "$ICON_SET/icon_1024x1024.png" --out "$ICON_SET/icon_256x256.png" >/dev/null
    sips -z 512 512   "$ICON_SET/icon_1024x1024.png" --out "$ICON_SET/icon_256x256@2x.png" >/dev/null
    sips -z 512 512   "$ICON_SET/icon_1024x1024.png" --out "$ICON_SET/icon_512x512.png" >/dev/null
    sips -z 1024 1024 "$ICON_SET/icon_1024x1024.png" --out "$ICON_SET/icon_512x512@2x.png" >/dev/null

    # Convert to icns
    iconutil -c icns "$ICON_SET" -o "$RESOURCES_DIR/AppIcon.icns"
else
    echo "⚠️ Failed to generate icon (PIL missing?), skipping."
    # Fallback: Copy a generic system icon if possible, or just have no icon
fi

echo "✅ App Bundle Created: $APP_BUNDLE"

# 6. Create Release Zip (for distribution)
echo ""
echo "📦 Creating Release Zip..."
RELEASE_ZIP="$BUILD_DIR/${APP_NAME}_v3.0.zip"
(cd "$BUILD_DIR" && zip -r "${APP_NAME}_v3.0.zip" "$APP_NAME.app") > /dev/null
echo "🎉 Release ready: $RELEASE_ZIP"

# 5. Install to User Applications (No Sudo required)
DEST="$HOME/Applications/$APP_NAME.app"
mkdir -p "$HOME/Applications"

echo "🚀 Installing to $DEST..."

# Check if app is running and kill it
pkill -f "$APP_NAME" || true

# Remove existing
if [ -d "$DEST" ]; then
    rm -rf "$DEST"
fi

# Copy instead of Move, so build dir stays valid
cp -R "$APP_BUNDLE" "$DEST"

echo "✨ Installed successfully!"
echo "▶️  Launching app..."
open "$DEST"
echo "✅ Done! You should see the permission prompt shortly (if not already granted)."
open -R "$RELEASE_ZIP"
