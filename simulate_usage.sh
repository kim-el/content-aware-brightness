#!/bin/bash
# SIMULATE_USAGE.SH - Simulates screen content changes to trigger brightness adjustments
# Usage: ./simulate_usage.sh [duration_seconds]

DURATION=${1:-30}
echo "Simulating screen content changes for ${DURATION} seconds..."
echo "This will switch between dark/light content to trigger your app."
echo ""

# Create temp HTML files for dark/light content
DARK_HTML="/tmp/dark_screen.html"
LIGHT_HTML="/tmp/light_screen.html"

cat > "$DARK_HTML" << 'EOF'
<!DOCTYPE html>
<html><head><style>body{margin:0;background:#000;height:100vh;}</style></head><body></body></html>
EOF

cat > "$LIGHT_HTML" << 'EOF'
<!DOCTYPE html>
<html><head><style>body{margin:0;background:#fff;height:100vh;}</style></head><body></body></html>
EOF

echo "Starting simulation..."
END=$((SECONDS + DURATION))
CYCLE=0

while [ $SECONDS -lt $END ]; do
    CYCLE=$((CYCLE + 1))

    # Alternate between dark and light
    if [ $((CYCLE % 2)) -eq 0 ]; then
        echo "[$CYCLE] Switching to LIGHT content..."
        open -a "Safari" "$LIGHT_HTML" 2>/dev/null || open "$LIGHT_HTML"
    else
        echo "[$CYCLE] Switching to DARK content..."
        open -a "Safari" "$DARK_HTML" 2>/dev/null || open "$DARK_HTML"
    fi

    # Wait for app to detect and adjust (your app samples every 3 seconds)
    sleep 4
done

echo ""
echo "Simulation complete. $CYCLE cycles performed."

# Cleanup
rm -f "$DARK_HTML" "$LIGHT_HTML"
