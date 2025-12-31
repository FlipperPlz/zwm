#!/bin/bash
# test_xephyr.sh - Test ZWM in Xephyr
set -e

echo "╔══════════════════════════════════════╗"
echo "║   ZWM Xephyr Test Script            ║"
echo "╚══════════════════════════════════════╝"
echo ""

# Build zwm
echo "📦 Building zwm..."
cd /devel/zwm
zig build || {
    echo "❌ Build failed!"
    exit 1
}
echo "✅ Build successful!"
echo ""

# Check if Xephyr is installed
if ! command -v Xephyr &> /dev/null; then
    echo "❌ Xephyr not found. Install with:"
    echo "   sudo pacman -S xorg-server-xephyr  # Arch"
    echo "   sudo apt install xserver-xephyr    # Debian/Ubuntu"
    exit 1
fi

# Check if xterm is installed
if ! command -v xterm &> /dev/null; then
    echo "⚠️  xterm not found. Install with:"
    echo "   sudo pacman -S xterm  # Arch"
    echo "   sudo apt install xterm # Debian/Ubuntu"
    echo "Continuing without xterm..."
fi

echo "🚀 Starting Xephyr on display :1..."
Xephyr -screen 1600x900 -br -reset -terminate :1 2>/dev/null &
XEPHYR_PID=$!
echo "   Xephyr PID: $XEPHYR_PID"
sleep 2

# Check if Xephyr started
if ! ps -p $XEPHYR_PID > /dev/null; then
    echo "❌ Xephyr failed to start!"
    exit 1
fi

echo "✅ Xephyr running on :1"
echo ""

echo "🪟 Starting zwm..."
DISPLAY=:1 ./zig-out/bin/zwm &
ZWM_PID=$!
echo "   ZWM PID: $ZWM_PID"
sleep 1

# Check if zwm started
if ! ps -p $ZWM_PID > /dev/null; then
    echo "❌ ZWM failed to start!"
    kill $XEPHYR_PID 2>/dev/null
    exit 1
fi

echo "✅ ZWM running!"
echo ""

# Launch test applications if xterm is available

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✨ ZWM Test Environment Running!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Test Instructions:"
echo "   1. Check if windows appear"
echo "   2. Try keyboard shortcuts (if implemented)"
echo "   3. Test window focus and management"
echo ""
echo "🎮 Default Keybindings (when implemented):"
echo "   Mod+Return     - Spawn terminal"
echo "   Mod+[1-9]      - View tag 1-9"
echo "   Mod+Shift+C    - Kill window"
echo "   Mod+Space      - Cycle layouts"
echo "   Mod+Tab        - Zoom (swap master/stack)"
echo ""
echo "Press Ctrl+C to stop and cleanup..."
echo ""

# Wait for user interrupt
trap "echo ''; echo '🛑 Stopping...'; kill $ZWM_PID $XEPHYR_PID 2>/dev/null; echo '✅ Cleanup complete!'; exit 0" INT

# Keep running
while ps -p $ZWM_PID > /dev/null && ps -p $XEPHYR_PID > /dev/null; do
    sleep 1
done

echo ""
echo "⚠️  Process terminated unexpectedly"
kill $ZWM_PID $XEPHYR_PID 2>/dev/null
echo "✅ Cleanup complete!"

