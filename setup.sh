#!/bin/bash
# SETUP.SH - Complete setup for Content-Aware Brightness
# Run this once to compile, configure permissions, and install as LaunchAgent

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BINARY_NAME="auto-brightness"
PLIST_NAME="com.kim.auto-brightness"
PLIST_PATH="$HOME/Library/LaunchAgents/$PLIST_NAME.plist"

echo "🔧 Content-Aware Brightness Setup"
echo "================================="
echo ""

# Step 1: Compile
echo "📦 Step 1: Compiling..."
cd "$SCRIPT_DIR"
swiftc -O -Xlinker -F/System/Library/PrivateFrameworks -Xlinker -framework -Xlinker DisplayServices -o "$BINARY_NAME" "$BINARY_NAME.swift"
chmod +x "$BINARY_NAME"
echo "   ✓ Built: $SCRIPT_DIR/$BINARY_NAME"
echo ""

# Step 2: Open Screen Recording permission
echo "🔐 Step 2: Screen Recording Permission"
echo "   Opening System Settings..."
echo ""
echo "   ⚠️  IMPORTANT: You must add '$BINARY_NAME' to the list!"
echo "   1. Click the '+' button"
echo "   2. Navigate to: $SCRIPT_DIR"
echo "   3. Select '$BINARY_NAME'"
echo "   4. Click 'Open'"
echo ""
open "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"

read -p "   Press ENTER after granting permission..."
echo ""

# Step 3: Create LaunchAgent
echo "⚙️  Step 3: Installing LaunchAgent..."
mkdir -p "$HOME/Library/LaunchAgents"

cat > "$PLIST_PATH" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$PLIST_NAME</string>
    <key>ProgramArguments</key>
    <array>
        <string>$SCRIPT_DIR/$BINARY_NAME</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>LimitLoadToSessionType</key>
    <string>Aqua</string>
    <key>StandardOutPath</key>
    <string>/tmp/auto-brightness.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/auto-brightness.log</string>
</dict>
</plist>
EOF
echo "   ✓ Created: $PLIST_PATH"
echo ""

# Step 4: Load LaunchAgent
echo "🚀 Step 4: Starting service..."
launchctl bootout gui/$(id -u)/"$PLIST_NAME" 2>/dev/null || true
launchctl bootstrap gui/$(id -u) "$PLIST_PATH"
echo "   ✓ Service started!"
echo ""

# Done
echo "✅ Setup complete!"
echo ""
echo "   The app is now running in the background."
echo "   Logs: tail -f /tmp/auto-brightness.log"
echo ""
echo "   To stop:  launchctl bootout gui/\$(id -u)/$PLIST_NAME"
echo "   To start: launchctl bootstrap gui/\$(id -u) $PLIST_PATH"
