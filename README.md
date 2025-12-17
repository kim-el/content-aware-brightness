# Content-Aware Brightness

Automatically adjusts Mac display brightness based on **screen content**, not room lighting.

- Dark content (dark mode apps, terminals) → brightness UP
- Bright content (white webpages, documents) → brightness DOWN

## Why This Instead of True Tone / Auto-Brightness?

Apple's built-in options react to **room lighting**:
- **True Tone** - adjusts color temperature based on ambient light
- **Auto-Brightness** - adjusts brightness based on ambient light sensor

But room lighting is not what hurts your eyes. **Screen content is.**

A white webpage at 100% brightness in a dark room is blinding. A dark terminal at 50% brightness is hard to read. This tool fixes that by looking at what's actually on your screen.

## How It Works

1. Takes a tiny screenshot (200x200 pixels from center) every 0.5 seconds
2. Calculates average brightness of the content
3. Smoothly adjusts display brightness to compensate

**Resource usage:** ~0.1-0.3% CPU

## Installation

```bash
# Copy scripts to ~/bin
cp auto-brightness ~/bin/
cp set-brightness ~/bin/
chmod +x ~/bin/auto-brightness ~/bin/set-brightness

# Install LaunchAgent (auto-start on login)
cp com.kim.auto-brightness.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.kim.auto-brightness.plist
```

## Configuration

Edit `~/bin/auto-brightness` to adjust:

```bash
BRIGHT_CONTENT_TARGET=0.5   # Brightness when viewing white content (0-1)
DARK_CONTENT_TARGET=0.87    # Brightness when viewing dark content (0-1)
CHECK_INTERVAL=0.5          # How often to check (seconds)
```

## Manual Control

```bash
# Check current brightness
set-brightness

# Set brightness (0.0 to 1.0)
set-brightness 0.7

# Set with smooth transition
set-brightness 0.7 smooth

# Relative adjustment
set-brightness +0.1
set-brightness -0.1 smooth
```

## Start/Stop

```bash
# Start daemon
launchctl load ~/Library/LaunchAgents/com.kim.auto-brightness.plist

# Stop daemon
launchctl unload ~/Library/LaunchAgents/com.kim.auto-brightness.plist

# Run manually (foreground)
auto-brightness
```

## Requirements

- macOS (Apple Silicon supported)
- Python 3 (pre-installed on macOS)

## Technical Details

Uses Apple's private `DisplayServices` framework for brightness control - the same API that apps like MonitorControl use. Works on Apple Silicon where public APIs are locked down.

## License

MIT
